"""弹幕预览出图：用 release harness 的 `run --at F` 取帧，按真弹图集画成 PNG 拼图 / GIF。

    python -m stgtranscribe.preview                          # cards/ 全部卡 × 卡内全部档，每档一张 8 帧拼图
    python -m stgtranscribe.preview cards/th06_s3_w12 --ranks 2-3 --gif
    python -m stgtranscribe.preview --serve                  # 起静态页（127.0.0.1:8612），ssh -L 转发后浏览

产物在 transcribe/work/preview/（gitignore；图集来自原作弹片，别提交）：
    <卡 id>/sheet_r<档>.png   选帧 = 有弹时间窗（首个到最后有弹帧）均匀取样 + 弹数峰值帧，峰值帧标题栏标红
    <卡 id>/anim_r<档>.gif    --gif：每 gif_step 帧取一帧，播放速度 = 原速
    index.html               全部拼图一页

口径：harness 不按键，自机停在场底中心 (0, 384) 不动，自机狙都瞄这个点。
取帧每次从开局重跑（一帧约 10–20 ms），GIF 用线程池并发。
"""
from __future__ import annotations

import argparse
import math
import os
import re
import subprocess
import sys
import tomllib
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from . import config

FIELD_W, FIELD_H, HEADER_H = 384, 448, 18
HALF_W = FIELD_W // 2
CELL, ATLAS_COLS, ATLAS_ROWS = 16, 16, 12
PLAYER_XY = (0.0, 384.0)
RANK_NAMES = "ENHLX"
BG = (8, 8, 16)
ROT_STEPS = 64  # 旋转缓存量化：一圈 64 档（5.625°），16px 贴图看不出差别
OUT_DIR = config.WORK_DIR / "preview"


@dataclass(frozen=True)
class Bullet:
    x: float
    y: float
    deg: float
    sprite: int


@dataclass(frozen=True)
class Enemy:
    x: float
    y: float
    sprite: int


@dataclass(frozen=True)
class Laser:
    ox: float
    oy: float
    deg: float
    start: float
    end: float
    width: float
    state: int   # 0 预警 · 1 生效 · 2 收缩
    timer: int
    warn: int
    fade: int
    color: int


@dataclass(frozen=True)
class Snapshot:
    frame: int
    enemies: list[Enemy]
    bullets: list[Bullet]
    lasers: list[Laser] = ()


@dataclass(frozen=True)
class Summary:
    peak_bullets: int
    peak_frame: int
    phase_end: int | None
    peak_lasers: int = 0
    peak_laser_frame: int = 0


def atlas_path() -> Path:
    return config.engine_dir() / "godot" / "assets" / "bullets.png"


def player_path() -> Path:
    return config.engine_dir() / "godot" / "assets" / "player.png"


# ── 解析 harness 输出 ────────────────────────────────────────────────────────

_TABLE_RE = re.compile(r"^帧 (\d+) · 活(敌|弹|激光) \d+ ")
_PEAK_RE = re.compile(r"^峰值：弹 (\d+)（帧 (\d+)）")
_LASER_PEAK_RE = re.compile(r"激光 (\d+)（帧 (\d+)）")
_PHASE_END_RE = re.compile(r"PHASE_ENDED@(\d+)")


def parse_at(text: str) -> Snapshot:
    """`run --at F` 的活敌 / 活弹 / 活激光三张表。表头之后逐行读到第一条不是数据行为止。"""
    frame, enemies, bullets, lasers = -1, [], [], []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        m = _TABLE_RE.match(lines[i])
        if not m:
            i += 1
            continue
        frame, kind = int(m.group(1)), m.group(2)
        i += 2  # 跳过表头
        while i < len(lines):
            p = lines[i].split()
            if kind == "敌" and len(p) == 5 and p[0].isdigit():
                enemies.append(Enemy(float(p[1]), float(p[2]), int(p[4])))
            elif kind == "弹" and len(p) == 7 and p[0].isdigit():
                bullets.append(Bullet(float(p[1]), float(p[2]), float(p[4]), int(p[6])))
            elif kind == "激光" and len(p) == 14 and p[0].isdigit():
                warn, _, fade = (int(v) for v in p[12].split("/"))
                lasers.append(Laser(float(p[1]), float(p[2]), float(p[4]), float(p[5]), float(p[6]),
                                    float(p[7]), int(p[10]), int(p[11]), warn, fade, int(p[13])))
            else:
                break
            i += 1
    return Snapshot(frame, enemies, bullets, lasers)


def parse_summary(text: str) -> Summary:
    peak, peak_frame, end, lpeak, lframe = 0, 0, None, 0, 0
    for line in text.splitlines():
        if m := _PEAK_RE.match(line):
            peak, peak_frame = int(m.group(1)), int(m.group(2))
            if lm := _LASER_PEAK_RE.search(line):
                lpeak, lframe = int(lm.group(1)), int(lm.group(2))
        elif line.startswith("段结束：") and (m := _PHASE_END_RE.search(line)):
            end = int(m.group(1))
    return Summary(peak, peak_frame, end, lpeak, lframe)


_COUNT_ROW_RE = re.compile(r"^\s+(\d+)\s+(\d+)(?:\s+\d+){6}\s*$")
_BULLET_COUNT_RE = re.compile(r"^帧 \d+ · 活弹 (\d+) 条", re.M)
_LASER_COUNT_RE = re.compile(r"^帧 \d+ · 活激光 (\d+) 条", re.M)


def parse_counts(text: str) -> list[tuple[int, int]]:
    """`run` 的采样计数表 → [(帧, 弹数)]（每 1/10 段一行）。"""
    return [(int(m.group(1)), int(m.group(2))) for line in text.splitlines() if (m := _COUNT_ROW_RE.match(line))]


def active_window(counts: list[tuple[int, int]], count_at, end: int) -> tuple[int, int]:
    """第一 / 最后有弹帧：采样表圈出区间，再在相邻采样点之间对 `count_at(帧)` 二分。全程无弹返回 (1, end)。"""
    nz = [k for k, (_, b) in enumerate(counts) if b > 0]
    if not nz:
        return 1, end
    i, j = nz[0], nz[-1]
    lo, hi = (counts[i - 1][0] if i > 0 else 0), counts[i][0]   # count(lo)=0, count(hi)>0
    while hi - lo > 1:
        mid = (lo + hi) // 2
        lo, hi = (lo, mid) if count_at(mid) > 0 else (mid, hi)
    first = hi
    lo = counts[j][0]
    hi = counts[j + 1][0] if j + 1 < len(counts) else end + 1    # count(lo)>0，hi 视作 0
    while hi - lo > 1:
        mid = (lo + hi) // 2
        lo, hi = (mid, hi) if count_at(mid) > 0 else (lo, mid)
    return max(1, first), min(lo, end)


def first_nonzero(count_at, hi: int) -> int:
    """(0, hi] 里第一个 `count_at > 0` 的帧（已知 count_at(hi) > 0、count_at(0) = 0；按单调近似二分）。"""
    lo = 0
    while hi - lo > 1:
        mid = (lo + hi) // 2
        lo, hi = (lo, mid) if count_at(mid) > 0 else (mid, hi)
    return hi


def pick_frames(end: int, peak: int, n: int, start: int = 1) -> list[int]:
    """[start, end] 里均匀取 n 帧，离峰值帧最近的那一帧换成峰值帧。"""
    if end - start + 1 <= n:
        return list(range(start, end + 1))
    base = [round(start + k * (end - start) / (n - 1)) for k in range(n)]
    if start <= peak <= end and peak not in base:
        base[min(range(n), key=lambda k: abs(base[k] - peak))] = peak
    return sorted(set(base))


# ── 图集 ─────────────────────────────────────────────────────────────────────

def cell_box(sprite: int) -> tuple[int, int, int, int]:
    """sprite 号 = 格号（行优先），越界回卷（同 godot/shaders/layer.gdshader）。"""
    s = sprite % (ATLAS_COLS * ATLAS_ROWS)
    col, row = s % ATLAS_COLS, s // ATLAS_COLS
    return (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL)


def pil_rotation(deg: float) -> float:
    """贴图朝上；桥 `bullet_basis` 旋转 angle + 90°（y 朝下）。PIL `rotate` 逆时针为正，所以取负。"""
    return -(deg + 90.0)


# 16 色表照 stg-engine godot/shaders/laser.gdshader（颜色号 = bullets.ecl 的色列顺序）
LASER_COLORS = [
    (164, 164, 164), (170, 40, 40), (255, 0, 0), (170, 40, 170), (255, 80, 255), (0, 0, 200),
    (0, 40, 255), (0, 200, 248), (0, 248, 248), (40, 180, 90), (0, 248, 120), (120, 248, 48),
    (200, 220, 60), (255, 240, 0), (255, 160, 40), (255, 255, 255),
]
LASER_BANDS = 5  # 截面分几层叠加：层层加色近似 shader 的「中心白芯、两侧渐暗」


def laser_display(lz: Laser) -> tuple[float, float]:
    """显示宽度 / alpha，照 stg-godot frame.rs `laser_display`：预警 1.2 px、最后 min(warn,30) 帧长到全宽；
    生效全宽；收缩宽度线性到 0（harness 不印 flags，淡出 alpha 那条腿按变窄画）。"""
    if lz.state == 0:
        ramp = min(lz.warn, 30)
        t0 = lz.warn - ramp
        if ramp > 0 and lz.timer >= t0:
            return 1.2 + (lz.width - 1.2) * (lz.timer - t0) / ramp, 1.0
        return 1.2, 1.0
    if lz.state == 1:
        return lz.width, 1.0
    k = 0.0 if lz.fade == 0 else 1.0 - lz.timer / lz.fade
    return lz.width * k, 1.0


def draw_lasers(im: Image.Image, lasers) -> Image.Image:
    """加色混合画激光（压在自机之上、弹层之下）。"""
    if not lasers:
        return im
    glow = Image.new("RGB", im.size, (0, 0, 0))
    for lz in lasers:
        w, alpha = laser_display(lz)
        if w <= 0 or alpha <= 0 or lz.end <= lz.start:
            continue
        rad = math.radians(lz.deg)
        dx, dy = math.cos(rad), math.sin(rad)
        cx, cy = -dy, dx
        ox, oy = lz.ox + HALF_W, lz.oy + HEADER_H
        a = (ox + dx * lz.start, oy + dy * lz.start)
        b = (ox + dx * lz.end, oy + dy * lz.end)
        base = LASER_COLORS[lz.color % 16]
        if w < 3:  # 预警细线
            layer = Image.new("RGB", im.size, (0, 0, 0))
            ImageDraw.Draw(layer).line((a, b), fill=tuple(round(c * 0.8 * alpha) for c in base), width=1)
            glow = ImageChops.add(glow, layer)
            continue
        for j in range(LASER_BANDS):
            hw = w / 2 * (1 - j / LASER_BANDS)
            t = ((j + 1) / LASER_BANDS) ** 2  # 越靠内越白
            col = tuple(round((c + (255 - c) * t) * alpha * 1.6 / LASER_BANDS) for c in base)
            poly = [(a[0] + cx * hw, a[1] + cy * hw), (b[0] + cx * hw, b[1] + cy * hw),
                    (b[0] - cx * hw, b[1] - cy * hw), (a[0] - cx * hw, a[1] - cy * hw)]
            layer = Image.new("RGB", im.size, (0, 0, 0))
            ImageDraw.Draw(layer).polygon(poly, fill=col)
            glow = ImageChops.add(glow, layer)
    return ImageChops.add(im, glow)


class Renderer:
    def __init__(self):
        self.atlas = Image.open(atlas_path()).convert("RGBA")
        pp = player_path()
        self.player = Image.open(pp).convert("RGBA") if pp.exists() else None
        self._rot: dict[tuple[int, int], Image.Image] = {}

    def sprite(self, sprite: int, deg: float) -> Image.Image:
        step = round(deg / 360.0 * ROT_STEPS) % ROT_STEPS
        key = (sprite, step)
        img = self._rot.get(key)
        if img is None:
            cell = self.atlas.crop(cell_box(sprite))
            img = cell.rotate(pil_rotation(step * 360.0 / ROT_STEPS), resample=Image.BICUBIC, expand=True)
            self._rot[key] = img
        return img

    def draw(self, snap: Snapshot, title: str, highlight: bool = False,
             player_xy: tuple[float, float] = PLAYER_XY) -> Image.Image:
        im = Image.new("RGB", (FIELD_W, FIELD_H + HEADER_H), BG)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, FIELD_W - 1, HEADER_H - 1), fill=(150, 30, 30) if highlight else (40, 40, 56))
        d.text((4, 3), title, fill=(235, 235, 235))
        for e in snap.enemies:
            cx, cy = e.x + HALF_W, e.y + HEADER_H
            d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=(120, 220, 140), width=2)
        if self.player is not None:
            px, py = player_xy[0] + HALF_W, player_xy[1] + HEADER_H
            im.paste(self.player, (round(px - self.player.width / 2), round(py - self.player.height / 2)), self.player)
        im = draw_lasers(im, snap.lasers)
        for b in snap.bullets:
            spr = self.sprite(b.sprite, b.deg)
            im.paste(spr, (round(b.x + HALF_W - spr.width / 2), round(b.y + HEADER_H - spr.height / 2)), spr)
        return im


# ── 跑 harness ──────────────────────────────────────────────────────────────

def harness(card: Path, rank: int, frames: int, at: int | None = None) -> str:
    cmd = [str(config.harness_bin()), "run", str(card), "--rank", str(rank), "--frames", str(frames)]
    if at is not None:
        cmd += ["--at", str(at)]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if p.returncode != 0 and "活弹" not in p.stdout:
        raise RuntimeError(f"harness 失败（{card} rank {rank} at {at}）：\n{p.stdout}{p.stderr}")
    return p.stdout


def card_meta(card: Path) -> dict:
    m = card / "meta.toml"
    return tomllib.loads(m.read_text(encoding="utf-8")) if m.exists() else {}


def snapshots(card: Path, rank: int, frames: list[int], threads: int) -> list[Snapshot]:
    with ThreadPoolExecutor(max_workers=max(1, threads)) as ex:
        return list(ex.map(lambda f: parse_at(harness(card, rank, f, at=f)), frames))


def render_card(card: Path, rank: int, out_dir: Path = OUT_DIR, n_frames: int = 8, cols: int = 4,
                gif_step: int | None = None, gif_frames: int | None = None, threads: int = 8) -> dict[str, Path]:
    card = Path(card)
    meta = card_meta(card)
    limit = int(meta.get("time_limit", 600))
    run_text = harness(card, rank, limit + 30)
    summary = parse_summary(run_text)
    count_at = lambda f: int(m.group(1)) if (m := _BULLET_COUNT_RE.search(harness(card, rank, f, at=f))) else 0  # noqa: E731
    start, end = active_window(parse_counts(run_text), count_at, summary.phase_end or limit)
    if summary.peak_lasers > 0 and summary.peak_laser_frame < start:  # 采样计数表不含激光
        laser_at = lambda f: int(m.group(1)) if (m := _LASER_COUNT_RE.search(harness(card, rank, f, at=f))) else 0  # noqa: E731
        start = max(1, first_nonzero(laser_at, summary.peak_laser_frame))
    dst = Path(out_dir) / card.name
    dst.mkdir(parents=True, exist_ok=True)
    r = Renderer()
    tag = RANK_NAMES[rank] if 0 <= rank < len(RANK_NAMES) else str(rank)
    title = lambda s: f"{card.name}  {tag}  f{s.frame}  b{len(s.bullets)}" + (f"  L{len(s.lasers)}" if s.lasers else "")  # noqa: E731

    frames = pick_frames(end, summary.peak_frame, n_frames, start=start)
    snaps = snapshots(card, rank, frames, threads)
    rows = math.ceil(len(snaps) / cols)
    sheet = Image.new("RGB", (cols * FIELD_W, rows * (FIELD_H + HEADER_H)), (0, 0, 0))
    for k, s in enumerate(snaps):
        panel = r.draw(s, title(s) + ("  PEAK" if s.frame == summary.peak_frame else ""),
                       highlight=s.frame == summary.peak_frame)
        sheet.paste(panel, ((k % cols) * FIELD_W, (k // cols) * (FIELD_H + HEADER_H)))
    out = {"sheet": dst / f"sheet_r{rank}.png"}
    sheet.save(out["sheet"])

    if gif_step:
        last = min(end, start + gif_frames - 1) if gif_frames else end
        gsnaps = snapshots(card, rank, list(range(start, last + 1, gif_step)), threads)
        imgs = [r.draw(s, title(s)) for s in gsnaps]
        out["gif"] = dst / f"anim_r{rank}.gif"
        imgs[0].save(out["gif"], save_all=True, append_images=imgs[1:], loop=0,
                     duration=max(20, round(gif_step * 1000 / 60)))
    return out


# ── 批量与静态页 ────────────────────────────────────────────────────────────

def find_cards(paths: list[Path]) -> list[Path]:
    found = []
    for p in paths:
        if (p / "main.ecl").exists():
            found.append(p)
        elif p.is_dir():
            found += sorted(d for d in p.iterdir() if (d / "main.ecl").exists())
    return found


def _ranks(spec: str) -> list[int]:
    lo, _, hi = spec.partition("-")
    return list(range(int(lo), int(hi or lo) + 1))


def _job(args: tuple) -> tuple[str, int, dict | str]:
    card, rank, kw = args
    try:
        return card.name, rank, render_card(card, rank, **kw)
    except Exception as e:  # 一张卡出错不拖垮整批
        return card.name, rank, f"{type(e).__name__}: {e}"


def write_index(out_dir: Path) -> Path:
    rows = []
    for d in sorted(p for p in out_dir.iterdir() if p.is_dir()):
        title = card_meta(config.CARDS_DIR / d.name).get("title", "")
        rows.append(f"<h2>{d.name} <small>{title}</small></h2>")
        for sheet in sorted(d.glob("sheet_r*.png")):
            rank = sheet.stem.removeprefix("sheet_r")
            gif = d / f"anim_r{rank}.gif"
            link = f' · <a href="{d.name}/{gif.name}">GIF</a>' if gif.exists() else ""
            rows.append(f'<p>rank {rank}{link}<br><a href="{d.name}/{sheet.name}">'
                        f'<img src="{d.name}/{sheet.name}" loading="lazy"></a></p>')
    html = ("<!doctype html><meta charset=utf-8><title>弹幕预览</title>"
            "<style>body{background:#111;color:#ddd;font:14px sans-serif;margin:16px}"
            "img{max-width:100%;border:1px solid #333}a{color:#8cf}small{color:#999}</style>\n"
            + "\n".join(rows))
    p = out_dir / "index.html"
    p.write_text(html, encoding="utf-8")
    return p


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtranscribe.preview", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", type=Path, help="卡目录或含卡的目录（默认 cards/）")
    ap.add_argument("--ranks", default="0-3", help="要出的档，和卡 meta 的 ranks 取交集（默认 0-3）")
    ap.add_argument("--frames", type=int, default=8, help="拼图帧数（默认 8）")
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--gif", action="store_true", help="另出 GIF")
    ap.add_argument("--gif-step", type=int, default=3, help="GIF 每几帧取一帧（默认 3，即 20 fps）")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 8), help="并行卡×档数")
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    ap.add_argument("--serve", action="store_true", help="不出图，起静态页服务预览目录")
    ap.add_argument("--port", type=int, default=8612)
    a = ap.parse_args(argv)

    if a.serve:
        print(f"http://localhost:{a.port}/  （远程先 ssh -L {a.port}:localhost:{a.port} <机器>；Ctrl+C 停）")
        return subprocess.call([sys.executable, "-m", "http.server", str(a.port), "--bind", "127.0.0.1",
                                "--directory", str(a.out)])

    for need in (config.harness_bin(), atlas_path()):
        if not need.exists():
            print(f"缺 {need}（stg-engine 路径见 STG_ENGINE_DIR）", file=sys.stderr)
            return 2
    cards = find_cards(a.paths or [config.CARDS_DIR])
    want = _ranks(a.ranks)
    kw = {"out_dir": a.out, "n_frames": a.frames, "cols": a.cols, "gif_step": a.gif_step if a.gif else None}
    jobs = []
    for c in cards:
        lo, hi = card_meta(c).get("ranks", [0, 3])
        jobs += [(c, r, kw) for r in want if lo <= r <= hi]
    print(f"出图 {len(jobs)} 组（{len(cards)} 张卡），并行 {a.jobs} → {a.out}")
    a.out.mkdir(parents=True, exist_ok=True)
    failed = 0
    with ProcessPoolExecutor(max_workers=a.jobs) as ex:
        for name, rank, res in ex.map(_job, jobs):
            if isinstance(res, str):
                failed += 1
                print(f"  ✘ {name} r{rank}: {res}")
            else:
                print(f"  {name} r{rank}: " + " · ".join(p.name for p in res.values()))
    print(f"索引页：{write_index(a.out)}  （python -m stgtranscribe.preview --serve 浏览）")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
