"""终端输出格式（console.py）：只测纯函数，训练循环里的 print 不测。"""
from stgtrain import console as C


def test_fmt_duration():
    assert C.fmt_duration(0) == "0:00"
    assert C.fmt_duration(59.6) == "1:00"
    assert C.fmt_duration(2840.5) == "47:20"
    assert C.fmt_duration(3 * 3600 + 5 * 60 + 9) == "3:05:09"


def test_fmt_count():
    assert C.fmt_count(950) == "950"
    assert C.fmt_count(83864.1) == "83.9k"
    assert C.fmt_count(200_015_872) == "200.0M"
    assert C.fmt_count(1.2e9) == "1.20B"


def test_progress_line_full():
    scalars = {"perf/sps": 83864.1, "ep/return": 6.4307, "ep/done1": 0.1396, "ep/in_r_frac": 0.5656,
               "ppo/entropy_loss": 2.5192, "ppo/explained_variance": 0.713}
    line = C.progress_line(update=763, total=2000, env_steps=200_015_872, elapsed=2840.5, eta=3872.0, scalars=scalars)
    assert line.startswith("[u  763/2000  38%]")
    for part in ("200.0M 帧", "83.9k/s", "已用 47:20", "剩 ~1:04:32", "回报 6.43", "死 14%", "跟点 57%",
                 "熵 2.52", "EV 0.71"):
        assert part in line, part


def test_progress_line_without_finished_episodes():
    # 这一轮没有局结束时 ep/* 缺席：只打有的
    line = C.progress_line(update=2, total=3, env_steps=2048, elapsed=1.2, eta=None,
                           scalars={"perf/sps": 900.0, "ppo/entropy_loss": 2.89})
    assert "回报" not in line and "剩" not in line and "熵 2.89" in line


def test_eval_block_marks_best_and_lists_cards():
    res = {"overall": {"episodes": 288.0, "survival": 0.84375, "in_r_frac": 0.72728, "reach_frames_median": 38.2,
                       "dir_changes_per_s": 39.67, "shift_toggles_per_s": 6.086, "edge_frac": 0.0454},
           "cards": {"th06_s1_b4": {"r2": {"survival": 0.75, "in_r_frac": 0.7, "frames_mean": 1200.0,
                                           "dir_changes_per_s": 35.0, "shift_toggles_per_s": 5.0}}}}
    text = C.eval_block(update=800, res=res, is_best=True, elapsed=3000.0)
    lines = text.splitlines()
    assert "评测 @ u800" in lines[0] and "★ 新 best" in lines[0]
    assert "撑过 84.4%" in lines[1] and "跟点 72.7%" in lines[1] and "到达 38 帧" in lines[1]
    assert "方向 39.7/s" in lines[1] and "shift 6.1/s" in lines[1] and "贴边 4.5%" in lines[1]
    assert any(l.strip().startswith("th06_s1_b4 r2") and "撑过  75%" in l for l in lines[2:])
    assert "新 best" not in C.eval_block(update=800, res=res, is_best=False, elapsed=3000.0)


def test_ckpt_line():
    assert C.ckpt_line(800, ["latest.pt", "u800.pt"]) == "  ✔ checkpoint u800 → latest.pt, u800.pt"


def test_throttle():
    t = C.Throttle(30.0)
    assert t.ready(0.0)          # 第一次必打
    assert not t.ready(10.0)
    assert t.ready(30.0)
    assert not t.ready(59.9)
    assert t.ready(61.0)


def test_eta():
    assert C.eta(done=0, remaining=10, elapsed=5.0) is None
    assert C.eta(done=4, remaining=6, elapsed=20.0) == 30.0
