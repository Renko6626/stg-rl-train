import pytest

from stgtrain.config import DEFAULTS
from stgtrain.curriculum import Curriculum


def cfg(**over):
    c = dict(DEFAULTS["curriculum"])
    c["enabled"] = True
    c.update(over)
    return c


def rec(start: int, done: int) -> dict:
    return {"start": start, "done": done}


def test_fail_ema_moves_toward_observed_rate():
    c = Curriculum(3, cfg(ema_decay=0.5, min_episodes=1))
    for _ in range(20):
        c.observe([rec(0, 1), rec(1, 2)])          # 0 号必死、1 号必活
    assert c.fail[0] == pytest.approx(1.0, abs=1e-3)
    assert c.fail[1] == pytest.approx(0.0, abs=1e-3)
    assert c.fail[2] == 0.5                         # 没见过的起点不动


def test_weights_favour_the_deadly_start_but_stay_clamped():
    c = Curriculum(2, cfg(ema_decay=0.5, min_episodes=1, w_lo=0.25, w_hi=4.0))
    for _ in range(50):
        c.observe([rec(0, 1), rec(1, 2)])
    w = c.weights()
    assert w[0] > w[1], "死得多的起点该被多采"
    assert min(w) >= 0.25 and max(w) <= 4.0

    # 极端比也不许突破上限：fail 0.95 vs 0.05 是 19 倍，w_hi = 2 时必须被削平
    c2 = Curriculum(2, cfg(ema_decay=0.5, min_episodes=1, w_hi=2.0, w_lo=0.5))
    for _ in range(50):
        c2.observe([rec(0, 1), rec(1, 2)])
    assert max(c2.weights()) <= 2.0


def test_starts_without_enough_episodes_keep_weight_one():
    c = Curriculum(2, cfg(ema_decay=0.5, min_episodes=10))
    for _ in range(3):
        c.observe([rec(0, 1)])
    assert c.weights() == [1.0, 1.0]


def test_observe_ignores_out_of_range_start():
    c = Curriculum(2, cfg(min_episodes=1))
    c.observe([rec(7, 1), rec(-1, 1), {"done": 1}])
    assert c.seen.tolist() == [0, 0]


def test_due_only_when_enabled():
    c = Curriculum(2, cfg(interval=5))
    assert c.due(10) and not c.due(11)
    off = Curriculum(2, {**cfg(interval=5), "enabled": False})
    assert not off.due(10)
