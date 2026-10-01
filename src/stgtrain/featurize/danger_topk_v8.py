"""14维激光：自机局部线段几何、有限旋转观测运动、伸长余量和预警。

列与公式见docs/superpowers/specs/2026-10-01-laser-token-joint-attention-design.md。
候选选择沿用v7；不推测未来脚本，omega是本帧总转角而非未来角速度。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import RawObs
from ..perf import maybe_phase
from ..registry import FEATURIZERS
from .danger_topk_v1 import _gather
from .danger_topk_v6 import DangerTopKV6
from .danger_topk_v7 import DangerTopKV7, SENTINEL, STATE_FADE, _C, box_distance, laser_frame

F_LASER = 14


@FEATURIZERS.register("danger_topk_v8")
class DangerTopKV8(DangerTopKV7):
    def __init__(self, cfg: dict):
        super().__init__(cfg)
        if self.laser_local:
            raise ValueError("danger_topk_v8 固定14维，不支持laser_local=true")
        self.F_LASER = F_LASER

    def __call__(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        if obs.lasers is None or obs.lasers_mask is None or obs.laser_start_len is None:
            raise ValueError("danger_topk_v8 要lasers、lasers_mask和laser_start_len")
        if obs.laser_start_len.shape != obs.lasers_mask.shape or obs.lasers.shape[:2] != obs.lasers_mask.shape:
            raise ValueError("laser_start_len、lasers_mask必须与lasers同行")
        out = DangerTopKV6.__call__(self, obs, timer=timer)
        with maybe_phase(timer, "feat_lasers"):
            lz = torch.where(obs.lasers_mask[..., None], obs.lasers, torch.zeros_like(obs.lasers))
            cs, sn, u, perp = laser_frame(lz, obs.player_xy)
            d = -perp
            a, b = lz[..., _C["start"]] - u, lz[..., _C["end"]] - u
            near = torch.minimum(torch.maximum(torch.zeros_like(a), a), b)
            s_near = u + near
            delta = lz[..., _C["omega"]]
            # 固定射线坐标上的有限位移，投到当前方向：不差分逐帧重新求的最近点。
            vx, vy = lz[..., _C["vx"]], lz[..., _C["vy"]]
            motion_t = vx * cs + vy * sn + s_near * (1.0 - torch.cos(delta))
            motion_n = -vx * sn + vy * cs + s_near * torch.sin(delta)
            growth = obs.laser_start_len - (b - a)
            tok = torch.stack([
                d / 192.0, a / 192.0, b / 192.0, cs, sn,
                lz[..., _C["half_h"]] / 8.0,
                motion_t / 8.0, motion_n / 8.0, delta * 60.0, s_near / 192.0,
                lz[..., _C["speed"]] / 8.0, growth / 192.0,
                (lz[..., _C["state"]] == 0.0).to(lz.dtype),
                torch.log1p(lz[..., _C["t_active"]].clamp_min(0.0) / 60.0),
            ], dim=-1)
            cand = obs.lasers_mask & (lz[..., _C["state"]] != STATE_FADE)
            dist = box_distance(lz, u, perp)
            kval, idx = torch.topk(torch.where(cand, dist, torch.full_like(dist, SENTINEL)),
                                   self.kl, dim=1, largest=False)
            sel = kval < SENTINEL * 0.1
            selected = _gather(tok, idx)
            out["lasers"] = torch.where(sel[..., None], selected, torch.zeros_like(selected))
            out["lasers_mask"] = sel
        return out
