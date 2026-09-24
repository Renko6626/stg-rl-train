"""PPO 一个 minibatch 的更新（前向 + 反向 + Adam）拆到算子：瓶颈在注意力、FFN、LayerNorm 还是别处？

不跑环境：按配置建出特征化器与 PPO，用随机特征喂一个与训练同形状的 minibatch（num_envs × num_steps / num_minibatches），
对每个 (配置, amp) 组合：
  1. 编译 + CUDA 图（与训练相同）下计时 ITERS 次，得到真实的每 minibatch 毫秒数；
  2. 关掉编译与 CUDA 图（否则整段是一次图重放、看不到算子），用 torch.profiler 按算子汇总 GPU 时间。

    python scripts/profile_update.py OUT_DIR configs/exp-q2-raw.toml configs/exp-r1a-sa1.toml …
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import torch
from tensordict import TensorDict

from stgtrain.config import deep_merge, from_dict, load_config
from stgtrain.ppo import PPO
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

ITERS, WARMUP = int(os.environ.get("ITERS", 20)), int(os.environ.get("WARMUP", 25))
DEVICE = torch.device(os.environ.get("DEVICE", "cuda"))   # 本机没卡时 DEVICE=cpu 只验流程


def sync() -> None:
    if DEVICE.type == "cuda":
        torch.cuda.synchronize()


def fake_feats(spec: dict, n: int, device) -> TensorDict:
    g = torch.Generator(device="cpu").manual_seed(0)
    out = {}
    for k, shape in spec.items():
        if k.endswith("_mask"):
            out[k] = (torch.rand(n, *shape, generator=g) < 0.7).to(device)
        else:
            out[k] = torch.randn(n, *shape, generator=g).to(device)
    return TensorDict(out, batch_size=[n])


def minibatch(cfg: dict, spec: dict, device) -> TensorDict:
    p = cfg["ppo"]
    n = cfg["env"]["num_envs"] * p["num_steps"] // p["num_minibatches"]
    return TensorDict(feats=fake_feats(spec, n, device), actions=torch.randint(0, 18, (n,), device=device),
                      logprobs=torch.full((n,), -2.89, device=device), advantages=torch.randn(n, device=device),
                      returns=torch.randn(n, device=device), vals=torch.randn(n, device=device), batch_size=[n])


def build(path: str, amp: str, fast: bool, device):
    over = {"ppo": {"amp": amp, "compile": fast, "cudagraphs": fast}, "run": {"device": device.type}}
    cfg = from_dict(deep_merge(load_config(path), over))
    feat = FEATURIZERS.get(cfg["featurize"]["name"])(cfg)
    ppo = PPO(cfg, lambda: MODELS.get(cfg["model"]["name"])(cfg, feat.spec()), device)
    return cfg, ppo, minibatch(cfg, feat.spec(), device)


def step(ppo, mb):
    torch.compiler.cudagraph_mark_step_begin()
    ppo.update(mb, tensordict_out=TensorDict())


def timed_ms(ppo, mb) -> float:
    for _ in range(WARMUP):
        step(ppo, mb)
    sync()
    t = time.perf_counter()
    for _ in range(ITERS):
        step(ppo, mb)
    sync()
    return (time.perf_counter() - t) / ITERS * 1e3


def profile(ppo, mb, top: int = 25) -> tuple[str, list[dict]]:
    from torch.profiler import ProfilerActivity, profile as prof
    for _ in range(3):
        step(ppo, mb)
    sync()
    with prof(activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA]) as p:
        for _ in range(5):
            step(ppo, mb)
        sync()
    avg = p.key_averages()
    rows = sorted(({"op": e.key, "cuda_ms": e.device_time_total / 1e3 / 5, "calls": e.count // 5} for e in avg
                   if e.device_time_total > 0), key=lambda r: -r["cuda_ms"])
    return avg.table(sort_by="device_time_total", row_limit=top), rows[:top]


def main(argv: list[str]) -> int:
    out, paths = Path(argv[0]), argv[1:]
    out.mkdir(parents=True, exist_ok=True)
    load_builtins()
    device = DEVICE
    summary = {}
    for path in paths:
        for amp in ("off", "bf16"):
            name = f"{Path(path).stem}-{amp}"
            _, fast, mb = build(path, amp, True, device)
            ms = timed_ms(fast, mb)
            del fast
            _, eager, mb = build(path, amp, False, device)
            eager_ms = timed_ms(eager, mb)
            table, rows = profile(eager, mb)
            del eager
            if device.type == "cuda":
                torch.cuda.empty_cache()
            (out / f"{name}.txt").write_text(table)
            summary[name] = {"minibatch": mb.batch_size[0], "compiled_ms": ms, "eager_ms": eager_ms, "top_ops": rows}
            print(f"== {name}: 编译 {ms:.1f} ms / eager {eager_ms:.1f} ms（每 minibatch {mb.batch_size[0]} 样本）", flush=True)
            for r in rows[:12]:
                print(f"   {r['cuda_ms']:8.2f} ms  ×{r['calls']:<4} {r['op'][:90]}", flush=True)
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
