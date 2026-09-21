"""「温和指挥」诊断意图：新目标点靠近自机 / 刷新间隔拉长。"""
import torch

from conftest import small_cfg
from stgtrain.registry import INTENTS, load_builtins

load_builtins()
CPU = torch.device("cpu")


def make(name, **intent):
    return INTENTS.get(name)(small_cfg(intent=intent), 64, CPU, seed=3)


def test_near_targets_stay_close_to_the_tracked_player_and_inside_bounds():
    it = make("follow_near_v1", near=80.0)
    ref = make("lower_half_uniform_v1")
    player = torch.stack([torch.linspace(-190, 190, 64), torch.linspace(230, 440, 64)], dim=-1)
    seen_far = False
    for _ in range(400):
        it.track(player)
        refreshed = it.advance(1, torch.ones(64, dtype=torch.bool))
        if refreshed.any():
            d = (it.target - player)[refreshed].abs()
            assert (d <= 80.0 + 1e-4).all(), "刷新出来的目标点离自机超过 near"
            seen_far |= bool((d.max(dim=-1).values > 40.0).any())
        assert (it.target[:, 0] >= ref.x_lo).all() and (it.target[:, 0] <= ref.x_hi).all()
        assert (it.target[:, 1] >= ref.y_lo).all() and (it.target[:, 1] <= ref.y_hi).all()
    assert seen_far, "不能退化成「目标点就是自机」—— 那是自由档"


def test_new_episode_target_is_drawn_around_the_spawn_point_not_the_death_spot():
    it = make("follow_near_v1", near=50.0)
    it.track(torch.tensor([[-180.0, 430.0]]).repeat(64, 1))         # 上一局死在左下角
    it.reset(torch.ones(64, dtype=torch.bool))
    assert ((it.target - torch.tensor([0.0, 384.0])).abs() <= 50.0 + 1e-4).all()


def test_slow_refreshes_less_often_with_the_same_uniform_targets():
    fast, slow = make("lower_half_uniform_v1"), make("follow_slow_v1")
    nf = ns = 0
    act = torch.ones(64, dtype=torch.bool)
    for _ in range(1500):
        nf += int(fast.advance(1, act).sum())
        ns += int(slow.advance(1, act).sum())
    assert 1.6 < nf / ns < 2.4, (nf, ns)                              # 120–300 对 240–600：约一半
    assert slow.target[:, 0].abs().max() > 100, "目标点仍然满场分布"


def test_gentle_is_both_and_deterministic():
    a, b = make("follow_gentle_v1"), make("follow_gentle_v1")
    p = torch.zeros(64, 2) + torch.tensor([10.0, 300.0])
    for _ in range(700):
        a.track(p); b.track(p)
        a.advance(1, torch.ones(64, dtype=torch.bool)); b.advance(1, torch.ones(64, dtype=torch.bool))
    assert torch.equal(a.target, b.target) and ((a.target - p).abs() <= 96.0 + 1e-4).all()
    assert a.lo == 240 and a.hi == 600
