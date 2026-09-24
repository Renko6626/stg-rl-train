"""特征化器 danger_topk_v6（d / t 对照实验 M0 ‖ Q1 ‖ Q2）= v5 + 两个开关，拆开「目标点耦合」与「外推量」。

设计与判据见 docs/2026-09-25-dt-ablation-design.md。v1–v5 的弹 / 敌 token 里有三样东西由同一个假想自机速度
`vp`（当前速度 × 朝目标点的方向，进 24 px 圈为 0）驱动：速度列（弹速 − vp）、外推的最近距离 d 与时刻 t、
按 d 选前 K 个。目标点一换，三样一起跳。

- `frame = "target"`：v5 行为。`"static"`：`vp ≡ 0` —— 速度列即绝对速度，d / t 按「自机不动」外推，
  弹 / 敌 token 与目标点完全无关（目标点只从 `cond` 进来）。
- `dt = true`：v5 行为（带 d / t，按 d 取前 K 且 d ≤ d_max）。`false`：**删掉** d / t 两列（弹 7 → 5 维、敌 8 → 6 维），
  改按**当前**边缘距离（中心距 − 半径 − 自机判定半径）取最近的 K 个，不设距离上限。

默认值（`target` + `true`）与 v5 逐元素相同；图的原始输入不变。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..registry import FEATURIZERS
from .danger_topk_v5 import DangerTopKV5

# 去掉 d、t 两列后：弹 = 相对位置 2 · 速度 2 · 半径；敌 = 相对位置 2 · 判定宽 · boss · 速度 2。
# 只用切片（不用列表下标）：rollout 会把特征化录成 CUDA 图，列表下标每次要从主机拷索引张量，捕获期间不允许。
F_BULLET_NO_DT, F_ENEMY_NO_DT = 5, 6


@FEATURIZERS.register("danger_topk_v6")
class DangerTopKV6(DangerTopKV5):
    def __init__(self, cfg: dict):
        super().__init__(cfg)
        f = cfg["featurize"]
        self.frame = f.get("frame", "target")
        self.dt = f.get("dt", True)
        if self.frame not in ("target", "static"):
            raise ValueError(f"featurize.frame 须为 \"target\" / \"static\"，得 {self.frame!r}")
        if not isinstance(self.dt, bool):
            raise ValueError(f"featurize.dt 须为布尔，得 {self.dt!r}")
        if not self.dt:
            self.F_BULLET, self.F_ENEMY = F_BULLET_NO_DT, F_ENEMY_NO_DT

    def player_velocity(self, obs: RawObs) -> Tensor:
        if self.frame == "static":
            return torch.zeros_like(obs.player_xy)
        return super().player_velocity(obs)

    def _topk(self, p: Tensor, v: Tensor, radius: Tensor, mask: Tensor, hit_r: Tensor, k: int):
        if self.dt:
            return super()._topk(p, v, radius, mask, hit_r, k)
        edge = p.norm(dim=-1) - radius - hit_r[:, None]
        kval, idx = torch.topk(edge.masked_fill(~mask, float("inf")), k, dim=1, largest=False)
        zeros = torch.zeros_like(kval)
        return idx, torch.isfinite(kval), zeros, zeros    # d / t 占位，__call__ 里连列一起删掉

    def __call__(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        out = super().__call__(obs, timer=timer)
        if not self.dt:
            e = out["enemies"]
            out["bullets"] = out["bullets"][..., :5]
            out["enemies"] = torch.cat([e[..., :3], e[..., 5:]], dim=-1)
        return out

