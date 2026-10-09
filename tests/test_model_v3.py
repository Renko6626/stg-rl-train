"""联合注意力：真实跨类型依赖、mask隔离、排列和训练梯度。"""
import pytest
import torch

from conftest import small_cfg
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins
from test_model_v2 import busy_obs

load_builtins()


def build(**model):
    cfg = small_cfg(featurize={"name": "danger_topk_v8", "frame": "static", "dt": False, "k_lasers": 8},
                    model={"name": "set_attn_v3", "joint_sa_layers": 1, **model})
    feat = FEATURIZERS.get("danger_topk_v8")(cfg)
    torch.manual_seed(4)
    net = MODELS.get("set_attn_v3")(cfg, feat.spec())
    o = busy_obs(n=2)
    o.laser_start_len = torch.full_like(o.lasers_mask, 400, dtype=torch.float32)
    return net, feat(o)


def test_joint_tokens_depend_on_other_type():
    net, f = build()
    b, l = net.threat_tokens(f)
    g = dict(f, bullets=f["bullets"] + 0.7)
    _, changed_l = net.threat_tokens(g)
    assert not torch.allclose(l[f["lasers_mask"]], changed_l[f["lasers_mask"]])
    g = dict(f, lasers=f["lasers"] + 0.7)
    changed_b, _ = net.threat_tokens(g)
    assert not torch.allclose(b[f["bullets_mask"]], changed_b[f["bullets_mask"]])


@pytest.mark.parametrize("action_query", [False, True])
def test_padding_and_permutation_do_not_change_outputs(action_query):
    net, f = build(action_query=action_query)
    expected = net(f)
    g = dict(f)
    for name in ("bullets", "lasers"):
        mask = f[name + "_mask"]
        g[name] = torch.where(mask[..., None], f[name], torch.full_like(f[name], 1e10))
    for a, b in zip(expected, net(g)):
        torch.testing.assert_close(a, b, atol=1e-5, rtol=1e-5)
    for name in ("bullets", "lasers"):
        perm = torch.arange(f[name].shape[1]-1, -1, -1)
        g[name], g[name+"_mask"] = f[name][:, perm], f[name+"_mask"][:, perm]
    for a, b in zip(expected, net(g)):
        torch.testing.assert_close(a, b, atol=1e-5, rtol=1e-5)


@pytest.mark.parametrize("empty", [("bullets",), ("lasers",), ("bullets", "lasers")])
def test_empty_types_are_safe(empty):
    net, f = build()
    for name in empty:
        f[name+"_mask"][:] = False
    logits, value = net(f)
    assert logits.shape == (2, 18) and value.shape == (2,)
    assert torch.isfinite(logits).all() and torch.isfinite(value).all()
    bt, lt = net.threat_tokens(f)
    for name, tok, enc in (("bullets", bt, net.bullets), ("lasers", lt, net.lasers)):
        if name in empty:
            pooled = enc(f[name], f[name+"_mask"], torch.ones(2, 16), tok)
            assert (pooled == 0).all()


@pytest.mark.parametrize("amp", [False, True])
def test_training_gradients_reach_encoders_and_joint_layer(amp):
    net, f = build()
    with torch.autocast("cpu", dtype=torch.bfloat16, enabled=amp):
        bt, lt = net.threat_tokens(f)
        if amp:
            assert bt.dtype == lt.dtype == torch.bfloat16
        logits, value = net(f)
    assert torch.isfinite(logits).all() and torch.isfinite(value).all()
    (logits.logsumexp(-1).sum() + value.sum()).backward()
    assert all(p.grad is not None and torch.isfinite(p.grad).all() and p.grad.abs().sum() > 0
               for p in net.parameters())


def test_disabled_joint_layer_does_not_mix_types():
    net, f = build(joint_sa_layers=0)
    _, l = net.threat_tokens(f)
    _, changed = net.threat_tokens(dict(f, bullets=f["bullets"]+1))
    torch.testing.assert_close(l, changed)


def test_density_can_be_disabled_without_changing_checkpoint_parameters():
    enabled, f = build()
    disabled, _ = build(density_enabled=False)
    disabled.load_state_dict(enabled.state_dict(), strict=True)
    changed = dict(f, density=f["density"] + 100.0)
    assert not torch.allclose(enabled(f)[0], enabled(changed)[0])
    for a, b in zip(disabled(f), disabled(changed)):
        torch.testing.assert_close(a, b, atol=0, rtol=0)


def test_explicit_density_enabled_matches_default():
    default, f = build()
    explicit, _ = build(density_enabled=True)
    explicit.load_state_dict(default.state_dict(), strict=True)
    for a, b in zip(default(f), explicit(f)):
        torch.testing.assert_close(a, b, atol=0, rtol=0)


@pytest.mark.parametrize("model", [{"sa_layers": 1}, {"laser_sa_layers": 1}, {"joint_sa_layers": -1}])
def test_invalid_layers_rejected(model):
    with pytest.raises(ValueError, match="layers"):
        build(**model)
