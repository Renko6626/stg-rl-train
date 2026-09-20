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

    out = {
        "episodes": float(n), "survival": frac(2), "death": frac(1), "timeout": frac(3),
        "frames_mean": mean("frames"), "return_mean": mean("return"), "in_r_frac": mean("in_r_frac"),
        "reach_frames_median": float(statistics.median(float(r["reach_frames"]) for r in records)),
        "shift_toggles_per_s": mean("shift_toggles_per_s"), "dir_changes_per_s": mean("dir_changes_per_s"),
        "edge_frac": mean("edge_frac"), "key_presses_per_s": mean("key_presses_per_s"),
        "graze_per_s": mean("graze_per_s"), "close4_frac": mean("close4_frac"), "close12_frac": mean("close12_frac"),
        "dir_changes_in_r_per_s": pooled_rate(records, "dir_changes_in_r", "secs_in_r"),
        "dir_changes_near_per_s": pooled_rate(records, "dir_changes_near", "secs_near"),
        "dir_changes_far_per_s": pooled_rate(records, "dir_changes_far", "secs_far"),
        "quick_frac": mean("quick_frac"), "quick3_frac": mean("quick3_frac"),
        "quick3_per_s": mean("quick3_per_s"),
        "dir_changes_out_r_per_s": pooled_rate(records, "dir_changes_out_r", "secs_out_r"),
    }
    if "mv_segs" in records[0]:
        # 人手指标（实验 N 起）：按总量合并 —— 单局移动段可能很少，逐局平均会被小分母带偏
        out["seg_le2_frac"] = pooled_rate(records, "mv_le2", "mv_segs")
        out["seg_le3_frac"] = pooled_rate(records, "mv_le3", "mv_segs")
        out["motor_override_frac"] = mean("motor_override_frac")
    return out


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
    motor_off = cfg["eval"].get("motor", "train") == "off" and cfg["motor"]["enabled"]
    if name == cfg["intent"]["name"] and not motor_off:
        return cfg
    c = copy.deepcopy(cfg)
    c["intent"]["name"] = name
    if motor_off:
        c["motor"]["enabled"] = False
    return c


def run_group(cfg: dict, ppo, featurizer, image, card: str, rank: int, episodes: int, device,
              hysteresis: float = 0.0) -> list[dict]:
    """逐组单跑：一张卡一个难度，`episodes` 个 env。`[eval].batched = false` 时走这条；也是批量路径的对照基准。"""
    return run_groups(cfg, ppo, featurizer, [(image, card, rank)], episodes, device, hysteresis)[0]


def run_groups(cfg: dict, ppo, featurizer, groups: list[tuple], episodes: int, device,
               hysteresis: float = 0.0) -> list[list[dict]]:
    """把若干 (image, card, rank) 组并成一批同步推进，返回每组的逐局记录（各 `episodes` 条，按 env 序）。

    每组的 VecEnv / 意图 / 运动层都与逐组单跑时同种子同规模（见 `envwrap.MultiVecEnv`），所以每一局的弹幕、
    目标点序列、运动层抽样都逐位相同；只有策略前向的批量从 32 变成了 G×32 —— 浮点归约顺序可能差出 1e-6，
    贪心 argmax 在近平局上偶尔翻一下，与「CPU 补测 vs GPU 评测」同一量级（±1–2pp 以内，通常为 0）。
    墙钟从「各组帧数之和」变成「最慢那组的帧数」。
    """
    cfg = eval_cfg(cfg)
    n_groups = len(groups)
    if n_groups == 1:
        image, card, rank = groups[0]
        envw = EnvWrapper(cfg, {card: image}, [stg_rl.Start(card, 0, rank)], device,
                          seed=int(cfg["eval"]["seed"]), num_envs=episodes, mirror=False)
    else:
        envw = EnvWrapper(cfg, {}, [], device, seed=int(cfg["eval"]["seed"]), num_envs=episodes, mirror=False,
                          groups=[({card: image}, stg_rl.Start(card, 0, rank)) for image, card, rank in groups])
    n_total = episodes * n_groups
    reward_fn = RewardFn(cfg)
    tracker = EpisodeTracker(n_total, device, list(reward_fn.terms), cfg["reward"]["hold_radius"],
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
            if len(first) == n_total:
                break
    for r in tracker.pop_finished():
        first.setdefault(r["env"], r)
    if len(first) != n_total:
        names = "、".join(f"{card} r{rank}" for _, card, rank in groups[:3])
        raise RuntimeError(f"评测（{names}{' …' if n_groups > 3 else ''}）只收到 {len(first)}/{n_total} 局")
    out = []
    for g in range(n_groups):          # env 编号改回组内编号，与逐组单跑的记录同形
        out.append([{**first[g * episodes + i], "env": i} for i in range(episodes)])
    return out


def evaluate(cfg: dict, ppo, featurizer, images: dict, specs: list[EvalSpec], device, hysteresis: float = 0.0) -> dict:
    result: dict = {"cards": {}, "overall": {}, "by_rank": {}}
    everything: list[dict] = []
    by_rank: dict[int, list[dict]] = {}
    # 局数相同的组并成一批同步推进（现在的评测集全是 32 局 ⇒ 一批 20 组）；`[eval].batched = false` 退回逐组单跑
    batched = bool(cfg["eval"].get("batched", True))
    todo: dict[int, list[tuple]] = {}
    for spec in specs:
        for rank in spec.ranks:
            key = spec.episodes if batched else len(todo)
            todo.setdefault(key, []).append((spec, rank))
    records: dict[tuple[str, int], list[dict]] = {}
    for items in todo.values():
        episodes = items[0][0].episodes
        got = run_groups(cfg, ppo, featurizer, [(images[sp.card], sp.card, rk) for sp, rk in items],
                         episodes, device, hysteresis)
        for (sp, rk), recs in zip(items, got):
            records[(sp.card, rk)] = recs
    for spec in specs:
        per: dict[str, dict] = {}
        for rank in spec.ranks:
            recs = records[(spec.card, rank)]
            per[f"r{rank}"] = summarize_eval(recs)
            everything.extend(recs)
            by_rank.setdefault(rank, []).extend(recs)
        result["cards"][spec.card] = per
    result["overall"] = summarize_eval(everything)
    # 分档聚合：评测集加档之后 `overall` 换了口径，`by_rank.r2` 保持与历史实验同口径可比。
    result["by_rank"] = {f"r{r}": summarize_eval(recs) for r, recs in sorted(by_rank.items())}
    return result
