import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.registry import FEATURIZERS, MODELS, check_compat, load_builtins

load_builtins()


def build(**model):
    cfg = small_cfg(model=model) if model else small_cfg()
    feat = FEATURIZERS.get(cfg["featurize"]["name"])(cfg)
    net = MODELS.get(cfg["model"]["name"])(cfg, feat.spec())
    return cfg, feat, net


def busy_obs(n=3):
    rows = [(float(10 * j - 40), 300.0 - 7 * j, 0.5 * j, 2.0, 2.0) for j in range(9)]
    return raw_obs(n=n, player=(5.0, 390.0), target=(-40.0, 280.0), bullets=[rows] * n,
                   enemies=[[(0.0, 100.0, 16.0, 1.0)]] * n)


def test_shapes_and_requires():
    _, feat, net = build()
    check_compat(net.requires(), feat.spec())
    logits, value = net(feat(busy_obs()))
    assert logits.shape == (3, 18) and value.shape == (3,)


def test_empty_masks_are_finite():
    _, feat, net = build()
    logits, value = net(feat(raw_obs(n=2)))
    assert torch.isfinite(logits).all() and torch.isfinite(value).all()


def test_permutation_invariance_over_bullets():
    _, feat, net = build()
    f = feat(busy_obs(n=1))
    perm = torch.randperm(f["bullets"].shape[1], generator=torch.Generator().manual_seed(1))
    g = dict(f)
    g["bullets"], g["bullets_mask"] = f["bullets"][:, perm], f["bullets_mask"][:, perm]
    la, va = net(f)
    lb, vb = net(g)
    assert torch.allclose(la, lb, atol=1e-5) and torch.allclose(va, vb, atol=1e-5)


def test_gradients_reach_every_parameter():
    _, feat, net = build()
    logits, value = net(feat(busy_obs()))
    (logits.sum() + value.sum()).backward()
    missing = [n for n, p in net.named_parameters() if p.grad is None]
    assert missing == []


def test_heads_must_divide_d():
    with pytest.raises(ValueError, match="整除"):
        build(d=15, heads=2)
