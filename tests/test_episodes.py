import pytest
import torch
from stgagent import consts as C

from conftest import raw_obs, step_info
from stgtrain.episodes import EpisodeTracker


def tracker(n=2, fs=1, cap=300):
    return EpisodeTracker(n, torch.device("cpu"), ["death", "hold"], hold_radius=24.0, edge_margin=16.0,
                          frame_skip=fs, reach_cap_frames=cap)


def feed(t, prev, cur, info, total):
    raw = {"death": -(info.done == 1).float(), "hold": torch.zeros(prev.player_xy.shape[0])}
    t.update(prev, cur, info, torch.tensor(total, dtype=torch.float32), raw)


def test_episode_record_fields_and_reset():
    t = tracker(fs=2)
    target = (0.0, 300.0)
    inside, outside = (0.0, 305.0), (0.0, 400.0)
    # env0：外 → 内 → 内 → 死；env1 一直在外不结束
    seq = [(outside, [0, 0]), (inside, [0, 0]), (inside, [0, 0]), (inside, [1, 0])]
    prev = raw_obs(n=2, player=[outside, outside], target=target)
    for pos, done in seq:
        cur = raw_obs(n=2, player=[pos, outside], target=target)
        feed(t, prev, cur, step_info(n=2, done=done, ep_frames=8), [1.0, 0.5])
        prev = cur
    recs = t.pop_finished()
    assert len(recs) == 1
    r = recs[0]
    assert (r["env"], r["done"], r["frames"], r["steps"]) == (0, 1, 8, 4)
    assert r["return"] == pytest.approx(4.0)
    assert r["in_r_frac"] == pytest.approx(2 / 4), "第 2、3 步在 R 内；死亡步不计"
    assert r["reach_frames"] == pytest.approx(2 * 2), "第 2 步到达 × frame_skip 2"
    assert r["term/death"] == pytest.approx(-1.0)
    assert t.pop_finished() == []
    # env0 已清零：再走一步结束，return 只含这一步
    cur = raw_obs(n=2, player=[outside, outside], target=target)
    feed(t, prev, cur, step_info(n=2, done=[2, 0]), [3.0, 0.0])
    r2 = t.pop_finished()[0]
    assert r2["steps"] == 1 and r2["return"] == pytest.approx(3.0)


def test_unreached_segment_counts_cap_and_key_rates():
    t = tracker(n=1, fs=1, cap=300)
    far = raw_obs(n=1, player=(0.0, 440.0), target=(0.0, 250.0))
    feed(t, far, far, step_info(n=1, refreshed=[True], prev_buttons=[C.BTN_SHOT], buttons=[C.BTN_SHOT | C.BTN_SLOW]), [0.0])
    feed(t, far, far, step_info(n=1, done=[3], prev_buttons=[C.BTN_SHOT | C.BTN_SLOW], buttons=[C.BTN_SHOT | C.BTN_LEFT]), [0.0])
    r = t.pop_finished()[0]
    assert r["reach_frames"] == pytest.approx(300.0), "两段都没到达，各记上限"
    assert r["shift_toggles_per_s"] == pytest.approx(2 / (2 / 60))
    assert r["dir_changes_per_s"] == pytest.approx(1 / (2 / 60))


def test_direction_changes_split_by_radius_at_decision_time():
    """按决策时（prev 自机 vs prev 目标）是否在 R 内切分方向变化；存活步两边互补，死亡步不计。"""
    t = tracker(n=1, fs=2)
    target = (0.0, 300.0)
    inside, outside = (0.0, 305.0), (0.0, 400.0)
    L, R, S = C.BTN_SHOT | C.BTN_LEFT, C.BTN_SHOT | C.BTN_RIGHT, C.BTN_SHOT
    # (prev 位置, cur 位置, prev 键, 键, done)
    seq = [
        (outside, outside, S, L, 0),   # 点外，变向
        (outside, inside, L, L, 0),    # 点外，不变
        (inside, inside, L, R, 0),     # 点内，变向
        (inside, inside, R, L, 0),     # 点内，变向
        (inside, inside, L, S, 1),     # 死亡步：不计
    ]
    for p, c, pb, b, done in seq:
        prev = raw_obs(n=1, player=p, target=target)
        cur = raw_obs(n=1, player=c, target=target)
        feed(t, prev, cur, step_info(n=1, done=[done], prev_buttons=[pb], buttons=[b]), [0.0])
    r = t.pop_finished()[0]
    assert r["dir_changes_in_r"] == 2 and r["dir_changes_out_r"] == 1
    assert r["secs_in_r"] == pytest.approx(2 * 2 / 60) and r["secs_out_r"] == pytest.approx(2 * 2 / 60)
    # 按下新键数（松开不算）：S→L 1、L→R 1、R→L 1、L→S 0
    assert r["key_presses_per_s"] == pytest.approx(3 / (5 * 2 / 60))


def test_near_miss_metrics_graze_and_close_fractions():
    """神穿指标：每秒擦弹（events 第 1 列）、存活步里离最近弹边缘 < 4 / < 12 px 的占比（死亡步不计，掩码外的弹不算）。"""
    t = tracker(n=1, fs=1)
    p = (0.0, 300.0)
    hit_r, br = 2.0, 3.0
    def at(edge):  # 弹心在自机正右方，边缘距离 = edge
        return (edge + hit_r + br, 300.0, 0.0, 0.0, br)
    seq = [([at(2.0)], 0, 1), ([at(8.0)], 0, 0), ([at(40.0)], 0, 2), ([], 0, 0), ([at(1.0)], 1, 0)]
    prev = raw_obs(n=1, player=p, hit_r=hit_r)
    for rows, done, graze in seq:
        cur = raw_obs(n=1, player=p, hit_r=hit_r, bullets=[rows])
        info = step_info(n=1, done=[done])
        info.events[0, 1] = graze
        feed(t, prev, cur, info, [0.0])
        prev = cur
    r = t.pop_finished()[0]
    assert r["graze_per_s"] == pytest.approx(3 / (5 / 60))
    assert r["close4_frac"] == pytest.approx(1 / 4), "存活 4 步里只有第 1 步 < 4 px"
    assert r["close12_frac"] == pytest.approx(2 / 4)


def test_movement_segment_length_metrics():
    """人手指标：只数**移动段**（上一步按着方向）结束时的长度；「不动」的段再短也不算点按。"""
    from stgagent import consts as C

    t = tracker(n=1)
    o = raw_obs(n=1)
    R, L, S = C.BTN_SHOT | C.BTN_RIGHT, C.BTN_SHOT | C.BTN_LEFT, C.BTN_SHOT
    steps = [
        (S, R, 1 << 20, 0),   # 不动 → 右：结束的是「不动」段，不计
        (R, L, 2, 0),         # 右（2 帧）→ 左：移动段，≤2
        (L, S, 3, 0),         # 左（3 帧）→ 停：移动段，≤3 但 >2；松开也算一次结束
        (S, R, 1, 0),         # 停了 1 帧又走：结束的是「不动」段，不计
        (R, R, 5, 0),         # 没换方向
        (R, S, 9, 1),         # 右（9 帧）→ 停，同时死亡：那一步不再计
    ]
    for prev_b, cur_b, hold, done in steps:
        info = step_info(n=1, done=[done], buttons=[cur_b], prev_buttons=[prev_b], dir_hold=[hold])
        info.overridden = torch.tensor([hold == 5])          # 任取一步标成「运动层做主」
        feed(t, o, o, info, [0.0])
    (rec,) = t.pop_finished()
    assert (rec["mv_segs"], rec["mv_le2"], rec["mv_le3"]) == (2, 1, 2)
    assert rec["seg_le2_frac"] == 0.5 and rec["seg_le3_frac"] == 1.0
    assert abs(rec["motor_override_frac"] - 1 / 6) < 1e-6


def test_step_is_pure_and_matches_update():
    """`step` 是 `update` 的纯函数内核（CUDA 图录它）：不改 tracker，返回的新状态与 update 后的状态逐位相同。"""
    target = (0.0, 300.0)
    prev = raw_obs(n=2, player=[(0.0, 400.0), (0.0, 305.0)], target=target)
    cur = raw_obs(n=2, player=[(0.0, 305.0), (0.0, 305.0)], target=target)
    info = step_info(n=2, done=[1, 0], ep_frames=8, refreshed=[False, True])
    total = torch.tensor([1.0, 0.5])
    raw = {"death": -(info.done == 1).float(), "hold": torch.zeros(2)}
    pure, ref = tracker(), tracker()
    feed(ref, prev, prev, step_info(n=2), [0.0, 0.0])     # 先走一步，让状态非零
    feed(pure, prev, prev, step_info(n=2), [0.0, 0.0])
    before = [s.clone() for s in pure.state()]

    new_state, entry = pure.step(pure.state(), prev, cur, info, total, raw)
    assert all(torch.equal(a, b) for a, b in zip(before, pure.state())), "step 不得改 tracker"

    ref.update(prev, cur, info, total, raw)
    assert all(torch.equal(a, b) for a, b in zip(new_state, ref.state()))
    pure.load_state(new_state)
    pure.push(entry)
    ref_recs = ref.pop_finished()
    assert pure.pop_finished() == ref_recs and len(ref_recs) == 1
