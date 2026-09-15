"""意图生成器（spec §3.3）：下半屏均匀随机目标点，随机间隔刷新。坐标为未镜像的场内坐标。"""
from __future__ import annotations

import torch
from torch import Tensor

from .registry import INTENTS


@INTENTS.register("lower_half_uniform_v1")
class LowerHalfUniform:
    def __init__(self, cfg: dict, num_envs: int, device: torch.device, seed: int):
        c = cfg["intent"]
        m = float(c["margin"])
        self.x_lo, self.x_hi = -192.0 + m, 192.0 - m
        self.y_lo, self.y_hi = 224.0, 448.0 - m
        self.lo, self.hi = int(c["interval"][0]), int(c["interval"][1])
        self.n, self.device = int(num_envs), device
        self.gen = torch.Generator(device=device)
        self.gen.manual_seed(int(seed) % (2**63))
        self.target = torch.zeros(self.n, 2, device=device)
        self.countdown = torch.zeros(self.n, dtype=torch.int64, device=device)
        self.reset_all()

    def _sample(self) -> tuple[Tensor, Tensor]:
        # 每次都为全部 env 抽样再按掩码取用：随机数消耗与掩码无关，保证可复现。
        u = torch.rand(self.n, 2, generator=self.gen, device=self.device)
        xy = torch.stack(
            [self.x_lo + u[:, 0] * (self.x_hi - self.x_lo), self.y_lo + u[:, 1] * (self.y_hi - self.y_lo)], dim=-1
        )
        cd = torch.randint(self.lo, self.hi + 1, (self.n,), generator=self.gen, device=self.device)
        return xy, cd

    def reset_all(self) -> None:
        self.target, self.countdown = self._sample()

    def reset(self, mask: Tensor) -> None:
        xy, cd = self._sample()
        self.target = torch.where(mask[:, None], xy, self.target)
        self.countdown = torch.where(mask, cd, self.countdown)

    def advance(self, frames: int, active: Tensor) -> Tensor:
        self.countdown = self.countdown - int(frames) * active.to(torch.int64)
        refreshed = active & (self.countdown <= 0)
        self.reset(refreshed)
        return refreshed
