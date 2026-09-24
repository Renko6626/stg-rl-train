"""bf16 autocast（`ppo.amp`）与 SDPA 版自注意力。"""
import math

import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.models.set_attn_v1 import SelfAttnBlock
from stgtrain.ppo import PPO
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins
from tensordict import TensorDict

load_builtins()


def manual_block(block: SelfAttnBlock, x, mask):
    """修改前的手写注意力（显式存注意力矩阵），作为 SDPA 版的对照。"""
    n, k, d = x.shape
    q, kk, v = block.qkv(block.ln1(x)).view(n, k, 3, block.heads, block.dk).permute(2, 0, 3, 1, 4)
    scores = (q @ kk.transpose(-1, -2)) / math.sqrt(block.dk)
    scores = scores.masked_fill(~mask[:, None, None, :], -1e4)
    x = x + block.proj((scores.softmax(-1) @ v).transpose(1, 2).reshape(n, k, d))
    return x + block.ffn(block.ln2(x))


def test_sdpa_block_matches_manual_attention():
    torch.manual_seed(0)
    block = SelfAttnBlock(16, 2)
    x = torch.randn(5, 12, 16)
    mask = torch.rand(5, 12) < 0.6
    mask[0] = False                      # 全空的行：不出 NaN
    mask[1] = True
    got, want = block(x, mask), manual_block(block, x, mask)
    assert torch.isfinite(got).all()
    assert torch.allclose(got[mask], want[mask], atol=1e-5)
    # 全空的行：手写版把分数整个替换成 −1e4（均匀），SDPA 是加性偏置（保留原分数差），两者不同但都有限；
    # 这些行全是 padding，SetEncoder 每层都乘掩码归零，下游看不到 —— 见下一条测试。


def test_all_padding_encoder_output_is_zero_pooled():
    from stgtrain.models.set_attn_v1 import SetEncoder
    torch.manual_seed(0)
    enc = SetEncoder(5, 16, 2, 16, sa_layers=2)
    x = torch.randn(3, 10, 5)
    out = enc(x, torch.zeros(3, 10, dtype=torch.bool), torch.randn(3, 16))
    assert torch.equal(out, torch.zeros_like(out))


def setup(amp, sa_layers=1):
    cfg = small_cfg(model={"sa_layers": sa_layers}, ppo={"amp": amp},
                    featurize={"name": "danger_topk_v6", "frame": "static", "dt": False})
    feat = FEATURIZERS.get("danger_topk_v6")(cfg)
    torch.manual_seed(0)
    ppo = PPO(cfg, lambda: MODELS.get("set_attn_v1")(cfg, feat.spec()), torch.device("cpu"))
    return cfg, feat, ppo


def busy_obs(n=4):
    rows = [(float(10 * j - 40), 300.0 - 7 * j, 0.5 * j, 2.0, 2.0) for j in range(9)]
    return raw_obs(n=n, player=(5.0, 390.0), target=(-40.0, 280.0), bullets=[rows] * n)


def test_amp_off_is_unchanged():
    _, feat, a = setup("off")
    f = TensorDict(feat(busy_obs()), batch_size=[4])
    logits, value = a.agent.model(f)
    act, logp, ent, val = a.agent.get_action_and_value(f, torch.zeros(4, dtype=torch.long))
    assert torch.equal(val, value)
    assert logp.dtype == torch.float32


def test_bf16_outputs_are_fp32_and_close():
    _, feat, off = setup("off")
    _, _, on = setup("bf16")
    on.agent.load_state_dict(off.agent.state_dict())
    f = TensorDict(feat(busy_obs()), batch_size=[4])
    a = torch.zeros(4, dtype=torch.long)
    _, lp_off, _, v_off = off.agent.get_action_and_value(f, a)
    _, lp_on, _, v_on = on.agent.get_action_and_value(f, a)
    assert lp_on.dtype == torch.float32 and v_on.dtype == torch.float32
    assert not torch.equal(lp_on, lp_off), "bf16 路径应当真的走了低精度"
    assert torch.allclose(lp_on, lp_off, atol=0.05) and torch.allclose(v_on, v_off, atol=0.05)


def test_bf16_update_step_trains_in_fp32():
    _, feat, ppo = setup("bf16")
    n = 16
    f = TensorDict(feat(busy_obs(n)), batch_size=[n])
    with torch.no_grad():
        act, logp, _, val = ppo.agent_inference.get_action_and_value(f)
    before = [p.detach().clone() for p in ppo.agent.parameters()]
    out = ppo.update(TensorDict(feats=f, actions=act, logprobs=logp, advantages=torch.randn(n),
                                returns=torch.randn(n), vals=val.flatten(), batch_size=[n]),
                     tensordict_out=TensorDict())
    assert all(torch.isfinite(out[k]).all() for k in out.keys())
    assert all(p.dtype == torch.float32 for p in ppo.agent.parameters())
    assert any(not torch.equal(b, p) for b, p in zip(before, ppo.agent.parameters()))


def test_bad_amp_rejected():
    with pytest.raises(ValueError):
        small_cfg(ppo={"amp": "fp8"})
