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


@INTENTS.register("mixed_v1")
class MixedIntent(LowerHalfUniform):
    """三档混合意图（实验 I）：**跟点 / 锚点 / 自由**，每局开局抽一次，整局不变。

    - `follow`（模式 0）= 原来的 `lower_half_uniform_v1`：下半屏随机目标，按 `interval` 刷新。
    - `anchor`（模式 1）= 开局抽一个点，**整局不刷新**。「给你个大致位置，别催你跑」——
      部署时上层没有新指令的那段时间就是这个样子。诊断里它的撑过率最高（0.972 vs 跟点 0.931）。
    - `free`（模式 2）= 目标点锁自机，等于没有目标，纯粹活下去。诊断里它最差（0.760、贴边 21%），
      因为模型完全失去位置先验；留一小撮只为鲁棒性。

    锚点与自由档把倒计时设成极大，于是 `advance` 永远不会 refresh——`refreshed` 这个信号
    在这两档里本来也没有意义（它喂的是 reach_frames 指标与 episodes 的分段）。
    """

    MODES = ("follow", "anchor", "free")
    NEVER = 1 << 40   # 锚点/自由档的倒计时：整局不刷新

    def __init__(self, cfg: dict, num_envs: int, device: torch.device, seed: int):
        mix = cfg["intent"]["mix"]
        p = torch.tensor([float(mix[k]) for k in self.MODES], dtype=torch.float64)
        if p.min() < 0 or p.sum() <= 0:
            raise ValueError(f"intent.mix 须非负且和 > 0，得 {mix}")
        self.p = (p / p.sum()).to(device)
        self.mode = torch.zeros(int(num_envs), dtype=torch.int64, device=device)
        super().__init__(cfg, num_envs, device, seed)

    def _sample_modes(self) -> Tensor:
        return torch.multinomial(self.p.expand(self.n, -1), 1, replacement=True, generator=self.gen).squeeze(-1)

    def _refresh(self, mask: Tensor) -> None:
        """只换目标点，**不换模式**——跟点档的定期刷新走这条；锚点/自由档拿 NEVER 倒计时。"""
        xy, cd = self._sample()
        cd = torch.where(self.mode == 0, cd, torch.full_like(cd, self.NEVER))
        self.target = torch.where(mask[:, None], xy, self.target)
        self.countdown = torch.where(mask, cd, self.countdown)

    def reset(self, mask: Tensor) -> None:
        """新局：先抽模式再抽目标。模式**一局一抽**，局内不变（envwrap 只在 done 时调它）。"""
        mode = self._sample_modes()
        self.mode = torch.where(mask, mode, self.mode)
        self._refresh(mask)

    def reset_all(self) -> None:
        self.reset(torch.ones(self.n, dtype=torch.bool, device=self.device))

    def advance(self, frames: int, active: Tensor) -> Tensor:
        self.countdown = self.countdown - int(frames) * active.to(torch.int64)
        refreshed = active & (self.countdown <= 0)
        self._refresh(refreshed)
        return refreshed

    def track(self, player_xy: Tensor) -> None:
        """自由档：目标点锁自机（envwrap 每步在 `_decode` 里喂未镜像坐标）。"""
        self.target = torch.where((self.mode == 2)[:, None], player_xy, self.target)
