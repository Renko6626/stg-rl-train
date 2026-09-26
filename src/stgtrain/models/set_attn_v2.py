"""模型 set_attn_v2（激光）= set_attn_v1 + 激光集合编码器。

配 `danger_topk_v7`：多一组激光 token（`lasers` / `lasers_mask`）。激光走自己的 `SetEncoder`（逐条 MLP → 可选的
自注意力 → 均值 / 最大 / ctx 注意力三路汇总），汇总向量与弹、敌、密度图、ctx 并排进主干。激光与弹分开编码：两者
列的含义完全不同（线段 vs 圆），硬塞进同一个 φ 只会让弹那一路为少数激光样本分心。

`model.laser_sa_layers`（默认 0）：激光编码器里的自注意力层数，同 `sa_layers` 之于弹。
`model.action_query = true`：18 路动作 query 同时看弹 token 与激光 token（两路 token 同维 d，拼成一个集合）。

其余开关（`sa_layers` / `ln_affine` / `density_fp32`）与 v1 同义；弹 / 敌 / 密度图各模块与 v1 逐个同构，只有主干
第一层的输入宽度多了激光那 3d。
"""
from __future__ import annotations

from typing import Mapping

import torch
from torch import Tensor, nn

from ..registry import MODELS
from .set_attn_v1 import SetAttnV1, SetEncoder, layer_init

_LASER_KEYS = ("lasers", "lasers_mask")


@MODELS.register("set_attn_v2")
class SetAttnV2(SetAttnV1):
    def __init__(self, cfg: dict, spec: dict[str, tuple[int, ...]]):
        for k in _LASER_KEYS:
            if k not in spec:
                raise ValueError(f"set_attn_v2 要特征 {k!r}（用 danger_topk_v7 这类带激光的特征化器）")
        super().__init__(cfg, spec)
        m = cfg["model"]
        d, heads, trunk = int(m["d"]), int(m["heads"]), int(m["trunk"])
        laser_sa = int(m.get("laser_sa_layers", 0))
        if laser_sa < 0:
            raise ValueError(f"model.laser_sa_layers 须 ≥ 0，得 {laser_sa}")
        self._spec.update({k: tuple(spec[k]) for k in _LASER_KEYS})
        self.lasers = SetEncoder(spec["lasers"][1], d, heads, d, laser_sa, bool(m.get("ln_affine", True)))
        in_dim = self.trunk[0].in_features + self.lasers.out_dim
        self.trunk = nn.Sequential(layer_init(nn.Linear(in_dim, trunk)), nn.ReLU(),
                                   layer_init(nn.Linear(trunk, trunk)), nn.ReLU())

    def forward(self, feats: Mapping[str, Tensor]) -> tuple[Tensor, Tensor]:
        ctx = self.ctx(torch.cat([feats["player"], feats["cond"]], dim=-1))
        tok = self.bullets.tokens(feats["bullets"], feats["bullets_mask"])
        hb = self.bullets(feats["bullets"], feats["bullets_mask"], ctx, tok)
        he = self.enemies(feats["enemies"], feats["enemies_mask"], ctx)
        ltok = self.lasers.tokens(feats["lasers"], feats["lasers_mask"])
        hl = self.lasers(feats["lasers"], feats["lasers_mask"], ctx, ltok)
        if self.density_fp32:
            with torch.autocast(feats["density"].device.type, enabled=False):
                hd = self.dens_proj(self.density(feats["density"].float()))
        else:
            hd = self.dens_proj(self.density(feats["density"]))
        h = self.trunk(torch.cat([hb, he, hd, ctx, hl], dim=-1))
        if self.action_query:
            logits = self.aq(torch.cat([tok, ltok], dim=1),
                             torch.cat([feats["bullets_mask"], feats["lasers_mask"]], dim=1), h, feats["player"])
        else:
            logits = self.actor(h)
        return logits, self.critic(h).squeeze(-1)
