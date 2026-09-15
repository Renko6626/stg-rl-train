"""GPU 验收（spec §8）：同一初始权重、同一批 rollout 数据，compile + CUDA 图 开 / 关 各做一次 train_step，
比较损失统计量的相对误差（阈值 1e-4）。

用法：uv run --frozen python -m stgtrain.gpucheck configs/base.toml
"""
from __future__ import annotations

import argparse

import torch

from .config import deep_merge, load_config
from .envwrap import EnvWrapper
from .episodes import EpisodeTracker
from .ppo import PPO
from .registry import MODELS
from .reward import RewardFn
from .train import build_components

TOLERANCE = 1e-4


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.gpucheck")
    ap.add_argument("config")
    args = ap.parse_args(argv)
    if not torch.cuda.is_available():
        print("gpucheck 需要 CUDA")
        return 2
    device = torch.device("cuda")
    base = load_config(args.config, {"run": {"device": "cuda"}})
    images, starts, _, featurizer, _ = build_components(base, device)
    spec = featurizer.spec()

    def make(ppo_over: dict) -> PPO:
        c = deep_merge(base, {"ppo": ppo_over})
        cls = MODELS.get(c["model"]["name"])
        torch.manual_seed(0)
        return PPO(c, lambda: cls(c, spec), device)

    off = make({"compile": False, "cudagraphs": False})
    on = make({"compile": True, "cudagraphs": True})
    envw = EnvWrapper(base, images, starts, device, seed=0)
    rf = RewardFn(base)
    tracker = EpisodeTracker(envw.n, device, list(rf.terms), base["reward"]["hold_radius"],
                             base["reward"]["edge_margin"], envw.frame_skip, base["intent"]["interval"][1])
    _, container, next_value = off.rollout(envw, featurizer, rf, tracker, None, envw.reset())
    stats = {}
    for name, ppo in (("off", off), ("on", on)):
        torch.manual_seed(123)
        stats[name] = ppo.train_step(container.clone(), next_value.clone(), 1, 10)
    worst = 0.0
    for k in ("pg_loss", "v_loss", "entropy_loss", "approx_kl"):
        a, b = stats["off"][k], stats["on"][k]
        rel = abs(a - b) / max(abs(a), 1e-8)
        worst = max(worst, rel)
        print(f"{k:>14}  off={a:.8g}  on={b:.8g}  rel={rel:.3g}")
    ok = worst <= TOLERANCE
    print("PASS" if ok else f"FAIL（最大相对误差 {worst:.3g} > {TOLERANCE}）")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
