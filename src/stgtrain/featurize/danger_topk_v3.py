"""特征化器 danger_topk_v3（实验 G）= v2 + 敌人速度。

v1/v2 把敌人当**静止**（`ve = -vp`），于是一只每帧俯冲 3 px 的妖精，在「预测最近距离 / 几帧后到达最近点」
这两个特征里和一根柱子没区别——而敌人有体碰判定，撞上就死。第 2 关的「妖精雨」整段没有弹、死因全是体碰，
是这个缺陷最干净的判别式；实际上绝大多数道中卡的小怪都在移动。

env 不导出敌人 vx/vy，速度由 `envwrap.enemy_velocity` 按 `enemies.id` 差分上一帧得到（部署侧 C 端同样要做）。
敌人行在 v1 的 6 维后追加 (vx, vy) / 8，并用相对速度算最近接近——与弹的处理一致。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..registry import FEATURIZERS
from .danger_topk_v1 import _gather
from .danger_topk_v2 import DangerTopKV2


@FEATURIZERS.register("danger_topk_v3")
class DangerTopKV3(DangerTopKV2):
    F_ENEMY = DangerTopKV2.F_ENEMY + 2

    def __call__(self, obs: RawObs) -> dict[str, Tensor]:
        out = super().__call__(obs)
        pos = obs.player_xy[:, None, :]
        pe = obs.enemies[..., 0:2] - pos
        ve = obs.enemies[..., 4:6] - self.player_velocity(obs)[:, None, :]
        idx, sel, ed, et = self._topk(pe, ve, obs.enemies[..., 2], obs.enemies_mask, obs.player_hit_r, self.ke)
        enemies = torch.cat([
            _gather(pe, idx) / 192.0, _gather(obs.enemies[..., 2:3], idx) / 32.0,
            ed.unsqueeze(-1), et.unsqueeze(-1), _gather(obs.enemies[..., 3:4], idx),
            _gather(obs.enemies[..., 4:6], idx) / 8.0,
        ], dim=-1) * sel.unsqueeze(-1)
        out["enemies"], out["enemies_mask"] = enemies, sel
        return out
