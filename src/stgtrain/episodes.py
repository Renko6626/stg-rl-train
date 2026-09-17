"""逐局统计累加器（训练 metrics 与评测共用；计划 Ruling 2）。

update 全程留在设备上不同步；pop_finished 每轮 rollout 调一次，把结束的局一次性搬回 CPU。
"""
from __future__ import annotations

import torch
from torch import Tensor

from . import actions
from .envwrap import RawObs, StepInfo

_COLS = ("return", "steps", "in_r", "edge", "shift", "dirchg", "reach_sum", "reach_cnt",
         "keys", "dir_in", "dir_out", "steps_in", "steps_out", "graze", "close4", "close12")
CLOSE_PX = (4.0, 12.0)  # 神穿指标：自机判定边缘到最近弹边缘的距离阈值


class EpisodeTracker:
    def __init__(self, n: int, device, term_names: list[str], hold_radius: float, edge_margin: float,
                 frame_skip: int, reach_cap_frames: int):
        self.n, self.device = int(n), device
        self.term_names = list(term_names)
        self.hold_radius, self.edge_margin = float(hold_radius), float(edge_margin)
        self.frame_skip, self.reach_cap = int(frame_skip), float(reach_cap_frames)
        self.acc = torch.zeros(self.n, len(_COLS) + len(self.term_names), device=device)
        self.since = torch.zeros(self.n, device=device)
        self.reached = torch.zeros(self.n, dtype=torch.bool, device=device)
        self._pending: list[tuple[Tensor, Tensor, Tensor, Tensor]] = []

    def update(self, prev: RawObs, cur: RawObs, info: StepInfo, total: Tensor, raw_terms: dict[str, Tensor]) -> None:
        alive = info.done == 0
        d = (cur.player_xy - prev.target_xy).norm(dim=-1)
        in_r = (d < self.hold_radius) & alive
        m = self.edge_margin
        x, y = cur.player_xy[:, 0].abs(), cur.player_xy[:, 1]
        edge = ((x > 192.0 - m) | (y > 448.0 - m) | (y < m)) & alive
        pressed, toggled = actions.key_changes(info.prev_buttons, info.buttons)
        dir_chg = actions.direction_changed(info.prev_buttons, info.buttons)
        # 决策时（本步动作是看着 prev 选的）是否在 R 内；只切分存活步，两边互补
        at_r = ((prev.player_xy - prev.target_xy).norm(dim=-1) < self.hold_radius) & alive
        at_out = ~at_r & alive
        # 本步之后离最近（有判定的）弹边缘多远；没有弹 = inf
        edge_d = ((cur.bullets[..., :2] - cur.player_xy[:, None, :]).norm(dim=-1)
                  - cur.bullets[..., 4] - cur.player_hit_r[:, None])
        near = edge_d.masked_fill(~cur.bullets_mask, float("inf")).min(dim=1).values if cur.bullets.shape[1] else \
            torch.full_like(d, float("inf"))

        self.since = self.since + 1
        newly = in_r & ~self.reached
        reach_add = newly.float() * self.since * self.frame_skip
        reach_cnt = newly.float()
        self.reached = self.reached | newly
        seg_end = info.refreshed | ~alive
        miss = seg_end & ~self.reached
        reach_add = reach_add + miss.float() * self.reach_cap
        reach_cnt = reach_cnt + miss.float()

        cols = [total.to(torch.float32), torch.ones_like(total, dtype=torch.float32), in_r.float(), edge.float(),
                toggled.float(), dir_chg.float(), reach_add, reach_cnt,
                pressed.float(), (dir_chg & at_r).float(), (dir_chg & at_out).float(), at_r.float(), at_out.float(),
                info.events[:, 1].to(torch.float32), ((near < CLOSE_PX[0]) & alive).float(),
                ((near < CLOSE_PX[1]) & alive).float()]
        cols += [raw_terms[name].to(torch.float32) for name in self.term_names]
        self.acc = self.acc + torch.stack(cols, dim=-1)

        ended = ~alive
        self._pending.append((ended, self.acc.clone(), info.done, info.ep_frames))
        self.acc = torch.where(ended[:, None], torch.zeros_like(self.acc), self.acc)
        self.since = torch.where(seg_end, torch.zeros_like(self.since), self.since)
        self.reached = self.reached & ~seg_end

    def pop_finished(self) -> list[dict]:
        if not self._pending:
            return []
        ended = torch.stack([p[0] for p in self._pending]).cpu()
        acc = torch.stack([p[1] for p in self._pending]).cpu()
        done = torch.stack([p[2] for p in self._pending]).cpu()
        frames = torch.stack([p[3] for p in self._pending]).cpu()
        self._pending.clear()
        out: list[dict] = []
        for t, i in ended.nonzero().tolist():
            a = acc[t, i].tolist()
            steps = max(a[1], 1.0)
            secs = steps * self.frame_skip / 60.0
            rec = {
                "env": i, "done": int(done[t, i]), "frames": int(frames[t, i]), "return": a[0], "steps": int(a[1]),
                "in_r_frac": a[2] / steps, "edge_frac": a[3] / steps,
                "shift_toggles_per_s": a[4] / secs, "dir_changes_per_s": a[5] / secs,
                "reach_frames": a[6] / max(a[7], 1.0),
                "key_presses_per_s": a[8] / secs,
                # 点内 / 点外方向变化：记计数与时长，汇总时按总时长合并（单局点内时长可能为 0）
                "dir_changes_in_r": int(a[9]), "dir_changes_out_r": int(a[10]),
                "secs_in_r": a[11] * self.frame_skip / 60.0, "secs_out_r": a[12] * self.frame_skip / 60.0,
                # 神穿：每秒擦弹、存活步中离弹边缘 < 4 / < 12 px 的占比
                "graze_per_s": a[13] / secs,
                "close4_frac": a[14] / max(a[11] + a[12], 1.0), "close12_frac": a[15] / max(a[11] + a[12], 1.0),
            }
            for k, name in enumerate(self.term_names):
                rec[f"term/{name}"] = a[len(_COLS) + k]
            out.append(rec)
        return out
