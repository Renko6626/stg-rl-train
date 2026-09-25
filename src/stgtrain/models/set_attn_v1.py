"""模型 set_attn_v1（spec §4.1）：弹 / 敌各一个集合编码器 + 密度图小卷积 + 主干 MLP，策略头 18 路、价值头 1 路。

全空掩码安全：池化与注意力对「一行都没有」输出 0，不出 NaN。形状全固定，ONNX 友好。

`model.sa_layers`（默认 0，实验 R1a / R1b）：弹编码器在逐颗 MLP 之后、三路汇总之前插入 N 个 Pre-LN 自注意力 block，
让每颗弹的 token 看得到其它弹（缝、通道这类局部结构）。0 = 原模型，模块、初始化顺序与前向逐位不变。敌人编码器不加。

两个性能开关（默认 = 旧行为，R1a 的 checkpoint 照常加载、数值照常复现；见 docs/perf-baseline.md「PPO 更新的算子级 profile」）：
- `model.ln_affine = false`：自注意力 block 的 LayerNorm 不带 γ / β。γ / β 的梯度要对 210 万行（32768 样本 × 64 颗）规约，
  是 PPO 更新里最贵的单个 kernel；其作用能被紧随其后的线性层吸收。
- `model.density_fp32 = true`：密度图卷积在 autocast 之外用 fp32 跑（bf16 下卷积的权重梯度反而更慢）。
"""
from __future__ import annotations

import math
from typing import Mapping

import torch
from torch import Tensor, nn
from torch.nn import functional as F

from ..actions import NUM_ACTIONS
from ..registry import MODELS

_KEYS = ("bullets", "bullets_mask", "enemies", "enemies_mask", "density", "player", "cond")


def layer_init(layer, std=math.sqrt(2), bias_const=0.0):
    torch.nn.init.orthogonal_(layer.weight, std)
    torch.nn.init.constant_(layer.bias, bias_const)
    return layer


class SelfAttnBlock(nn.Module):
    """Pre-LN：x + MHA(LN(x))，再 x + FFN(LN(x))。注意力走 SDPA（加性掩码）：全空的行不出 NaN。"""

    def __init__(self, d: int, heads: int, ln_affine: bool = True):
        super().__init__()
        self.heads, self.dk = heads, d // heads
        self.ln1 = nn.LayerNorm(d, elementwise_affine=ln_affine)
        self.ln2 = nn.LayerNorm(d, elementwise_affine=ln_affine)
        self.qkv = layer_init(nn.Linear(d, 3 * d), std=1.0)
        self.proj = layer_init(nn.Linear(d, d), std=1.0)
        self.ffn = nn.Sequential(layer_init(nn.Linear(d, 2 * d)), nn.ReLU(), layer_init(nn.Linear(2 * d, d), std=1.0))

    def forward(self, x: Tensor, mask: Tensor) -> Tensor:
        n, k, d = x.shape
        q, kk, v = self.qkv(self.ln1(x)).view(n, k, 3, self.heads, self.dk).permute(2, 0, 3, 1, 4)
        # SDPA 不显式存 [n, heads, k, k] 的注意力矩阵（每层省下 GB 级显存读写）；加性掩码 −1e4 而非 −inf，
        # 全空的行因此是均匀分布而不是 NaN。掩码按 q 的 dtype 建，bf16 autocast 下也匹配。
        bias = (~mask).to(q.dtype)[:, None, None, :] * -1e4
        att = F.scaled_dot_product_attention(q, kk, v, attn_mask=bias)
        x = x + self.proj(att.transpose(1, 2).reshape(n, k, d))
        return x + self.ffn(self.ln2(x))


class SetEncoder(nn.Module):
    def __init__(self, f_in: int, d: int, heads: int, ctx_dim: int, sa_layers: int = 0, ln_affine: bool = True):
        super().__init__()
        self.phi = nn.Sequential(layer_init(nn.Linear(f_in, d)), nn.ReLU(), layer_init(nn.Linear(d, d)), nn.ReLU())
        self.heads, self.dk = heads, d // heads
        self.q = layer_init(nn.Linear(ctx_dim, d))
        self.k = layer_init(nn.Linear(d, d))
        self.v = layer_init(nn.Linear(d, d))
        self.out_dim = 3 * d
        if sa_layers:   # 0 时不建这个子模块：state_dict 与初始化顺序和旧模型逐位相同
            self.sa = nn.ModuleList(SelfAttnBlock(d, heads, ln_affine) for _ in range(sa_layers))

    def forward(self, x: Tensor, mask: Tensor, ctx: Tensor) -> Tensor:
        n, k, _ = x.shape
        h = self.phi(x)
        for block in getattr(self, "sa", ()):
            h = block(h, mask) * mask.unsqueeze(-1).to(h.dtype)   # padding 行归零，不带进下一层
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
        sa_layers = int(m.get("sa_layers", 0))
        if sa_layers < 0:
            raise ValueError(f"model.sa_layers 须 ≥ 0，得 {sa_layers}")
        self._spec = {k: tuple(spec[k]) for k in _KEYS}
        f_b, f_e = spec["bullets"][1], spec["enemies"][1]
        f_p, f_c = spec["player"][0], spec["cond"][0]
        c_d, h_d, w_d = spec["density"]
        self.ctx = nn.Sequential(layer_init(nn.Linear(f_p + f_c, d)), nn.ReLU())
        self.bullets = SetEncoder(f_b, d, heads, d, sa_layers, bool(m.get("ln_affine", True)))
        self.density_fp32 = bool(m.get("density_fp32", False))
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
        if self.density_fp32:
            with torch.autocast(feats["density"].device.type, enabled=False):
                hd = self.dens_proj(self.density(feats["density"].float()))
        else:
            hd = self.dens_proj(self.density(feats["density"]))
        h = self.trunk(torch.cat([hb, he, hd, ctx], dim=-1))
        return self.actor(h), self.critic(h).squeeze(-1)
