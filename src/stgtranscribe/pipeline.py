"""TH06 input preparation and historical records. New writing/review uses stgtranscribe.runner.

Commands: split, extract, sample, status, density, notes, usage, collect.
Historical state.jsonl is retained; it is not the new runner state.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from . import config
from . import density as D
from . import notes as N
from . import structure, split_check, usage, worker
from . import extract as X
from . import units as U
from .thecl import parse_file

DSH_TIMEOUT = 1800

_state_lock = threading.Lock()


def state_path() -> Path:
    return config.WORK_DIR / "state.jsonl"


def record(uid: str, state: str, **extra) -> None:
    row = {"id": uid, "state": state, "ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **extra}
    with _state_lock:
        state_path().parent.mkdir(parents=True, exist_ok=True)
        with state_path().open("a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def states() -> dict[str, dict]:
    out: dict[str, dict] = {}
    p = state_path()
    if p.exists():
        for line in p.read_text(encoding="utf-8").splitlines():
            if line.strip():
                row = json.loads(line)
                # 用量行（_record_usage）与状态行同文件：worker 秒失败时它落在状态行之后，不能盖掉真实状态
                if row.get("state") != "usage":
                    out[row["id"]] = row
    return out


def stage_of(uid: str) -> int:
    m = U.TH06_ID_RE.fullmatch(uid)
    return int(m.group(1)) if m else 0


# ── dsh ──────────────────────────────────────────────────────────────────────

def dsh_bin() -> str:
    return os.environ.get("STG_DSH_CLI", "dsh")


def run_worker(cwd: Path, prompt: str, log: Path, kind: str = "split") -> int:
    """Legacy source preparation also uses the official headless command."""
    (cwd / "brief.md").write_text(prompt, encoding="utf-8")
    return worker.run_worker(cwd, prompt, [dsh_bin(), "--profile", "headless", "--json", "-"],
                             log.with_suffix(".run") / str(time.time_ns()), DSH_TIMEOUT)


def _paths_block() -> str:
    e = config.engine_dir()
    py = config.REPO_ROOT / ".venv" / "bin" / "python"
    return "\n".join([
        f"- 训练仓（只读）：{config.REPO_ROOT}",
        f"- 对照表全文：{config.TH06_DIR / 'mapping.md'}",
        f"- 内建签名速查（cwd 里，**先看它**）：builtins.md",
        f"- harness：{config.harness_bin()}",
        f"- 验收器：cd {config.REPO_ROOT} && PYTHONDONTWRITEBYTECODE=1 {py} -m stgtranscribe.validate <卡目录>",
        "",
        "**省 token 的硬规矩**（上下文每多一次整篇读，后面每一步都要重发一遍）：",
        f"- 下面这些**不许整篇 read**，只能用 `grep -n 关键词 <文件>` 再 `sed -n 'A,Bp'` 取需要的十几行：",
        f"  {e / 'docs/ecl-lang'}/*.md、{e / '.claude/skills/writing-danmaku-ecl/SKILL.md'}、"
        f"{e / 'docs/rl-card-pool.md'}、{config.decomp_dir()}/*.cpp",
        f"- **不要读验收器源码**（`stgtranscribe/validate.py`）：判据已写在契约里，跑一次 `validate` 看输出即可。",
        "- 语义以 `mapping-excerpt.md` 为准；它没有的才去 grep 对照表全文 "
        f"{config.TH06_DIR / 'mapping.md'}。",
    ])


def prompt_for(kind: str, cwd: Path, extra: str = "") -> str:
    contract = config.CONTRACTS_DIR / f"{kind}.md"
    return (f"你是 TH06 ECL 转写流水线的 {kind} worker。\n"
            f"第一步：完整读契约 {contract}，严格按契约做。\n"
            f"工作目录（你唯一能写的地方）：{cwd}\n\n关键路径：\n{_paths_block()}\n" + (f"\n{extra}\n" if extra else ""))


# ── split ────────────────────────────────────────────────────────────────────

def split_dir(stage: int) -> Path:
    return config.WORK_DIR / "split" / f"s{stage}"


def load_split(stage: int) -> dict | None:
    p = split_dir(stage) / "split.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def check_stage_split(stage: int) -> list[str]:
    split = load_split(stage)
    if split is None:
        return ["没有 split.json"]
    ecl = parse_file(config.stage_file(stage))
    return split_check.check(split, ecl, stage, U.localization())


def do_split(stage: int, force: bool = False) -> bool:
    d = split_dir(stage)
    d.mkdir(parents=True, exist_ok=True)
    ecl = parse_file(config.stage_file(stage))
    (d / "structure.md").write_text(structure.render(ecl, stage), encoding="utf-8")
    if not force and load_split(stage) is not None and not check_stage_split(stage):
        record(f"split_s{stage}", "split_ok")
        return True
    extra = (f"本关：Stage {stage}。原文：{config.stage_file(stage)}。结构摘要：{d / 'structure.md'}。"
             f"产出写到 {d / 'split.json'}。")
    code = run_worker(d, prompt_for("split", d, extra), config.WORK_DIR / "logs" / f"split_s{stage}.log")
    if code:
        record(f"split_s{stage}", "split_fail", reason=f"worker exited {code}")
        return False
    errs = check_stage_split(stage)
    record(f"split_s{stage}", "split_fail" if errs else "split_ok", reason=errs)
    if errs:
        (d / "feedback.md").write_text("\n".join(errs), encoding="utf-8")
    return not errs


# ── extract ──────────────────────────────────────────────────────────────────

def units_dir() -> Path:
    return config.WORK_DIR / "units"


def do_extract(stage: int) -> list[str]:
    if check_stage_split(stage):
        raise SystemExit(f"Stage {stage} 的 split.json 没过校验，先跑 split")
    ecl = parse_file(config.stage_file(stage))
    mapping_text = (config.TH06_DIR / "mapping.md").read_text(encoding="utf-8")
    st = states()
    made = []
    for unit, text in X.build_units(load_split(stage), ecl, stage, U.localization()):
        if unit.id in st and st[unit.id]["state"] not in ("pending", "excluded"):
            continue  # 已经往下走了，不覆盖
        X.write_unit(unit, text, units_dir(), mapping_text)
        record(unit.id, "excluded" if unit.skip else "pending", reason=unit.skip)
        made.append(unit.id)
    return made


def _select(stage: int, want: set[str], ids: list[str] | None) -> list[str]:
    st = states()
    picked = sorted(u for u, row in st.items() if stage_of(u) == stage and row["state"] in want)
    return [u for u in picked if u in ids] if ids else picked


def do_sample(stage: int, rate: float, seed: int = 0) -> list[str]:
    st = states()
    passed = sorted(u for u, r in st.items() if stage_of(u) == stage and r["state"] in ("reviewed", "collected"))
    human = sorted(u for u, r in st.items() if stage_of(u) == stage and r["state"] == "needs_human")
    k = min(len(passed), max(2, round(len(passed) * rate)))
    chosen = sorted(random.Random(seed + stage).sample(passed, k)) + human
    out = config.WORK_DIR / f"sample-s{stage}.json"
    out.write_text(json.dumps({"stage": stage, "units": chosen}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return chosen


def do_collect(stage: int) -> list[str]:
    done = []
    for uid in _select(stage, {"reviewed"}, None):
        dst = config.CARDS_DIR / "th06" / uid
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(units_dir() / uid / "out", dst, ignore=shutil.ignore_patterns("report.md"))
        record(uid, "collected")
        done.append(uid)
    return done


def measure_density() -> list[dict]:
    """跑一遍卡池，记每张卡 × 每档的弹峰值与场上均值（采样表的 10 个点求平均）。"""
    import tomllib

    from .preview import parse_counts, parse_summary

    def one(args):
        d, rank = args
        meta = tomllib.loads((d / "meta.toml").read_text(encoding="utf-8"))
        lo, hi = meta["ranks"]
        if not lo <= rank <= hi:
            return None
        out = subprocess.run([str(config.harness_bin()), "run", str(d), "--rank", str(rank),
                              "--frames", str(int(meta["time_limit"]) + 30)],
                             capture_output=True, text=True, timeout=600).stdout
        vals = [b for _, b in parse_counts(out)]
        return {"id": d.name, "rank": rank, "peak": parse_summary(out).peak_bullets,
                "mean": round(sum(vals) / max(len(vals), 1), 1)}

    from stgtrain.cards import discover
    cards = [card.path for card in discover(config.CARDS_DIR / "th06").values()]
    jobs = [(d, r) for d in cards for r in (0, 1, 2, 3, 4)]   # 4 = Extra（meta.ranks 过滤）
    with ThreadPoolExecutor(max_workers=16) as ex:
        return [r for r in ex.map(one, jobs) if r]


def _usage_rows() -> list[dict]:
    p = state_path()
    if not p.exists():
        return []
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        if r.get("state") == "usage":
            out.append(r)
    return out


def status_table(stage: int | None) -> str:
    st = states()
    rows = sorted((u, r) for u, r in st.items() if U.TH06_ID_RE.fullmatch(u) and (stage is None or stage_of(u) == stage))
    counts: dict[str, int] = {}
    for _, r in rows:
        counts[r["state"]] = counts.get(r["state"], 0) + 1
    lines = ["状态计数：" + " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))]
    for u, r in rows:
        if r["state"] not in ("collected", "reviewed"):
            lines.append(f"  {u:18} {r['state']:12} 轮 {r.get('round', 0)}  {r.get('reason') or ''}")
    return "\n".join(lines)


def _stages(spec: str) -> list[int]:
    if "-" in spec:
        a, b = spec.split("-")
        return list(range(int(a), int(b) + 1))
    return [int(x) for x in spec.split(",")]


def preflight(need_src: bool = True) -> None:
    problems = []
    if need_src and not config.ecl_files():
        problems.append(f"读不到原文：{config.decoded_dir() / 'ecl'}（设 STG_TH06_SRC）")
    if not config.harness_bin().exists():
        problems.append(f"没有 release harness：{config.harness_bin()}（stg-engine 里 cargo build --release -p stg-harness）")
    if not shutil.which(dsh_bin()) and not Path(dsh_bin()).exists():
        problems.append(f"找不到官方 dsh：{dsh_bin()}（设 STG_DSH_CLI）")
    if problems:
        raise SystemExit("前置检查失败：\n" + "\n".join(f"- {p}" for p in problems))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtranscribe.pipeline")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("split"); s.add_argument("--stages", default="1-7"); s.add_argument("--jobs", type=int, default=7)
    s.add_argument("--force", action="store_true")
    s = sub.add_parser("extract"); s.add_argument("--stages", default="1-7")
    s = sub.add_parser("sample"); s.add_argument("--stage", type=int, required=True); s.add_argument("--rate", type=float, default=0.2)
    s = sub.add_parser("status"); s.add_argument("--stage", type=int)
    s = sub.add_parser("density"); s.add_argument("--rank", type=int, default=2)
    s.add_argument("--out", default="cards/th06/density.json")
    s = sub.add_parser("notes"); s.add_argument("--all", action="store_true", help="含已分诊的")
    s.add_argument("--mark", action="store_true", help="把本次列出的标记为已分诊")
    s = sub.add_parser("usage"); s.add_argument("--stage", type=int); s.add_argument("--since", default=None,
        help="只算这个时间戳之后的记录（state.jsonl 的 ts 前缀，如 2026-09-18）")
    s = sub.add_parser("collect"); s.add_argument("--stage", type=int, required=True)
    a = ap.parse_args(argv)
    config.WORK_DIR.mkdir(parents=True, exist_ok=True)

    if a.cmd == "split":
        preflight()
        stages = _stages(a.stages)
        with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
            for stage, ok in zip(stages, ex.map(lambda st: do_split(st, a.force), stages)):
                print(f"Stage {stage}: {'split_ok' if ok else 'split_fail（见 work/split/s%d/feedback.md）' % stage}")
    elif a.cmd == "extract":
        for stage in _stages(a.stages):
            made = do_extract(stage)
            print(f"Stage {stage}: 摘录 {len(made)} 个单元")
    elif a.cmd == "sample":
        chosen = do_sample(a.stage, a.rate)
        print("抽检清单（交给 Claude 会话按 .claude/skills/th06-transcribe 执行）：")
        print("\n".join(f"  {u}" for u in chosen))
    elif a.cmd == "status":
        print(status_table(a.stage))
    elif a.cmd == "density":
        rows = measure_density()
        Path(a.out).write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(D.render(rows, a.rank))
        empty = D.low(rows, a.rank)
        if empty:
            print(f"\n⚠ rank {a.rank} 下弹量为空的卡（别放进评测集；训练里只练体碰）："
                  + "、".join(r["id"] for r in empty))
        print(f"\n画像写入 {a.out}")
    elif a.cmd == "notes":
        found = N.collect(config.WORK_DIR)
        show = found if a.all else N.new_only(found, config.WORK_DIR)
        print(N.render(show) if show else "没有待分诊的便笺")
        if a.mark and show:
            N.mark_triaged(show, config.WORK_DIR)
            print(f"\n已标记 {len(show)} 条为已分诊（{config.WORK_DIR / N.TRIAGED}）")
    elif a.cmd == "usage":
        rows = [r for r in _usage_rows() if (a.stage is None or f"_s{a.stage}" in r["id"])
                and (a.since is None or r.get("ts", "") >= a.since)]
        if not rows:
            print("没有用量记录（旧批次跑在加统计之前；新批次每个 worker 结束后会记一行）")
            return 0
        print(usage.render(usage.summarize(rows)))
        worst = sorted(rows, key=lambda r: -r.get("billed_in", 0))[:5]
        print("\n最贵的 5 次：")
        for r in worst:
            print(f"  {r['id']:20} {r.get('kind',''):10} 步 {r.get('steps',0):3} · 输入 {r.get('billed_in',0)/1e6:5.2f}M"
                  f" · 末上下文 {r.get('ctx_end',0)/1000:5.0f}k · 推理 {r.get('reasoning',0)/1000:5.0f}k")
    elif a.cmd == "collect":
        done = do_collect(a.stage)
        print(f"收进 cards/ {len(done)} 张。提交：\n  git add cards/ && git commit -m 'cards: th06 Stage {a.stage} 转写卡 {len(done)} 张'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
