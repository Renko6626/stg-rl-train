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


@pytest.mark.parametrize("name", ["th18_s1_w01", "th18_s1_mb1", "th18_s6_b12", "th18_s7_b1"])
def test_lint_th18_ids(tmp_path, name):
    assert lint_errs(make_card(tmp_path, name=name, source='"th18"')) == []


@pytest.mark.parametrize("name, source", [
    ("th18_s1_w01", '"th06"'),
    ("th06_s1_w01", '"th18"'),
    ("th18_s1_w01", '"th19"'),
])
def test_lint_id_source_mismatch(tmp_path, name, source):
    assert any("source" in e for e in lint_errs(make_card(tmp_path, name=name, source=source)))


@pytest.mark.parametrize("name", ["th18_s0_w01", "th18_s8_w01", "th18_s1_x1", "th18_s1_w001", "th19_s1_b1"])
def test_lint_invalid_modern_id(tmp_path, name):
    assert any("目录名" in e for e in lint_errs(make_card(tmp_path, name=name, source='"th18"')))


@pytest.mark.parametrize("source, limit, valid", [
    ("th06", 3500, False), ("th18", 3500, True),
    ("th18", 65535, True), ("th18", 65536, False), ("th18", 0, False),
])
def test_time_limit_by_source(tmp_path, source, limit, valid):
    d = make_card(tmp_path, name=f"{source}_s1_w01", source=f'"{source}"', time_limit=str(limit))
    p = d / "main.ecl"
    p.write_text(p.read_text().replace("TIME_LIMIT: int = 1400", f"TIME_LIMIT: int = {limit}"))
    errors = lint_errs(d)
    if valid:
        assert errors == []
    else:
        assert any("time_limit" in e for e in errors)


def test_th06_batch_does_not_select_th18(work):
    pipeline.record("th06_s1_w01", "pending")
    pipeline.record("th18_s1_w01", "pending")
    assert pipeline._select(1, {"pending"}, None) == ["th06_s1_w01"]
    assert "th18_s1_w01" not in pipeline.status_table(None)


@pytest.mark.parametrize("source, pool_full, expected_ok", [
    ("th06", 0, False), ("th18", 0, True), ("th18", 1, False),
])
def test_peak_policy_keeps_pool_exhaustion_error(tmp_path, monkeypatch, source, pool_full, expected_ok):
    monkeypatch.setattr(validate, "harness_run", lambda *args: {
        "exit": 0, "peak_bullets": 1100, "diag": {"pool_full": pool_full}, "seg_end": 1403,
    })
    report = validate.Report(card=str(tmp_path))
    validate.check_runs(report, tmp_path, {"source": source, "ranks": [0, 0], "time_limit": 1400})
    assert report.ok == expected_ok
    if pool_full:
        assert any("pool_full" in e for e in report.errors)
    elif not expected_ok:
        assert any("弹峰值" in e for e in report.errors)


@pytest.mark.skipif(not HAS_HARNESS, reason="没有 stg-engine release harness")
def test_th18_cli_all_layers_with_native_bullets(tmp_path):
    """自写合成卡验证新词表、旧预算之外的运行和 JSON；不冒充原作转写。"""
    d = make_card(tmp_path, name="th18_s1_w01", source='"th18"', ranks="[0, 0]", time_limit="3500")
    shutil.copyfile(config.engine_dir() / "godot/ecl/game/touhou-bullets.ecl", d / "touhou-bullets.ecl")
    (d / "main.ecl").write_text("""
const TIME_LIMIT: int = 3500;
async sub attack() {
    wait(120);
    for wave in 0..55 {
        for i in 0..20 {
            _ = fire(TH18_RICE, 0, (i - 50) as fx, 32fx, 0fx, 90deg, none, none);
        }
        wait(1);
    }
    loop { wait(1); }
}
async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, attack, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
""", encoding="utf-8")
    output = tmp_path / "validate.json"
    assert validate.main([str(d), "--json", str(output)]) == 0
    report = json.loads(output.read_text())
    assert report["ok"], report
    assert report["runs"]["0"]["peak_bullets"] == 1100
    assert 3500 <= report["runs"]["0"]["seg_end"] <= 3560
    assert report["opening_death_rate"] == {"0": 0.0}


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

    def worker(cwd, prompt, log, kind="transcribe"):
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
                                  worker=lambda cwd, p, log, kind="transcribe": (cwd / "out" / "main.ecl").write_text("x"))
    assert res == "blocked"


def test_worker_reported_blocked(work):
    fake_unit()

    def worker(cwd, prompt, log, kind="transcribe"):
        (cwd / "out" / "report.md").write_text("status: blocked\n原因：用了激光\n")

    assert pipeline.transcribe_one("th06_s1_w01", validator=lambda c: Rep(True), worker=worker) == "blocked"


def verdict(v, findings=(), volleys=3):
    return {"verdict": v, "findings": list(findings), "volleys": [{"frame": i} for i in range(volleys)]}


def test_review_pass_fail_and_rounds(work):
    d = fake_unit()
    pipeline.record("th06_s1_w01", "validated")
    fail = verdict("fail", [{"severity": "major", "src_line": 3, "ecl_line": 9, "expected": "16", "actual": "8"}])

    def worker_with(v):
        return lambda cwd, p, log, kind="review": (cwd / "verdict.json").write_text(json.dumps(v))

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
    w = lambda cwd, p, log, kind="review": (cwd / "verdict.json").write_text(json.dumps(verdict("pass", volleys=1)))  # noqa: E731
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
    assert len(done) == 4 and (config.CARDS_DIR / "th06" / "th06_s1_w01" / "main.ecl").exists()
    assert not (config.CARDS_DIR / "th06" / "th06_s1_w01" / "report.md").exists()
    table = pipeline.status_table(1)
    assert "collected 4" in table and "needs_human" in table


def test_usage_rows_do_not_mask_unit_state(work):
    """用量行（state="usage"）与单元状态同写 state.jsonl：worker 秒失败时用量行会落在状态行之后，
    不能把真实状态盖掉（2026-09-25 余额耗尽时 37 个单元被显示成 usage）。"""
    pipeline.record("th06_s7_w01", "pending")
    pipeline.record("th06_s7_w01", "usage", kind="transcribe", steps=0)
    assert pipeline.states()["th06_s7_w01"]["state"] == "pending"


def test_run_worker_aborts_whole_batch_on_provider_quota(work, monkeypatch, tmp_path):
    """DeepSeek 余额 / 限流错误时整批中止，不回写任何单元状态（2026-09-25 两次余额耗尽都把状态搞乱，
    还让没真正返工的旧卡进了审核）。"""
    fake = tmp_path / "fake-dsh"
    fake.write_text("#!/bin/sh\necho 'dsh-flash: worker failed (exit 1)'\necho 'dsh: QUOTA: Insufficient Balance (request_id: x)'\nexit 1\n")
    fake.chmod(0o755)
    monkeypatch.setattr(pipeline, "dsh_bin", lambda: str(fake))

    class Abort(Exception):
        pass

    def boom(msg):
        raise Abort(msg)

    monkeypatch.setattr(pipeline, "_abort_provider", boom)
    d = tmp_path / "unit"
    d.mkdir()
    with pytest.raises(Abort, match="QUOTA"):
        pipeline.run_worker(d, "x", tmp_path / "logs" / "u.transcribe.0.log")
