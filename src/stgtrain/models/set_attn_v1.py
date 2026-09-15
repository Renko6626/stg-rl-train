"""模型 set_attn_v1（spec §4.1）：弹 / 敌各一个集合编码器 + 密度图小卷积 + 主干 MLP，策略头 18 路、价值头 1 路。

全空掩码安全：池化与注意力对「一行都没有」输出 0，不出 NaN。形状全固定，ONNX 友好。
"""
from __future__ import annotations

import math
from typing import Mapping

import torch
from torch import Tensor, nn

from ..actions import NUM_ACTIONS
from ..registry import MODELS

_KEYS = ("bullets", "bullets_mask", "enemies", "enemies_mask", "density", "player", "cond")


def layer_init(layer, std=math.sqrt(2), bias_const=0.0):
    torch.nn.init.orthogonal_(layer.weight, std)
    torch.nn.init.constant_(layer.bias, bias_const)
    return layer


class SetEncoder(nn.Module):
    def __init__(self, f_in: int, d: int, heads: int, ctx_dim: int):
        super().__init__()
        self.phi = nn.Sequential(layer_init(nn.Linear(f_in, d)), nn.ReLU(), layer_init(nn.Linear(d, d)), nn.ReLU())
        self.heads, self.dk = heads, d // heads
        self.q = layer_init(nn.Linear(ctx_dim, d))
        self.k = layer_init(nn.Linear(d, d))
        self.v = layer_init(nn.Linear(d, d))
        self.out_dim = 3 * d

    def forward(self, x: Tensor, mask: Tensor, ctx: Tensor) -> Tensor:
        n, k, _ = x.shape
        h = self.phi(x)
        m = mask.unsqueeze(-1).to(h.dtype)
        cnt = m.sum(1)
        any_ = (cnt > 0).to(h.dtype)
        mean = (h * m).sum(1) / cnt.clamp_min(1.0)
        mx = h.masked_fill(~mask.unsqueeze(-1), -1e4).max(1).values * any_
        q = self.q(ctx).view(n, self.heads, 1, self.dk)
        kk = self.k(h).view(n, k, self.heads, self.dk).transpose(1, 2)
        vv = self.v(h).view(n, k, self.heads, self.dk).transpose(1, 2)
        scores = (q @ kk.transpose(-1, -2)) / math.sqrt(self.dk)
        scores = scores.masked_fill(~mask[:, None, None, :], -1e4)
        attn = (scores.softmax(-1) @ vv).reshape(n, -1) * any_
        return torch.cat([mean, mx, attn], dim=-1)


@MODELS.register("set_attn_v1")
class SetAttnV1(nn.Module):
    def __init__(self, cfg: dict, spec: dict[str, tuple[int, ...]]):
        super().__init__()
        m = cfg["model"]
        d, heads, trunk = int(m["d"]), int(m["heads"]), int(m["trunk"])
        if d % heads:
            raise ValueError(f"model.d({d}) 须能被 model.heads({heads}) 整除")
        self._spec = {k: tuple(spec[k]) for k in _KEYS}
        f_b, f_e = spec["bullets"][1], spec["enemies"][1]
        f_p, f_c = spec["player"][0], spec["cond"][0]
        c_d, h_d, w_d = spec["density"]
        self.ctx = nn.Sequential(layer_init(nn.Linear(f_p + f_c, d)), nn.ReLU())
        self.bullets = SetEncoder(f_b, d, heads, d)
        self.enemies = SetEncoder(f_e, d, heads, d)
        self.density = nn.Sequential(
            layer_init(nn.Conv2d(c_d, 16, 3, padding=1)), nn.ReLU(),
            layer_init(nn.Conv2d(16, 16, 3, stride=2, padding=1)), nn.ReLU(), nn.Flatten(),
        )
        dens_out = 16 * ((h_d + 1) // 2) * ((w_d + 1) // 2)
        self.dens_proj = nn.Sequential(layer_init(nn.Linear(dens_out, d)), nn.ReLU())
        in_dim = self.bullets.out_dim + self.enemies.out_dim + 2 * d
        self.trunk = nn.Sequential(layer_init(nn.Linear(in_dim, trunk)), nn.ReLU(),
                                   layer_init(nn.Linear(trunk, trunk)), nn.ReLU())
        self.actor = layer_init(nn.Linear(trunk, NUM_ACTIONS), std=0.01)
        self.critic = layer_init(nn.Linear(trunk, 1), std=1.0)

    def requires(self) -> dict[str, tuple[int, ...]]:
        return dict(self._spec)

    def forward(self, feats: Mapping[str, Tensor]) -> tuple[Tensor, Tensor]:
        ctx = self.ctx(torch.cat([feats["player"], feats["cond"]], dim=-1))
        hb = self.bullets(feats["bullets"], feats["bullets_mask"], ctx)
        he = self.enemies(feats["enemies"], feats["enemies_mask"], ctx)
        hd = self.dens_proj(self.density(feats["density"]))
        h = self.trunk(torch.cat([hb, he, hd, ctx], dim=-1))
        return self.actor(h), self.critic(h).squeeze(-1)
