"""特征化器 danger_topk_v5（实验 N3）= v4 + 「当前低速位已经执行了几帧」。

N3 让低速键也过手部运动层（另一路状态机，与方向互不牵连）：按下 / 松开 shift 之后，要保持一个随机、对模型不可见的
最短长度才许再切。和 v4 的 `dir_held` 同理，没有这一维状态就不满足马尔可夫性——刚按下 shift 和已经按了 10 帧，
能不能松开的概率完全不同。低速位本身（按着还是松着）v1 起就在 `player.focus` 里。

`player` 向量在 v4 的 14 维后追加 `min(slow_held, HELD_CAP) / HELD_CAP`，共 15 维。缺席按 1.0（= 早就可以切了）。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..perf import maybe_phase
from ..registry import FEATURIZERS
from .danger_topk_v4 import HELD_CAP, DangerTopKV4


@FEATURIZERS.register("danger_topk_v5")
class DangerTopKV5(DangerTopKV4):
    F_PLAYER = DangerTopKV4.F_PLAYER + 1

    def __call__(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        out = super().__call__(obs, timer=timer)
        with maybe_phase(timer, "feat_slow_held"):
            if obs.slow_held is None:
                held = torch.full_like(obs.player_xy[:, 0], HELD_CAP)
            else:
                held = obs.slow_held.to(obs.player_xy.device, torch.float32).clamp(0.0, HELD_CAP)
            out["player"] = torch.cat([out["player"], (held / HELD_CAP).unsqueeze(-1)], dim=-1)
        return out
