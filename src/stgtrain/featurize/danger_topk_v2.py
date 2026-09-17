"""特征化器 danger_topk_v2（实验 E）= v1 + 上一步动作。

`player` 向量在 v1 的 (x, y, focus) 之后追加上一步动作：方向 one-hot（9，顺序同 actions.DIR_BUTTONS）+ 低速位（1），共 13 维。
动作 id 取智能体坐标系（镜像前），镜像局天然一致；新局首步为 0（不动、不低速）。

动机：v1 只能从 `focus` 看到上一步的低速键，看不到上一步方向——实验 D 的按键惩罚因此只压下了 shift 切换
（7.1 → 3.5/s），方向变化几乎不降（23.7 → 19.5/s）。见 docs/experiments.md。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..actions import NUM_ACTIONS
from ..envwrap import RawObs
from ..registry import FEATURIZERS
from .danger_topk_v1 import DangerTopKV1

N_DIRS = NUM_ACTIONS // 2


@FEATURIZERS.register("danger_topk_v2")
class DangerTopKV2(DangerTopKV1):
    F_PLAYER = DangerTopKV1.F_PLAYER + N_DIRS + 1

    def __call__(self, obs: RawObs) -> dict[str, Tensor]:
        out = super().__call__(obs)
        n = obs.player_xy.shape[0]
        prev = obs.prev_action if obs.prev_action is not None else torch.zeros(n, dtype=torch.int64,
                                                                                device=obs.player_xy.device)
        prev = prev.to(obs.player_xy.device, torch.int64)
        onehot = torch.nn.functional.one_hot(prev // 2, N_DIRS).to(torch.float32)
        slow = (prev % 2).to(torch.float32).unsqueeze(-1)
        out["player"] = torch.cat([out["player"], onehot, slow], dim=-1)
        return out
