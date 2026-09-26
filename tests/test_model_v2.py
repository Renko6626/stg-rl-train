"""set_attn_v2：v1 + 激光集合编码器。"""
import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins
from test_featurize_v7 import laser, random_lasers, with_lasers

load_builtins()

V7 = {"name": "danger_topk_v7", "frame": "static", "dt": False, "k_lasers": 8}


def build(seed=0, **model):
    cfg = small_cfg(model={"name": "set_attn_v2", **model}, featurize=V7)
    feat = FEATURIZERS.get("danger_topk_v7")(cfg)
    torch.manual_seed(seed)
    return feat, MODELS.get("set_attn_v2")(cfg, feat.spec())


def busy_obs(n=3):
    rows = [(float(10 * j - 40), 300.0 - 7 * j, 0.5 * j, 2.0, 2.0) for j in range(9)]
    o = raw_obs(n=n, player=(5.0, 390.0), target=(-40.0, 280.0), bullets=[rows] * n,
                enemies=[[(0.0, 100.0, 16.0, 1.0), (-50.0, 160.0, 8.0, 0.0, 1.0, 0.5)]] * n)
    o.dir_held = torch.full((n,), 3, dtype=torch.int64)
    o.slow_held = torch.full((n,), 9, dtype=torch.int64)
    lz = [laser(x=-60.0, y=100.0, deg=80.0), laser(x=40.0, y=120.0, deg=100.0, state=0.0, t_active=20.0),
          laser(x=0.0, y=90.0, deg=95.0, speed=3.0, start=50.0, end=150.0, half_h=4.0)]
    return with_lasers(o, [lz] * n)


def empty_obs(n=2):
    o = busy_obs(n)
    o.lasers_mask[:] = False
    o.bullets_mask[:] = False
    o.enemies_mask[:] = False
    return o


@pytest.mark.parametrize("model", [{}, {"sa_layers": 1, "laser_sa_layers": 1}, {"sa_layers": 1, "action_query": True}])
def test_shapes_and_finite(model):
    feat, net = build(**model)
    assert net.requires() == feat.spec()
    for o in (busy_obs(), empty_obs()):
        logits, value = net(feat(o))
        assert logits.shape == (o.player_xy.shape[0], 18) and value.shape == (o.player_xy.shape[0],)
        assert torch.isfinite(logits).all() and torch.isfinite(value).all()


def test_lasers_change_the_output():
    feat, net = build()
    o = busy_obs(n=1)
    a = net(feat(o))
    o.lasers_mask[:] = False
    b = net(feat(o))
    assert not torch.allclose(a[0], b[0]) and not torch.allclose(a[1], b[1])


@pytest.mark.parametrize("model", [{"laser_sa_layers": 1}, {"sa_layers": 1, "action_query": True}])
def test_permutation_invariance_over_lasers(model):
    feat, net = build(**model)
    f = feat(random_lasers(busy_obs(n=2), seed=3))
    perm = torch.randperm(f["lasers"].shape[1], generator=torch.Generator().manual_seed(1))
    g = dict(f)
    g["lasers"], g["lasers_mask"] = f["lasers"][:, perm], f["lasers_mask"][:, perm]
    la, va = net(f)
    lb, vb = net(g)
    assert torch.allclose(la, lb, atol=1e-5) and torch.allclose(va, vb, atol=1e-5)


@pytest.mark.parametrize("model", [{}, {"laser_sa_layers": 1}, {"sa_layers": 1, "action_query": True}])
def test_padding_rows_do_not_leak(model):
    """掩码外的激光行写什么都不影响输出。"""
    feat, net = build(**model)
    f = feat(busy_obs(n=2))
    g = dict(f)
    g["lasers"] = torch.where(f["lasers_mask"][..., None], f["lasers"], torch.randn_like(f["lasers"]) * 50)
    la, va = net(f)
    lb, vb = net(g)
    assert torch.allclose(la, lb, atol=1e-5) and torch.allclose(va, vb, atol=1e-5)


@pytest.mark.parametrize("model", [{}, {"laser_sa_layers": 1}, {"sa_layers": 1, "action_query": True}])
def test_gradients_reach_every_parameter(model):
    feat, net = build(**model)
    logits, value = net(feat(busy_obs()))
    (logits.logsumexp(-1).sum() + value.sum()).backward()
    dead = [k for k, p in net.named_parameters() if p.grad is None or not p.grad.abs().sum() > 0]
    assert not dead, dead


def test_laser_sa_layers_only_on_laser_encoder():
    _, net = build(laser_sa_layers=2)
    keys = list(net.state_dict())
    assert {k.split(".")[2] for k in keys if k.startswith("lasers.sa.")} == {"0", "1"}
    assert not any(k.startswith("bullets.sa") for k in keys)


def test_rejects_featurizer_without_lasers():
    cfg = small_cfg(model={"name": "set_attn_v2"}, featurize={"name": "danger_topk_v6"})
    with pytest.raises(ValueError, match="lasers"):
        MODELS.get("set_attn_v2")(cfg, FEATURIZERS.get("danger_topk_v6")(cfg).spec())


def test_negative_laser_sa_layers_rejected():
    with pytest.raises(ValueError, match="laser_sa_layers"):
        build(laser_sa_layers=-1)
