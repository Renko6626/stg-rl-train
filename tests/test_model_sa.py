"""set_attn_v1 的弹间自注意力（`model.sa_layers`，实验 R1a / R1b）。"""
import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

load_builtins()


def build(sa_layers=None, seed=0):
    model = {} if sa_layers is None else {"sa_layers": sa_layers}
    cfg = small_cfg(model=model, featurize={"name": "danger_topk_v6", "frame": "static", "dt": False})
    feat = FEATURIZERS.get("danger_topk_v6")(cfg)
    torch.manual_seed(seed)
    return feat, MODELS.get("set_attn_v1")(cfg, feat.spec())


def busy_obs(n=3):
    rows = [(float(10 * j - 40), 300.0 - 7 * j, 0.5 * j, 2.0, 2.0) for j in range(9)]
    return raw_obs(n=n, player=(5.0, 390.0), target=(-40.0, 280.0), bullets=[rows] * n,
                   enemies=[[(0.0, 100.0, 16.0, 1.0)]] * n)


def test_zero_layers_is_the_original_model():
    feat, a = build(None)
    _, b = build(0)
    assert list(a.state_dict()) == list(b.state_dict())
    for k in a.state_dict():
        assert torch.equal(a.state_dict()[k], b.state_dict()[k]), k
    assert not any("sa" in k for k in a.state_dict())


@pytest.mark.parametrize("layers", [1, 2])
def test_adds_that_many_blocks_to_bullets_only(layers):
    _, net = build(layers)
    keys = list(net.state_dict())
    assert {k.split(".")[2] for k in keys if k.startswith("bullets.sa.")} == {str(i) for i in range(layers)}
    assert not any(k.startswith("enemies.sa") for k in keys)


@pytest.mark.parametrize("layers", [1, 2])
def test_finite_with_empty_and_busy_masks(layers):
    feat, net = build(layers)
    for obs in (raw_obs(n=2), busy_obs()):
        logits, value = net(feat(obs))
        assert torch.isfinite(logits).all() and torch.isfinite(value).all()


@pytest.mark.parametrize("layers", [1, 2])
def test_permutation_invariance_over_bullets(layers):
    feat, net = build(layers)
    f = feat(busy_obs(n=1))
    perm = torch.randperm(f["bullets"].shape[1], generator=torch.Generator().manual_seed(1))
    g = dict(f)
    g["bullets"], g["bullets_mask"] = f["bullets"][:, perm], f["bullets_mask"][:, perm]
    la, va = net(f)
    lb, vb = net(g)
    assert torch.allclose(la, lb, atol=1e-5) and torch.allclose(va, vb, atol=1e-5)


@pytest.mark.parametrize("layers", [1, 2])
def test_padding_rows_do_not_leak(layers):
    feat, net = build(layers)
    f = feat(busy_obs(n=1))
    g = dict(f)
    junk = f["bullets"].clone()
    junk[~f["bullets_mask"]] = torch.randn_like(junk[~f["bullets_mask"]]) * 5
    g["bullets"] = junk
    la, va = net(f)
    lb, vb = net(g)
    assert torch.allclose(la, lb, atol=1e-5) and torch.allclose(va, vb, atol=1e-5)


@pytest.mark.parametrize("layers", [1, 2])
def test_gradients_reach_every_parameter(layers):
    feat, net = build(layers)
    logits, value = net(feat(busy_obs()))
    (logits.sum() + value.sum()).backward()
    assert [n for n, p in net.named_parameters() if p.grad is None] == []


def test_negative_layers_rejected():
    with pytest.raises(ValueError):
        build(-1)
