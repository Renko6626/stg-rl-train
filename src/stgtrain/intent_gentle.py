"""「温和指挥」诊断意图：把 `lower_half_uniform_v1`（下半屏均匀随机、每 2–5 s 换一次）的两个激进之处拆开量。

起因（docs/experiments.md「N1 / N2 结果」）：套上手部运动层之后，跟点档比自由档低 12–20pp，而自由档带着人手的成绩
与 J 无约束时相当 —— 丢分来自「粗的手 × 每 2–5 s 被命令穿过半个场地」。真实的上层指挥（人手拖鼠标、或将来的指挥模型）
不会这样下指令。这里**只改评测、不动训练**，先量出那十几个百分点里有多少是这把尺子本身造成的：

    follow_near_v1    新目标点落在自机当前位置 `near` px 以内（默认 96），刷新间隔不变（120–300 帧）
    follow_slow_v1    目标点仍是下半屏均匀随机，刷新间隔拉长到 `gentle_interval`（默认 240–600 帧 = 4–10 s）
    follow_gentle_v1  两者都改

用法：`python -m stgtrain.eval_ckpt <ckpt> --intent follow_gentle_v1`。`near` / `gentle_interval` 可在 `[intent]` 里覆盖。
新局的第一个目标点抽在出生点（0, 384）附近 —— 那一刻还不知道新一局的自机位置（`track` 在解码时才喂进来）。
"""
from __future__ import annotations

import torch
from torch import Tensor

from .intent import LowerHalfUniform
from .registry import INTENTS

SPAWN_XY = (0.0, 384.0)


class _Gentle(LowerHalfUniform):
    NEAR = False   # 新目标点是否限制在自机附近
    SLOW = False   # 是否拉长刷新间隔

    def __init__(self, cfg: dict, num_envs: int, device: torch.device, seed: int):
        c = cfg["intent"]
        self.near = float(c.get("near", 96.0))
        self.player = torch.tensor(SPAWN_XY, device=device).repeat(int(num_envs), 1)
        super().__init__(cfg, num_envs, device, seed)      # 内部会 reset_all → _sample，所以 near / player 要先备好
        if self.SLOW:
            self.lo, self.hi = (int(v) for v in c.get("gentle_interval", [240, 600]))
            self.reset_all()

    def _sample(self) -> tuple[Tensor, Tensor]:
        xy, cd = super()._sample()          # 随机数的消耗与父类逐次相同（先 rand 再 randint）
        if self.NEAR:
            # 把 [0,1)² 的均匀样本重新映射成「自机 ± near」的方框，再钳回目标点的合法范围
            ux = (xy[:, 0] - self.x_lo) / (self.x_hi - self.x_lo)
            uy = (xy[:, 1] - self.y_lo) / (self.y_hi - self.y_lo)
            x = (self.player[:, 0] + (ux * 2 - 1) * self.near).clamp(self.x_lo, self.x_hi)
            y = (self.player[:, 1] + (uy * 2 - 1) * self.near).clamp(self.y_lo, self.y_hi)
            xy = torch.stack([x, y], dim=-1)
        return xy, cd

    def reset(self, mask: Tensor) -> None:
        # 新局：上一局的自机位置（多半是死亡地点）没有意义，退回出生点
        spawn = torch.tensor(SPAWN_XY, device=self.device).expand_as(self.player)
        self.player = torch.where(mask[:, None], spawn, self.player)
        super().reset(mask)

    def advance(self, frames: int, active: Tensor) -> Tensor:
        # 定期刷新不是新局：不能走上面那个会把位置退回出生点的 reset
        self.countdown = self.countdown - int(frames) * active.to(torch.int64)
        refreshed = active & (self.countdown <= 0)
        xy, cd = self._sample()
        self.target = torch.where(refreshed[:, None], xy, self.target)
        self.countdown = torch.where(refreshed, cd, self.countdown)
        return refreshed

    def track(self, player_xy: Tensor) -> None:
        """envwrap 每步在 `_decode` 里喂未镜像的自机坐标。"""
        self.player = player_xy.detach().clone()


@INTENTS.register("follow_near_v1")
class FollowNear(_Gentle):
    NEAR = True


@INTENTS.register("follow_slow_v1")
class FollowSlow(_Gentle):
    SLOW = True


@INTENTS.register("follow_gentle_v1")
class FollowGentle(_Gentle):
    NEAR = True
    SLOW = True
