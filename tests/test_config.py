import copy

import pytest

from stgtrain.config import DEFAULTS, deep_merge, dump_toml, from_dict, load_config, validate


def test_defaults_are_valid():
    validate(copy.deepcopy(DEFAULTS))


def test_deep_merge_keeps_unmentioned_keys():
    out = deep_merge(DEFAULTS, {"reward": {"terms": {"hold": 0.5}}})
    assert out["reward"]["terms"]["hold"] == 0.5
    assert out["reward"]["terms"]["death"] == DEFAULTS["reward"]["terms"]["death"]
    assert DEFAULTS["reward"]["terms"]["hold"] == 0.01, "不得改动 DEFAULTS 本身"


@pytest.mark.parametrize(
    "over, msg",
    [
        ({"env": {"nmu_envs": 4}}, "未知配置键"),
        ({"env": {"bullets_cap": 0}}, "bullets_cap"),
        ({"featurize": {"k_bullets": 2048}}, "k_bullets"),
        ({"intent": {"interval": [300, 120]}}, "interval"),
        ({"run": {"device": "gpu"}}, "device"),
        ({"env": {"num_envs": 6}, "ppo": {"num_steps": 5, "num_minibatches": 4}}, "num_minibatches"),
        ({"env": {"ranks": [5]}}, "ranks"),
    ],
)
def test_validate_rejects(over, msg):
    with pytest.raises(ValueError, match=msg):
        from_dict(over)


def test_toml_roundtrip(tmp_path):
    cfg = from_dict({"model": {"d": 32}, "env": {"ranks": [0, 4]}})
    p = tmp_path / "c.toml"
    dump_toml(cfg, p)
    assert load_config(p) == cfg


def test_load_config_overrides(tmp_path):
    p = tmp_path / "c.toml"
    p.write_text('[run]\nseed = 7\n', encoding="utf-8")
    cfg = load_config(p, overrides={"run": {"total_updates": 3}})
    assert cfg["run"]["seed"] == 7 and cfg["run"]["total_updates"] == 3


def test_multiple_card_roots_round_trip(tmp_path):
    cfg = from_dict({'env': {'cards_dir': ['cards', 'cards-synthetic']}})
    dump_toml(cfg, tmp_path / 'config.toml')
    env = load_config(tmp_path / 'config.toml')['env']
    assert env['cards_dir'] == 'cards'
    assert env['card_filter']['sources'] == ['th06', 'synthetic']
    assert env['card_filter']['exclude_synthetic_kinds'] == ['laser_specialist']


def test_source_selection_keeps_old_checkpoint_pool_and_explicit_new_selection():
    old = from_dict({'env': {'cards_dir': 'cards'}})['env']
    assert old['card_filter']['sources'] == ['th06']
    mixed = from_dict({'env': {'cards_dir': ['cards', 'cards-synthetic', 'cards-laser-specialist']}})['env']
    assert mixed['card_filter']['sources'] == ['th06', 'synthetic']
    assert mixed['card_filter']['exclude_synthetic_kinds'] == []
    new = from_dict({'env': {'cards_dir': 'cards', 'card_filter': {'sources': ['th18']}}})['env']
    assert new['card_filter']['sources'] == ['th18']
