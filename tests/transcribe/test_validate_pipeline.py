"""验收器第 3 层 lint 负例、范例卡全层验收（需 release harness）、流水线状态机（假 worker）。"""
import json
import shutil
from pathlib import Path

import pytest

from stgtranscribe import config, pipeline, validate

EXAMPLES = config.TH06_DIR / "examples"
HAS_HARNESS = config.harness_bin().exists()


def make_card(tmp_path: Path, name="th06_s1_w01", **meta_over) -> Path:
    src = EXAMPLES / "th06_s1_w01"
    d = tmp_path / name
    shutil.copytree(src, d)
    if meta_over:
        text = (d / "meta.toml").read_text(encoding="utf-8")
        for k, v in meta_over.items():
            lines = [ln for ln in text.splitlines() if not ln.startswith(f"{k} ")]
            if v is not None:
                lines.append(f"{k} = {v}")
            text = "\n".join(lines) + "\n"
        (d / "meta.toml").write_text(text, encoding="utf-8")
    return d


def lint_errs(card):
    return validate.lint(card)[0]


def test_lint_example_clean(tmp_path):
    assert lint_errs(make_card(tmp_path)) == []


@pytest.mark.parametrize("over, needle", [
    ({"source": '"th07"'}, "source"),
    ({"ranks": "[0, 5]"}, "ranks"),
    ({"time_limit": "3500"}, "time_limit 3500"),
    ({"time_limit": "1300"}, "不一致"),
    ({"tags": '["weird"]'}, "未知标签"),
    ({"origin": None}, "缺 origin"),
    ({"laser_approx": '"no"'}, "laser_approx 应为 bool"),
])
def test_lint_meta_negatives(tmp_path, over, needle):
    assert any(needle in e for e in lint_errs(make_card(tmp_path, **over)))


@pytest.mark.parametrize("old, new, needle", [
    ("set_invuln(65535)", "set_invuln(60)", "set_invuln(65535)"),
    ("phase_begin(0, wave, TIME_LIMIT, 0);", "wave_now();", "phase_begin"),
    ("global(GVAR_RANK) == RANK_LUNATIC", "$rank == 3", "$rank"),
])
def test_lint_source_negatives(tmp_path, old, new, needle):
    d = make_card(tmp_path)
    p = d / "main.ecl"
    p.write_text(p.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")
    assert any(needle in e for e in lint_errs(d))


def test_lint_dir_name(tmp_path):
    assert any("目录名" in e for e in lint_errs(make_card(tmp_path, name="orig_ring")))


@pytest.mark.skipif(not HAS_HARNESS, reason="没有 stg-engine release harness")
@pytest.mark.parametrize("card", sorted(p.name for p in EXAMPLES.iterdir() if p.is_dir()))
def test_examples_pass_all_layers(card):
    rep = validate.validate(EXAMPLES / card)
    assert rep.ok, validate.render(rep)


@pytest.mark.skipif(not HAS_HARNESS, reason="没有 stg-engine release harness")
def test_opening_safety_catches_instant_death(tmp_path):
    d = make_card(tmp_path)
    p = d / "main.ecl"
    # 开场就在出生点周围铺满静止大玉
    killer = ("async sub carpet() { for i in 0..40 { _ = fire(48, 2, (i * 10 - 200) as fx, 384.0fx, 0fx, 0deg, none, none);"
              " _ = fire(48, 2, (i * 10 - 200) as fx, 376.0fx, 0fx, 0deg, none, none); } loop { wait(1); } }\n")
    text = p.read_text(encoding="utf-8").replace("async sub director() {", killer + "async sub director() {\n    spawn carpet();")
    p.write_text(text, encoding="utf-8")
    assert validate.opening_death_rate(d, 0, episodes=8) > 0.5


# ── 流水线状态机（假 worker / 假 validator，不跑 dsh）───────────────────────────

@pytest.fixture
def work(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "WORK_DIR", tmp_path / "work")
    monkeypatch.setattr(config, "CARDS_DIR", tmp_path / "cards")
    return tmp_path


def fake_unit(uid="th06_s1_w01"):
    d = pipeline.units_dir() / uid
    (d / "out").mkdir(parents=True)
    (d / "source.txt").write_text("x\n")
    (d / "unit.json").write_text("{}\n")
    pipeline.record(uid, "pending")
    return d


class Rep:
    def __init__(self, ok):
        self.ok, self.card, self.errors, self.warnings, self.runs, self.opening_death_rate = ok, "", [] if ok else ["boom"], [], {}, {}


def test_transcribe_retries_then_validates(work, monkeypatch):
    d = fake_unit()
    calls = []
    monkeypatch.setattr(validate, "asdict", lambda r: {"errors": r.errors})

    def worker(cwd, prompt, log):
        calls.append(prompt)
        (cwd / "out" / "main.ecl").write_text("// x\n")

    results = iter([False, True])
    assert pipeline.transcribe_one("th06_s1_w01", validator=lambda c: Rep(next(results)), worker=worker) == "validated"
    assert len(calls) == 2 and "返工" in calls[1]
    assert "验收失败" in (d / "feedback.md").read_text()
    assert pipeline.states()["th06_s1_w01"]["state"] == "validated"


def test_transcribe_blocked_after_retries(work, monkeypatch):
    fake_unit()
    monkeypatch.setattr(validate, "asdict", lambda r: {"errors": r.errors})
    res = pipeline.transcribe_one("th06_s1_w01", validator=lambda c: Rep(False),
                                  worker=lambda cwd, p, log: (cwd / "out" / "main.ecl").write_text("x"))
    assert res == "blocked"


def test_worker_reported_blocked(work):
    fake_unit()

    def worker(cwd, prompt, log):
        (cwd / "out" / "report.md").write_text("status: blocked\n原因：用了激光\n")

    assert pipeline.transcribe_one("th06_s1_w01", validator=lambda c: Rep(True), worker=worker) == "blocked"


def verdict(v, findings=(), volleys=3):
    return {"verdict": v, "findings": list(findings), "volleys": [{"frame": i} for i in range(volleys)]}


def test_review_pass_fail_and_rounds(work):
    d = fake_unit()
    pipeline.record("th06_s1_w01", "validated")
    fail = verdict("fail", [{"severity": "major", "src_line": 3, "ecl_line": 9, "expected": "16", "actual": "8"}])

    def worker_with(v):
        return lambda cwd, p, log: (cwd / "verdict.json").write_text(json.dumps(v))

    assert pipeline.review_one("th06_s1_w01", worker=worker_with(fail)) == "revise"
    assert "期望 16，实际 8" in (d / "feedback.md").read_text()
    assert pipeline.states()["th06_s1_w01"]["round"] == 1
    pipeline.record("th06_s1_w01", "validated", round=1)
    assert pipeline.review_one("th06_s1_w01", worker=worker_with(fail)) == "needs_human"
    pipeline.record("th06_s1_w01", "validated", round=0)
    assert pipeline.review_one("th06_s1_w01", worker=worker_with(verdict("pass"))) == "reviewed"


def test_pass_verdict_without_volleys_is_rejected(work):
    fake_unit()
    pipeline.record("th06_s1_w01", "validated")
    w = lambda cwd, p, log: (cwd / "verdict.json").write_text(json.dumps(verdict("pass", volleys=1)))  # noqa: E731
    assert pipeline.review_one("th06_s1_w01", worker=w) == "needs_human"


def test_select_sample_collect_status(work):
    for i in range(1, 6):
        d = fake_unit(f"th06_s1_w0{i}")
        (d / "out" / "main.ecl").write_text("x")
        (d / "out" / "report.md").write_text("status: done")
        pipeline.record(f"th06_s1_w0{i}", "reviewed")
    pipeline.record("th06_s1_w05", "needs_human")
    fake_unit("th06_s2_w01")
    assert pipeline._select(1, {"reviewed"}, None) == [f"th06_s1_w0{i}" for i in range(1, 5)]
    chosen = pipeline.do_sample(1, 0.2)
    assert "th06_s1_w05" in chosen and len(chosen) == 3
    done = pipeline.do_collect(1)
    assert len(done) == 4 and (config.CARDS_DIR / "th06_s1_w01" / "main.ecl").exists()
    assert not (config.CARDS_DIR / "th06_s1_w01" / "report.md").exists()
    table = pipeline.status_table(1)
    assert "collected 4" in table and "needs_human" in table
