import torch

from stgtrain.config import DEFAULTS
from stgtrain.intent import MixedIntent
from stgtrain.registry import INTENTS


def cfg(**mix):
    c = {"intent": dict(DEFAULTS["intent"])}
    c["intent"]["mix"] = {"follow": 0.6, "anchor": 0.3, "free": 0.1, **mix}
    return c


def test_registered_and_mode_proportions_match_the_mix():
    it = INTENTS.get("mixed_v1")(cfg(), 4000, torch.device("cpu"), seed=7)
    assert isinstance(it, MixedIntent)
    frac = [(it.mode == m).float().mean().item() for m in range(3)]
    assert abs(frac[0] - 0.6) < 0.03 and abs(frac[1] - 0.3) < 0.03 and abs(frac[2] - 0.1) < 0.02


def test_anchor_and_free_never_refresh_but_follow_does():
    it = MixedIntent(cfg(), 512, torch.device("cpu"), seed=3)
    active = torch.ones(512, dtype=torch.bool)
    refreshed = torch.zeros(512, dtype=torch.bool)
    for _ in range(40):                       # 远超 interval 上限 300 帧
        refreshed |= it.advance(30, active)
    assert refreshed[it.mode == 0].any(), "跟点档必须会刷新"
    assert not refreshed[it.mode != 0].any(), "锚点/自由档整局不刷新"


def test_free_mode_locks_target_to_the_player_others_keep_theirs():
    it = MixedIntent(cfg(follow=1.0, anchor=0.0, free=0.0), 8, torch.device("cpu"), seed=1)
    it.mode = torch.tensor([2, 0, 2, 0, 1, 2, 1, 0])
    before = it.target.clone()
    player = torch.arange(16, dtype=torch.float32).reshape(8, 2)
    it.track(player)
    free = it.mode == 2
    assert torch.equal(it.target[free], player[free])
    assert torch.equal(it.target[~free], before[~free])


def test_mode_survives_reset_of_other_envs():
    it = MixedIntent(cfg(), 64, torch.device("cpu"), seed=11)
    before = it.mode.clone()
    keep = torch.zeros(64, dtype=torch.bool)
    keep[:8] = True                            # 只重开前 8 个
    it.reset(keep)
    assert torch.equal(it.mode[8:], before[8:])
