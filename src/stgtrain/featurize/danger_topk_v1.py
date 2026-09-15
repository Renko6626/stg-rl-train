"""特征化器 danger_topk_v1（spec §3.4）：按预测最近接近距离取前 K 颗弹 / 敌 + 密度图 + 自机 + 条件向量。

输出形状固定（可录 CUDA 图）；未入选行清零并由掩码标出。输入 RawObs 已按镜像处理，这里不再关心镜像。

密度图分箱（spec §3.4 要求严格左右镜像）：x 恰落在内部格线（x 为 32 的整数倍且不在 [-192, 192] 端点）上时，
该弹对左右两格各贡献一半权重（0.5 / 0.5），两个通道同样处理；其余位置整颗计入所在格。这样
``density(mirror(obs)) == density(obs).flip(-1)`` 逐元素成立（端点 x = ±192 本就映射 0 ↔ 11）。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..registry import FEATURIZERS

GRID_H, GRID_W, CELL = 14, 12, 32.0


def closest_approach(p: Tensor, v: Tensor, r_sum: Tensor, horizon: float) -> tuple[Tensor, Tensor]:
    """相对位置 p、相对速度 v（像素/帧）匀速外推，t ∈ [0, horizon] 内的边缘最近距离与达到时刻。"""
    vv = (v * v).sum(-1)
    pv = (p * v).sum(-1)
    t = (-pv / (vv + 1e-6)).clamp(0.0, horizon)
    closest = p + v * t.unsqueeze(-1)
    return closest.norm(dim=-1) - r_sum, t


def _gather(x: Tensor, idx: Tensor) -> Tensor:
    if x.dim() == 2:
        return torch.gather(x, 1, idx)
    return torch.gather(x, 1, idx.unsqueeze(-1).expand(-1, -1, x.shape[-1]))


@FEATURIZERS.register("danger_topk_v1")
class DangerTopKV1:
    F_BULLET, F_ENEMY, F_PLAYER, F_COND = 7, 6, 3, 4

    def __init__(self, cfg: dict):
        f = cfg["featurize"]
        self.kb, self.ke = int(f["k_bullets"]), int(f["k_enemies"])
        self.horizon = float(f["horizon"])
        self.d_max = float(f["d_max"])
        self.hold_r = float(cfg["reward"]["hold_radius"])

    def spec(self) -> dict[str, tuple[int, ...]]:
        return {
            "bullets": (self.kb, self.F_BULLET), "bullets_mask": (self.kb,),
            "enemies": (self.ke, self.F_ENEMY), "enemies_mask": (self.ke,),
            "density": (2, GRID_H, GRID_W), "player": (self.F_PLAYER,), "cond": (self.F_COND,),
        }

    def player_velocity(self, obs: RawObs) -> Tensor:
        d = obs.target_xy - obs.player_xy
        dist = d.norm(dim=-1, keepdim=True)
        v = d / dist.clamp_min(1e-6) * obs.player_speed.unsqueeze(-1)
        return torch.where(dist < self.hold_r, torch.zeros_like(v), v)

    def _topk(self, p: Tensor, v: Tensor, radius: Tensor, mask: Tensor, hit_r: Tensor, k: int):
        dmin, t = closest_approach(p, v, radius + hit_r[:, None], self.horizon)
        key = dmin.masked_fill(~mask, float("inf"))
        kval, idx = torch.topk(key, k, dim=1, largest=False)
        sel = torch.isfinite(kval) & (kval <= self.d_max)
        d_norm = kval.clamp(-self.d_max, self.d_max) / self.d_max
        return idx, sel, d_norm, _gather(t, idx) / self.horizon

    def __call__(self, obs: RawObs) -> dict[str, Tensor]:
        n = obs.player_xy.shape[0]
        dev = obs.player_xy.device
        pos = obs.player_xy[:, None, :]
        vp = self.player_velocity(obs)

        pb = obs.bullets[..., 0:2] - pos
        vb = obs.bullets[..., 2:4] - vp[:, None, :]
        idx, bsel, bd, bt = self._topk(pb, vb, obs.bullets[..., 4], obs.bullets_mask, obs.player_hit_r, self.kb)
        bullets = torch.cat([
            _gather(pb, idx) / 192.0, _gather(vb, idx) / 8.0, _gather(obs.bullets[..., 4:5], idx) / 8.0,
            bd.unsqueeze(-1), bt.unsqueeze(-1),
        ], dim=-1) * bsel.unsqueeze(-1)

        pe = obs.enemies[..., 0:2] - pos
        ve = (-vp)[:, None, :].expand_as(pe)
        eidx, esel, ed, et = self._topk(pe, ve, obs.enemies[..., 2], obs.enemies_mask, obs.player_hit_r, self.ke)
        enemies = torch.cat([
            _gather(pe, eidx) / 192.0, _gather(obs.enemies[..., 2:3], eidx) / 32.0,
            ed.unsqueeze(-1), et.unsqueeze(-1), _gather(obs.enemies[..., 3:4], eidx),
        ], dim=-1) * esel.unsqueeze(-1)

        valid = obs.bullets_mask.to(torch.float32)
        u = (obs.bullets[..., 0] + 192.0) / CELL
        col = u.floor().clamp(0, GRID_W - 1).long()
        row = (obs.bullets[..., 1] / CELL).floor().clamp(0, GRID_H - 1).long()
        # 内部格线上左右各半，保证 density(mirror(obs)) == density(obs).flip(-1)。
        edge = (u == u.floor()) & (u > 0.0) & (u < float(GRID_W))
        w_right = torch.where(edge, 0.5, 1.0)
        w_left = torch.where(edge, 0.5, 0.0)
        col_left = (col - 1).clamp_min(0)
        cells = GRID_H * GRID_W
        base = torch.arange(n, device=dev)[:, None] * cells + row * GRID_W
        flat_right = (base + col).reshape(-1)
        flat_left = (base + col_left).reshape(-1)
        unit = pb / pb.norm(dim=-1, keepdim=True).clamp_min(1e-6)
        approach = (-(unit * obs.bullets[..., 2:4]).sum(-1)).clamp_min(0.0) / 8.0
        count = torch.zeros(n * cells, device=dev).scatter_add_(
            0, flat_right, (valid * w_right).reshape(-1)
        ).scatter_add_(0, flat_left, (valid * w_left).reshape(-1))
        appr = torch.zeros(n * cells, device=dev).scatter_add_(
            0, flat_right, (approach * valid * w_right).reshape(-1)
        ).scatter_add_(0, flat_left, (approach * valid * w_left).reshape(-1))
        density = torch.stack([count.view(n, GRID_H, GRID_W), appr.view(n, GRID_H, GRID_W)], dim=1)

        player = torch.stack([obs.player_xy[:, 0] / 192.0, obs.player_xy[:, 1] / 192.0,
                              obs.player_focus.to(torch.float32)], dim=-1)
        d = obs.target_xy - obs.player_xy
        dn = d.norm(dim=-1)
        cond = torch.stack([d[:, 0] / 192.0, d[:, 1] / 192.0, dn / 448.0, (dn < self.hold_r).to(torch.float32)], dim=-1)
        return {"bullets": bullets, "bullets_mask": bsel, "enemies": enemies, "enemies_mask": esel,
                "density": density, "player": player, "cond": cond}
