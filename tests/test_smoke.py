import json
from pathlib import Path

import pytest
import torch

from conftest import small_cfg
from stgtrain import gpucheck
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import dump_toml, from_dict, load_config
from stgtrain.metrics import read_jsonl
from stgtrain.train import main, make_run_dir, train

REPO = Path(__file__).resolve().parents[1]


def test_repo_configs_load():
    assert load_config(REPO / "configs" / "base.toml") == from_dict({}), "base.toml 须与 DEFAULTS 一致"
    smoke = load_config(REPO / "configs" / "smoke.toml")
    assert smoke["run"]["device"] == "cpu" and not smoke["ppo"]["compile"] and not smoke["ppo"]["cudagraphs"]


def test_train_end_to_end_then_resume(tmp_path):
    cfg = small_cfg(run={"total_updates": 2, "ckpt_every": 2, "eval_every": 2}, log={"tensorboard": True})
    run_dir = make_run_dir(tmp_path, "smoke")
    train(cfg, run_dir, pack_result=True)
    for rel in ("config.toml", "env.json", "metrics.jsonl", "perf.jsonl", "checkpoints/latest.pt",
                "checkpoints/u2.pt", "checkpoints/best.pt", "eval/2.json", "plots/ppo.png", "tb"):
        assert (run_dir / rel).exists(), rel
    assert (tmp_path / f"{run_dir.name}.tar.gz").exists()
    rows = read_jsonl(run_dir / "metrics.jsonl")
    assert [r["update"] for r in rows if "ppo/pg_loss" in r] == [1, 2]
    assert any("eval/survival" in r for r in rows)
    env = json.loads((run_dir / "env.json").read_text(encoding="utf-8"))
    assert env["action_table_version"] == 1 and "perf_summary" in env and env["stg_rl"]["engine_ver"]

    # 模拟「update 3 写了日志但 latest.pt 还是 update 2」的崩溃残留，续训须把其后行截掉
    with open(run_dir / "metrics.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"update": 3, "env_steps": 1, "wall": 0, "ppo/pg_loss": 999}) + "\n")

    assert main(["--resume", str(run_dir), "--total-updates", "3", "--no-pack"]) == 0
    ck = load_checkpoint(run_dir / "checkpoints" / "latest.pt")
    assert ck["update"] == 3 and ck["cfg"]["run"]["total_updates"] == 3
    rows = read_jsonl(run_dir / "metrics.jsonl")
    assert [r["update"] for r in rows if "ppo/pg_loss" in r] == [1, 2, 3]
    assert all(r.get("ppo/pg_loss") != 999 for r in rows)

    env = json.loads((run_dir / "env.json").read_text(encoding="utf-8"))
    assert env["perf_summary"]["phase_frac"], "分阶段计时须留下非空 phase_frac"
    assert any("perf/env_step_s" in r for r in rows), "metrics 须记录分阶段耗时"

    with pytest.raises(ValueError, match="没有要续训的更新"):
        main(["--resume", str(run_dir), "--total-updates", "3", "--no-pack"])
    with pytest.raises(ValueError, match="须 ≥ 1"):
        main(["--resume", str(run_dir), "--total-updates", "0", "--no-pack"])


def test_bench_cli(tmp_path):
    cfg_path = tmp_path / "bench.toml"
    dump_toml(small_cfg(bench={"seconds": 0.3, "num_envs": [8]}), cfg_path)
    assert main([str(cfg_path), "b", "--bench", "--runs-dir", str(tmp_path / "runs")]) == 0
    (bench_json,) = list((tmp_path / "runs").glob("*-bench-b/bench.json"))
    out = json.loads(bench_json.read_text(encoding="utf-8"))
    assert out["results"] and set(out["recommended"]) == {"num_envs", "threads"}


def test_gpucheck_requires_cuda(monkeypatch, tmp_path):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    assert gpucheck.main([str(REPO / "configs" / "smoke.toml")]) == 2


def test_gpucheck_close_enough():
    assert gpucheck.close_enough(1.0, 1.0 + 1e-5)
    assert gpucheck.close_enough(0.0, 1e-6)
    assert not gpucheck.close_enough(0.0, 1e-4)
    assert not gpucheck.close_enough(1.0, 1.01)
