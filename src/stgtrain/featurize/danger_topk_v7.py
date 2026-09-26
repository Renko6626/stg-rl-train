"""特征化器 danger_topk_v7（激光）= v6 + 激光 token。

引擎的激光池（stg_rl 0.3.0 起 Tier 0 `lasers` 表）之前没有进观测：模型看得见激光上挂的弹，看不见激光本身。
v7 在 v6 的全部输出之外加一组 `lasers` / `lasers_mask`，交给模型的激光编码器（`set_attn_v2`）。

**选哪几条**：候选 = 活着且不在收缩态的激光（收缩态不判定，也不会再判定）。按自机中心到激光判定盒（射线上
[start, end] 一段、横向 ±half_h）的距离取最近的 K 条（`featurize.k_lasers`，默认 16）——与引擎的判定几何、
与引擎自己排行的口径同一个，但在这里重算，不依赖输入行的顺序（部署侧 DLL 填表顺序不同也选出同一批）。
这个距离只用来挑行，**不进 token**。

**token 列**（全是原始量换到自机相对系、按量纲缩放，不喂预测类的构造量）：

    0–1   原点相对自机 (x − px, y − py) / 192
    2–3   方向 cos θ, sin θ
    4–5   射线上的一段 start / 192, end / 192
    6     判定半宽 half_h / 8（与弹的 radius / 8 同尺度）
    7     生长速度 speed / 8（px/帧，短棒沿射线飞出）
    8     角速度 omega · 60（弧度/秒；扫射）
    9–10  原点速度 vx / 8, vy / 8
    11    预警态标记（state == 0：还不判定）
    12    t_active 封顶 120 帧后 / 60（预警态还有几帧开始判定；生效态 0）

`laser_local = true` 再追加 2 列：自机在激光自身坐标系里的位置（沿射线 along / 192、横向 perp / 192）。这只是把
第 0–1 列转到激光的方向上，但对「离这条线多远」是线性可读的；默认关（见 docs 里的讨论），留作对照开关。

镜像由 envwrap 在上游处理（x、vx 取反，θ → π − θ，omega 取反），这里不管。形状固定，可录 CUDA 图、可导出 ONNX：
挑行用哨兵 `1e30` + `torch.where`（不用 inf / isfinite），训练与导出同一份代码。
"""
from __future__ import annotations

import torch
from torch import Tensor

from ..envwrap import LASER_COLS, RawObs
from ..perf import maybe_phase
from ..registry import FEATURIZERS
from .danger_topk_v1 import _gather
from .danger_topk_v6 import DangerTopKV6

F_LASER, F_LASER_LOCAL = 13, 2
T_ACTIVE_CAP = 120.0
SENTINEL = 1.0e30
_C = {name: k for k, name in enumerate(LASER_COLS)}
STATE_FADE = 2.0


def laser_frame(lasers: Tensor, player_xy: Tensor) -> tuple[Tensor, Tensor, Tensor, Tensor]:
    """(cos θ, sin θ, along, perp)：自机相对激光原点的位移投到激光方向 / 法向上。"""
    a = lasers[..., _C["angle"]]
    c, s = torch.cos(a), torch.sin(a)
    rx = player_xy[:, None, 0] - lasers[..., _C["x"]]
    ry = player_xy[:, None, 1] - lasers[..., _C["y"]]
    return c, s, rx * c + ry * s, ry * c - rx * s


def box_distance(lasers: Tensor, along: Tensor, perp: Tensor) -> Tensor:
    """自机中心到判定盒的距离（盒内为 0）。同引擎 `seg_box_dist_sq` 的几何（这里开了根）。"""
    h = lasers[..., _C["half_h"]]
    qa = torch.minimum(torch.maximum(along, lasers[..., _C["start"]]), lasers[..., _C["end"]])
    qp = torch.minimum(torch.maximum(perp, -h), h)
    return torch.sqrt((along - qa) ** 2 + (perp - qp) ** 2)


@FEATURIZERS.register("danger_topk_v7")
class DangerTopKV7(DangerTopKV6):
    def __init__(self, cfg: dict):
        super().__init__(cfg)
        f = cfg["featurize"]
        self.kl = int(f.get("k_lasers", 16))
        self.laser_local = f.get("laser_local", False)
        if not 1 <= self.kl <= 64:
            raise ValueError(f"featurize.k_lasers 须在 1..64（引擎每 env 至多给 64 条），得 {self.kl}")
        if not isinstance(self.laser_local, bool):
            raise ValueError(f"featurize.laser_local 须为布尔，得 {self.laser_local!r}")
        self.F_LASER = F_LASER + (F_LASER_LOCAL if self.laser_local else 0)

    def spec(self) -> dict[str, tuple[int, ...]]:
        return {**super().spec(), "lasers": (self.kl, self.F_LASER), "lasers_mask": (self.kl,)}

    def __call__(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        out = super().__call__(obs, timer=timer)
        if obs.lasers is None or obs.lasers_mask is None:
            raise ValueError("danger_topk_v7 要 RawObs.lasers / lasers_mask（envwrap 解码 stg_rl 的 lasers 表）")
        with maybe_phase(timer, "feat_lasers"):
            lz = obs.lasers
            c, s, along, perp = laser_frame(lz, obs.player_xy)
            cand = obs.lasers_mask & (lz[..., _C["state"]] != STATE_FADE)
            dist = box_distance(lz, along, perp)
            kval, idx = torch.topk(torch.where(cand, dist, torch.full_like(dist, SENTINEL)), self.kl, dim=1,
                                   largest=False)
            sel = kval < SENTINEL * 0.1
            rel = lz[..., 0:2] - obs.player_xy[:, None, :]
            state = lz[..., _C["state"]]
            cols = [
                rel / 192.0, torch.stack([c, s], dim=-1),
                lz[..., _C["start"]:_C["end"] + 1] / 192.0,
                lz[..., _C["half_h"]:_C["half_h"] + 1] / 8.0,
                lz[..., _C["speed"]:_C["speed"] + 1] / 8.0,
                lz[..., _C["omega"]:_C["omega"] + 1] * 60.0,
                lz[..., _C["vx"]:_C["vy"] + 1] / 8.0,
                (state == 0.0).to(lz.dtype).unsqueeze(-1),
                lz[..., _C["t_active"]:_C["t_active"] + 1].clamp(0.0, T_ACTIVE_CAP) / 60.0,
            ]
            if self.laser_local:
                cols.append(torch.stack([along, perp], dim=-1) / 192.0)
            tok = torch.cat(cols, dim=-1)
            out["lasers"] = _gather(tok, idx) * sel.unsqueeze(-1)
            out["lasers_mask"] = sel
        return out
