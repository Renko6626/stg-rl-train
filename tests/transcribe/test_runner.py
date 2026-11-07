"""Exercise orchestration with local executable workers; no model requests."""
import json
import shutil
import sys
import os
import signal
import subprocess
import time
from pathlib import Path

import pytest

from stgtranscribe import config, runner, worker


def batch(tmp_path, sources=("th06",)):
    fake = tmp_path / "agent"
    fake.write_text(f'#!{sys.executable}\n' + '''
import json, pathlib, shutil, sys, time
p = pathlib.Path.cwd()
(p / 'received.txt').write_text(sys.stdin.read())
if p.name == 'review':
    task = p.parent
    mode = (task / 'mode').read_text() if (task / 'mode').exists() else ''
    if mode == 'no-review': sys.exit(0)
    verdict = {'verdict': 'pass', 'findings': [], 'volleys': [
        {'frame': f, 'rank': 0, 'expected': '8 bullets from source line 3',
         'observed': '8 bullets', 'command': 'harness run card --at ' + str(f)}
        for f in (120,)]}
    if mode == 'no-anchors': verdict['volleys'] = []
    if mode == 'bad-anchor': verdict['volleys'][0]['observed'] = ''
    if mode == 'major': verdict['findings'] = [{'severity': 'major'}]
    (p / 'verdict.json').write_text(json.dumps(verdict))
else:
    mode = (p / 'mode').read_text() if (p / 'mode').exists() else ''
    if mode == 'fail': sys.exit(9)
    if mode == 'timeout': time.sleep(10)
    card = p / 'card' / p.name
    card.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p / 'example.ecl', card / 'main.ecl')
    shutil.copyfile(p / 'example.toml', card / 'meta.toml')
    if mode == 'invalid': (card / 'main.ecl').write_text('invalid ecl')
    (p / 'report.md').write_text('status: done\\nsource mapping explained')
''')
    fake.chmod(0o755)
    tasks = []
    for source in sources:
        uid = f"{source}_s1_w01"
        task = tmp_path / uid
        task.mkdir()
        (task / "task.md").write_text("Test task; rank 0; use the supplied source.")
        (task / "source.txt").write_text("source excerpt\n")
        example = config.TH06_DIR / "examples/th06_s1_w01"
        shutil.copyfile(example / "main.ecl", task / "example.ecl")
        meta = (example / "meta.toml").read_text().replace('source = "th06"', f'source = "{source}"')
        meta = meta.replace("ranks = [0, 3]", "ranks = [0, 0]")
        (task / "example.toml").write_text(meta)
        tasks.append({"id": uid, "dir": uid})
    refs = tmp_path / "reference.md"
    refs.write_text("Actual reference contents")
    backend = [str(fake), "-"]
    manifest = tmp_path / "tasks.json"
    manifest.write_text(json.dumps({"writer": backend, "reviewer": backend,
                                    "references": {"reference.md": "reference.md"}, "tasks": tasks}))
    return manifest, [tmp_path / t["dir"] for t in tasks]


def result(task):
    return json.loads((task / "result.json").read_text())


@pytest.mark.skipif(not config.harness_bin().exists(), reason="requires release harness")
def test_two_sources_real_validation_and_one_gate_per_card(tmp_path, monkeypatch):
    manifest, tasks = batch(tmp_path, ("th06", "th18"))
    calls = []
    real = runner.validate.validate

    def count(card):
        calls.append(card)
        return real(card)

    monkeypatch.setattr(runner.validate, "validate", count)
    assert runner.main([str(manifest), "--jobs", "2"]) == 0
    assert len(calls) == 2
    for task in tasks:
        r = result(task)
        assert r["status"] == "reviewed"
        log = Path(r["log"])
        assert json.loads((log / "validate.json").read_text())["ok"]
        assert (log / "source.txt").read_text() == "source excerpt\n"
        assert task.name in (task / "received.txt").read_text()
        assert "Actual reference contents" in next(tmp_path.glob("logs/*/references/reference.md")).read_text()


def test_failed_writer_cannot_consume_old_success(tmp_path):
    manifest, (task,) = batch(tmp_path)
    card = task / "card" / task.name
    card.mkdir(parents=True)
    (card / "main.ecl").write_text("old code")
    (task / "report.md").write_text("status: done\n")
    (task / "review").mkdir()
    (task / "review/verdict.json").write_text('{"verdict":"pass"}')
    (task / "mode").write_text("fail")
    assert runner.main([str(manifest)]) == 1
    r = result(task)
    assert r["status"] == "failed" and "9" in r["error"]
    assert not (Path(r["log"]) / "validate.json").exists()
    assert (Path(r["log"]) / "previous/card" / task.name / "main.ecl").read_text() == "old code"
    assert not (task / "review/verdict.json").exists()


@pytest.mark.skipif(not config.harness_bin().exists(), reason="requires release harness")
@pytest.mark.parametrize("mode", ["invalid", "major", "no-review", "no-anchors", "bad-anchor"])
def test_bad_card_or_review_never_passes(tmp_path, mode):
    manifest, (task,) = batch(tmp_path)
    (task / "mode").write_text(mode)
    assert runner.main([str(manifest)]) == 1
    assert result(task)["status"] == "failed"
    if mode == "invalid":
        assert not (task / "review/verdict.json").exists()
        assert runner.main([str(manifest), "--step", "write"]) == 0
        old_gate = Path(result(task)["log"]) / "previous/validate.json"
        assert not json.loads(old_gate.read_text())["ok"]


def test_write_only_parallel_failure_and_dry_run(tmp_path):
    manifest, tasks = batch(tmp_path, ("th06", "th18"))
    assert runner.main([str(manifest), "--dry-run"]) == 0
    assert not (tmp_path / "logs").exists()
    (tasks[0] / "mode").write_text("fail")
    assert runner.main([str(manifest), "--jobs", "2", "--step", "write"]) == 1
    assert [result(t)["status"] for t in tasks] == ["failed", "written"]


def test_worker_timeout_retains_logs(tmp_path):
    manifest, (task,) = batch(tmp_path)
    backend = json.loads(manifest.read_text())["writer"]
    (task / "mode").write_text("timeout")
    log = task / "timeout-log"
    assert worker.run_worker(task, "task", backend, log, 0.1) == 124
    assert (log / "prompt.txt").read_text() == "task"
    assert json.loads((log / "result.json").read_text())["returncode"] == 124


@pytest.mark.parametrize("sig", [signal.SIGINT, signal.SIGTERM])
def test_interrupt_stops_worker_and_does_not_start_queued_card(tmp_path, sig):
    manifest, tasks = batch(tmp_path, ("th06", "th18"))
    (tasks[0] / "mode").write_text("timeout")
    with (tmp_path / "runner.log").open("w") as log:
        process = subprocess.Popen([sys.executable, "-m", "stgtranscribe.runner", str(manifest),
                                    "--jobs", "1", "--step", "write"], stdout=log, stderr=log)
        child_pid = None
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                invocations = list(tasks[0].glob("logs/*/writer/invocation.json"))
                if invocations:
                    child_pid = json.loads(invocations[0].read_text()).get("pid")
                    if child_pid:
                        break
                time.sleep(0.02)
            assert child_pid is not None
            process.send_signal(sig)
            assert process.wait(timeout=3) == 130
            with pytest.raises(ProcessLookupError):
                os.kill(child_pid, 0)
            assert not (tasks[1] / "received.txt").exists()
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            if child_pid:
                try:
                    os.killpg(child_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass


@pytest.mark.parametrize("change", ["duplicate", "unknown-id", "same-dir"])
def test_manifest_selection_rejects_ambiguous_tasks(tmp_path, change):
    manifest, _ = batch(tmp_path, ("th06", "th18"))
    data = json.loads(manifest.read_text())
    args = [str(manifest), "--dry-run"]
    if change == "duplicate": data["tasks"][1]["id"] = data["tasks"][0]["id"]
    elif change == "same-dir": data["tasks"][1]["dir"] = data["tasks"][0]["dir"]
    else: args += ["--ids", "missing"]
    manifest.write_text(json.dumps(data))
    with pytest.raises(SystemExit) as exc:
        runner.main(args)
    assert exc.value.code == 2
