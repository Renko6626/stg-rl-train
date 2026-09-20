"""配置：默认值 + TOML 读写 + 校验（spec §4 / §5）。reward 项名的合法性由 reward.RewardFn 校验。"""
from __future__ import annotations

import copy
import json
import tomllib
from pathlib import Path

DEFAULTS: dict = {
    "run": {"seed": 1, "device": "auto", "total_updates": 2000, "ckpt_every": 50, "eval_every": 50,
            "torch_threads": 2, "max_minutes": 0.0},
    "env": {"cards_dir": "cards", "eval_splits": "eval/splits.toml", "num_envs": 2048, "threads": 0,
            "frame_skip": 1, "max_frames": 3600, "warmup_max": 120, "bullets_cap": 1024, "ranks": [2],
            "mirror": True},
    "intent": {"name": "lower_half_uniform_v1", "margin": 16.0, "interval": [120, 300],
               "mix": {"follow": 0.6, "anchor": 0.3, "free": 0.1}},
    "curriculum": {"enabled": True, "interval": 20, "ema_decay": 0.98, "alpha": 1.0, "fail_floor": 0.05,
                   "fail_ceil": 0.95, "w_lo": 0.25, "w_hi": 4.0, "min_episodes": 30},
    # 手部运动层（实验 N）：策略只说「想按哪个方向」，实际按出去的由 envwrap.MotorLayer 决定。
    # hold = 每段方向最短保持帧数的抽样区间（闭区间，换段时抽，对模型不可见）；delay = 变向生效延迟的抽样区间。
    "motor": {"enabled": False, "hold": [2, 6], "delay": [0, 0]},
    "featurize": {"name": "danger_topk_v3", "k_bullets": 64, "k_enemies": 8, "horizon": 60, "d_max": 128.0},
    "model": {"name": "set_attn_v1", "d": 64, "heads": 4, "trunk": 256},
    "reward": {"hold_radius": 24.0, "edge_margin": 16.0, "quick_frames": 3,
               "terms": {"death": 10.0, "follow_shaping": 1.0, "hold": 0.01, "segment_survived": 0.0,
                         "key_press": 0.0, "quick_change": 0.0, "shift_toggle": 0.0, "edge_hug": 0.0}},
    "ppo": {"num_steps": 64, "gamma": 0.995, "gae_lambda": 0.95, "num_minibatches": 8, "update_epochs": 4,
            "clip_coef": 0.2, "clip_vloss": True, "ent_coef": 0.01, "vf_coef": 0.5, "max_grad_norm": 0.5,
            "learning_rate": 3e-4, "anneal_lr": True, "norm_adv": True, "compile": True, "cudagraphs": True},
    # eval.intent 把**评测用的意图钉死**，与训练意图解耦：实验 I 用 mixed_v1 训练，评测仍走规范的
    # 跟点档，撑过率才跟 G0/H 同口径可比（锚点 / 自由档的数字用 eval_ckpt --intent 单独跑）。
    # eval.motor："train" = 评测沿用 [motor]（主判据，与训练同分布）；"off" = 评测关掉运动层。
    "eval": {"episodes": 32, "greedy": True, "seed": 12345, "intent": "lower_half_uniform_v1", "motor": "train",
             # batched：把局数相同的评测组并成一批同步推进（一次前向），墙钟从各组之和变成最慢一组；false = 逐组单跑
             "batched": True},
    "log": {"tensorboard": True, "perf_sync_every": 20, "sample_hz": 1.0},
    "bench": {"seconds": 10.0, "num_envs": [512, 1024, 2048, 4096]},
}

# 这些 section 的子键允许自由增删（模型/特征化器/意图/reward 项各有自己的参数）。
_FREE_SECTIONS = {("model",), ("featurize",), ("intent",), ("reward", "terms")}


def deep_merge(base: dict, over: dict) -> dict:
    out = copy.deepcopy(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def _check_keys(cfg: dict, ref: dict, path: tuple[str, ...] = ()) -> None:
    if path in _FREE_SECTIONS:
        return
    for k, v in cfg.items():
        if k not in ref:
            raise ValueError(f"未知配置键 {'.'.join(path + (k,))}")
        if isinstance(v, dict) and isinstance(ref[k], dict):
            _check_keys(v, ref[k], path + (k,))


def validate(cfg: dict) -> None:
    _check_keys(cfg, DEFAULTS)
    run, env, ppo, feat, intent = cfg["run"], cfg["env"], cfg["ppo"], cfg["featurize"], cfg["intent"]
    if run["device"] not in ("auto", "cuda", "cpu"):
        raise ValueError(f"run.device 须为 auto/cuda/cpu，得 {run['device']!r}")
    if env["num_envs"] < 1 or env["frame_skip"] < 1 or env["max_frames"] < 1:
        raise ValueError("env.num_envs / frame_skip / max_frames 须 ≥ 1")
    if not 1 <= env["bullets_cap"] <= 8192:
        raise ValueError(f"env.bullets_cap 须在 1..=8192，得 {env['bullets_cap']}")
    if not env["ranks"] or any(not 0 <= r <= 4 for r in env["ranks"]):
        raise ValueError(f"env.ranks 须非空且每项在 0..=4，得 {env['ranks']}")
    if not 1 <= feat["k_bullets"] <= env["bullets_cap"]:
        raise ValueError(f"featurize.k_bullets 须在 1..=bullets_cap({env['bullets_cap']})，得 {feat['k_bullets']}")
    if not 1 <= feat["k_enemies"] <= 256:
        raise ValueError(f"featurize.k_enemies 须在 1..=256，得 {feat['k_enemies']}")
    cur = cfg["curriculum"]
    if not 0.0 < cur["ema_decay"] < 1.0:
        raise ValueError(f"curriculum.ema_decay 须在 (0,1)，得 {cur['ema_decay']}")
    if not 0.0 <= cur["fail_floor"] < cur["fail_ceil"] <= 1.0:
        raise ValueError("curriculum 须满足 0 <= fail_floor < fail_ceil <= 1")
    if not 0.0 < cur["w_lo"] <= 1.0 <= cur["w_hi"]:
        raise ValueError("curriculum 须满足 0 < w_lo <= 1 <= w_hi")
    if cur["interval"] < 1 or cur["min_episodes"] < 1 or cur["alpha"] <= 0:
        raise ValueError("curriculum.interval / min_episodes 须 ≥ 1，alpha 须 > 0")
    mot = cfg["motor"]
    for k in ("hold", "delay"):
        lo_hi = mot[k]
        if len(lo_hi) != 2 or not 0 <= lo_hi[0] <= lo_hi[1] <= 120:
            raise ValueError(f"motor.{k} 须为 [lo, hi] 且 0 <= lo <= hi <= 120，得 {lo_hi}")
    if cfg["eval"]["motor"] not in ("train", "off"):
        raise ValueError(f"eval.motor 须为 train/off，得 {cfg['eval']['motor']!r}")
    mix = intent["mix"]
    if any(v < 0 for v in mix.values()) or sum(mix.values()) <= 0:
        raise ValueError(f"intent.mix 须非负且和 > 0，得 {mix}")
    lo, hi = intent["interval"]
    if not 0 < lo <= hi:
        raise ValueError(f"intent.interval 须满足 0 < lo <= hi，得 {intent['interval']}")
    if (env["num_envs"] * ppo["num_steps"]) % ppo["num_minibatches"] != 0:
        raise ValueError("num_envs × ppo.num_steps 须能被 ppo.num_minibatches 整除（CUDA 图要求固定 minibatch 形状）")
    for k in ("total_updates", "ckpt_every", "eval_every", "torch_threads"):
        if run[k] < 1:
            raise ValueError(f"run.{k} 须 ≥ 1")
    if run["max_minutes"] < 0:
        raise ValueError("run.max_minutes 须 ≥ 0（0 = 不限时）")


def from_dict(d: dict) -> dict:
    cfg = deep_merge(DEFAULTS, d)
    validate(cfg)
    return cfg


def load_config(path: str | Path, overrides: dict | None = None) -> dict:
    with open(path, "rb") as f:
        user = tomllib.load(f)
    if overrides:
        user = deep_merge(user, overrides)
    return from_dict(user)


def _toml_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "[" + ", ".join(_toml_value(x) for x in v) + "]"
    raise TypeError(f"dump_toml 不支持的值类型 {type(v).__name__}")


def _dump_table(d: dict, prefix: str, lines: list[str]) -> None:
    scalars = {k: v for k, v in d.items() if not isinstance(v, dict)}
    tables = {k: v for k, v in d.items() if isinstance(v, dict)}
    if prefix and scalars:
        lines.append(f"[{prefix}]")
    for k, v in scalars.items():
        lines.append(f"{k} = {_toml_value(v)}")
    if scalars:
        lines.append("")
    for k, v in tables.items():
        _dump_table(v, f"{prefix}.{k}" if prefix else k, lines)


def dump_toml(cfg: dict, path: str | Path) -> None:
    lines: list[str] = []
    _dump_table(cfg, "", lines)
    Path(path).write_text("\n".join(lines), encoding="utf-8")
