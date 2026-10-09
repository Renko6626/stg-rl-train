import pytest
import torch

from test_ppo import setup
from stgtrain.checkpoint import load_checkpoint, restore_rng, save_checkpoint
from stgtrain.train import initialize_from_checkpoint, initialize_density_from_checkpoint


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


def test_load_state_dict_keeps_lr_tensor_identity(tmp_path):
    # CUDA 图 update 路径靠 lr.copy_() 退火；load_state_dict 若换掉 lr 张量对象，
    # 图里捕获的旧张量不再被更新，续训后退火静默失效。
    cfg, envw, feat, ppo, rf, tr = setup()
    ppo.optimizer.param_groups[0]["lr"].copy_(1.23e-4)
    p = tmp_path / "lr.pt"
    save_checkpoint(p, ppo=ppo, update=1, env_steps=1, cfg=cfg)
    t0 = ppo.optimizer.param_groups[0]["lr"]
    ppo.load_state_dict(load_checkpoint(p)["state"])
    assert ppo.optimizer.param_groups[0]["lr"] is t0
    assert float(t0) == pytest.approx(1.23e-4)


def test_initialize_inherits_weights_only_and_records_source(tmp_path):
    cfg, envw, feat, source, rf, tr = setup()
    _, container, next_value = source.rollout(envw, feat, rf, tr, None, envw.reset())
    source.train_step(container, next_value, 7, 10)
    assert source.optimizer.state
    path = tmp_path / "checkpoints" / "latest.pt"
    save_checkpoint(path, ppo=source, update=7, env_steps=896, cfg=cfg, extra={"best": [1.0, 1.0]})
    (tmp_path / "env.json").write_text('{"stg_rl": {"engine_ver": 24}}')
    new_cfg, _, _, target, _, _ = setup(
        ppo={"learning_rate": 1e-4}, reward={"action_source": "request", "terms": {"shift_toggle": 0.02}})
    lr = target.optimizer.param_groups[0]["lr"]
    rng = torch.get_rng_state().clone()
    provenance = initialize_from_checkpoint(target, new_cfg, path)
    assert not target.optimizer.state
    assert target.optimizer.param_groups[0]["lr"] is lr
    assert float(lr) == pytest.approx(1e-4)
    assert torch.equal(torch.get_rng_state(), rng)
    for a, b, c in zip(source.agent.parameters(), target.agent.parameters(), target.agent_inference.parameters()):
        assert torch.equal(a, b) and torch.equal(b, c)
        assert not c.requires_grad
    assert provenance["path"] == str(path.resolve())
    import hashlib

    assert provenance["sha256"] == hashlib.sha256(path.read_bytes()).hexdigest()
    assert provenance["source_update"] == 7 and provenance["source_env_steps"] == 896
    assert provenance["source_stg_rl"]["engine_ver"] == 24
    assert provenance["source_model"] == cfg["model"]
    assert provenance["source_featurize"] == cfg["featurize"]


def test_initialize_rejects_feature_signature_change(tmp_path):
    cfg, _, _, source, _, _ = setup(featurize={"k_lasers": 8})
    path = tmp_path / "source.pt"
    save_checkpoint(path, ppo=source, update=7, env_steps=896, cfg=cfg)
    new_cfg, _, _, target, _, _ = setup(featurize={"k_lasers": 4})
    with pytest.raises(ValueError, match="featurize.k_lasers"):
        initialize_from_checkpoint(target, new_cfg, path)


def test_density_initialization_only_allows_switch_and_keeps_weights(tmp_path):
    from conftest import small_cfg
    from stgtrain.ppo import PPO
    from stgtrain.registry import FEATURIZERS, MODELS

    cfg = small_cfg(featurize={"name": "danger_topk_v8", "frame": "static", "dt": False, "k_lasers": 8},
                    model={"name": "set_attn_v3", "joint_sa_layers": 1})
    feat = FEATURIZERS.get("danger_topk_v8")(cfg)
    source = PPO(cfg, lambda: MODELS.get("set_attn_v3")(cfg, feat.spec()), torch.device("cpu"))
    path = tmp_path / "source.pt"
    save_checkpoint(path, ppo=source, update=1000, env_steps=262144000, cfg=cfg)
    import copy

    target_cfg = copy.deepcopy(cfg)
    target_cfg["model"]["density_enabled"] = False
    target = PPO(target_cfg, lambda: MODELS.get("set_attn_v3")(target_cfg, feat.spec()), torch.device("cpu"))
    with pytest.raises(ValueError, match="model.density_enabled"):
        initialize_from_checkpoint(target, target_cfg, path)
    info = initialize_density_from_checkpoint(target, target_cfg, path)
    assert not target.optimizer.state
    assert info["migration"]["kind"] == "density_ablation_v3"
    assert info["migration"]["model.density_enabled"] == {"source": True, "target": False}
    from operator import attrgetter

    for key, tensor in source.agent.state_dict().items():
        assert torch.equal(tensor, target.agent.state_dict()[key])
        assert torch.equal(tensor, attrgetter(key)(target.agent_inference))
    target_cfg["featurize"]["k_lasers"] = 4
    with pytest.raises(ValueError, match="featurize.k_lasers"):
        initialize_density_from_checkpoint(target, target_cfg, path)
