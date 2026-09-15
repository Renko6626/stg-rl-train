"""--bench（spec §7.3）：扫 threads × num_envs，测端到端稳态吞吐（env + 胶水 + 未训练模型推理，不做更新）。"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import stg_rl
import torch

from .config import deep_merge
from .envwrap import EnvWrapper
from .perf import machine_info
from .train import build_components, pick_device


def _step(envw, featurizer, model, obs):
    logits, _ = model(featurizer(obs))
    action = torch.distributions.Categorical(logits=logits).sample()
    nxt, _ = envw.step(action)
    return nxt


def _sync(device: torch.device) -> None:
    if device.type == "cuda":
        torch.cuda.synchronize()


def run_bench(cfg: dict, out_dir: Path) -> dict:
    device = pick_device(cfg["run"]["device"])
    images, starts, _, featurizer, factory = build_components(cfg, device)
    model = factory().to(device).eval()
    cpu = os.cpu_count() or 1
    grid = sorted({max(1, cpu // 4), max(1, cpu // 2), cpu})
    seconds = float(cfg["bench"]["seconds"])
    results = []
    print(f"{'num_envs':>8} {'threads':>7} {'env_steps/s':>12}")
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))  # 与训练一致，否则 bench 的线程数结论不可迁移
    for n in cfg["bench"]["num_envs"]:
        for threads in sorted({min(t, int(n)) for t in grid}):
            c = deep_merge(cfg, {"env": {"num_envs": int(n), "threads": threads}})
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
            row = {"num_envs": int(n), "threads": min(threads, int(n)), "steps": steps, "seconds": dt,
                   "env_steps_per_s": steps * int(n) * envw.frame_skip / dt}
            results.append(row)
            print(f"{row['num_envs']:>8} {row['threads']:>7} {row['env_steps_per_s']:>12.0f}")
            del envw
    best = max(results, key=lambda r: r["env_steps_per_s"])
    out = {"machine": machine_info(), "stg_rl": stg_rl.build_info(), "results": results,
           "recommended": {"num_envs": best["num_envs"], "threads": best["threads"]}}
    (Path(out_dir) / "bench.json").write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"推荐：env.num_envs = {best['num_envs']}，env.threads = {best['threads']}")
    return out
