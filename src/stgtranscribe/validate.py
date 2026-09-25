"""转写卡自动验收四层（spec §8）。

    python -m stgtranscribe.validate <卡目录> [--json 输出文件] [--skip-rl]

退出码 0 = 全过；1 = 有错误；2 = 用法错误。转写 worker 自检和 pipeline 收卡用的是同一个入口。
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import subprocess
import sys
import tomllib
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import config
from . import units as U

ALLOWED_TAGS = {"aimed", "random", "ring", "spiral", "wall", "curve", "split", "stream", "dense", "fast", "mixed", "laser"}
META_REQUIRED = {
    "title": str, "source": str, "origin": str, "source_ref": str, "ranks": list, "marks": list,
    "time_limit": int, "original_time_limit": int, "tags": list, "laser_approx": bool, "lower_half_blocked": bool,
}
PEAK_LIMIT = 1024
SEG_EARLIEST = U.OPENING_BUFFER
SEG_SLACK = 60
OPENING_FRAMES = 120
OPENING_EPISODES = 32
OPENING_MAX_DEATH_RATE = 0.10

_PEAK_RE = re.compile(r"^峰值：弹 (\d+)")
_DIAG_RE = re.compile(r"^诊断：(.*)$")
_SEG_RE = re.compile(r"^段结束：(.*)$")


@dataclass
class Report:
    card: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    runs: dict = field(default_factory=dict)
    opening_death_rate: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.errors


# ── 第 3 层：静态 lint ────────────────────────────────────────────────────────

def lint(card: Path) -> tuple[list[str], dict]:
    errs: list[str] = []
    meta: dict = {}
    if not U.ID_RE.match(card.name):
        errs.append(f"目录名 {card.name!r} 不合 th06_s<关>_<w|mb|b><序号>")
    mp = card / "meta.toml"
    if not mp.exists():
        return errs + ["缺 meta.toml"], meta
    try:
        meta = tomllib.loads(mp.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as e:
        return errs + [f"meta.toml 解析失败：{e}"], {}
    for k, ty in META_REQUIRED.items():
        if k not in meta:
            errs.append(f"meta.toml 缺 {k}")
        elif not isinstance(meta[k], ty) or (ty is int and isinstance(meta[k], bool)):
            errs.append(f"meta.toml 的 {k} 应为 {ty.__name__}")
    if meta.get("source") != "th06":
        errs.append('meta.toml source 应为 "th06"')
    r = meta.get("ranks")
    if isinstance(r, list) and not (len(r) == 2 and all(isinstance(x, int) for x in r) and 0 <= r[0] <= r[1] <= 4):
        errs.append("meta.toml ranks 应为 [lo, hi] 且 0 ≤ lo ≤ hi ≤ 4")
    if meta.get("marks") not in ([0], None):
        errs.append("meta.toml marks 应为 [0]")
    tl = meta.get("time_limit")
    if isinstance(tl, int) and not (0 < tl <= U.MAX_TIME_LIMIT):
        errs.append(f"time_limit {tl} 应在 (0, {U.MAX_TIME_LIMIT}]")
    if isinstance(meta.get("tags"), list) and (bad := set(meta["tags"]) - ALLOWED_TAGS):
        errs.append(f"tags 含未知标签 {sorted(bad)}")
    src = "\n".join(p.read_text(encoding="utf-8") for p in sorted(card.glob("*.ecl")))
    if not src:
        return errs + ["目录里没有 .ecl"], meta
    code = re.sub(r"//[^\n]*", "", src)
    if "set_invuln(65535)" not in code:
        errs.append("没有 set_invuln(65535)（boss / 导演敌 / 小怪都要无敌）")
    if "phase_begin(" not in code and "spell_begin(" not in code:
        errs.append("没有 phase_begin / spell_begin（段必须以结束事件收尾）")
    if "$rank" in code:
        errs.append("用了 $rank；难度读 global(GVAR_RANK)")
    m = re.search(r"const\s+TIME_LIMIT\s*:\s*int\s*=\s*(\d+)", code)
    if not m:
        errs.append("没有 const TIME_LIMIT: int = …")
    elif isinstance(tl, int) and int(m.group(1)) != tl:
        errs.append(f"TIME_LIMIT {m.group(1)} 与 meta.toml time_limit {tl} 不一致")
    return errs, meta


# ── 第 1 层：编译 ────────────────────────────────────────────────────────────

def compile_card(card: Path) -> str | None:
    import stg_rl

    try:
        stg_rl.compile_dir(card)
    except stg_rl.CompileError as e:
        return f"编译失败：\n{e}"
    return None


# ── 第 2 层 + 第 4a 层：harness run ──────────────────────────────────────────

def harness_run(card: Path, rank: int, frames: int) -> dict:
    exe = config.harness_bin()
    p = subprocess.run([str(exe), "run", str(card), "--rank", str(rank), "--frames", str(frames)],
                       capture_output=True, text=True, timeout=600)
    out = p.stdout + p.stderr
    res: dict = {"exit": p.returncode, "peak_bullets": None, "diag": {}, "seg_end": None}
    for line in out.splitlines():
        if m := _PEAK_RE.match(line):
            res["peak_bullets"] = int(m.group(1))
        elif m := _DIAG_RE.match(line):
            for part in m.group(1).split("·"):
                k, _, v = part.strip().rpartition(" ")
                if v.isdigit():
                    res["diag"][k] = int(v)
        elif m := _SEG_RE.match(line):
            frames_seen = [int(x) for x in re.findall(r"@(\d+)", m.group(1))]
            res["seg_end"] = min(frames_seen) if frames_seen else None
    if p.returncode != 0:
        res["tail"] = out[-2000:]
    return res


def check_runs(report: Report, card: Path, meta: dict) -> None:
    lo, hi = meta["ranks"]
    tl = meta["time_limit"]
    for rank in range(lo, hi + 1):
        r = harness_run(card, rank, tl + 300)
        report.runs[rank] = r
        if r["exit"] != 0:
            report.errors.append(f"rank {rank}: harness run 退出码 {r['exit']}（fault 或编译错误）\n{r.get('tail', '')}")
            continue
        if (pk := r["peak_bullets"]) is not None and pk > PEAK_LIMIT:
            report.errors.append(f"rank {rank}: 弹峰值 {pk} > {PEAK_LIMIT}")
        if r["diag"].get("pool_full", 0):
            report.errors.append(f"rank {rank}: pool_full {r['diag']['pool_full']}（池被打满，场上少了东西）")
        if r["diag"].get("contract_viol", 0):
            report.warnings.append(f"rank {rank}: contract_viol {r['diag']['contract_viol']}（有调用被吞成 no-op）")
        seg = r["seg_end"]
        if seg is None:
            report.errors.append(f"rank {rank}: {tl + 300} 帧内没有段结束事件")
        elif not (SEG_EARLIEST <= seg <= tl + SEG_SLACK):
            report.errors.append(f"rank {rank}: 段结束帧 {seg} 不在 [{SEG_EARLIEST}, time_limit + {SEG_SLACK}]")


# ── 第 4b 层：开场安全（stg_rl 真 env）───────────────────────────────────────

def opening_death_rate(card: Path, rank: int, episodes: int = OPENING_EPISODES, seed: int = 1) -> float:
    """env 自带预热关掉，照卡池规则自己闭眼游走 120 帧（9 方向，每段 8–32 帧），统计死亡比例。"""
    import numpy as np
    import stg_rl
    from stgagent import consts as C

    dirs = [0, C.BTN_UP, C.BTN_UP | C.BTN_RIGHT, C.BTN_RIGHT, C.BTN_DOWN | C.BTN_RIGHT, C.BTN_DOWN,
            C.BTN_DOWN | C.BTN_LEFT, C.BTN_LEFT, C.BTN_UP | C.BTN_LEFT]
    img = stg_rl.compile_dir(card)
    env = stg_rl.VecEnv(episodes, max(1, min(4, os.cpu_count() or 1)), {"card": img},
                        [stg_rl.Start(image="card", mark=0, rank=rank, weight=1.0)],
                        max_frames=OPENING_FRAMES + 60, warmup_max=0, seed=seed + rank)
    buf = env.reset()
    rng = random.Random(seed * 7919 + rank)
    cur = [rng.choice(dirs) for _ in range(episodes)]
    left = [rng.randint(8, 32) for _ in range(episodes)]
    ended = [False] * episodes
    died = 0
    for _ in range(OPENING_FRAMES):
        for i in range(episodes):
            if left[i] == 0:
                cur[i], left[i] = rng.choice(dirs), rng.randint(8, 32)
            left[i] -= 1
        env.step(np.array(cur, dtype=np.uint32))
        done = buf["done"]
        for i in range(episodes):
            if not ended[i] and int(done[i]) != 0:
                ended[i] = True
                died += int(done[i]) == 1
    return died / episodes


def check_opening(report: Report, card: Path, meta: dict) -> None:
    lo, hi = meta["ranks"]
    for rank in range(lo, hi + 1):
        rate = opening_death_rate(card, rank)
        report.opening_death_rate[rank] = rate
        if rate > OPENING_MAX_DEATH_RATE:
            report.errors.append(f"rank {rank}: 开场 {OPENING_FRAMES} 帧闭眼游走死亡率 {rate:.0%} > "
                                 f"{OPENING_MAX_DEATH_RATE:.0%}（开场缓冲不够）")


def validate(card: Path, skip_rl: bool = False) -> Report:
    report = Report(card=str(card))
    errs, meta = lint(card)
    report.errors += errs
    if (e := compile_card(card)) is not None:
        report.errors.append(e)
        return report
    if errs:
        return report
    if not config.harness_bin().exists():
        report.errors.append(f"找不到 release harness：{config.harness_bin()}")
        return report
    check_runs(report, card, meta)
    if not skip_rl and not report.errors:
        check_opening(report, card, meta)
    return report


def render(report: Report) -> str:
    lines = [f"validate {report.card}: {'OK' if report.ok else 'FAIL'}"]
    for rank, r in sorted(report.runs.items()):
        lines.append(f"  rank {rank}: exit {r['exit']} · 弹峰值 {r['peak_bullets']} · 段结束 {r['seg_end']} · "
                     f"开场死亡率 {report.opening_death_rate.get(rank, '—')}")
    lines += [f"  ✘ {e}" for e in report.errors]
    lines += [f"  ⚠ {w}" for w in report.warnings]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtranscribe.validate")
    ap.add_argument("card", type=Path)
    ap.add_argument("--json", type=Path)
    ap.add_argument("--skip-rl", action="store_true", help="跳过第 4b 层（开场安全）")
    a = ap.parse_args(argv)
    if not a.card.is_dir():
        print(f"不是目录：{a.card}", file=sys.stderr)
        return 2
    rep = validate(a.card, skip_rl=a.skip_rl)
    print(render(rep))
    if a.json:
        a.json.write_text(json.dumps({**asdict(rep), "ok": rep.ok}, ensure_ascii=False, indent=2) + "\n",
                          encoding="utf-8")
    return 0 if rep.ok else 1


if __name__ == "__main__":
    sys.exit(main())
