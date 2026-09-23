"""特征化器 danger_topk_v4（实验 N）= v3 + 「当前方向已经执行了几帧」。

配合手部运动层（`envwrap.MotorLayer`）：换了方向之后要执行满一个**随机、对模型不可见**的最短长度才许再换。
没有这一维状态就不满足马尔可夫性——同一个局面下「刚换完方向」和「已经走了 10 帧」能不能再换的概率完全不同。
模型看得到的只有「已经按了多久」（人也知道），看不到「还要锁多久」（人不知道手指什么时候真正抬起来）。

`player` 向量在 v3 的 13 维后追加 `min(dir_held, HELD_CAP) / HELD_CAP`，共 14 维。新局首步 dir_held 很大 → 1.0
（= 「早就可以换了」）。没开运动层时这一维照样有定义，所以 v4 的模型可以关掉运动层评测（探针）。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..perf import maybe_phase
from ..registry import FEATURIZERS
from .danger_topk_v3 import DangerTopKV3

HELD_CAP = 16.0   # 运动层的最短保持上限远小于它；再长就没有区分的必要了


@FEATURIZERS.register("danger_topk_v4")
class DangerTopKV4(DangerTopKV3):
    F_PLAYER = DangerTopKV3.F_PLAYER + 1

    def __call__(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        out = super().__call__(obs, timer=timer)
        with maybe_phase(timer, "feat_dir_held"):
            if obs.dir_held is None:
                held = torch.full_like(obs.player_xy[:, 0], HELD_CAP)
            else:
                held = obs.dir_held.to(obs.player_xy.device, torch.float32).clamp(0.0, HELD_CAP)
            out["player"] = torch.cat([out["player"], (held / HELD_CAP).unsqueeze(-1)], dim=-1)
        return out
