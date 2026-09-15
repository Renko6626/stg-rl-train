import json
import time

import pytest
import torch

from stgtrain.perf import LoadSampler, PerfWriter, PhaseTimer, machine_info, maybe_phase, summarize


def test_phase_timer_only_times_sync_iterations():
    t = PhaseTimer(sync_every=2, device=torch.device("cpu"))
    t.start_iteration(0)
    with t.phase("env_step"):
        time.sleep(0.02)
    with t.phase("policy"):
        time.sleep(0.01)
    row = t.pop_iteration()
    assert row["env_step_s"] >= 0.018 and row["policy_s"] >= 0.008
    assert row["total_s"] >= row["env_step_s"] + row["policy_s"]
    t.start_iteration(1)
    with t.phase("env_step"):
        pass
    assert t.pop_iteration() is None


def test_maybe_phase_accepts_none():
    with maybe_phase(None, "x"):
        pass


def test_load_sampler_writes_rows(tmp_path):
    w = PerfWriter(tmp_path / "perf.jsonl")
    s = LoadSampler(w, hz=20.0)
    s.start()
    time.sleep(0.35)
    s.stop()
    w.close()
    rows = [json.loads(l) for l in (tmp_path / "perf.jsonl").read_text().splitlines()]
    assert len(rows) >= 2 and all(r["kind"] == "load" for r in rows)
    assert {"cpu_percent", "rss_mb", "cpu_per_core"} <= set(rows[0])
    assert s.n_samples >= 2
    assert "load/cpu_percent" in s.summary()


def test_load_sampler_summary_is_streaming(tmp_path):
    w = PerfWriter(tmp_path / "perf.jsonl")
    s = LoadSampler(w, hz=1.0)
    s.add({"kind": "load", "wall": 0, "cpu_percent": 10.0, "cpu_per_core": [1, 2]})
    s.add({"kind": "load", "wall": 1, "cpu_percent": 30.0, "rss_mb": 5.0})
    assert s.summary() == {"load/cpu_percent": 20.0, "load/rss_mb": 5.0}
    assert s.n_samples == 2
    assert not hasattr(s, "rows")
    w.close()


def test_machine_info_and_summarize():
    info = machine_info()
    assert {"cpu_model", "cpu_logical", "torch", "gpus"} <= set(info)
    rows = [{"env_step_s": 0.5, "policy_s": 0.2, "update_s": 0.2, "total_s": 1.0},
            {"env_step_s": 0.3, "policy_s": 0.2, "update_s": 0.4, "total_s": 1.0}]
    s = summarize(rows, {"load/cpu_percent": 40.0}, env_steps_per_iter=1000)
    assert s["iter_s"] == pytest.approx(1.0) and s["sps"] == pytest.approx(1000.0)
    assert s["gpu_waits_cpu"] == pytest.approx(0.4)
    assert s["cpu_waits_gpu"] == pytest.approx(0.5)
    assert s["load/cpu_percent"] == 40.0
    assert summarize([], {}, 10) == {"phase_frac": {}}
