import pytest
import torch
from stgagent import consts as C

from conftest import raw_obs, small_cfg, step_info
from stgtrain.registry import REWARD_TERMS, load_builtins
from stgtrain.reward import RewardContext, RewardFn

load_builtins()


def ctx(prev, cur, info, gamma=1.0):
    return RewardContext(prev, cur, info, gamma=gamma, hold_radius=24.0, edge_margin=16.0)


def term(name, *a, **k):
    return REWARD_TERMS.get(name)(ctx(*a, **k))


def test_death_and_segment_survived():
    o = raw_obs(n=3)
    info = step_info(n=3, done=[0, 1, 2])
    assert term("death", o, o, info).tolist() == [0.0, -1.0, 0.0]
    assert term("segment_survived", o, o, info).tolist() == [0.0, 0.0, 1.0]


def test_follow_shaping_telescopes_across_refresh():
    # γ=1：一局内塑形总和 = 各刷新段 Φ(段末) − Φ(段首)（计划 Ruling 1：刷新步用旧目标精确计算）
    path = [(0.0, 400.0), (10.0, 380.0), (20.0, 350.0), (-5.0, 330.0), (-30.0, 320.0), (-40.0, 300.0)]
    targets = [(0.0, 300.0)] * 3 + [(-50.0, 260.0)] * 3  # 第 2 步（0 起）之后刷新
    phi = lambda p, t: -((p[0] - t[0]) ** 2 + (p[1] - t[1]) ** 2) ** 0.5 / 448.0
    total = 0.0
    for s in range(len(path) - 1):
        prev = raw_obs(n=1, player=path[s], target=targets[s])
        cur = raw_obs(n=1, player=path[s + 1], target=targets[s + 1])
        total += term("follow_shaping", prev, cur, step_info(n=1)).item()
    expected = (phi(path[3], targets[0]) - phi(path[0], targets[0])) + (phi(path[5], targets[3]) - phi(path[3], targets[3]))
    assert total == pytest.approx(expected, abs=1e-5)


def test_follow_shaping_zero_on_terminal_step():
    prev = raw_obs(n=2, player=(150.0, 440.0), target=(-150.0, 230.0))
    cur = raw_obs(n=2, player=(0.0, 384.0), target=(0.0, 300.0))
    v = term("follow_shaping", prev, cur, step_info(n=2, done=[1, 3]), gamma=0.995)
    assert v.tolist() == [0.0, 0.0]


def test_hold_and_edge_hug():
    prev = raw_obs(n=3, target=(0.0, 300.0))
    cur = raw_obs(n=3, player=[(0.0, 310.0), (185.0, 300.0), (0.0, 310.0)])
    info = step_info(n=3, done=[0, 0, 1])
    assert term("hold", prev, cur, info).tolist() == [1.0, 0.0, 0.0]
    assert term("edge_hug", prev, cur, info).tolist() == [0.0, 1.0, 0.0]


def test_key_terms():
    o = raw_obs(n=2)
    info = step_info(n=2, prev_buttons=[C.BTN_SHOT, C.BTN_SHOT | C.BTN_SLOW],
                     buttons=[C.BTN_SHOT | C.BTN_UP | C.BTN_SLOW, C.BTN_SHOT])
    assert term("key_press", o, o, info).tolist() == [2.0, 0.0]
    assert term("shift_toggle", o, o, info).tolist() == [1.0, 1.0]


def test_reward_fn_weights_and_validation():
    cfg = small_cfg(reward={"terms": {"death": 10.0, "follow_shaping": 1.0, "hold": 0.5, "segment_survived": 0.0,
                                       "key_press": 0.0, "shift_toggle": 0.0, "edge_hug": -0.1}})
    fn = RewardFn(cfg)
    prev = raw_obs(n=2, target=(0.0, 300.0), player=(0.0, 320.0))
    cur = raw_obs(n=2, player=[(0.0, 310.0), (0.0, 310.0)])
    total, raw = fn(prev, cur, step_info(n=2, done=[0, 1]))
    manual = sum(fn.terms[k] * raw[k] for k in raw)
    assert torch.allclose(total, manual)
    assert total[1].item() == pytest.approx(-10.0)
    with pytest.raises(ValueError, match="未知"):
        RewardFn(small_cfg(reward={"terms": {"nope": 1.0}}))
    with pytest.raises(ValueError, match="防自杀"):
        RewardFn(small_cfg(reward={"terms": {"death": 1.0, "follow_shaping": 1.0}}))


def test_rollout_features_and_rewards_are_deterministic():
    """spec §8：同种子、不带学习的 rollout，特征与 reward 逐字节相同。"""
    import stg_rl

    from conftest import FIXTURES
    from stgtrain.cards import compile_cards, discover
    from stgtrain.envwrap import EnvWrapper
    from stgtrain.registry import FEATURIZERS

    cfg = small_cfg(env={"mirror": True})
    images = compile_cards(discover(FIXTURES / "cards"))
    feat = FEATURIZERS.get("danger_topk_v1")(cfg)
    fn = RewardFn(cfg)

    def run():
        w = EnvWrapper(cfg, images, [stg_rl.Start("example_ring", 0, 2)], torch.device("cpu"), seed=21)
        obs = w.reset()
        g = torch.Generator().manual_seed(5)
        feats, rewards = [], []
        for _ in range(80):
            nxt, info = w.step(torch.randint(0, 18, (w.n,), generator=g))
            total, _ = fn(obs, nxt, info)
            feats.append(feat(nxt))
            rewards.append(total)
            obs = nxt
        return feats, rewards

    fa, ra = run()
    fb, rb = run()
    for a, b in zip(fa, fb):
        for k in a:
            assert torch.equal(a[k], b[k]), k
    assert all(torch.equal(x, y) for x, y in zip(ra, rb))
