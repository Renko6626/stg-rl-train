"""checkpoint 独立评测入口：评测划分 / 全卡两种模式，输出 json 与终端块。"""
import json

from conftest import small_cfg
from stgtrain.eval_ckpt import main
from stgtrain.train import make_run_dir, train


def test_eval_ckpt_splits_and_all_cards(tmp_path, capsys):
    cfg = small_cfg(run={"total_updates": 1, "ckpt_every": 1, "eval_every": 1})
    run_dir = make_run_dir(tmp_path, "ck")
    train(cfg, run_dir, pack_result=False)
    ck = run_dir / "checkpoints" / "best.pt"
    capsys.readouterr()

    out1 = tmp_path / "splits.json"
    assert main([str(ck), "--device", "cpu", "--episodes", "2", "--eval-seed", "23456",
                 "--records", "--splits", cfg["env"]["eval_splits"], "--out", str(out1)]) == 0
    res = json.loads(out1.read_text(encoding="utf-8"))
    assert list(res["cards"]) == ["example_calm"] and res["overall"]["episodes"] == 2
    assert "dir_changes_in_r_per_s" in res["overall"] and res["checkpoint"]["update"] == 1
    assert len(res["records"]) == 2 and all(r["eval_seed"] == 23456 for r in res["records"])
    assert "评测 @ u1" in capsys.readouterr().out

    out2 = tmp_path / "all.json"
    assert main([str(ck), "--device", "cpu", "--all-cards", "--ranks", "2,3", "--episodes", "2", "--out", str(out2)]) == 0
    res = json.loads(out2.read_text(encoding="utf-8"))
    assert sorted(res["cards"]) == ["example_calm", "example_ring"]
    # 与卡 meta 的 ranks 取交集：example_calm 只有 r2
    groups = {c: sorted(per) for c, per in res["cards"].items()}
    assert groups == {"example_calm": ["r2"], "example_ring": ["r2", "r3"]}
    assert res["overall"]["episodes"] == 3 * 2

    splits = tmp_path / "rank-splits.toml"
    splits.write_text('[[eval]]\ncard = "example_ring"\nranks = [2, 3]\nepisodes = 2\n')
    out3 = tmp_path / "rank3.json"
    assert main([str(ck), "--device", "cpu", "--splits", str(splits), "--ranks", "3",
                 "--records", "--out", str(out3)]) == 0
    res = json.loads(out3.read_text())
    assert list(res["cards"]["example_ring"]) == ["r3"]
    assert len(res["records"]) == 2 and all(r["rank"] == 3 for r in res["records"])
