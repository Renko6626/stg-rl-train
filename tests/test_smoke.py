import json
from pathlib import Path

import pytest
import torch

from conftest import small_cfg
from stgtrain import bench, gpucheck
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

    # TensorBoard：purge_step 不能删掉 checkpoint 那一 update 的点（x 轴 = post-increment env_steps）
    from tensorboard.backend.event_processing.event_accumulator import EventAccumulator

    ea = EventAccumulator(str(run_dir / "tb"))
    ea.Reload()
    pg_steps = [e.step for e in ea.Scalars("ppo/pg_loss")]
    assert pg_steps == [r["env_steps"] for r in rows if "ppo/pg_loss" in r]

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
    row = out["results"][0]
    # 推荐按端到端吞吐：rollout 之外还要实测更新耗时，否则会选出「rollout 快、更新慢到跑不动」的 num_envs
    assert row["update_s"] > 0 and row["minibatch_rows"] > 0
    assert 0 < row["end_to_end_steps_per_s"] < row["env_steps_per_s"]
    pick, best = bench.recommend(out["results"])
    assert out["recommended"]["num_envs"] == pick["num_envs"]
    assert out["fastest"]["num_envs"] == best["num_envs"]


def _row(n, sps):
    return {"num_envs": n, "threads": 63, "update_s": 1.0, "end_to_end_steps_per_s": sps}


def test_bench_recommend_prefers_small_batch_within_tolerance():
    """4090 实测：2048→4096 只快 18%（该升档）；若再加 8192 仅微涨，则不该继续升。"""
    measured = [_row(1024, 52728), _row(2048, 65739), _row(4096, 77681)]
    pick, best = bench.recommend(measured)
    assert pick["num_envs"] == 4096 and best["num_envs"] == 4096
    pick, best = bench.recommend([*measured, _row(8192, 78000)])
    assert best["num_envs"] == 8192, "最快的仍如实记录"
    assert pick["num_envs"] == 4096, "只快 0.4% ⇒ 不值得把批量翻倍"
    # 同一 num_envs 内仍取最快线程数
    rows = [_row(2048, 65739), {**_row(2048, 40000), "threads": 255}]
    assert bench.recommend(rows)[0]["threads"] == 63


def test_gpucheck_requires_cuda(monkeypatch, tmp_path):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    assert gpucheck.main([str(REPO / "configs" / "smoke.toml")]) == 2


def test_gpucheck_policy_tolerances_cover_measured_diffs():
    """实测差异不该判失败，量级再大一位则应判失败（4050 笔记本 / 4090 各踩中一项）。"""
    # 4050：value 量级 0.66、逐元素最大差 2.5e-4
    assert 2.5e-4 <= gpucheck.MAXABS_REL * 0.66
    assert not (2.5e-3 <= gpucheck.MAXABS_REL * 0.66)
    # 4090：value 均值 -0.198、差 3.35e-5（相对 1.7e-4）
    assert gpucheck.close_enough(-0.19798049, -0.19794697, rel=gpucheck.POLICY_REL)
    assert not gpucheck.close_enough(-0.19798049, -0.19794697)  # 损失类仍用 1e-4，不放宽
    assert not gpucheck.close_enough(-0.198, -0.1976, rel=gpucheck.POLICY_REL)


def test_gpucheck_close_enough():
    assert gpucheck.close_enough(1.0, 1.0 + 1e-5)
    assert gpucheck.close_enough(0.0, 1e-6)
    assert not gpucheck.close_enough(0.0, 1e-4)
    assert not gpucheck.close_enough(1.0, 1.01)


def test_train_with_featurizer_v2(tmp_path):
    cfg = small_cfg(run={"total_updates": 1, "ckpt_every": 1, "eval_every": 1}, featurize={"name": "danger_topk_v2"})
    run_dir = make_run_dir(tmp_path, "v2")
    train(cfg, run_dir, pack_result=False)
    ck = load_checkpoint(run_dir / "checkpoints" / "latest.pt")
    assert ck["cfg"]["featurize"]["name"] == "danger_topk_v2"
    assert (run_dir / "eval" / "1.json").exists()
