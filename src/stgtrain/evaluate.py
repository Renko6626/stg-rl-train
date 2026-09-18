"""固定评测集（spec §6 + 计划 Ruling 5）：每个 (卡, rank) 开一个 num_envs = episodes 的 VecEnv，
env 种子与意图种子固定、不镜像，每个 env 只取第一局 ⇒ 不同 checkpoint 之间可直接比较。"""
from __future__ import annotations

import copy

import statistics

import stg_rl
import torch
from torch import Tensor

from .cards import EvalSpec
from .envwrap import EnvWrapper
from .episodes import EpisodeTracker
from .reward import RewardFn


def summarize_eval(records: list[dict]) -> dict[str, float]:
    n = len(records)
    if n == 0:
        return {"episodes": 0.0}

    def mean(k: str) -> float:
        return sum(float(r[k]) for r in records) / n

    def frac(code: int) -> float:
        return sum(1 for r in records if r["done"] == code) / n

    return {
        "episodes": float(n), "survival": frac(2), "death": frac(1), "timeout": frac(3),
        "frames_mean": mean("frames"), "return_mean": mean("return"), "in_r_frac": mean("in_r_frac"),
        "reach_frames_median": float(statistics.median(float(r["reach_frames"]) for r in records)),
        "shift_toggles_per_s": mean("shift_toggles_per_s"), "dir_changes_per_s": mean("dir_changes_per_s"),
        "edge_frac": mean("edge_frac"), "key_presses_per_s": mean("key_presses_per_s"),
        "graze_per_s": mean("graze_per_s"), "close4_frac": mean("close4_frac"), "close12_frac": mean("close12_frac"),
        "dir_changes_in_r_per_s": pooled_rate(records, "dir_changes_in_r", "secs_in_r"),
        "dir_changes_near_per_s": pooled_rate(records, "dir_changes_near", "secs_near"),
        "dir_changes_far_per_s": pooled_rate(records, "dir_changes_far", "secs_far"),
        "quick_frac": mean("quick_frac"),
        "dir_changes_out_r_per_s": pooled_rate(records, "dir_changes_out_r", "secs_out_r"),
    }


def pooled_rate(records: list[dict], count_key: str, secs_key: str) -> float:
    secs = sum(float(r[secs_key]) for r in records)
    return sum(float(r[count_key]) for r in records) / secs if secs > 0 else 0.0


def score(overall: dict) -> tuple[float, float]:
    return float(overall.get("survival", 0.0)), float(overall.get("in_r_frac", 0.0))


def hysteresis_action(logits: Tensor, prev: Tensor, tau: float) -> Tensor:
    """诊断用滞回：只有最优动作的 logit 比上一步动作高出 **超过** τ 才换，否则保持上一步。τ = 0 等价 argmax。"""
    best = logits.argmax(-1)
    keep = logits.max(-1).values - logits.gather(-1, prev.unsqueeze(-1)).squeeze(-1) <= tau
    return torch.where(keep & (tau > 0), prev, best)


def eval_cfg(cfg: dict) -> dict:
    """评测用的配置：`eval.intent` 非空时覆盖意图（训练意图换了，尺子不跟着换）。"""
    name = cfg["eval"].get("intent") or cfg["intent"]["name"]
    if name == cfg["intent"]["name"]:
        return cfg
    c = copy.deepcopy(cfg)
    c["intent"]["name"] = name
    return c


def run_group(cfg: dict, ppo, featurizer, image, card: str, rank: int, episodes: int, device,
              hysteresis: float = 0.0) -> list[dict]:
    cfg = eval_cfg(cfg)
    envw = EnvWrapper(cfg, {card: image}, [stg_rl.Start(card, 0, rank)], device,
                      seed=int(cfg["eval"]["seed"]), num_envs=episodes, mirror=False)
    reward_fn = RewardFn(cfg)
    tracker = EpisodeTracker(episodes, device, list(reward_fn.terms), cfg["reward"]["hold_radius"],
                             cfg["reward"]["edge_margin"], envw.frame_skip, cfg["intent"]["interval"][1])
    greedy = bool(cfg["eval"]["greedy"])
    first: dict[int, dict] = {}
    obs = envw.reset()
    # 每个 env 的第一局最迟在 max_frames 帧内结束（预热发生在 step 内部，不占步数）
    max_steps = int(cfg["env"]["max_frames"]) // envw.frame_skip + 2
    for step in range(max_steps):
        if hysteresis > 0:
            logits, _ = ppo.agent_inference.model(featurizer(obs))
            action = hysteresis_action(logits, obs.prev_action.to(logits.device), hysteresis)
        else:
            action = ppo.act(featurizer(obs), greedy)
        nxt, info = envw.step(action)
        total, raw = reward_fn(obs, nxt, info)
        tracker.update(obs, nxt, info, total, raw)
        obs = nxt
        if (step + 1) % 64 == 0:
            for r in tracker.pop_finished():
                first.setdefault(r["env"], r)
            if len(first) == episodes:
                break
    for r in tracker.pop_finished():
        first.setdefault(r["env"], r)
    if len(first) != episodes:
        raise RuntimeError(f"评测组 {card} r{rank} 只收到 {len(first)}/{episodes} 局")
    return [first[i] for i in sorted(first)]


def evaluate(cfg: dict, ppo, featurizer, images: dict, specs: list[EvalSpec], device, hysteresis: float = 0.0) -> dict:
    result: dict = {"cards": {}, "overall": {}}
    everything: list[dict] = []
    for spec in specs:
        per: dict[str, dict] = {}
        for rank in spec.ranks:
            recs = run_group(cfg, ppo, featurizer, images[spec.card], spec.card, rank, spec.episodes, device, hysteresis)
            per[f"r{rank}"] = summarize_eval(recs)
            everything.extend(recs)
        result["cards"][spec.card] = per
    result["overall"] = summarize_eval(everything)
    return result
