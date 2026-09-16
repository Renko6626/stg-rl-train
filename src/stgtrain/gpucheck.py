"""GPU 验收（spec §8）：同一初始权重、同一批 rollout 数据，比较 compile + CUDA 图 开 / 关 的
`train_step` 损失统计量与策略输出。

方法：把 ppo.learning_rate 设为 0 且关掉 anneal_lr，使 `off` / `on` 在多次调用间权重不变，
避免 Adam 舍入误差随更新步数逐步累积放大；`on` 走 torch.compile + CudaGraphModule
（warmup=20），调用 CALLS=25 次，比较的是第 25 次——此时才走图重放而非动态执行。
比较 pg_loss / v_loss / entropy_loss / approx_kl，以及 gn（梯度范数）——lr=0 时梯度仍会计算并
backward，从而把反向路径也纳入被捕获的图；再比较策略 entropy / value 的均值与逐元素最大绝对差。
逐项用绝对/相对混合容差 `abs(a - b) <= rel * max(|a|, |b|) + abs_`：损失可能接近 0，
纯相对误差会把数值噪声放大成巨大百分比，故加 1e-6 绝对下限。
盲区：每次调用都用同一批输入，无法识别「图重放忽略新输入」这类错误。

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
MAXABS_REL = 1e-3  # 逐元素最大差相对取值量级的上限（见 policy_value_maxabs 处注释）
CALLS = 25


def close_enough(a: float, b: float, rel: float = TOLERANCE, abs_: float = 1e-6) -> bool:
    """绝对/相对混合容差：非零量用相对项，近零量由绝对项兜底。"""
    return abs(a - b) <= rel * max(abs(a), abs(b)) + abs_


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.gpucheck")
    ap.add_argument("config")
    args = ap.parse_args(argv)
    if not torch.cuda.is_available():
        print("gpucheck 需要 CUDA")
        return 2
    device = torch.device("cuda")
    base = load_config(args.config, {"run": {"device": "cuda"}, "env": {"num_envs": 256},
                                     "ppo": {"update_epochs": 1, "num_minibatches": 1,
                                             "learning_rate": 0.0, "anneal_lr": False}})
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

    # 损失：各跑 CALLS 次，只比最后一次（on 已过 warmup，走的才是图重放）
    stats = {}
    for name, ppo in (("off", off), ("on", on)):
        last = None
        for _ in range(CALLS):
            torch.manual_seed(123)
            last = ppo.train_step(container.clone(), next_value.clone(), 1, 10)
        stats[name] = last

    # 策略：同一批 feats 各跑 CALLS 次，比最后一次的 entropy / value
    feats = container["feats"][0]
    policy: dict[str, tuple[torch.Tensor, torch.Tensor]] = {}
    for name, ppo in (("off", off), ("on", on)):
        ent = val = None
        for _ in range(CALLS):
            torch.compiler.cudagraph_mark_step_begin()
            _, _, ent, val = ppo.policy(feats)
        policy[name] = (ent, val)

    checks: list[tuple[str, float, float, float, bool]] = []
    for k in ("pg_loss", "v_loss", "entropy_loss", "approx_kl", "gn"):
        a, b = stats["off"][k], stats["on"][k]
        checks.append((k, a, b, abs(a - b), close_enough(a, b)))
    e_off, v_off = policy["off"]
    e_on, v_on = policy["on"]
    checks.append(("policy_entropy_mean", e_off.mean().item(), e_on.mean().item(),
                   abs(e_off.mean().item() - e_on.mean().item()),
                   close_enough(e_off.mean().item(), e_on.mean().item())))
    checks.append(("policy_value_mean", v_off.mean().item(), v_on.mean().item(),
                   abs(v_off.mean().item() - v_on.mean().item()),
                   close_enough(v_off.mean().item(), v_on.mean().item())))
    # 逐元素最大差用**相对**判据：编译 / 融合的浮点差随取值量级走，纯绝对 1e-4 在 value 量级 ~1 时
    # 会把 0.04% 的正常差异判成失败（笔记本 4050 实测 2.5e-4）。
    v_maxabs = (v_off - v_on).abs().max().item()
    v_scale = max(v_off.abs().max().item(), v_on.abs().max().item(), 1e-3)
    checks.append(("policy_value_maxabs", v_off.abs().max().item(), v_on.abs().max().item(),
                   v_maxabs, v_maxabs <= MAXABS_REL * v_scale))

    print(f"{'key':>22} {'off':>14} {'on':>14} {'abs diff':>12}  ok")
    for k, a, b, diff, good in checks:
        print(f"{k:>22} {a:>14.8g} {b:>14.8g} {diff:>12.3g}  {good}")
    ok = all(good for *_, good in checks)
    print("PASS" if ok else f"FAIL（容差 {TOLERANCE}）")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
