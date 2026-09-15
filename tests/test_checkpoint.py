import pytest
import torch

from test_ppo import setup
from stgtrain.checkpoint import load_checkpoint, restore_rng, save_checkpoint


def test_roundtrip(tmp_path):
    cfg, envw, feat, ppo, rf, tr = setup()
    p = tmp_path / "ck" / "latest.pt"
    save_checkpoint(p, ppo=ppo, update=7, env_steps=896, cfg=cfg, extra={"best": [0.5, 0.2]})
    saved = [x.detach().clone() for x in ppo.agent.parameters()]
    with torch.no_grad():
        for x in ppo.agent.parameters():
            x.add_(1.0)
    ck = load_checkpoint(p)
    assert ck["update"] == 7 and ck["env_steps"] == 896 and ck["extra"]["best"] == [0.5, 0.2]
    assert ck["model_name"] == "set_attn_v1" and ck["cfg"] == cfg
    ppo.load_state_dict(ck["state"])
    for a, b in zip(ppo.agent.parameters(), saved):
        assert torch.equal(a, b)
    for a, b in zip(ppo.agent.parameters(), ppo.agent_inference.parameters()):
        assert torch.equal(a.data, b.data)
    restore_rng(ck)
    assert not (p.parent / "latest.pt.tmp").exists()


def test_rejects_other_action_table(tmp_path):
    cfg, envw, feat, ppo, rf, tr = setup()
    p = tmp_path / "x.pt"
    save_checkpoint(p, ppo=ppo, update=1, env_steps=1, cfg=cfg)
    ck = torch.load(p, weights_only=False)
    ck["action_table_version"] = 2
    torch.save(ck, p)
    with pytest.raises(ValueError, match="动作表"):
        load_checkpoint(p)
