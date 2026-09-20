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
    prev_action: Tensor | None = None  # 上一步**实际执行**的动作 id（智能体坐标系、镜像前），新局首步为 0（不动）；v2 特征化用
    dir_held: Tensor | None = None     # 当前方向已经执行了多少帧（新局 = 很大）；v4 特征化用
    slow_held: Tensor | None = None    # 当前低速位（按着 / 松着）已经执行了多少帧（新局 = 很大）；v5 特征化用


@dataclass
class StepInfo:
    done: Tensor
    events: Tensor
    ep_frames: Tensor
    refreshed: Tensor
    buttons: Tensor
    prev_buttons: Tensor
    dir_hold: Tensor | None = None      # 本步做决策时，上一个方向已经保持了多少步（变向那步读它 = 上段的长度）
    overridden: Tensor | None = None    # 本步运动层是否替策略做了主（执行的方向 != 想按的方向）；没开运动层为全 False
    start_index: Tensor | None = None   # 本步所属那一局的起点下标（done≠0 时是**刚结束**那局的，env 在 reset 前取）
    intent_mode: Tensor | None = None   # 混合意图的模式（0 跟点 / 1 锚点 / 2 自由），无混合时 None


def _off(table: str, field: str) -> int:
    return stg_rl.OFFSETS[table][field][0]


def _fx(rows: Tensor, off: int) -> Tensor:
    """rows[..., off:off+4] 小端 int32 定点 → float32 像素。先压平再 view：规避 size-1 维度步长不整除 4 的问题。"""
    part = rows[..., off:off + 4]
    flat = part.contiguous().reshape(-1)
    if flat.storage_offset() % 4 != 0:
        # size-1 / 空张量在 PyTorch 眼里“连续”，`.contiguous()` 是 no-op，会留下不整除 4 的存储偏移
        # （如 bullets `radius` 偏移 22），`view(int32)` 仍会报错；clone 成偏移 0 的紧凑副本。
        flat = flat.clone()
    return flat.view(torch.int32).reshape(part.shape[:-1]).to(torch.float32) * FX_SCALE


def _u16(rows: Tensor, off: int) -> Tensor:
    return rows[..., off].to(torch.int64) | (rows[..., off + 1].to(torch.int64) << 8)


def _u32(rows: Tensor, off: int) -> Tensor:
    v = rows[..., off].to(torch.int64)
    for k in (1, 2, 3):
        v = v | (rows[..., off + k].to(torch.int64) << (8 * k))
    return v


TELEPORT_PX = 16.0   # 单帧位移超过它 = 瞬移（不是运动），速度记 0
DIR_HOLD_NEVER = 1 << 20   # dir_hold 的初值 / 新局值：开局第一次变向不算连击


def enemy_velocity(prev_ids: Tensor, prev_xy: Tensor, cur_ids: Tensor, cur_xy: Tensor,
                   frame_skip: int, valid: Tensor, teleport_px: float = TELEPORT_PX) -> Tensor:
    """按 `enemies.id` 把当前帧的敌人对上上一帧，差分出每帧速度（env 只导出坐标，不导出敌人 vx/vy）。

    对不上的（新出现的敌）与 `valid=False` 的 env（新局第一步）记 0——不能拿上一局的坐标差分。
    id 是 u32 且同一只敌在池里换槽也不变，所以按 id 匹配比按槽位稳。

    **瞬移守卫**：`move_to(0, …)` 会让敌人当帧跳过去（第 5 关咲夜那六张卡把时停窗口压平后，boss
    每轮都要跳一次，最远一跳 112px）。差分把它读成上百 px/帧的速度，`/8` 归一化后是个十几倍的
    离群值，还会让最近接近算出「这敌人瞬间飞走了」。单帧位移超过 `teleport_px` 的一律记 0——
    敌人正常移动远达不到这个量级（原作 boss 游走 2.5 px/帧）。
    """
    same = (cur_ids[:, :, None] == prev_ids[:, None, :]) & (cur_ids[:, :, None] != 0)
    hit, idx = same.max(dim=-1)
    matched = torch.gather(prev_xy, 1, idx.unsqueeze(-1).expand(-1, -1, 2))
    step = cur_xy - matched
    v = step / max(1, int(frame_skip))
    keep = hit & valid[:, None] & (step.abs().amax(dim=-1) <= float(teleport_px) * max(1, int(frame_skip)))
    return torch.where(keep.unsqueeze(-1), v, torch.zeros_like(v))


_M32 = 0xFFFFFFFF
_RNG_C_ENV, _RNG_C_STEP, _RNG_C_STREAM = 0x9E3779B1, 0x85EBCA6B, 0xC2B2AE35


def _mix32(x: Tensor) -> Tensor:
    """lowbias32（Chris Wellons）：32 位整数的雪崩混合。int64 张量里算，每次乘完掩回 32 位 ——
    int64 乘法溢出是按 2^64 回绕的，低 32 位不受影响，所以与 C 的 uint32 运算逐位相同。"""
    x = x ^ (x >> 16)
    x = (x * 0x7FEB352D) & _M32
    x = x ^ (x >> 15)
    x = (x * 0x846CA68B) & _M32
    return x ^ (x >> 16)


def counter_draw(seed: int, env_ids: Tensor, step0: int, steps: int, stream: int, lo: int, hi: int) -> Tensor:
    """**基于计数器的随机数**：第 `t` 步、第 `e` 个 env、第 `stream` 路的抽样值只由 (seed, e, t, stream) 决定。
    返回 `[steps, n]`，取值 U{lo..hi}。

    为什么不用 `torch.Generator`：① 有状态的发生器，抽样值取决于**此前调过多少次**，于是「20 组评测串行跑」与
    「20 组并成一批跑」没法逐位一致；计数器式的与调用顺序无关，给定 env 编号就能复现。② 同一个公式用 C 写出来
    逐位相同（契约仓 `sa_motor.c`），DLL 侧的运动层因此可以和训练侧对拍。③ 一次算一整块（`[steps, n]`），
    每步只取一行视图，不再每步发射随机数核。取模偏差 < 3e-8，可忽略。
    """
    if hi <= lo:
        return torch.full((steps, env_ids.shape[0]), lo, dtype=torch.int64, device=env_ids.device)
    t = torch.arange(step0, step0 + steps, dtype=torch.int64, device=env_ids.device)
    x = (int(seed) & _M32) + env_ids[None, :] * _RNG_C_ENV + t[:, None] * _RNG_C_STEP + int(stream) * _RNG_C_STREAM
    return lo + _mix32(x & _M32) % (hi - lo + 1)


class MotorLayer:
    """手部运动层（实验 N）：把人手的限制写进环境 —— 策略只说「想按哪个方向」，实际按出去的由这里决定。

    两种**随机**约束（设计与理由见 docs/experiments.md「N1 / N2 手部运动层」）：

    - `hold = [lo, hi]`：每换一次方向，为新的一段抽一个最短长度 L ~ U{lo..hi}；这一段没执行满 L 帧不许再换。
      **L 对模型不可见**（它只看得到 `dir_held` = 已经执行了几帧）—— 想点一下，出来 2 帧还是 6 帧自己说了不算。
    - `delay = [lo, hi]`：想换方向时，抽一个延迟 d ~ U{lo..hi}，d 帧后才生效；期间改主意就按新意图重抽，
      改回当前方向则撤销。

    随机数是基于计数器的（见 `counter_draw`），不用 `torch.Generator`。

    确定性的「至少 N 帧」不行：那只是把时间轴量化成 N 帧一格，模型照样能在粗格子上精确操作。
    `slow = false`（N1 / N2）：只锁方向，低速键直通。这是个被实测用上的漏洞 —— 方向被锁住时，高速 4.5 / 低速 2 px
    来回切是模型手里唯一还能立即生效的调节手段，N1 / N2 的 shift 切换因此是 J 的 4 倍。
    `slow = true`（N3）：低速键走**同一套规则的另一路状态机**（各自的锁、待生效请求、随机抽样），与方向互不牵连 ——
    人按 shift 的手指和按方向的手指是两根。按住低速微调本来就是人的打法，这里禁的只是「切得太快、太精确」。
    作用在智能体坐标系的动作 id 上（镜像之前），只做相等与计数，天然左右对称。
    """

    BLOCK = 64     # 一次预抽多少步
    STREAM_HOLD, STREAM_DELAY, STREAM_SLOW_HOLD, STREAM_SLOW_DELAY = 0, 1, 2, 3

    def __init__(self, cfg: dict, n: int, device: torch.device, seed: int, env_ids: Tensor | None = None):
        m = cfg["motor"]
        self.n, self.device = int(n), device
        self.hold_lo, self.hold_hi = int(m["hold"][0]), int(m["hold"][1])
        self.delay_lo, self.delay_hi = int(m["delay"][0]), int(m["delay"][1])
        self.slow = bool(m.get("slow", False))
        self.seed = (int(seed) * 40503 + 7919) & _M32
        # env 编号进随机数的键。批量评测把多组并成一批时，每组各传自己的 0..k-1，结果就与逐组单跑逐位相同。
        self.env_ids = (torch.arange(self.n, device=device) if env_ids is None else env_ids.to(device)).to(torch.int64)
        self.reset_all()

    def reset_all(self) -> None:
        self.t = 0                       # 已走过的步数 = 随机数的计数器；reset_all 归零 ⇒ 同种子的评测可复现
        self._block0 = -1
        # 每路通道一份 [need, pend, wait]：need = 本段最短长度（新局 0 = 第一下不受限）、pend = 待生效的取值（−1 = 无）
        zeros = lambda: torch.zeros(self.n, dtype=torch.int64, device=self.device)   # noqa: E731
        self.dir_state = [zeros(), zeros() - 1, zeros()]
        self.slow_state = [zeros(), zeros() - 1, zeros()]

    # 旧名字留着：测试与诊断脚本读的是方向那一路
    need = property(lambda self: self.dir_state[0])
    pend = property(lambda self: self.dir_state[1])
    wait = property(lambda self: self.dir_state[2])

    def reset(self, mask: Tensor) -> None:
        for st in (self.dir_state, self.slow_state):
            st[0] = torch.where(mask, torch.zeros_like(st[0]), st[0])
            st[1] = torch.where(mask, torch.full_like(st[1], -1), st[1])
            st[2] = torch.where(mask, torch.zeros_like(st[2]), st[2])

    def _draws(self) -> tuple[Tensor, ...]:
        """本步的 (hold, delay, slow_hold, slow_delay) 抽样。整块预抽，每步只取一行视图。
        四路各用各的 stream ⇒ 开不开低速那一路，方向这一路抽到的值都不变（N3 关掉 slow 就逐位退回 N2）。"""
        b0 = self.t - self.t % self.BLOCK
        if b0 != self._block0:
            d = lambda stream, lo, hi: counter_draw(self.seed, self.env_ids, b0, self.BLOCK, stream, lo, hi)  # noqa: E731
            self._tab = [d(self.STREAM_HOLD, self.hold_lo, self.hold_hi), d(self.STREAM_DELAY, self.delay_lo, self.delay_hi)]
            if self.slow:
                self._tab += [d(self.STREAM_SLOW_HOLD, self.hold_lo, self.hold_hi),
                              d(self.STREAM_SLOW_DELAY, self.delay_lo, self.delay_hi)]
            self._block0 = b0
        k = self.t - b0
        return tuple(t[k] for t in self._tab)

    @staticmethod
    def _channel(st: list, want: Tensor, cur: Tensor, held: Tensor, hold_draw: Tensor, delay_draw: Tensor) -> Tensor:
        """一路通道走一帧：想要 `want`、正在执行 `cur`（已执行 `held` 帧）。返回本帧实际执行的取值，就地更新 `st`。"""
        need, pend, wait = st
        diff = want != cur
        wait = torch.where(diff & (want != pend), delay_draw, wait)      # 新意图（或改了主意）→ 重抽延迟
        go = diff & (wait <= 0) & (held >= need)
        st[2] = torch.where(diff & ~go, (wait - 1).clamp_min(0), wait)
        st[0] = torch.where(go, hold_draw, need)
        st[1] = torch.where(diff & ~go, want, torch.full_like(pend, -1))  # 想回当前取值 = 撤销；放行了也清掉
        return torch.where(go, want, cur)

    def apply(self, want: Tensor, prev_exec: Tensor, held: Tensor, slow_held: Tensor | None = None) -> Tensor:
        """`want` = 策略选的动作 id；`prev_exec` = 上一步实际执行的；`held` / `slow_held` = 当前方向 / 低速位已执行帧数。
        返回本步实际执行的动作 id。"""
        want = want.to(torch.int64)
        draws = self._draws()
        self.t += 1
        exec_dir = self._channel(self.dir_state, want // 2, prev_exec // 2, held, draws[0], draws[1])
        slow = want % 2
        if self.slow:
            if slow_held is None:
                raise ValueError("motor.slow = true 需要 slow_held")
            slow = self._channel(self.slow_state, slow, prev_exec % 2, slow_held, draws[2], draws[3])
        return exec_dir * 2 + slow


class MultiVecEnv:
    """把 G 个小 `VecEnv`（各 k 个 env、各自一个起点）并成一个大的给 `EnvWrapper` 用 —— **批量评测**的底座。

    为什么不是一个 640-env 的 VecEnv：引擎的起点是按权重**随机**抽的，没法把第 i 个 env 钉在第 j 张卡上；
    而评测要的正是「每张卡每个难度恰好 k 局」。所以保留 G 个独立的小 VecEnv（种子、env 数都与逐组单跑时相同，
    于是每一局的弹幕与逐组单跑逐位相同），只把它们的输出缓冲拼起来，让解码 / 特征化 / 策略前向 / 统计在 G×k 的
    大批量上各做**一次**。逐组单跑时 GPU 每步只推理 32 条、20 组串行，几乎全在空转（一次评测 6–7 分钟，
    占整条训练墙钟的两成）。
    """

    def __init__(self, cfg: dict, groups: list[tuple[dict, "stg_rl.Start"]], k: int, seed: int, threads: int):
        e = cfg["env"]
        self.k, self.g = int(k), len(groups)
        self.cap = int(e["bullets_cap"])
        self.bufs = [stg_rl.alloc_buffers(self.k, self.cap, backend="torch", pin=False) for _ in groups]
        self.envs = [
            stg_rl.VecEnv(self.k, max(1, min(int(threads), self.k)), images, [start], frame_skip=int(e["frame_skip"]),
                          max_frames=int(e["max_frames"]), warmup_max=int(e["warmup_max"]), bullets_cap=self.cap,
                          seed=int(seed), buffers=buf)
            for (images, start), buf in zip(groups, self.bufs)
        ]
        self.buf: dict[str, Tensor] = {}

    def _gather(self) -> None:
        bs = self.bufs
        out = {key: torch.cat([b[key] for b in bs]) for key in ("done", "events", "ep_frames", "player", "enemies",
                                                                "enemies_count")}
        counts = [int(b["bullets_offsets"][self.k]) for b in bs]
        out["bullets"] = torch.cat([b["bullets"][:m] for b, m in zip(bs, counts)])
        base, offs = 0, []
        for b, m in zip(bs, counts):
            offs.append(b["bullets_offsets"][:self.k] + base)
            base += m
        offs.append(torch.tensor([base], dtype=bs[0]["bullets_offsets"].dtype))
        out["bullets_offsets"] = torch.cat(offs)
        # start_index：各组自己的都是 0，这里改记「第几组」，逐局统计按它归组
        out["start_index"] = torch.arange(self.g, dtype=bs[0]["start_index"].dtype).repeat_interleave(self.k)
        self.buf.clear()
        self.buf.update(out)

    def reset(self) -> None:
        for env in self.envs:
            env.reset()
        self._gather()

    def step(self, buttons: Tensor) -> None:
        for i, env in enumerate(self.envs):
            env.step(buttons[i * self.k:(i + 1) * self.k].contiguous())
        self._gather()

    def set_start_weights(self, w: list[float]) -> None:
        raise RuntimeError("批量评测的每组只有一个起点，没有权重可调")


class StackedIntent:
    """G 个同种子、各 k 个 env 的意图生成器并排放。逐组单跑时每组各有一个这样的实例；并成一批后仍然各用各的，
    随机数的消耗与逐组单跑逐步相同，于是目标点序列逐位相同。"""

    def __init__(self, make, g: int, k: int):
        self.parts = [make() for _ in range(g)]
        self.k = int(k)

    def _cat(self, name: str) -> Tensor:
        return torch.cat([getattr(p, name) for p in self.parts])

    @property
    def target(self) -> Tensor:
        return self._cat("target")

    def __getattr__(self, name: str):
        # mode / track / track_world 只有部分意图有：有就转发，没有就照常 AttributeError（envwrap 用 hasattr / getattr 探测）
        parts = self.__dict__.get("parts")
        if not parts or not hasattr(parts[0], name):
            raise AttributeError(name)
        if name == "mode":
            return self._cat("mode")
        if name in ("track", "track_world"):
            def call(*args):
                for i, p in enumerate(parts):
                    getattr(p, name)(*(a[i * self.k:(i + 1) * self.k] for a in args))
            return call
        raise AttributeError(name)

    def reset_all(self) -> None:
        for p in self.parts:
            p.reset_all()

    def reset(self, mask: Tensor) -> None:
        for i, p in enumerate(self.parts):
            p.reset(mask[i * self.k:(i + 1) * self.k])

    def advance(self, frames: int, active: Tensor) -> Tensor:
        return torch.cat([p.advance(frames, active[i * self.k:(i + 1) * self.k]) for i, p in enumerate(self.parts)])


def _phase(timer, name: str):
    return timer.phase(name) if timer is not None else contextlib.nullcontext()


class EnvWrapper:
    def __init__(self, cfg: dict, images: dict, starts: list, device: torch.device, seed: int,
                 num_envs: int | None = None, mirror: bool | None = None,
                 groups: list[tuple[dict, "stg_rl.Start"]] | None = None):
        """`groups` 非空 = 批量评测：每个 (images, start) 一组、每组 `num_envs` 个 env，并成一批（见 `MultiVecEnv`）。
        此时 `images` / `starts` 不用；意图与运动层的随机数按组各自为政，与逐组单跑逐位相同。"""
        e = cfg["env"]
        k = int(num_envs if num_envs is not None else e["num_envs"])
        self.n = k * len(groups) if groups else k
        self.cap = int(e["bullets_cap"])
        self.frame_skip = int(e["frame_skip"])
        self.device = device
        threads = max(1, min(int(e["threads"]) or (os.cpu_count() or 1), k))
        make_intent = lambda: INTENTS.get(cfg["intent"]["name"])(cfg, k, device, seed)   # noqa: E731
        if groups:
            self.env = MultiVecEnv(cfg, groups, k, seed, threads=min(threads, 8))
            self.buf = self.env.buf
            self.intent = StackedIntent(make_intent, len(groups), k)
        else:
            self.buf = stg_rl.alloc_buffers(self.n, self.cap, backend="torch", pin=device.type == "cuda")
            self.env = stg_rl.VecEnv(
                self.n, threads, images, starts, frame_skip=self.frame_skip, max_frames=int(e["max_frames"]),
                warmup_max=int(e["warmup_max"]), bullets_cap=self.cap, seed=int(seed), buffers=self.buf,
            )
            self.intent = make_intent()
        self._group_k = k if groups else None
        self.mirror_enabled = bool(e["mirror"] if mirror is None else mirror)
        self._mirror_gen = torch.Generator(device=device)
        self._mirror_gen.manual_seed((int(seed) * 2654435761 + 97) % (2**63))
        self.mirrored = torch.zeros(self.n, dtype=torch.bool, device=device)
        self.prev_buttons = torch.zeros(self.n, dtype=torch.int64, device=device)
        self.prev_action = torch.zeros(self.n, dtype=torch.int64, device=device)
        self._buttons = actions.buttons_table(device)
        self._mirror = actions.mirror_table(device)
        self._arange_n = torch.arange(self.n, device=device)
        self._arange_e = torch.arange(stg_rl.ENEMIES_CAP, device=device)
        # 敌人速度靠按 id 差分（env 不导出）；新局第一步 valid=False，避免跨局差分
        self._prev_enemy_ids = torch.zeros(self.n, stg_rl.ENEMIES_CAP, dtype=torch.int64, device=device)
        self._prev_enemy_xy = torch.zeros(self.n, stg_rl.ENEMIES_CAP, 2, device=device)
        self._enemy_prev_valid = torch.zeros(self.n, dtype=torch.bool, device=device)
        self.dir_hold = torch.full((self.n,), DIR_HOLD_NEVER, dtype=torch.int64, device=device)
        self.slow_held = torch.full((self.n,), DIR_HOLD_NEVER, dtype=torch.int64, device=device)
        env_ids = torch.arange(self.n, device=device) % self._group_k if self._group_k else None
        self.motor = MotorLayer(cfg, self.n, device, seed, env_ids=env_ids) if cfg["motor"]["enabled"] else None

    def _dev(self, t: Tensor) -> Tensor:
        # CUDA：从 pinned 缓冲异步拷贝。安全性来自下一次 step 之前 `buttons.to("cpu")` 的阻塞同步——
        # 在那之前 env 不会再写缓冲。CPU：必须 clone，否则 RawObs 与下一步被覆写的缓冲共享内存。
        return t.to(self.device, non_blocking=True) if self.device.type == "cuda" else t.clone()

    def _draw_mirror(self, mask: Tensor) -> None:
        if not self.mirror_enabled:
            return
        flips = torch.rand(self.n, generator=self._mirror_gen, device=self.device) < 0.5
        self.mirrored = torch.where(mask, flips, self.mirrored)

    def set_start_weights(self, w: list[float]) -> None:
        """课程学习：改起点采样权重（下一次 reset 生效，即各 env 下一局才换分布）。"""
        self.env.set_start_weights(list(w))

    def reset(self) -> RawObs:
        self.env.reset()
        self.intent.reset_all()
        self._draw_mirror(torch.ones(self.n, dtype=torch.bool, device=self.device))
        self.prev_buttons = torch.zeros(self.n, dtype=torch.int64, device=self.device)
        self.prev_action = torch.zeros(self.n, dtype=torch.int64, device=self.device)
        self.dir_hold = torch.full((self.n,), DIR_HOLD_NEVER, dtype=torch.int64, device=self.device)
        self.slow_held = torch.full((self.n,), DIR_HOLD_NEVER, dtype=torch.int64, device=self.device)
        self._enemy_prev_valid = torch.zeros(self.n, dtype=torch.bool, device=self.device)
        if self.motor is not None:
            self.motor.reset_all()
        return self._decode()

    def step(self, action_ids: Tensor, timer=None) -> tuple[RawObs, StepInfo]:
        # 运动层：策略给的是「想按的」，从这里往下（镜像、env、上一步动作、按键统计、reward）全按**实际执行的**算。
        # dir_hold 在变向那步清零、之后每步 +1，所以「当前方向已执行帧数」= dir_hold + 1。
        want = action_ids
        if self.motor is not None:
            action_ids = self.motor.apply(want, self.prev_action, self.dir_hold + 1, self.slow_held).to(want.dtype)
        overridden = action_ids != want          # 方向或低速位，任一路被运动层否决都算
        # 低速位已执行帧数：换了 → 1，否则 +1（与 dir_held = dir_hold + 1 同口径）；不管开没开运动层都记
        slow_chg = (action_ids % 2) != (self.prev_action % 2)
        self.slow_held = torch.where(slow_chg, torch.ones_like(self.slow_held),
                                     (self.slow_held + 1).clamp_max(DIR_HOLD_NEVER))
        ids = torch.where(self.mirrored, self._mirror[action_ids], action_ids)
        buttons = self._buttons[ids]
        with _phase(timer, "env_step"):
            self.env.step(buttons.to("cpu"))
        with _phase(timer, "h2d"):
            done = self._dev(self.buf["done"]).to(torch.int64)
            events = self._dev(self.buf["events"]).to(torch.int64)
            ep_frames = self._dev(self.buf["ep_frames"]).to(torch.int64)
            ended = done != 0
            # **先拍下模式再 reset**：reset 会给结束的 env 抽新一局的模式，晚读就把刚结束那局
            # 标成了下一局的档，三档统计等于随机切一刀（2026-09-19 实验 I 踩过）。
            # start_index 没这个问题——它是 env 在自动 reset 之前写进缓冲的。
            # 方向保持步数：本步决策相对上一步换没换方向；换了就读出上一段保持了多久，然后清零。
            # reward 的 quick_change 与 episodes 的连击统计都吃这一份，避免两处各算一遍算岔。
            dir_chg = actions.direction_changed(self.prev_buttons, buttons)
            self.dir_hold = self.dir_hold + 1
            hold_now = self.dir_hold.clone()
            self.dir_hold = torch.where(dir_chg, torch.zeros_like(self.dir_hold), self.dir_hold)
            mode = getattr(self.intent, "mode", None)
            mode = mode.clone() if mode is not None else None
            self.intent.reset(ended)
            self._draw_mirror(ended)
            refreshed = self.intent.advance(self.frame_skip, ~ended)
            info = StepInfo(done=done, events=events, ep_frames=ep_frames, refreshed=refreshed,
                            buttons=buttons, prev_buttons=self.prev_buttons,
                            dir_hold=hold_now, overridden=overridden,
                            start_index=self._dev(self.buf["start_index"]).to(torch.int64),
                            intent_mode=mode)
            self.prev_buttons = torch.where(ended, torch.zeros_like(buttons), buttons)
            self.dir_hold = torch.where(ended, torch.full_like(self.dir_hold, DIR_HOLD_NEVER), self.dir_hold)
            self.slow_held = torch.where(ended, torch.full_like(self.slow_held, DIR_HOLD_NEVER), self.slow_held)
            # 智能体坐标系的动作 id：镜像只在新局重抽，而新局这里清零，所以不会与镜像标志错位
            self.prev_action = torch.where(ended, torch.zeros_like(action_ids), action_ids.to(torch.int64))
            self._enemy_prev_valid = self._enemy_prev_valid & ~ended
            if self.motor is not None:
                self.motor.reset(ended)
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
        ex, ey = _fx(en, _off("enemies", "x")), _fx(en, _off("enemies", "y"))
        eids = _u32(en, _off("enemies", "id"))
        exy = torch.stack([ex, ey], dim=-1)
        evel = enemy_velocity(self._prev_enemy_ids, self._prev_enemy_xy, eids, exy,
                              self.frame_skip, self._enemy_prev_valid)
        self._prev_enemy_ids, self._prev_enemy_xy = eids, exy
        self._enemy_prev_valid = torch.ones_like(self._enemy_prev_valid)
        enemies = torch.stack([
            ex, ey, _fx(en, _off("enemies", "hit_w")),
            ((eflags & ENEMY_FLAG_BOSS) != 0).to(torch.float32), evel[..., 0], evel[..., 1],
        ], dim=-1)

        if hasattr(self.intent, "track"):   # 自由躲弹诊断：目标点锁自机（未镜像坐标）
            self.intent.track(torch.stack([px, py], dim=-1))
        if hasattr(self.intent, "track_world"):   # 跟随场上实体的意图（如 boss 正下方），同样用未镜像坐标
            self.intent.track_world(torch.stack([px, py], dim=-1), enemies[..., 0:2],
                                    enemies[..., 3] != 0, emask)
        target = self.intent.target.clone()
        sign = torch.where(self.mirrored, -1.0, 1.0)
        px = px * sign
        bullets[..., 0] *= sign[:, None]
        bullets[..., 2] *= sign[:, None]
        enemies[..., 0] *= sign[:, None]
        enemies[..., 4] *= sign[:, None]   # 敌人速度 x 分量随镜像取反
        target[:, 0] *= sign
        return RawObs(
            player_xy=torch.stack([px, py], dim=-1), player_hit_r=hit_r, player_speed=speed, player_focus=focus,
            bullets=bullets, bullets_mask=bmask, enemies=enemies, enemies_mask=emask, target_xy=target,
            prev_action=self.prev_action.clone(), dir_held=(self.dir_hold + 1).clone(),
            slow_held=self.slow_held.clone(),
        )
