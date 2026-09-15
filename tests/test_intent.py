import torch

from conftest import small_cfg
from stgtrain.registry import INTENTS, load_builtins

load_builtins()


def make(n=64, seed=3, **intent):
    cfg = small_cfg(intent=intent) if intent else small_cfg()
    return INTENTS.get("lower_half_uniform_v1")(cfg, n, torch.device("cpu"), seed)


def test_points_and_countdowns_in_range():
    it = make(n=4096, margin=16.0, interval=[120, 300])
    x, y = it.target[:, 0], it.target[:, 1]
    assert x.min() >= -176 and x.max() <= 176
    assert y.min() >= 224 and y.max() <= 432
    assert it.countdown.min() >= 120 and it.countdown.max() <= 300
    assert x.min() < -150 and x.max() > 150 and y.min() < 240 and y.max() > 420, "应铺满区域"


def test_advance_refreshes_only_expired_active_envs():
    it = make(n=4)
    it.countdown = torch.tensor([1, 5, 1, 1])
    before = it.target.clone()
    active = torch.tensor([True, True, True, False])
    refreshed = it.advance(1, active)
    assert refreshed.tolist() == [True, False, True, False]
    assert torch.equal(it.target[1], before[1]) and torch.equal(it.target[3], before[3])
    assert it.countdown[1] == 4 and it.countdown[3] == 1, "未激活的 env 不扣计时"
    assert (it.countdown[[0, 2]] >= 120).all()


def test_reset_mask_and_determinism():
    a, b = make(seed=9), make(seed=9)
    assert torch.equal(a.target, b.target)
    mask = torch.zeros(64, dtype=torch.bool)
    mask[5] = True
    keep = a.target.clone()
    a.reset(mask)
    b.reset(mask)
    assert torch.equal(a.target, b.target)
    assert torch.equal(a.target[~mask], keep[~mask])
    assert not torch.equal(a.target[5], keep[5])
