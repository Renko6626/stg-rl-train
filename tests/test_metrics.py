import json
import math

import pytest

from stgtrain.metrics import MetricsLogger, read_jsonl, summarize_episodes, truncate_after


def test_logger_writes_jsonl_and_tensorboard(tmp_path):
    lg = MetricsLogger(tmp_path, tensorboard=True)
    lg.log(1, 128, {"ppo/pg_loss": 0.5, "ep/return": float("nan")})
    lg.log(2, 256, {"ppo/pg_loss": 0.25})
    lg.close()
    rows = read_jsonl(tmp_path / "metrics.jsonl")
    assert [r["update"] for r in rows] == [1, 2] and rows[1]["env_steps"] == 256
    assert rows[0]["ep/return"] is None and rows[0]["ppo/pg_loss"] == 0.5
    assert "wall" in rows[0]
    assert any((tmp_path / "tb").iterdir())


def test_summarize_episodes():
    recs = [{"env": 0, "done": 1, "return": 1.0, "frames": 100},
            {"env": 3, "done": 2, "return": 3.0, "frames": 300}]
    s = summarize_episodes(recs)
    assert s["ep/count"] == 2 and s["ep/done1"] == 0.5 and s["ep/done2"] == 0.5 and s["ep/done3"] == 0.0
    assert s["ep/return"] == pytest.approx(2.0) and s["ep/frames"] == pytest.approx(200.0)
    assert "ep/env" not in s
    assert summarize_episodes([]) == {}


def test_truncate_after(tmp_path):
    p = tmp_path / "m.jsonl"
    rows = [{"update": i, "env_steps": i} for i in range(1, 6)] + [{"wall": 0.0, "env_steps": 0}]
    p.write_text("\n".join(json.dumps(r) for r in rows) + "\n", encoding="utf-8")
    assert truncate_after(p, 3) == 2
    kept = read_jsonl(p)
    assert len(kept) == 4
    assert [r["update"] for r in kept if "update" in r] == [1, 2, 3]
    assert not (tmp_path / "m.jsonl.tmp").exists()
    assert truncate_after(tmp_path / "missing.jsonl", 3) == 0


def test_truncate_after_drops_half_written_last_line(tmp_path):
    p = tmp_path / "m.jsonl"
    lines = [json.dumps({"update": i, "env_steps": i}) for i in range(1, 4)]
    p.write_text("\n".join(lines) + '\n{"update": 4, "env_st', encoding="utf-8")
    assert truncate_after(p, 3) == 1
    kept = read_jsonl(p)
    assert [r["update"] for r in kept] == [1, 2, 3]


def test_summarize_episodes_pools_radius_split():
    recs = [{"env": 0, "done": 2, "dir_changes_in_r": 6, "secs_in_r": 1.0, "dir_changes_out_r": 1, "secs_out_r": 2.0},
            {"env": 1, "done": 2, "dir_changes_in_r": 0, "secs_in_r": 0.0, "dir_changes_out_r": 3, "secs_out_r": 2.0}]
    s = summarize_episodes(recs)
    assert s["ep/dir_changes_in_r_per_s"] == pytest.approx(6.0)
    assert s["ep/dir_changes_out_r_per_s"] == pytest.approx(1.0)
