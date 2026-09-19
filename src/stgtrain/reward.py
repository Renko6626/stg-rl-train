"""reward 项（spec §3.5 + 计划 Ruling 1）。每项返回未加权的 (N,) float；RewardFn 按配置系数加权求和。

符号约定：death 返回 −1（系数取正），edge_hug / key_press / shift_toggle 返回正计数（要惩罚就配负系数）。
"""
from __future__ import annotations

from dataclasses import dataclass

import torch
from torch import Tensor

from . import actions
from .envwrap import RawObs, StepInfo
from .registry import REWARD_TERMS

FIELD_HALF_W, FIELD_H, DIST_NORM = 192.0, 448.0, 448.0


@dataclass
class RewardContext:
    prev: RawObs
    cur: RawObs
    info: StepInfo
    gamma: float
    hold_radius: float
    quick_frames: int
    edge_margin: float

    @property
    def alive(self) -> Tensor:
        return (self.info.done == 0).to(torch.float32)

    def dist_prev(self) -> Tensor:
        return (self.prev.player_xy - self.prev.target_xy).norm(dim=-1)

    def dist_next(self) -> Tensor:
        # 对本步动作所瞄的旧目标：刷新发生在 reward 之后，所以不会有目标突变造成的跳变
        return (self.cur.player_xy - self.prev.target_xy).norm(dim=-1)


@REWARD_TERMS.register("death")
def death(ctx: RewardContext) -> Tensor:
    return -(ctx.info.done == 1).to(torch.float32)


@REWARD_TERMS.register("follow_shaping")
def follow_shaping(ctx: RewardContext) -> Tensor:
    """γ·Φ(s') − Φ(s)，Φ = −d/448。终局步记 0：cur 已是新局，且令终态 Φ=0 会让「远离时死亡」白赚。"""
    phi_prev = -ctx.dist_prev() / DIST_NORM
    phi_next = -ctx.dist_next() / DIST_NORM
    return (ctx.gamma * phi_next - phi_prev) * ctx.alive


@REWARD_TERMS.register("hold")
def hold(ctx: RewardContext) -> Tensor:
    return (ctx.dist_next() < ctx.hold_radius).to(torch.float32) * ctx.alive


@REWARD_TERMS.register("segment_survived")
def segment_survived(ctx: RewardContext) -> Tensor:
    return (ctx.info.done == 2).to(torch.float32)


@REWARD_TERMS.register("key_press")
def key_press(ctx: RewardContext) -> Tensor:
    return actions.key_changes(ctx.info.prev_buttons, ctx.info.buttons)[0].to(torch.float32)


@REWARD_TERMS.register("quick_change")
def quick_change(ctx: RewardContext) -> Tensor:
    """**只罚「上一个方向没保持够 N 步就又换」**，不碰正常移动。

    `key_press` 是无差别惩罚，压水平不挑形状：D→E→F 一路加码，边际在变差，而且会把有用的
    移动一起压掉。实测（评测集）F 的方向变化里有 43% 发生在上一次变向后 ≤2 步——60Hz 下
    ≤33ms，那不是反应，是振荡。本项专打这一段，`quick_frames` 之外的变向一分不扣。
    """
    if ctx.info.dir_hold is None:
        return torch.zeros_like(ctx.alive)
    changed = actions.direction_changed(ctx.info.prev_buttons, ctx.info.buttons)
    return (changed & (ctx.info.dir_hold <= ctx.quick_frames)).to(torch.float32)


@REWARD_TERMS.register("shift_toggle")
def shift_toggle(ctx: RewardContext) -> Tensor:
    return actions.key_changes(ctx.info.prev_buttons, ctx.info.buttons)[1].to(torch.float32)


@REWARD_TERMS.register("edge_hug")
def edge_hug(ctx: RewardContext) -> Tensor:
    m = ctx.edge_margin
    x, y = ctx.cur.player_xy[:, 0].abs(), ctx.cur.player_xy[:, 1]
    return ((x > FIELD_HALF_W - m) | (y > FIELD_H - m) | (y < m)).to(torch.float32) * ctx.alive


class RewardFn:
    def __init__(self, cfg: dict):
        terms = {k: float(v) for k, v in cfg["reward"]["terms"].items()}
        self.fns = {name: REWARD_TERMS.get(name) for name in terms}  # 未知名 ⇒ ValueError
        follow, death_c = terms.get("follow_shaping", 0.0), terms.get("death", 0.0)
        if follow > 0 and death_c < 5.0 * follow * 1.1:
            raise ValueError(
                f"reward.terms.death={death_c} 须 ≥ 5 × follow_shaping × 1.1 = {5.0 * follow * 1.1:.2f}（防自杀，spec §3.5）"
            )
        self.terms = terms
        self.gamma = float(cfg["ppo"]["gamma"])
        self.hold_radius = float(cfg["reward"]["hold_radius"])
        self.quick_frames = int(cfg["reward"]["quick_frames"])
        self.edge_margin = float(cfg["reward"]["edge_margin"])

    def __call__(self, prev: RawObs, cur: RawObs, info: StepInfo) -> tuple[Tensor, dict[str, Tensor]]:
        ctx = RewardContext(prev, cur, info, self.gamma, self.hold_radius, self.quick_frames, self.edge_margin)
        raw = {name: fn(ctx) for name, fn in self.fns.items()}
        total = torch.zeros_like(info.done, dtype=torch.float32)
        for name, value in raw.items():
            total = total + self.terms[name] * value
        return total, raw
