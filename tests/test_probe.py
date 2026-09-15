import json
import tarfile
from pathlib import Path

import torch

from conftest import small_cfg
from stgtrain import probe
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import dump_toml, load_config
from stgtrain.train import make_run_dir, train

REPO = Path(__file__).resolve().parents[1]


def test_probe_config_loads():
    cfg = load_config(REPO / "configs" / "probe.toml")
    assert cfg["env"]["cards_dir"] == "probe/cards" and cfg["run"]["max_minutes"] > 0


def test_max_minutes_stops_early_and_finalizes(tmp_path):
    cfg = small_cfg(run={"total_updates": 1000, "max_minutes": 1e-6, "ckpt_every": 500, "eval_every": 500})
    run_dir = make_run_dir(tmp_path, "t")
    train(cfg, run_dir, pack_result=False)
    assert load_checkpoint(run_dir / "checkpoints" / "latest.pt")["update"] == 1
    assert (run_dir / "eval" / "1.json").exists(), "提前停止的那个 update 也要评测"
    env = json.loads((run_dir / "env.json").read_text(encoding="utf-8"))
    assert env["stopped_early_at_update"] == 1


def test_probe_cpu_end_to_end(tmp_path, monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    cfg_path = tmp_path / "p.toml"
    dump_toml(small_cfg(bench={"seconds": 0.2, "num_envs": [8]}), cfg_path)
    out = tmp_path / "runs" / "probe-x"
    out.mkdir(parents=True)
    (out / "install.json").write_text('{"uv_sync_s": 1, "ok": true}\n', encoding="utf-8")
    rc = probe.main(["--out", str(out), "--minutes", "0.01", "--min-train-minutes", "0.001",
                     "--config", str(cfg_path), "--no-adapt"])
    assert rc == 0
    res = json.loads((out / "probe.json").read_text(encoding="utf-8"))
    assert res["steps"]["gpucheck"]["result"].startswith("skip")
    assert res["steps"]["train"]["result"]["num_envs"] == 8
    assert (out / "sysinfo" / "machine.json").exists()
    summary = (out / "SUMMARY.md").read_text(encoding="utf-8")
    assert "uv_sync_s" in summary and "训练负载" in summary
    dst = tmp_path / "runs" / "probe-x.tar.gz"
    with tarfile.open(dst) as tf:
        names = tf.getnames()
    assert "probe-x/train/perf.jsonl" in names and "probe-x/bench/bench.json" in names


def test_probe_records_failures_and_still_packs(tmp_path, monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    out = tmp_path / "probe-y"
    rc = probe.main(["--out", str(out), "--minutes", "0.01", "--config", str(tmp_path / "missing.toml")])
    assert rc == 1
    res = json.loads((out / "probe.json").read_text(encoding="utf-8"))
    assert res["steps"]["config"]["ok"] is False and (out / "config.error.txt").exists()
    assert (tmp_path / "probe-y.tar.gz").exists()


def _info(**kw):
    base = {"cuda_available": False, "gpus": [], "driver": None, "torch": "2.14.0+cu130", "cuda": "13.0"}
    return {**base, **kw}


def test_gpu_diagnosis_driver_too_old(tmp_path):
    proc = tmp_path / "version"
    proc.write_text("NVRM version: NVIDIA UNIX x86_64 Kernel Module  550.163.01  Tue Apr  8 2025\n")
    nvsmi = tmp_path / "nvidia-smi.txt"
    nvsmi.write_text("No devices were found\n")
    msg = probe.gpu_diagnosis(nvsmi, _info(), proc=proc)
    assert "550.163.01" in msg and "≥ 580" in msg and "权限" in msg


def test_gpu_diagnosis_no_driver_and_ok(tmp_path):
    assert "没有检测到" in probe.gpu_diagnosis(tmp_path / "none.txt", _info(), proc=tmp_path / "none")
    ok = probe.gpu_diagnosis(tmp_path / "none.txt", _info(cuda_available=True, gpus=["RTX 4090"], driver="580.1"))
    assert ok.startswith("CUDA 可用") and "RTX 4090" in ok
