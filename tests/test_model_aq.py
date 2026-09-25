"""set_attn_v1 的 18 路动作 query 策略头（`model.action_query`，实验 R2）。"""
import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.models.set_attn_v1 import action_physics
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

load_builtins()

V6 = {"name": "danger_topk_v6", "frame": "static", "dt": False}


def build(aq=True, sa_layers=1, featurize=None, seed=0):
    cfg = small_cfg(model={"sa_layers": sa_layers, "action_query": aq}, featurize=featurize or V6)
    feat = FEATURIZERS.get(cfg["featurize"]["name"])(cfg)
    torch.manual_seed(seed)
    return feat, MODELS.get("set_attn_v1")(cfg, feat.spec())


def busy_obs(n=3, prev_action=0):
    rows = [(float(10 * j - 40), 300.0 - 7 * j, 0.5 * j, 2.0, 2.0) for j in range(9)]
    o = raw_obs(n=n, player=(5.0, 390.0), target=(-40.0, 280.0), bullets=[rows] * n,
                enemies=[[(0.0, 100.0, 16.0, 1.0)]] * n, prev_action=prev_action)
    o.dir_held = torch.full((n,), 3, dtype=torch.int64)
    o.slow_held = torch.full((n,), 9, dtype=torch.int64)
    return o


def test_default_off_adds_nothing():
    _, net = build(aq=False)
    assert not any(k.startswith("aq.") for k in net.state_dict())


def test_shapes_and_finite_including_empty():
    feat, net = build()
    for obs in (busy_obs(), raw_obs(n=2)):
        if obs.dir_held is None:
            obs.dir_held = torch.zeros(2, dtype=torch.int64)
            obs.slow_held = torch.zeros(2, dtype=torch.int64)
        logits, value = net(feat(obs))
        assert logits.shape == (obs.player_xy.shape[0], 18) and value.shape == (obs.player_xy.shape[0],)
        assert torch.isfinite(logits).all() and torch.isfinite(value).all()


def test_value_head_is_unchanged_path():
    """价值头仍从主干出：同一组权重下，开关动作 query 不影响 value。"""
    feat, a = build(aq=False)
    _, b = build(aq=True)
    b.load_state_dict({**b.state_dict(), **{k: v for k, v in a.state_dict().items() if k in b.state_dict()}})
    f = feat(busy_obs())
    assert torch.allclose(a(f)[1], b(f)[1], atol=1e-6)


def test_permutation_invariance_over_bullets():
    feat, net = build()
    f = feat(busy_obs(n=1))
    perm = torch.randperm(f["bullets"].shape[1], generator=torch.Generator().manual_seed(1))
    g = dict(f)
    g["bullets"], g["bullets_mask"] = f["bullets"][:, perm], f["bullets_mask"][:, perm]
    la, _ = net(f)
    lb, _ = net(g)
    assert torch.allclose(la, lb, atol=1e-5)


def test_gradients_reach_every_parameter():
    feat, net = build()
    logits, value = net(feat(busy_obs()))
    (logits.sum() + value.sum()).backward()
    assert [n for n, p in net.named_parameters() if p.grad is None] == []


def test_action_physics_layout():
    """每个动作的物理量：方向单位向量、低速位、与当前执行的方向 / 低速位是否相同、两个 held（封顶归一）。"""
    feat, _ = build()
    f = feat(busy_obs(n=1, prev_action=7))        # 动作 7 = 方向 3（右）+ 低速
    phys = action_physics(f["player"])             # [n, 18, 7]
    assert phys.shape == (1, 18, 7)
    right_slow, left_fast, still = phys[0, 7], phys[0, 14], phys[0, 0]
    assert torch.allclose(right_slow[:2], torch.tensor([1.0, 0.0])) and right_slow[2] == 1
    assert torch.allclose(left_fast[:2], torch.tensor([-1.0, 0.0])) and left_fast[2] == 0
    assert torch.allclose(still[:2], torch.zeros(2))
    up_right = phys[0, 4]                          # 方向 2（右上）：y 向下为正
    assert torch.allclose(up_right[:2], torch.tensor([2 ** -0.5, -(2 ** -0.5)]), atol=1e-6)
    assert right_slow[3] == 1 and right_slow[4] == 1   # 与当前执行的方向、低速位都相同
    assert left_fast[3] == 0 and left_fast[4] == 0
    assert torch.allclose(phys[0, :, 5], torch.full((18,), 3 / 16)) and torch.allclose(phys[0, :, 6], torch.full((18,), 9 / 16))


def test_prev_action_changes_per_action_features():
    feat, net = build()
    la, _ = net(feat(busy_obs(n=1, prev_action=0)))
    lb, _ = net(feat(busy_obs(n=1, prev_action=7)))
    assert not torch.allclose(la, lb)


def test_requires_v5_style_player_vector():
    with pytest.raises(ValueError, match="player"):
        build(featurize={"name": "danger_topk_v3"})
