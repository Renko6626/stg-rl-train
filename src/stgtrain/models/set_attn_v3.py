"""弹／激光各自投影，联合自注意力，分类型池化；主干沿用v2。"""
from __future__ import annotations

from typing import Mapping

import torch
from torch import Tensor, nn

from ..registry import MODELS
from .set_attn_v1 import SelfAttnBlock
from .set_attn_v2 import SetAttnV2


@MODELS.register("set_attn_v3")
class SetAttnV3(SetAttnV2):
    def __init__(self, cfg: dict, spec: dict[str, tuple[int, ...]]):
        m = cfg["model"]
        if int(m.get("sa_layers", 0)) or int(m.get("laser_sa_layers", 0)):
            raise ValueError("set_attn_v3 用joint_sa_layers；sa_layers和laser_sa_layers须为0")
        layers = int(m.get("joint_sa_layers", 1))
        if layers < 0:
            raise ValueError("model.joint_sa_layers 须≥0")
        super().__init__(cfg, spec)
        d, heads = int(m["d"]), int(m["heads"])
        self.type_embedding = nn.Parameter(torch.randn(2, d) * 0.1)
        self.joint_sa = nn.ModuleList(SelfAttnBlock(d, heads, bool(m.get("ln_affine", True)))
                                      for _ in range(layers))

    def threat_tokens(self, feats: Mapping[str, Tensor]) -> tuple[Tensor, Tensor]:
        """交流后的弹和激光token；padding输入及每层输出均归零。"""
        bm, lm = feats["bullets_mask"], feats["lasers_mask"]
        bx = torch.where(bm[..., None], feats["bullets"], torch.zeros_like(feats["bullets"]))
        lx = torch.where(lm[..., None], feats["lasers"], torch.zeros_like(feats["lasers"]))
        bt = self.bullets.tokens(bx, bm)
        lt = self.lasers.tokens(lx, lm)
        # 类型参数保持fp32，激活沿用autocast精度，避免整个联合序列提升为fp32。
        bt = bt + self.type_embedding[0].to(bt.dtype)
        lt = lt + self.type_embedding[1].to(lt.dtype)
        mask = torch.cat([bm, lm], dim=1)
        h = torch.cat([bt, lt], dim=1) * mask[..., None]
        for block in self.joint_sa:
            h = block(h, mask) * mask[..., None]
        k = bx.shape[1]
        return h[:, :k], h[:, k:]

    def forward(self, feats: Mapping[str, Tensor]) -> tuple[Tensor, Tensor]:
        ctx = self.ctx(torch.cat([feats["player"], feats["cond"]], dim=-1))
        bt, lt = self.threat_tokens(feats)
        hb = self.bullets(feats["bullets"], feats["bullets_mask"], ctx, bt)
        hl = self.lasers(feats["lasers"], feats["lasers_mask"], ctx, lt)
        he = self.enemies(feats["enemies"], feats["enemies_mask"], ctx)
        if self.density_fp32:
            with torch.autocast(feats["density"].device.type, enabled=False):
                hd = self.dens_proj(self.density(feats["density"].float()))
        else:
            hd = self.dens_proj(self.density(feats["density"]))
        h = self.trunk(torch.cat([hb, he, hd, ctx, hl], dim=-1))
        if self.action_query:
            logits = self.aq(torch.cat([bt, lt], dim=1),
                             torch.cat([feats["bullets_mask"], feats["lasers_mask"]], dim=1), h, feats["player"])
        else:
            logits = self.actor(h)
        return logits, self.critic(h).squeeze(-1)
