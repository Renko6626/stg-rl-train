"""转写流水线驱动（spec §9）。

    python -m stgtranscribe.pipeline split      --stages 1-7 [--jobs 7]
    python -m stgtranscribe.pipeline extract    --stages 1-7
    python -m stgtranscribe.pipeline transcribe --stage 1 [--ids a,b] [--jobs 16]
    python -m stgtranscribe.pipeline review     --stage 1 [--ids a,b] [--jobs 16]
    python -m stgtranscribe.pipeline sample     --stage 1 [--rate 0.2]
    python -m stgtranscribe.pipeline status     [--stage 1]
    python -m stgtranscribe.pipeline collect    --stage 1

单元状态追加写 work/state.jsonl，同一单元以最后一行为准。每个子命令只处理处于前置状态的单元，
中断后重跑同一命令即续跑。dsh worker 只能写自己的 cwd，所以每个 worker 一个目录。
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
from . import structure, split_check, validate
from . import extract as X
from . import units as U
from .thecl import parse_file

MAX_SPLIT_RETRIES = 2
MAX_VALIDATE_RETRIES = 2
MAX_REVIEW_ROUNDS = 2
DSH_TIMEOUT = 1800

# ── 状态 ─────────────────────────────────────────────────────────────────────

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
                out[row["id"]] = row
    return out


def stage_of(uid: str) -> int:
    m = U.ID_RE.match(uid)
    return int(m.group(1)) if m else 0


# ── dsh ──────────────────────────────────────────────────────────────────────

def dsh_bin() -> str:
    return os.environ.get("STG_DSH_BIN", str(Path.home() / ".local/bin/dsh-flash"))


def run_worker(cwd: Path, prompt: str, log: Path) -> int:
    """派一个一次性 dsh worker。prompt 同时落盘 brief.md 便于事后查。"""
    (cwd / "brief.md").write_text(prompt, encoding="utf-8")
    log.parent.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
    cmd = [dsh_bin(), "--cwd", str(cwd), "--timeout", str(DSH_TIMEOUT), "--log", str(log), prompt]
    with (log.with_suffix(".stdout")).open("w", encoding="utf-8") as out:
        p = subprocess.run(cmd, cwd=cwd, env=env, stdout=out, stderr=subprocess.STDOUT, timeout=DSH_TIMEOUT + 120)
    return p.returncode


def _paths_block() -> str:
    e = config.engine_dir()
    py = config.REPO_ROOT / ".venv" / "bin" / "python"
    return "\n".join([
        f"- 训练仓（只读）：{config.REPO_ROOT}",
        f"- 对照表全文：{config.TH06_DIR / 'mapping.md'}",
        f"- 我方 ECL 手册：{e / 'docs/ecl-lang.md'}（索引）、{e / 'docs/ecl-lang/7-reference.md'}（签名）",
        f"- 静默坑：{e / '.claude/skills/writing-danmaku-ecl/SKILL.md'}",
        f"- 卡池约束：{e / 'docs/rl-card-pool.md'}",
        f"- harness：{config.harness_bin()}",
        f"- 验收器：cd {config.REPO_ROOT} && PYTHONDONTWRITEBYTECODE=1 {py} -m stgtranscribe.validate <卡目录>",
        f"- th06-decomp 源码（审核查语义）：{config.decomp_dir()}",
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
    feedback = ""
    for attempt in range(MAX_SPLIT_RETRIES + 1):
        extra = (f"本关：Stage {stage}。原文：{config.stage_file(stage)}。结构摘要：{d / 'structure.md'}。"
                 f"产出写到 {d / 'split.json'}。")
        if feedback:
            (d / "feedback.md").write_text(feedback, encoding="utf-8")
            extra += f"\n上一次的 split.json 没过机械校验，错误清单在 {d / 'feedback.md'}，改完再交。"
        run_worker(d, prompt_for("split", d, extra), config.WORK_DIR / "logs" / f"split_s{stage}.{attempt}.log")
        errs = check_stage_split(stage)
        if not errs:
            record(f"split_s{stage}", "split_ok", round=attempt)
            return True
        feedback = "# split.json 机械校验失败\n\n" + "\n".join(f"- {e}" for e in errs) + "\n"
        record(f"split_s{stage}", "split_fail", round=attempt, reason=errs[:5])
    return False


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


# ── transcribe ───────────────────────────────────────────────────────────────

_rl_gate = threading.Semaphore(max(1, (os.cpu_count() or 2) // 2))


def run_validate(card: Path) -> validate.Report:
    with _rl_gate:
        return validate.validate(card)


def _report_status(out: Path) -> str | None:
    p = out / "report.md"
    if not p.exists():
        return None
    for line in p.read_text(encoding="utf-8").splitlines():
        if line.strip().lower().startswith("status:"):
            return line.split(":", 1)[1].strip().split()[0].lower() if line.split(":", 1)[1].strip() else None
    return None


def transcribe_one(uid: str, validator=run_validate, worker=run_worker) -> str:
    d = units_dir() / uid
    st = states().get(uid, {})
    rnd = int(st.get("round", 0))
    out = d / "out"
    card = d / "card" / uid  # validate 要求目录名 = 卡 id
    for attempt in range(MAX_VALIDATE_RETRIES + 1):
        extra = f"单元：{uid}。输入：source.txt / unit.json / mapping-excerpt.md。产出写到 {out}/。"
        if (d / "feedback.md").exists():
            extra += f"\n这是返工：先读 {d / 'feedback.md'}（验收失败或审核发现），逐条改。"
        worker(d, prompt_for("transcribe", d, extra),
               config.WORK_DIR / "logs" / f"{uid}.transcribe.{rnd}.{attempt}.log")
        if _report_status(out) == "blocked":
            record(uid, "blocked", round=rnd, reason="worker 报告 blocked（见 out/report.md）")
            return "blocked"
        if card.exists():
            shutil.rmtree(card)
        card.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(out, card)
        rep = validator(card)
        (d / "validate.json").write_text(json.dumps({**validate.asdict(rep), "ok": rep.ok}, ensure_ascii=False,
                                                    indent=2) + "\n", encoding="utf-8")
        if rep.ok:
            record(uid, "validated", round=rnd, attempt=attempt)
            return "validated"
        with (d / "feedback.md").open("a", encoding="utf-8") as f:
            f.write(f"\n## 验收失败（第 {rnd} 轮第 {attempt} 次）\n\n" + validate.render(rep) + "\n")
    record(uid, "blocked", round=rnd, reason="验收重试用尽")
    return "blocked"


# ── review ───────────────────────────────────────────────────────────────────

def review_dir(uid: str) -> Path:
    return config.WORK_DIR / "review" / uid


def review_one(uid: str, worker=run_worker) -> str:
    src = units_dir() / uid
    d = review_dir(uid)
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    for name in ("source.txt", "unit.json", "mapping-excerpt.md", "validate.json"):
        if (src / name).exists():
            shutil.copy2(src / name, d / name)
    shutil.copytree(src / "out", d / "out")
    st = states().get(uid, {})
    rnd = int(st.get("round", 0))
    worker(d, prompt_for("review", d, f"单元：{uid}。待审的卡在 {d / 'out'}/。结论写到 {d / 'verdict.json'}。"),
           config.WORK_DIR / "logs" / f"{uid}.review.{rnd}.log")
    verdict = _load_verdict(d / "verdict.json")
    if verdict is None:
        record(uid, "needs_human", round=rnd, reason="审核没有产出合法 verdict.json")
        return "needs_human"
    if verdict["verdict"] == "pass":
        record(uid, "reviewed", round=rnd)
        return "reviewed"
    with (src / "feedback.md").open("a", encoding="utf-8") as f:
        f.write(f"\n## 审核发现（第 {rnd} 轮）\n\n")
        for fd in verdict["findings"]:
            f.write(f"- [{fd.get('severity')}] 原文行 {fd.get('src_line')} / 卡行 {fd.get('ecl_line')}："
                    f"期望 {fd.get('expected')}，实际 {fd.get('actual')}\n")
    if rnd + 1 >= MAX_REVIEW_ROUNDS:
        record(uid, "needs_human", round=rnd, reason="审核轮次用尽")
        return "needs_human"
    record(uid, "revise", round=rnd + 1)
    return "revise"


def _load_verdict(p: Path) -> dict | None:
    try:
        v = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if v.get("verdict") not in ("pass", "fail") or not isinstance(v.get("findings", []), list):
        return None
    if v["verdict"] == "pass":
        if any(f.get("severity") in ("critical", "major") for f in v.get("findings", [])):
            return None
        if len(v.get("volleys", [])) < 3:
            return None
    v.setdefault("findings", [])
    return v


# ── 批量执行 ─────────────────────────────────────────────────────────────────

def _select(stage: int, want: set[str], ids: list[str] | None) -> list[str]:
    st = states()
    picked = sorted(u for u, row in st.items() if stage_of(u) == stage and row["state"] in want)
    return [u for u in picked if u in ids] if ids else picked


def _parallel(fn, items: list[str], jobs: int) -> dict[str, str]:
    results: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        for uid, res in zip(items, ex.map(fn, items)):
            results[uid] = res
            print(f"  {uid}: {res}", flush=True)
    return results


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
        dst = config.CARDS_DIR / uid
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(units_dir() / uid / "out", dst, ignore=shutil.ignore_patterns("report.md"))
        record(uid, "collected")
        done.append(uid)
    return done


def status_table(stage: int | None) -> str:
    st = states()
    rows = sorted((u, r) for u, r in st.items() if U.ID_RE.match(u) and (stage is None or stage_of(u) == stage))
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
        problems.append(f"找不到 dsh-flash：{dsh_bin()}（设 STG_DSH_BIN）")
    if problems:
        raise SystemExit("前置检查失败：\n" + "\n".join(f"- {p}" for p in problems))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtranscribe.pipeline")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("split"); s.add_argument("--stages", default="1-7"); s.add_argument("--jobs", type=int, default=7)
    s.add_argument("--force", action="store_true")
    s = sub.add_parser("extract"); s.add_argument("--stages", default="1-7")
    for name in ("transcribe", "review"):
        s = sub.add_parser(name); s.add_argument("--stage", type=int, required=True)
        s.add_argument("--ids"); s.add_argument("--jobs", type=int, default=8)
    s = sub.add_parser("sample"); s.add_argument("--stage", type=int, required=True); s.add_argument("--rate", type=float, default=0.2)
    s = sub.add_parser("status"); s.add_argument("--stage", type=int)
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
    elif a.cmd == "transcribe":
        preflight()
        ids = a.ids.split(",") if a.ids else None
        items = _select(a.stage, {"pending", "revise"}, ids)
        print(f"转写 {len(items)} 个单元（并发 {a.jobs}）")
        _parallel(transcribe_one, items, a.jobs)
    elif a.cmd == "review":
        preflight()
        ids = a.ids.split(",") if a.ids else None
        items = _select(a.stage, {"validated"}, ids)
        print(f"审核 {len(items)} 个单元（并发 {a.jobs}）")
        _parallel(review_one, items, a.jobs)
    elif a.cmd == "sample":
        chosen = do_sample(a.stage, a.rate)
        print("抽检清单（交给 Claude 会话按 .claude/skills/th06-transcribe 执行）：")
        print("\n".join(f"  {u}" for u in chosen))
    elif a.cmd == "status":
        print(status_table(a.stage))
    elif a.cmd == "collect":
        done = do_collect(a.stage)
        print(f"收进 cards/ {len(done)} 张。提交：\n  git add cards/ && git commit -m 'cards: th06 Stage {a.stage} 转写卡 {len(done)} 张'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
