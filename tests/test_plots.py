import json
import tarfile

from stgtrain import plots


def write_rows(d, n=5):
    d.mkdir(parents=True, exist_ok=True)
    with open(d / "metrics.jsonl", "w") as f:
        for u in range(1, n + 1):
            f.write(json.dumps({"update": u, "env_steps": u * 100, "wall": float(u), "ppo/pg_loss": 1.0 / u,
                                "ep/return": float(u), "ep/term/death": -0.1 * u, "eval/survival": None}) + "\n")
    with open(d / "perf.jsonl", "w") as f:
        for t in range(3):
            f.write(json.dumps({"kind": "load", "wall": float(t), "cpu_percent": 50.0, "rss_mb": 900.0}) + "\n")
            f.write(json.dumps({"kind": "phase", "update": t, "env_step": 0.1}) + "\n")


def test_group_of():
    assert plots.group_of("ppo/pg_loss") == "ppo"
    assert plots.group_of("ep/term/death") == "ep/term"
    assert plots.group_of("ep/return") == "ep"
    assert plots.group_of("lr") == "misc"


def test_plot_runs_and_load(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    write_rows(a)
    write_rows(b, n=3)
    out = plots.plot_runs({"a": plots.load_run(a), "b": plots.load_run(b)}, tmp_path / "plots")
    names = sorted(p.name for p in out)
    assert names == ["ep.png", "ep_term.png", "ppo.png"], "全为 null 的 eval/survival 不出图"
    assert all(p.stat().st_size > 0 for p in out)
    load = plots.plot_load(plots.load_perf(a / "perf.jsonl"), tmp_path / "plots")
    assert load is not None and load.exists()


def test_load_run_from_tar_and_cli(tmp_path):
    run = tmp_path / "20260915-000000-x"
    write_rows(run)
    tgz = tmp_path / "x.tar.gz"
    with tarfile.open(tgz, "w:gz") as tf:
        tf.add(run, arcname=run.name)
    assert len(plots.load_run(tgz)) == 5
    out = tmp_path / "cli"
    assert plots.main([str(tgz), str(run), "--out", str(out)]) == 0
    assert (out / "ppo.png").exists()
