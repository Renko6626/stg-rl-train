"""--bench（spec §7.3）：扫 threads × num_envs，测**端到端**吞吐并给出推荐配置。

一次 PPO 迭代 = rollout（T 步 env + 胶水 + 推理）+ 一次更新（epochs × minibatches 的前向反向）。
`num_envs` 同时决定两边：rollout 吞吐随 env 数上升，但批量 = num_envs × num_steps 也随之变大，
更新耗时跟着涨。只按 rollout 选会选出「rollout 快、更新慢到跑不动」的配置（笔记本 4050 实测：
4096 env 的 rollout 77k steps/s，一次更新却要 ~425 s）。所以这里两段都测，按端到端 SPS 推荐。

更新耗时用**一个 minibatch 实测 × epochs × minibatches** 外推（整次更新太贵）；
测的是未编译路径，compile / CUDA 图的加速对各 num_envs 大致同比，不影响排序——数值本身偏保守。
"""
from __future__ import annotations

import json
import time
from pathlib import Path

import stg_rl
import torch
from tensordict import TensorDict

from .config import deep_merge
from .envwrap import EnvWrapper, usable_cpus
from .perf import machine_info
from .ppo import PPO
from .train import build_components, pick_device

MB_WARMUP, MB_MEASURE = 1, 3
# 推荐规则：端到端吞吐在最优的 RECOMMEND_TOL 以内时，取 **num_envs 最小**的那档。
# 批量 = num_envs × num_steps，同样帧数下批量越大梯度更新次数越少、每帧学习效率越低；
# 吞吐差几个百分点不值得拿样本效率换（4090 实测 2048 → 4096 吞吐只 +18%，批量却翻倍）。
RECOMMEND_TOL = 0.95


def _step(envw, featurizer, model, obs):
    logits, _ = model(featurizer(obs))
    action = torch.distributions.Categorical(logits=logits).sample()
    nxt, _ = envw.step(action)
    return nxt


def _sync(device: torch.device) -> None:
    if device.type == "cuda":
        torch.cuda.synchronize()


def _tile(x: torch.Tensor, rows: int) -> torch.Tensor:
    reps = (rows + x.shape[0] - 1) // x.shape[0]
    return x.repeat(reps, *([1] * (x.dim() - 1)))[:rows].contiguous()


def minibatch_seconds(cfg: dict, device: torch.device, featurizer, factory, obs) -> tuple[float, int]:
    """一个 minibatch 的前向 + 反向 + optimizer.step 的秒数，以及 minibatch 行数。"""
    p = cfg["ppo"]
    rows = max(1, cfg["env"]["num_envs"] * int(p["num_steps"]) // int(p["num_minibatches"]))
    c = deep_merge(cfg, {"ppo": {"compile": False, "cudagraphs": False}})
    ppo = PPO(c, factory, device)
    feats = TensorDict({k: _tile(v, rows) for k, v in featurizer(obs).items()}, batch_size=[rows], device=device)
    zeros = torch.zeros(rows, device=device)
    args = (feats, torch.zeros(rows, dtype=torch.long, device=device), zeros, zeros, zeros, zeros)
    for _ in range(MB_WARMUP):
        ppo._update(*args)
    _sync(device)
    t0 = time.perf_counter()
    for _ in range(MB_MEASURE):
        ppo._update(*args)
    _sync(device)
    dt = (time.perf_counter() - t0) / MB_MEASURE
    del ppo, feats
    if device.type == "cuda":
        torch.cuda.empty_cache()
    return dt, rows


def run_bench(cfg: dict, out_dir: Path) -> dict:
    device = pick_device(cfg["run"]["device"])
    images, starts, _, featurizer, factory = build_components(cfg, device)
    model = factory().to(device).eval()
    cpu = usable_cpus()
    # 线程网格：大机器上线程数远超实际并行度反而崩（255 核机实测 255 线程只有 63 线程的 1/8），
    # 所以从小往大都要试，别只试 cpu/4 以上。
    grid = sorted({t for t in (8, 16, 32, cpu // 8, cpu // 4, cpu // 2, cpu) if t >= 1})
    seconds = float(cfg["bench"]["seconds"])
    num_steps = int(cfg["ppo"]["num_steps"])
    epochs_mb = int(cfg["ppo"]["update_epochs"]) * int(cfg["ppo"]["num_minibatches"])
    results: list[dict] = []
    skipped: list[dict] = []
    print(f"{'num_envs':>8} {'threads':>7} {'rollout/s':>11} {'update_s':>9} {'端到端/s':>10}")
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))  # 与训练一致，否则 bench 的线程数结论不可迁移
    for n in cfg["bench"]["num_envs"]:
        update_s = None
        for threads in sorted({min(t, int(n)) for t in grid}):
            c = deep_merge(cfg, {"env": {"num_envs": int(n), "threads": threads}})
            try:
                envw = EnvWrapper(c, images, starts, device, seed=int(c["run"]["seed"]))
                with torch.no_grad():
                    obs = envw.reset()
                    for _ in range(10):
                        obs = _step(envw, featurizer, model, obs)
                    _sync(device)
                    t0, steps = time.perf_counter(), 0
                    while time.perf_counter() - t0 < seconds:
                        obs = _step(envw, featurizer, model, obs)
                        steps += 1
                    _sync(device)
                    dt = time.perf_counter() - t0
                if update_s is None:  # 更新耗时只跟 num_envs 有关，同一 n 的各 threads 复用
                    mb_s, mb_rows = minibatch_seconds(c, device, featurizer, factory, obs)
                    update_s, update_rows = mb_s * epochs_mb, mb_rows
                del envw, obs
            except torch.OutOfMemoryError as e:
                skipped.append({"num_envs": int(n), "threads": threads, "reason": f"显存不足：{e}".split("\n")[0]})
                print(f"{n:>8} {threads:>7}  显存不足，跳过")
                if device.type == "cuda":
                    torch.cuda.empty_cache()
                continue
            frame_skip = int(c["env"]["frame_skip"])
            rollout_sps = steps * int(n) * frame_skip / dt
            iter_steps = int(n) * num_steps * frame_skip
            end_to_end = iter_steps / (iter_steps / rollout_sps + update_s)
            row = {"num_envs": int(n), "threads": min(threads, int(n)), "steps": steps, "seconds": dt,
                   "env_steps_per_s": rollout_sps, "update_s": update_s, "minibatch_rows": update_rows,
                   "end_to_end_steps_per_s": end_to_end}
            if device.type == "cuda":
                row["gpu_max_alloc_mb"] = torch.cuda.max_memory_allocated() / 2**20
            results.append(row)
            print(f"{row['num_envs']:>8} {row['threads']:>7} {rollout_sps:>11.0f} {update_s:>9.2f} {end_to_end:>10.0f}")
    if not results:
        raise RuntimeError(f"bench 没有可用配置（全部失败）：{skipped}")
    pick, best = recommend(results)
    out = {"machine": machine_info(), "stg_rl": stg_rl.build_info(), "results": results, "skipped": skipped,
           "recommended": {"num_envs": pick["num_envs"], "threads": pick["threads"]},
           "fastest": {"num_envs": best["num_envs"], "threads": best["threads"],
                       "end_to_end_steps_per_s": best["end_to_end_steps_per_s"]},
           "note": f"端到端吞吐（rollout + 一次更新）在最快的 {RECOMMEND_TOL:.0%} 以内时取 num_envs 最小的一档"
                   "（同等速度下小批量的样本效率更好）；update_s 由单 minibatch 实测 × epochs × minibatches 外推，未编译，偏保守"}
    (Path(out_dir) / "bench.json").write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"推荐：env.num_envs = {pick['num_envs']}，env.threads = {pick['threads']}"
          f"（端到端 {pick['end_to_end_steps_per_s']:.0f} steps/s，一次更新 {pick['update_s']:.1f} s）")
    if pick["num_envs"] != best["num_envs"]:
        print(f"（最快的是 {best['num_envs']} env / {best['end_to_end_steps_per_s']:.0f} steps/s，"
              f"只快 {best['end_to_end_steps_per_s'] / pick['end_to_end_steps_per_s'] - 1:.1%}，不值得把批量翻倍）")
    return out


def recommend(results: list[dict], tol: float = RECOMMEND_TOL) -> tuple[dict, dict]:
    """→ (推荐行, 最快行)。推荐 = 吞吐在最快的 tol 以内的那些档里 num_envs 最小的，同档取最快线程数。"""
    best = max(results, key=lambda r: r["end_to_end_steps_per_s"])
    floor = tol * best["end_to_end_steps_per_s"]
    min_n = min(r["num_envs"] for r in results if r["end_to_end_steps_per_s"] >= floor)
    pick = max((r for r in results if r["num_envs"] == min_n), key=lambda r: r["end_to_end_steps_per_s"])
    return pick, best
