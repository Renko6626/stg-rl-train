"""评测局操作回放 GIF：看 checkpoint 在评测卡上实际怎么走、怎么抖。

    python -m stgtrain.replay_gif runs/<run>/checkpoints/best.pt                        # 评测划分每张卡 × rank 2 × 第 0 局
    python -m stgtrain.replay_gif <ckpt> --cards th06_s2_mb1,th06_s1_b4 --episodes 0,1,2 --every 1

与评测完全同一局：VecEnv 局数、种子、意图种子、不镜像都照 `evaluate.run_group`，第 k 局 = 那组 VecEnv 的第 k 个 env。
（CPU 回放与 GPU 训练时的评测浮点不同，个别局走向可能分叉。）

画面：弹 / 敌 / 自机同弹幕预览（stgtranscribe.preview，需要本机 stg-engine 的弹图集）；黄圈 = 指令点（R = hold_radius，
自机进圈变绿），白点拖尾 = 最近 30 帧轨迹，按住低速时显示判定点。底部 HUD：最近 64 帧的方向键带（每帧一格，颜色 = 方向，
下沿红 = 低速）、当前按键、最近 1 秒按键次数。结束帧标 DEATH / CLEAR（done 码 1 / 2）。
产物默认 `runs/<run>/replay/<卡>_r<档>_e<局>.gif`。
"""
from __future__ import annotations

import argparse
import math
import multiprocessing as mp
import time
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

import stg_rl
import torch
from PIL import Image, ImageDraw

from stgtranscribe import preview as P

from . import actions
from .cards import allowed_ranks, discover
from .checkpoint import load_checkpoint
from .config import deep_merge, from_dict
from .envwrap import EnvWrapper, _fx, _off, _u16
from .ppo import PPO
from .train import build_components, pick_device

HUD_H = 40
TAPE = 64
TRAIL = 30
_DIR_COLORS = [(70, 70, 80), (90, 170, 255), (80, 220, 220), (90, 230, 120), (220, 230, 90),
               (255, 170, 60), (255, 100, 90), (230, 90, 220), (150, 110, 255)]  # 方向 0–8，同 actions.DIR_BUTTONS
_DIR_ARROWS = ["--", "U", "UR", "R", "DR", "D", "DL", "L", "UL"]


@dataclass
class EnvFrame:
    bullets: list[P.Bullet]
    enemies: list[P.Enemy]
    player: tuple[float, float]
    focus: bool


@dataclass
class RecFrame:
    frame: int
    env: EnvFrame
    target: tuple[float, float]
    buttons: int = 0


@dataclass
class Episode:
    card: str
    rank: int
    index: int
    hold_radius: float
    frame_skip: int
    frames: list[RecFrame] = field(default_factory=list)
    done: int = 0


def decode_env(buf: dict, i: int) -> EnvFrame:
    """第 i 个 env 的原始缓冲（世界坐标、未镜像）→ 画面用的一帧。"""
    lo, hi = int(buf["bullets_offsets"][i]), int(buf["bullets_offsets"][i + 1])
    rows = buf["bullets"][lo:hi]
    bullets: list[P.Bullet] = []
    if hi > lo:
        xs, ys = _fx(rows, _off("bullets", "x")), _fx(rows, _off("bullets", "y"))
        ang = _u16(rows, _off("bullets", "angle")).to(torch.float32) * (360.0 / 65536.0)
        spr = _u16(rows, _off("bullets", "type"))
        bullets = [P.Bullet(x, y, d, s) for x, y, d, s in zip(xs.tolist(), ys.tolist(), ang.tolist(), spr.tolist())]
    ne = int(buf["enemies_count"][i])
    en = buf["enemies"][i, :ne]
    enemies = [P.Enemy(x, y, 0) for x, y in zip(_fx(en, _off("enemies", "x")).tolist(),
                                                  _fx(en, _off("enemies", "y")).tolist())] if ne else []
    pl = buf["player"][i]
    px = float(_fx(pl[None], _off("player", "x"))[0])
    py = float(_fx(pl[None], _off("player", "y"))[0])
    return EnvFrame(bullets, enemies, (px, py), bool(pl[_off("player", "focus")]))


def gif_durations(n: int, frames_per_image: int) -> list[int]:
    """GIF 帧时长只有 10 ms 精度：按累计时刻取整再差分，整段平均恰为原速。"""
    t = frames_per_image * 1000.0 / 60.0
    r10 = lambda ms: int(round(ms / 10.0)) * 10  # noqa: E731
    return [max(10, r10((k + 1) * t) - r10(k * t)) for k in range(n)]


def record(cfg: dict, ppo, featurizer, image, card: str, rank: int, episodes: int, indices: list[int],
           device, max_frames: int | None) -> list[Episode]:
    """与 evaluate.run_group 同一组 VecEnv；按顺序记录指定 env 的第一局，每步记「当前状态 + 本步按键」。"""
    envw = EnvWrapper(cfg, {card: image}, [stg_rl.Start(card, 0, rank)], device,
                      seed=int(cfg["eval"]["seed"]), num_envs=episodes, mirror=False)
    hold_r = float(cfg["reward"]["hold_radius"])
    eps = {i: Episode(card, rank, i, hold_r, envw.frame_skip) for i in indices}
    live = set(indices)
    obs = envw.reset()
    step_cap = int(cfg["env"]["max_frames"]) // envw.frame_skip + 2
    if max_frames:
        step_cap = min(step_cap, max_frames // envw.frame_skip)
    for step in range(step_cap):
        action = ppo.act(featurizer(obs), True)
        buttons = envw._buttons[action].cpu()
        frame_no = step * envw.frame_skip
        for i in live:
            t = envw.intent.target[i].tolist()
            eps[i].frames.append(RecFrame(frame_no, decode_env(envw.buf, i), (t[0], t[1]), int(buttons[i])))
        obs, info = envw.step(action)
        done = info.done.cpu()
        for i in list(live):
            if int(done[i]) != 0:
                eps[i].done = int(done[i])
                live.discard(i)
        if not live:
            break
    return [eps[i] for i in indices]


def _dir_index(buttons: int) -> int:
    m = buttons & actions.DIR_MASK
    return actions.DIR_BUTTONS.index(m) if m in actions.DIR_BUTTONS else 0


def _hud(ep: Episode, k: int) -> Image.Image:
    im = Image.new("RGB", (P.FIELD_W, HUD_H), (16, 16, 24))
    d = ImageDraw.Draw(im)
    lo = max(0, k - TAPE + 1)
    cell = 4
    for j, f in enumerate(ep.frames[lo:k + 1]):
        dir_idx = _dir_index(f.buttons)
        x0 = 4 + j * cell
        d.rectangle((x0, 4, x0 + cell - 2, 20), fill=_DIR_COLORS[dir_idx])
        if f.buttons & actions.C.BTN_SLOW:
            d.rectangle((x0, 22, x0 + cell - 2, 25), fill=(230, 60, 60))
    cur = ep.frames[k]
    dir_idx = _dir_index(cur.buttons)
    w = max(1, round(60 / ep.frame_skip))
    presses = 0
    for a, b in zip(ep.frames[max(0, k - w):k], ep.frames[max(0, k - w) + 1:k + 1]):
        presses += int(actions.key_changes(torch.tensor([a.buttons]), torch.tensor([b.buttons]))[0])
    slow = "SLOW" if cur.buttons & actions.C.BTN_SLOW else ""
    d.text((4 + TAPE * cell + 8, 6), f"{_DIR_ARROWS[dir_idx]} {slow}", fill=(235, 235, 235))
    d.text((4, 28), f"keys/s {presses:>2}   (tape = last {TAPE} steps, color = direction, red = slow)", fill=(150, 150, 160))
    return im


def render_episode(ep: Episode, out_path: Path, every: int) -> Path:
    r = P.Renderer()
    imgs = []
    idxs = list(range(0, len(ep.frames), every))
    for k in idxs:
        f = ep.frames[k]
        title = f"{ep.card} {P.RANK_NAMES[ep.rank]} e{ep.index} f{f.frame} b{len(f.env.bullets)}"
        snap = P.Snapshot(f.frame, f.env.enemies, f.env.bullets)
        field_im = r.draw(snap, title, player_xy=f.env.player)
        d = ImageDraw.Draw(field_im)
        ox, oy = P.HALF_W, P.HEADER_H
        # 拖尾
        for j, g in enumerate(ep.frames[max(0, k - TRAIL):k]):
            a = int(60 + 150 * (j + 1) / TRAIL)
            gx, gy = g.env.player[0] + ox, g.env.player[1] + oy
            d.point((gx, gy), fill=(a, a, a))
        px, py = f.env.player[0] + ox, f.env.player[1] + oy
        tx, ty = f.target[0] + ox, f.target[1] + oy
        inside = math.dist(f.env.player, f.target) < ep.hold_radius
        col = (90, 230, 120) if inside else (240, 210, 70)
        R = ep.hold_radius
        d.ellipse((tx - R, ty - R, tx + R, ty + R), outline=col, width=1)
        d.line((px, py, tx, ty), fill=(120, 110, 50), width=1)
        if f.env.focus:
            d.ellipse((px - 3, py - 3, px + 3, py + 3), fill=(255, 60, 60), outline=(255, 255, 255))
        if k == idxs[-1] and ep.done in (1, 2):
            d.text((P.FIELD_W // 2 - 20, P.HEADER_H + P.FIELD_H // 2), "DEATH" if ep.done == 1 else "CLEAR",
                   fill=(255, 80, 80) if ep.done == 1 else (120, 255, 140))
        canvas = Image.new("RGB", (P.FIELD_W, P.FIELD_H + P.HEADER_H + HUD_H))
        canvas.paste(field_im, (0, 0))
        canvas.paste(_hud(ep, k), (0, P.FIELD_H + P.HEADER_H))
        imgs.append(canvas)
    durs = gif_durations(len(imgs), every * ep.frame_skip)
    durs[-1] += 1500  # 结束帧停 1.5 秒
    out_path.parent.mkdir(parents=True, exist_ok=True)
    imgs[0].save(out_path, save_all=True, append_images=imgs[1:], loop=0, duration=durs)
    return out_path


def _render_job(args) -> str:
    ep, path, every = args
    return str(render_episode(ep, path, every))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.replay_gif", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("checkpoint")
    ap.add_argument("--device", default="cpu", choices=("auto", "cpu", "cuda"))
    ap.add_argument("--cards", default=None, help="逗号分隔的卡 id（默认评测划分里的全部卡）")
    ap.add_argument("--rank", type=int, default=2)
    ap.add_argument("--episodes", default="0", help="评测组里第几局，逗号分隔（默认 0）")
    ap.add_argument("--every", type=int, default=2, help="每几个决策步出一帧 GIF（默认 2 = 30 fps）")
    ap.add_argument("--max-frames", type=int, default=None, help="最多录多少游戏帧（默认录到局结束）")
    ap.add_argument("--jobs", type=int, default=8, help="并行出图进程数")
    ap.add_argument("--out", default=None, help="输出目录（默认 runs/<run>/replay）")
    a = ap.parse_args(argv)

    for need in (P.atlas_path(),):
        if not need.exists():
            raise SystemExit(f"缺 {need}（stg-engine 路径见 STG_ENGINE_DIR）")
    ckp = Path(a.checkpoint)
    ck = load_checkpoint(ckp, map_location="cpu")
    cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": a.device}}))
    device = pick_device(cfg["run"]["device"])
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))
    images, _starts, specs, featurizer, factory = build_components(cfg, device)
    ppo = PPO(cfg, factory, device)
    ppo.load_state_dict(ck["state"])

    split_n = {s.card: s.episodes for s in specs}
    all_cards = discover(cfg["env"]["cards_dir"])
    cards = a.cards.split(",") if a.cards else [s.card for s in specs]
    indices = [int(x) for x in a.episodes.split(",")]
    out_dir = Path(a.out) if a.out else ckp.parent.parent / "replay"

    t0 = time.perf_counter()
    jobs = []
    for card in cards:
        if card not in all_cards:
            raise SystemExit(f"卡池里没有 {card}")
        if not allowed_ranks(all_cards[card], [a.rank]):
            print(f"  跳过 {card}：meta ranks 不含 {a.rank}")
            continue
        n = split_n.get(card, int(cfg["eval"]["episodes"]))
        if max(indices) >= n:
            raise SystemExit(f"{card} 评测组只有 {n} 局，--episodes 越界")
        for ep in record(cfg, ppo, featurizer, images[card], card, a.rank, n, indices, device, a.max_frames):
            tag = {0: "未结束", 1: "死亡", 2: "撑过"}.get(ep.done, str(ep.done))
            print(f"  {card} r{a.rank} e{ep.index}: {len(ep.frames) * ep.frame_skip} 帧 · {tag}", flush=True)
            jobs.append((ep, out_dir / f"{card}_r{a.rank}_e{ep.index}.gif", a.every))
    # spawn：父进程已起 torch / rayon 线程，fork 不安全
    with ProcessPoolExecutor(max_workers=max(1, min(a.jobs, len(jobs))), mp_context=mp.get_context("spawn")) as ex:
        for path in ex.map(_render_job, jobs):
            print(f"  → {path}", flush=True)
    print(f"完成 {len(jobs)} 个 GIF · 用时 {time.perf_counter() - t0:.0f} s · {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
