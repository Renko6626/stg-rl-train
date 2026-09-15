"""包 stg_rl.VecEnv：pinned 缓冲 → 设备张量（RawObs / StepInfo），外加意图、镜像、上一帧按键（spec §3.1）。

镜像：镜像局里 RawObs 的所有 x 类量取反，模型输出的动作先按动作表置换再发给 env——模型始终活在一个自洽的镜像世界里。
意图目标在 intent 里存未镜像坐标；RawObs.target_xy 是镜像后的。
"""
from __future__ import annotations

import contextlib
import os
from dataclasses import dataclass

import stg_rl
import torch
from torch import Tensor

from . import actions
from .registry import INTENTS

FX_SCALE = 1.0 / 65536.0
ENEMY_FLAG_BOSS = 0x01
ENEMY_FLAG_COLLIDABLE = 0x10
BULLET_FLAG_COLLIDABLE = 0x01


@dataclass
class RawObs:
    player_xy: Tensor
    player_hit_r: Tensor
    player_speed: Tensor
    player_focus: Tensor
    bullets: Tensor
    bullets_mask: Tensor
    enemies: Tensor
    enemies_mask: Tensor
    target_xy: Tensor


@dataclass
class StepInfo:
    done: Tensor
    events: Tensor
    ep_frames: Tensor
    refreshed: Tensor
    buttons: Tensor
    prev_buttons: Tensor


def _off(table: str, field: str) -> int:
    return stg_rl.OFFSETS[table][field][0]


def _fx(rows: Tensor, off: int) -> Tensor:
    """rows[..., off:off+4] 小端 int32 定点 → float32 像素。"""
    part = rows[..., off:off + 4]
    if part.numel() == 0:
        # 空子弹表：`.contiguous()` 对 0 元素张量是 no-op（is_contiguous 恒真），行跨步 30 % 4 != 0，
        # 直接 view(int32) 会报错。空表没有数据要解码，按前缀形状返回空张量即可。
        return torch.zeros(part.shape[:-1], dtype=torch.float32, device=rows.device)
    return part.contiguous().view(torch.int32).squeeze(-1).to(torch.float32) * FX_SCALE


def _u16(rows: Tensor, off: int) -> Tensor:
    return rows[..., off].to(torch.int64) | (rows[..., off + 1].to(torch.int64) << 8)


def _phase(timer, name: str):
    return timer.phase(name) if timer is not None else contextlib.nullcontext()


class EnvWrapper:
    def __init__(self, cfg: dict, images: dict, starts: list, device: torch.device, seed: int,
                 num_envs: int | None = None, mirror: bool | None = None):
        e = cfg["env"]
        self.n = int(num_envs if num_envs is not None else e["num_envs"])
        self.cap = int(e["bullets_cap"])
        self.frame_skip = int(e["frame_skip"])
        self.device = device
        threads = max(1, min(int(e["threads"]) or (os.cpu_count() or 1), self.n))
        self.buf = stg_rl.alloc_buffers(self.n, self.cap, backend="torch", pin=device.type == "cuda")
        self.env = stg_rl.VecEnv(
            self.n, threads, images, starts, frame_skip=self.frame_skip, max_frames=int(e["max_frames"]),
            warmup_max=int(e["warmup_max"]), bullets_cap=self.cap, seed=int(seed), buffers=self.buf,
        )
        self.intent = INTENTS.get(cfg["intent"]["name"])(cfg, self.n, device, seed)
        self.mirror_enabled = bool(e["mirror"] if mirror is None else mirror)
        self._mirror_gen = torch.Generator(device=device)
        self._mirror_gen.manual_seed((int(seed) * 2654435761 + 97) % (2**63))
        self.mirrored = torch.zeros(self.n, dtype=torch.bool, device=device)
        self.prev_buttons = torch.zeros(self.n, dtype=torch.int64, device=device)
        self._buttons = actions.buttons_table(device)
        self._mirror = actions.mirror_table(device)
        self._arange_n = torch.arange(self.n, device=device)
        self._arange_e = torch.arange(stg_rl.ENEMIES_CAP, device=device)

    def _dev(self, t: Tensor) -> Tensor:
        # CUDA：从 pinned 缓冲异步拷贝。安全性来自下一次 step 之前 `buttons.to("cpu")` 的阻塞同步——
        # 在那之前 env 不会再写缓冲。CPU：必须 clone，否则 RawObs 与下一步被覆写的缓冲共享内存。
        return t.to(self.device, non_blocking=True) if self.device.type == "cuda" else t.clone()

    def _draw_mirror(self, mask: Tensor) -> None:
        if not self.mirror_enabled:
            return
        flips = torch.rand(self.n, generator=self._mirror_gen, device=self.device) < 0.5
        self.mirrored = torch.where(mask, flips, self.mirrored)

    def reset(self) -> RawObs:
        self.env.reset()
        self.intent.reset_all()
        self._draw_mirror(torch.ones(self.n, dtype=torch.bool, device=self.device))
        self.prev_buttons = torch.zeros(self.n, dtype=torch.int64, device=self.device)
        return self._decode()

    def step(self, action_ids: Tensor, timer=None) -> tuple[RawObs, StepInfo]:
        ids = torch.where(self.mirrored, self._mirror[action_ids], action_ids)
        buttons = self._buttons[ids]
        with _phase(timer, "env_step"):
            self.env.step(buttons.to("cpu"))
        with _phase(timer, "h2d"):
            done = self._dev(self.buf["done"]).to(torch.int64)
            events = self._dev(self.buf["events"]).to(torch.int64)
            ep_frames = self._dev(self.buf["ep_frames"]).to(torch.int64)
            ended = done != 0
            self.intent.reset(ended)
            self._draw_mirror(ended)
            refreshed = self.intent.advance(self.frame_skip, ~ended)
            info = StepInfo(done=done, events=events, ep_frames=ep_frames, refreshed=refreshed,
                            buttons=buttons, prev_buttons=self.prev_buttons)
            self.prev_buttons = torch.where(ended, torch.zeros_like(buttons), buttons)
            obs = self._decode()
        return obs, info

    def _decode(self) -> RawObs:
        b, n, cap, dev = self.buf, self.n, self.cap, self.device
        player = self._dev(b["player"])
        px, py = _fx(player, _off("player", "x")), _fx(player, _off("player", "y"))
        hit_r = _fx(player, _off("player", "hit_radius"))
        speed = _fx(player, _off("player", "speed"))
        focus = player[:, _off("player", "focus")] != 0

        m = int(b["bullets_offsets"][n])  # CPU 缓冲，读它不触发 GPU 同步
        rows = self._dev(b["bullets"][:m])
        offs = self._dev(b["bullets_offsets"]).to(torch.int64)
        counts = offs[1:] - offs[:-1]
        env_idx = torch.repeat_interleave(self._arange_n, counts, output_size=m)
        slot = torch.arange(m, device=dev) - offs[:-1][env_idx]
        feats = torch.stack([_fx(rows, _off("bullets", f)) for f in ("x", "y", "vx", "vy", "radius")], dim=-1)
        collidable = (rows[:, _off("bullets", "flags")] & BULLET_FLAG_COLLIDABLE) != 0
        bullets = torch.zeros(n, cap, 5, device=dev)
        bmask = torch.zeros(n, cap, dtype=torch.bool, device=dev)
        bullets[env_idx, slot] = feats
        bmask[env_idx, slot] = collidable

        en = self._dev(b["enemies"])
        ecount = self._dev(b["enemies_count"]).to(torch.int64)
        eflags = _u16(en, _off("enemies", "flags"))
        emask = (self._arange_e[None, :] < ecount[:, None]) & ((eflags & ENEMY_FLAG_COLLIDABLE) != 0)
        enemies = torch.stack([
            _fx(en, _off("enemies", "x")), _fx(en, _off("enemies", "y")), _fx(en, _off("enemies", "hit_w")),
            ((eflags & ENEMY_FLAG_BOSS) != 0).to(torch.float32),
        ], dim=-1)

        target = self.intent.target.clone()
        sign = torch.where(self.mirrored, -1.0, 1.0)
        px = px * sign
        bullets[..., 0] *= sign[:, None]
        bullets[..., 2] *= sign[:, None]
        enemies[..., 0] *= sign[:, None]
        target[:, 0] *= sign
        return RawObs(
            player_xy=torch.stack([px, py], dim=-1), player_hit_r=hit_r, player_speed=speed, player_focus=focus,
            bullets=bullets, bullets_mask=bmask, enemies=enemies, enemies_mask=emask, target_xy=target,
        )
