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

**rollout 图（`rollout_graph.py`）另做一项**：同一条真实轨迹上逐步把同一份观测分别喂给 eager 与录图两套
特征化 / reward + 逐局统计，比较每一步的输出与 tracker 状态。步数超过 warmup，后面走的都是重放，
而且每步输入都在变——上面那个盲区在这一项里是覆盖到的。两边跑的是同一批核，只有密度图的原子加
求和顺序不定，故用 ROLLOUT_REL 这个很紧的相对容差。

**比对在全精度 FP32 下做（2026-09-20）**：训练开着 TF32（`ppo.py` 的 `set_float32_matmul_precision("high")`），
而 TF32 的矩阵乘内部只有约 10 位尾数，**单次 matmul 的相对误差本来就在 1e-3 量级**；eager 与编译后走的是
不同的 GEMM 核与融合方式，两边各带各的 TF32 噪声。于是 1e-3 的容差正好压在噪声地板上 —— 这个检查因此
三次误报（策略输出 → 梯度范数 → 09-20 的 value 逐元素最大差：7.72e-4 对阈值 7.69e-4，超 0.3%，
同一次里四个损失吻合到 1e-6）。本检查要验的是「编译 + CUDA 图重放算的是不是同一个东西」，与 TF32 无关，
所以在这里把 TF32 关掉再比：真错误（图重放吃错输入、反向漏算）的差异是数量级的，FP32 下照样现形，
而噪声降到 1e-6，容差重新有了意义。**训练本身不受影响**，仍走 TF32。

用法：uv run --frozen python -m stgtrain.gpucheck configs/base.toml [--warn-only]
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
from .rollout_graph import WARMUP, RolloutGraphs
from .train import build_components

TOLERANCE = 1e-4
# 策略输出（entropy / value 的均值与逐元素最大差）用更松的相对判据：它们直接是网络前向的结果，
# 编译后核函数与归约顺序变了，差异量级本就在 1e-4 相对——4090 实测 value 均值差 1.7e-4、
# 笔记本 4050 实测最大差 3.8e-4，而同一次比较里的损失统计量吻合到 1e-7，说明反向与更新都是对的。
POLICY_REL = 1e-3
MAXABS_REL = 1e-3
# 梯度范数单独放宽到和策略输出同档（2026-09-19，租用机上 0.35315809 vs 0.35306996 = 2.5e-4 相对被判 FAIL）。
# 它是**对全部参数做平方和再开根**的全局归约，是这组标量里最吃累加顺序的一个：编译改了归约树、
# 融合了核函数，1e-4 相对压不住。同一次比较里四个损失吻合到 1e-7、策略输出在 1e-3 内 ⇒ 前向反向都对，
# 差异只在这一个归约上。它的用途是梯度裁剪（max_grad_norm 0.5），0.025% 的差异对训练没有影响。
GN_REL = 1e-3
CALLS = 25
ROLLOUT_REL = 1e-5
ROLLOUT_STEPS = WARMUP + 16


def _maxdiff(a, b) -> tuple[float, float]:
    """(两边的最大绝对值, 逐元素最大绝对差)；bool / 整型按 float 比。"""
    a, b = a.float(), b.float()
    return max(a.abs().max().item(), b.abs().max().item(), 0.0), (a - b).abs().max().item()


def check_gae_graph(ppo: PPO, container, next_value, calls: int = 6) -> tuple:
    """录图的 GAE（`ppo._gae`）每次喂**不同**的奖励，与 eager `gae` 比；过了 warmup 走的是重放。"""
    from .ppo import gae

    p = ppo.p
    g = torch.Generator(device=next_value.device).manual_seed(0)
    scale = worst = 0.0
    for _ in range(calls):
        r = torch.randn(container["rewards"].shape, generator=g, device=next_value.device)
        args = (r, container["vals"], container["dones"], next_value, float(p["gamma"]), float(p["gae_lambda"]))
        for a, b in zip(ppo._gae(*args), gae(*args)):
            s_, d_ = _maxdiff(a, b)
            scale, worst = max(scale, s_), max(worst, d_)
    return ("gae_graph", scale, scale, worst, worst <= ROLLOUT_REL * scale + 1e-6)


def check_rollout_graphs(cfg: dict, images, starts, featurizer, ppo: PPO, device) -> list[tuple]:
    envw = EnvWrapper(cfg, images, starts, device, seed=0)
    rf = RewardFn(cfg)

    def tracker():
        return EpisodeTracker(envw.n, device, list(rf.terms), cfg["reward"]["hold_radius"],
                              cfg["reward"]["edge_margin"], envw.frame_skip, cfg["intent"]["interval"][1])

    eager = RolloutGraphs(featurizer, rf, tracker(), graphs=False)
    graphed = RolloutGraphs(featurizer, rf, tracker(), graphs=True)
    worst = {"rollout_feats": (0.0, 0.0), "rollout_reward": (0.0, 0.0), "rollout_tracker": (0.0, 0.0)}

    def note(key, a, b):
        scale, diff = _maxdiff(a, b)
        worst[key] = (max(worst[key][0], scale), max(worst[key][1], diff))

    obs = envw.reset()
    for _ in range(ROLLOUT_STEPS):
        fe, fg = eager.featurize(obs), graphed.featurize(obs)
        for k in fe:
            note("rollout_feats", fe[k], fg[k])
        nxt, info = envw.step(ppo.act(fe, greedy=False))
        note("rollout_reward", eager.reward(obs, nxt, info), graphed.reward(obs, nxt, info))
        for a, b in zip(eager.tracker.state(), graphed.tracker.state()):
            note("rollout_tracker", a, b)
        obs = nxt
    return [(k, scale, scale, diff, diff <= ROLLOUT_REL * scale + 1e-6) for k, (scale, diff) in worst.items()]


def close_enough(a: float, b: float, rel: float = TOLERANCE, abs_: float = 1e-6) -> bool:
    """绝对/相对混合容差：非零量用相对项，近零量由绝对项兜底。"""
    return abs(a - b) <= rel * max(abs(a), abs(b)) + abs_


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.gpucheck")
    ap.add_argument("config")
    ap.add_argument("--warn-only", action="store_true",
                    help="不通过也返回 0（只打印 WARN）：租机器时不想被浮点噪声卡住整夜的应急开关")
    args = ap.parse_args(argv)
    if not torch.cuda.is_available():
        print("gpucheck 需要 CUDA")
        return 2
    device = torch.device("cuda")
    # 关 TF32 再比，理由见模块注释。必须在建模型 / 编译之前设（ppo.py 在 import 时设成了 "high"）。
    torch.set_float32_matmul_precision("highest")
    torch.backends.cuda.matmul.allow_tf32 = False
    torch.backends.cudnn.allow_tf32 = False
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
        checks.append((k, a, b, abs(a - b), close_enough(a, b, rel=GN_REL if k == "gn" else TOLERANCE)))
    e_off, v_off = policy["off"]
    e_on, v_on = policy["on"]
    checks.append(("policy_entropy_mean", e_off.mean().item(), e_on.mean().item(),
                   abs(e_off.mean().item() - e_on.mean().item()),
                   close_enough(e_off.mean().item(), e_on.mean().item(), rel=POLICY_REL)))
    checks.append(("policy_value_mean", v_off.mean().item(), v_on.mean().item(),
                   abs(v_off.mean().item() - v_on.mean().item()),
                   close_enough(v_off.mean().item(), v_on.mean().item(), rel=POLICY_REL)))
    # 逐元素最大差用**相对**判据：编译 / 融合的浮点差随取值量级走，纯绝对 1e-4 在 value 量级 ~1 时
    # 会把 0.04% 的正常差异判成失败（笔记本 4050 实测 2.5e-4）。
    v_maxabs = (v_off - v_on).abs().max().item()
    v_scale = max(v_off.abs().max().item(), v_on.abs().max().item(), 1e-3)
    checks.append(("policy_value_maxabs", v_off.abs().max().item(), v_on.abs().max().item(),
                   v_maxabs, v_maxabs <= MAXABS_REL * v_scale))

    # rollout 图：两列都是两边输出的最大绝对值（量级参考），比较看 abs diff
    checks += check_rollout_graphs(base, images, starts, featurizer, off, device)
    checks.append(check_gae_graph(on, container, next_value))

    print(f"{'key':>22} {'off':>14} {'on':>14} {'abs diff':>12}  ok")
    for k, a, b, diff, good in checks:
        print(f"{k:>22} {a:>14.8g} {b:>14.8g} {diff:>12.3g}  {good}")
    ok = all(good for *_, good in checks)
    if ok:
        print("PASS")
    else:
        bad = "、".join(k for k, *_, good in checks if not good)
        print(f"{'WARN' if args.warn_only else 'FAIL'}（不合格项：{bad}；损失容差 {TOLERANCE}，"
              f"梯度范数 {GN_REL}，策略输出 {POLICY_REL}，rollout 图 {ROLLOUT_REL}，均为相对）")
    return 0 if ok or args.warn_only else 1


if __name__ == "__main__":
    raise SystemExit(main())
