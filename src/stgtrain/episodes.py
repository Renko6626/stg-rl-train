"""逐局统计累加器（训练 metrics 与评测共用；计划 Ruling 2）。

update 全程留在设备上不同步；pop_finished 每轮 rollout 调一次，把结束的局一次性搬回 CPU。
"""
from __future__ import annotations

import torch
from torch import Tensor

from . import actions
from .envwrap import RawObs, StepInfo

_COLS = ("return", "steps", "in_r", "edge", "shift", "dirchg", "reach_sum", "reach_cnt",
         "keys", "dir_in", "dir_out", "steps_in", "steps_out", "graze", "close4", "close12",
         "quick", "quick3", "dir_near", "steps_near", "mv_seg", "mv_le2", "mv_le3", "override")
CLOSE_PX = (4.0, 12.0)  # 神穿指标：自机判定边缘到最近弹边缘的距离阈值
# 连击两档都记：≤2 与历史实验（F/G0/H/I）同口径，≤3 对应 reward.quick_frames 的默认判据。
# 指标口径固定，不跟着 reward 阈值走——否则换个惩罚参数，历史数字就全废了。
QUICK_STEPS, QUICK_STEPS3 = 2, 3
DANGER_PX = 24.0  # 最近弹边缘在这个距离内算「弹到脸上」，用来分「临危抖」与「平时抖」
NEVER = 1 << 20   # hold 的初值：开局第一次变向不算连击


class EpisodeTracker:
    def __init__(self, n: int, device, term_names: list[str], hold_radius: float, edge_margin: float,
                 frame_skip: int, reach_cap_frames: int):
        self.n, self.device = int(n), device
        self.term_names = list(term_names)
        self.hold_radius, self.edge_margin = float(hold_radius), float(edge_margin)
        self.frame_skip, self.reach_cap = int(frame_skip), float(reach_cap_frames)
        self.acc = torch.zeros(self.n, len(_COLS) + len(self.term_names), device=device)
        self.since = torch.zeros(self.n, device=device)
        # 距上次变向多少步。全局平均看不出「平时不动、弹来了猛抽」——这个计数器让连击现形。
        self.hold = torch.full((self.n,), NEVER, dtype=torch.int64, device=device)   # info.dir_hold 缺席时的兜底
        self.reached = torch.zeros(self.n, dtype=torch.bool, device=device)
        self._pending: list[tuple[Tensor, Tensor, Tensor, Tensor]] = []

    def state(self) -> tuple[Tensor, Tensor, Tensor, Tensor]:
        return self.acc, self.since, self.hold, self.reached

    def load_state(self, state: tuple[Tensor, Tensor, Tensor, Tensor]) -> None:
        self.acc, self.since, self.hold, self.reached = state

    def push(self, entry: tuple[Tensor, ...]) -> None:
        self._pending.append(entry)

    def update(self, prev: RawObs, cur: RawObs, info: StepInfo, total: Tensor, raw_terms: dict[str, Tensor]) -> None:
        state, entry = self.step(self.state(), prev, cur, info, total, raw_terms)
        self.load_state(state)
        self.push(entry)

    def step(self, state: tuple[Tensor, Tensor, Tensor, Tensor], prev: RawObs, cur: RawObs, info: StepInfo,
             total: Tensor, raw_terms: dict[str, Tensor]) -> tuple[tuple[Tensor, ...], tuple[Tensor, ...]]:
        """`update` 的纯函数内核：不读写 self 上的状态，返回 (新状态, 待 pop 的一条记录)。
        rollout 把它录进 CUDA 图（`rollout_graph.py`），状态靠图的输入 / 输出传递。"""
        acc, since, hold_state, reached = state
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

        if info.dir_hold is not None:
            hold = info.dir_hold          # envwrap 算好的那一份（reward 也吃它）
        else:
            hold = hold_state + 1
            hold_state = torch.where(dir_chg, torch.zeros_like(hold), hold)
        quick = dir_chg & (hold <= QUICK_STEPS) & alive
        quick3 = dir_chg & (hold <= QUICK_STEPS3) & alive
        danger = (near < DANGER_PX) & alive
        # 「像不像人手」：刚结束的那一段若是**移动段**（上一步按着方向），它持续了几帧（= hold）。
        # 与 quick 的区别：quick 把「不动」的段也算进去，而人手做不出来的是 1–2 帧的**点按**。
        mv_end = dir_chg & ((info.prev_buttons & actions.DIR_MASK) != 0) & alive
        override = (info.overridden & alive) if info.overridden is not None else torch.zeros_like(alive)

        since = since + 1
        newly = in_r & ~reached
        reach_add = newly.float() * since * self.frame_skip
        reach_cnt = newly.float()
        reached = reached | newly
        seg_end = info.refreshed | ~alive
        miss = seg_end & ~reached
        reach_add = reach_add + miss.float() * self.reach_cap
        reach_cnt = reach_cnt + miss.float()

        cols = [total.to(torch.float32), torch.ones_like(total, dtype=torch.float32), in_r.float(), edge.float(),
                toggled.float(), dir_chg.float(), reach_add, reach_cnt,
                pressed.float(), (dir_chg & at_r).float(), (dir_chg & at_out).float(), at_r.float(), at_out.float(),
                info.events[:, 1].to(torch.float32), ((near < CLOSE_PX[0]) & alive).float(),
                ((near < CLOSE_PX[1]) & alive).float(),
                quick.float(), quick3.float(), (dir_chg & danger).float(), danger.float(),
                mv_end.float(), (mv_end & (hold <= 2)).float(), (mv_end & (hold <= 3)).float(), override.float()]
        cols += [raw_terms[name].to(torch.float32) for name in self.term_names]
        acc = acc + torch.stack(cols, dim=-1)

        ended = ~alive
        zero = torch.zeros_like(info.done)
        # 起点下标与意图模式：env 在自动 reset 前写 start_index，所以 done≠0 这一步读到的正是
        # 刚结束那局的起点（课程采样按它归因）；意图模式只有混合意图才有。
        entry = (ended, acc, info.done, info.ep_frames,
                 info.start_index if info.start_index is not None else zero,
                 info.intent_mode if info.intent_mode is not None else zero)
        acc = torch.where(ended[:, None], torch.zeros_like(acc), acc)
        since = torch.where(seg_end, torch.zeros_like(since), since)
        hold_state = torch.where(ended, torch.full_like(hold_state, NEVER), hold_state)
        reached = reached & ~seg_end
        return (acc, since, hold_state, reached), entry

    def pop_finished(self) -> list[dict]:
        if not self._pending:
            return []
        ended = torch.stack([p[0] for p in self._pending]).cpu()
        acc = torch.stack([p[1] for p in self._pending]).cpu()
        done = torch.stack([p[2] for p in self._pending]).cpu()
        frames = torch.stack([p[3] for p in self._pending]).cpu()
        start = torch.stack([p[4] for p in self._pending]).cpu()
        mode = torch.stack([p[5] for p in self._pending]).cpu()
        self._pending.clear()
        out: list[dict] = []
        for t, i in ended.nonzero().tolist():
            a = acc[t, i].tolist()
            steps = max(a[1], 1.0)
            secs = steps * self.frame_skip / 60.0
            rec = {
                "env": i, "done": int(done[t, i]), "frames": int(frames[t, i]), "return": a[0], "steps": int(a[1]),
                "start": int(start[t, i]), "mode": int(mode[t, i]),
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
                # 抖动的**形状**：连击占比 + 临危/平时分开的变向率（后两个按总时长合并，见 summarize）
                "quick_frac": a[16] / max(a[5], 1.0), "quick3_frac": a[17] / max(a[5], 1.0),
                "quick3_per_s": a[17] / secs,
                "dir_changes_near": int(a[18]), "dir_changes_far": int(a[5] - a[18]),
                "secs_near": a[19] * self.frame_skip / 60.0,
                "secs_far": max(a[1] - a[19], 0.0) * self.frame_skip / 60.0,
                # 人手指标（实验 N）：移动段里 ≤2 / ≤3 帧点按的占比（计数留着给评测按总量合并）、运动层做主的帧占比
                "mv_segs": int(a[20]), "mv_le2": int(a[21]), "mv_le3": int(a[22]),
                "seg_le2_frac": a[21] / max(a[20], 1.0), "seg_le3_frac": a[22] / max(a[20], 1.0),
                "motor_override_frac": a[23] / steps,
            }
            for k, name in enumerate(self.term_names):
                rec[f"term/{name}"] = a[len(_COLS) + k]
            out.append(rec)
        return out
