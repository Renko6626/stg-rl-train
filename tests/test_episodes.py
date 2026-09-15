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
