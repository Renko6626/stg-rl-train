"""Run an official headless CLI with a prompt on stdin. No provider protocol."""
from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
from threading import Event
import time


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_worker(cwd: Path, prompt: str, command: list[str], log_dir: Path, timeout: float,
               stop: Event | None = None) -> int:
    log_dir.mkdir(parents=True, exist_ok=True)
    (log_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    record = {"command": command, "cwd": str(cwd), "timeout": timeout}
    write_json(log_dir / "invocation.json", record)
    started = time.monotonic()
    stop = stop or Event()
    try:
        with (log_dir / "stdout.log").open("w") as out, (log_dir / "stderr.log").open("w") as err:
            if stop.is_set():
                write_json(log_dir / "result.json", {**record, "returncode": 130})
                return 130
            process = subprocess.Popen(command, cwd=cwd, stdin=subprocess.PIPE,
                                       stdout=out, stderr=err, text=True, start_new_session=True)
            record["pid"] = process.pid
            write_json(log_dir / "invocation.json", record)
            while not stop.is_set() and time.monotonic() - started < timeout:
                try:
                    process.communicate(prompt, timeout=min(0.2, max(0.001, timeout - (time.monotonic() - started))))
                    break
                except subprocess.TimeoutExpired:
                    prompt = None  # communicate retains any partially written stdin.
            if stop.is_set() or process.poll() is None:
                # Terminate the CLI and its tool processes together, then reap the CLI.
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                code = 130 if stop.is_set() else 124
            else:
                code = process.returncode
    except OSError as exc:
        record["error"] = str(exc)
        code = 127
    record.update(returncode=code, elapsed_seconds=round(time.monotonic() - started, 2))
    write_json(log_dir / "result.json", record)
    return code
