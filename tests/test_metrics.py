import math

import pytest

from stgtrain.metrics import MetricsLogger, read_jsonl, summarize_episodes


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
