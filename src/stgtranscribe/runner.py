"""File-based transcription: official CLI → validation → independent CLI review."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
from threading import Event

from . import config, validate, worker
from .worker import write_json


def load_manifest(path: Path, ids: set[str] | None, step: str) -> tuple[dict, list[dict]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    tasks, known, directories = [], set(), set()
    for row in data["tasks"]:
        uid = row["id"]
        if not isinstance(uid, str) or not re.fullmatch(r"[a-zA-Z0-9_-]+", uid) or uid in known:
            raise ValueError(f"invalid or duplicate task id: {uid}")
        known.add(uid)
        cwd = (path.parent / row["dir"]).resolve()
        if cwd in directories:
            raise ValueError(f"task directory used twice: {cwd}")
        directories.add(cwd)
        if ids is not None and uid not in ids:
            continue
        for name in ("task.md", "source.txt"):
            if not (cwd / name).is_file() or not (cwd / name).stat().st_size:
                raise ValueError(f"{uid}: missing {name} in {cwd}")
        task = {"id": uid, "dir": cwd}
        for role in ("writer", "reviewer"):
            command = row.get(role, data.get(role))
            needed = (role == "writer" and step in ("all", "write")) or (role == "reviewer" and step in ("all", "review"))
            if needed:
                if not isinstance(command, list) or not command or not all(isinstance(v, str) and v for v in command):
                    raise ValueError(f"{uid}: {role} must be an argv array")
                if not shutil.which(command[0]):
                    raise ValueError(f"{uid}: executable not found: {command[0]}")
            task[role] = command
        tasks.append(task)
    if ids is not None and ids - known:
        raise ValueError(f"unknown ids: {sorted(ids - known)}")
    if not tasks:
        raise ValueError("no tasks selected")
    for name, value in data.get("references", {}).items():
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts or not relative.parts:
            raise ValueError(f"reference destination must be relative: {name}")
        if not (path.parent / value).exists():
            raise ValueError(f"missing reference: {value}")
    return data, tasks


def prepare_run(manifest: Path, data: dict, tasks: list[dict], step: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run = manifest.parent / "logs" / stamp
    run.mkdir(parents=True)
    shutil.copyfile(manifest, run / "tasks.json")
    refs = run / "references"
    refs.mkdir()
    for name, value in data.get("references", {}).items():
        source, target = (manifest.parent / value).resolve(), refs / name
        # Copy ordinary reference files once per batch, preserving the chosen layout.
        if source.is_dir():
            shutil.copytree(source, target, ignore=shutil.ignore_patterns(".git", "__pycache__", "work", "logs"))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    versions = {}
    for role in ("writer", "reviewer"):
        if (role == "writer" and step not in ("all", "write")) or (role == "reviewer" and step not in ("all", "review")):
            continue
        for executable in {t[role][0] for t in tasks}:
            # Only known official version queries; arbitrary executables may run a task.
            if Path(executable).name not in ("codex", "dsh"):
                versions[executable] = "unknown"
                continue
            try:
                p = subprocess.run([executable, "--version"], capture_output=True, text=True, timeout=10)
                versions[executable] = p.stdout.strip() if p.returncode == 0 else "unknown"
            except (OSError, subprocess.TimeoutExpired):
                versions[executable] = "unknown"
    import stg_rl
    write_json(run / "environment.json", {"python": sys.version, "cli_versions": versions,
               "stg_rl": stg_rl.build_info(), "harness": str(config.harness_bin()),
               "seed": 1, "references": data.get("references", {}), "step": step})
    return run


def prompt_for(task: dict, role: str, run: Path, log: Path) -> str:
    contract = config.TRANSCRIBE_DIR / "contracts" / ("transcribe.md" if role == "writer" else "review.md")
    cwd, uid = task["dir"], task["id"]
    paths = [f"任务ID：{uid}", f"任务目录：{cwd}", f"任务说明（读一次）：{cwd / 'task.md'}",
             f"原文：{cwd / 'source.txt'}", f"目标卡：{cwd / 'card' / uid}",
             f"作者报告：{cwd / 'report.md'}",
             f"参考副本（按任务所列章节查阅，不通读目录）：{run / 'references'}",
             f"harness：{config.harness_bin()}"]
    if role == "reviewer":
        paths += [f"审核结果：{cwd / 'review/verdict.json'}", f"本次机器报告：{log / 'validate.json'}"]
    feedback = [log / "previous" / name for name in ("validate.json", "review/verdict.json")]
    paths += [f"上轮反馈：{p}" for p in feedback if p.is_file()]
    return contract.read_text(encoding="utf-8") + "\n\n" + "\n".join(paths) + "\n"


def review_passed(value: dict) -> bool:
    if not isinstance(value, dict) or value.get("verdict") != "pass":
        return False
    findings, anchors = value.get("findings"), value.get("volleys")
    if not isinstance(findings, list) or any(not isinstance(f, dict) or f.get("severity") != "minor" for f in findings):
        return False
    return (isinstance(anchors, list) and len(anchors) >= 1 and all(
        isinstance(a, dict) and type(a.get("rank")) is int and type(a.get("frame")) is int
        and all(isinstance(a.get(k), str) and a[k].strip() for k in ("expected", "observed", "command"))
        for a in anchors))


def execute(task: dict, run: Path, step: str, timeout: int, stop: Event) -> dict:
    cwd, uid = task["dir"], task["id"]
    if stop.is_set():
        return {"id": uid, "status": "cancelled", "step": step}
    log = cwd / "logs" / run.name
    log.mkdir(parents=True)
    outcome = {"id": uid, "status": "running", "step": step, "log": str(log), "batch_log": str(run)}
    print(f"START {uid} {step}", flush=True)
    try:
        for name in ("task.md", "source.txt"):
            shutil.copyfile(cwd / name, log / name)
        previous = log / "previous"
        previous.mkdir()
        if (cwd / "result.json").exists():
            old = json.loads((cwd / "result.json").read_text())
            write_json(previous / "result.json", old)
            old_validation = Path(old["log"]) / "validate.json"
            if old_validation.exists():
                shutil.copyfile(old_validation, previous / "validate.json")
        write_json(cwd / "result.json", outcome)
        card = cwd / "card" / uid
        if card.exists():
            shutil.copytree(card, previous / "card" / uid)
        # Moving old reports prevents a successful no-output process reusing a pass.
        if (cwd / "review").exists():
            shutil.move(str(cwd / "review"), previous / "review")
        if step in ("all", "write"):
            if (cwd / "report.md").exists():
                shutil.move(str(cwd / "report.md"), previous / "report.md")
            card.mkdir(parents=True, exist_ok=True)
            code = worker.run_worker(cwd, prompt_for(task, "writer", run, log), task["writer"], log / "writer", timeout, stop)
            if code:
                raise ValueError(f"writer exited {code}")
            report = (cwd / "report.md").read_text(encoding="utf-8")
            if not re.search(r"^status:\s*done\s*$", report, re.M):
                raise ValueError("author did not report status: done (see report.md)")
        for name in ("main.ecl", "meta.toml"):
            if not (card / name).is_file() or not (card / name).stat().st_size:
                raise ValueError(f"missing card/{uid}/{name}")
        outcome["status"] = "written"
        if step != "write":
            report = validate.validate(card)
            write_json(log / "validate.json", {**asdict(report), "ok": report.ok})
            if not report.ok:
                raise ValueError("machine validation failed; see validate.json")
            outcome["status"] = "validated"
        if step in ("all", "review"):
            review = cwd / "review"
            review.mkdir()
            code = worker.run_worker(review, prompt_for(task, "reviewer", run, log), task["reviewer"], log / "reviewer", timeout, stop)
            if code:
                raise ValueError(f"reviewer exited {code}")
            verdict = json.loads((review / "verdict.json").read_text(encoding="utf-8"))
            if not review_passed(verdict):
                raise ValueError("review failed or incomplete; see review/verdict.json")
            outcome["status"] = "reviewed"
    except Exception as exc:
        outcome.update(status="failed", error=f"{type(exc).__name__}: {exc}")
    if stop.is_set():
        outcome["status"] = "cancelled"
    write_json(log / "result.json", outcome)
    write_json(cwd / "result.json", outcome)
    print(f"END {uid} {outcome['status']} {outcome.get('error', '')}", flush=True)
    return outcome


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--ids", help="comma-separated task ids")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=3600)
    parser.add_argument("--step", choices=("all", "write", "check", "review"), default="all")
    parser.add_argument("--engine-dir", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if args.jobs < 1 or args.timeout < 1:
        parser.error("jobs and timeout must be positive")
    if args.engine_dir:
        os.environ["STG_ENGINE_DIR"] = str(args.engine_dir.resolve())
    manifest = args.manifest.resolve()
    try:
        data, tasks = load_manifest(manifest, set(args.ids.split(",")) if args.ids else None, args.step)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.error(str(exc))
    if args.dry_run:
        for task in tasks:
            print(json.dumps({**task, "dir": str(task["dir"]), "step": args.step}, ensure_ascii=False))
        return 0
    run = prepare_run(manifest, data, tasks, args.step)
    stop = Event()
    handlers = {sig: signal.signal(sig, lambda *_: stop.set()) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            results = list(pool.map(lambda t: execute(t, run, args.step, args.timeout, stop), tasks))
    finally:
        for sig, handler in handlers.items():
            signal.signal(sig, handler)
    write_json(run / "results.json", results)
    print(f"Results: {run / 'results.json'}", flush=True)
    return 130 if stop.is_set() else int(any(r["status"] == "failed" for r in results))


if __name__ == "__main__":
    sys.exit(main())
