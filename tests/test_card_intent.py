import pytest
import stg_rl
import torch

from conftest import FIXTURES, small_cfg
from stgtrain.cards import Card, card_manifest, discover, compile_cards, train_starts
from stgtrain.config import from_dict
from stgtrain.envwrap import EnvWrapper
from stgtrain.evaluate import eval_cfg
from stgtrain.registry import load_builtins

CPU = torch.device('cpu')
FOLLOW = {'follow': 1.0, 'anchor': 0.0, 'free': 0.0}
FREE = {'follow': 0.0, 'anchor': 0.0, 'free': 1.0}

@pytest.mark.parametrize('mix', [None, [], {}, {'follow': 1},
    {'follow': -1, 'anchor': 1, 'free': 1}, {'follow': 0, 'anchor': 0, 'free': 0},
    {'follow': float('nan'), 'anchor': 1, 'free': 1},
    {'follow': float('inf'), 'anchor': 1, 'free': 1},
    {'follow': '1', 'anchor': 0, 'free': 0},
    {'follow': 1, 'anchor': 0, 'free': 0, 'other': 1}])
def test_card_mix_rejects_invalid_metadata(mix):
    card = Card('bad', FIXTURES, {'laser_intent_mix': mix})
    with pytest.raises(ValueError, match='laser_intent_mix'):
        card_manifest({'bad': card})


def test_start_mix_maps_filtered_rank_mark_order_and_normalizes():
    from stgtrain.cards import start_intent_mixes
    cards = {'ordinary': Card('ordinary', FIXTURES, {'marks': [0, 3]}),
             'laser': Card('laser', FIXTURES, {'laser_intent_mix': {'follow': 3, 'anchor': 3, 'free': 4}}),
             'held': Card('held', FIXTURES, {'laser_intent_mix': FREE})}
    starts = train_starts(cards, {'held'}, [2, 3])
    mixes = start_intent_mixes(cards, starts, FOLLOW, enabled=True)
    assert mixes == [FOLLOW] * 4 + [{'follow': .3, 'anchor': .3, 'free': .4}] * 2
    assert start_intent_mixes(cards, starts, FOLLOW, enabled=False) == [FOLLOW] * 6
    assert card_manifest(cards)['laser']['laser_intent_mix'] == {'follow': 3, 'anchor': 3, 'free': 4}


@pytest.mark.parametrize('intent', ['', 'mixed_v1', 'lower_half_uniform_v1'])
def test_eval_always_disables_card_mix_without_mutating_training(intent):
    cfg = from_dict({'intent': {'name': 'mixed_v1', 'card_mix_enabled': True}, 'eval': {'intent': intent}})
    c = eval_cfg(cfg)
    assert c['intent']['card_mix_enabled'] is False
    assert cfg['intent']['card_mix_enabled'] is True


def test_feature_requires_mixed_intent():
    with pytest.raises(ValueError, match='mixed_v1'):
        from_dict({'intent': {'card_mix_enabled': True}})


def test_engine_reset_and_autoreset_select_new_card_mix_and_keep_episode_attribution():
    if not hasattr(stg_rl.VecEnv, 'current_start_indices'):
        pytest.skip('integration requires the current_start_indices engine API')
    load_builtins()
    cfg = small_cfg(env={'max_frames': 1, 'warmup_max': 0},
                    intent={'name': 'mixed_v1', 'card_mix_enabled': True, 'mix': FOLLOW})
    cards = discover(FIXTURES / 'cards')
    starts = [stg_rl.Start('example_ring', 0, 2), stg_rl.Start('example_calm', 0, 2)]
    w = EnvWrapper(cfg, compile_cards(cards), starts, CPU, seed=3, start_intent_mixes=[FOLLOW, FREE])
    w.set_start_weights([0, 1])
    o = w.reset()
    assert (w.intent.mode == 2).all()
    assert torch.equal(o.target_xy, o.player_xy)
    w.set_start_weights([1, 0])
    _, info = w.step(torch.zeros(w.n, dtype=torch.int64))
    assert (info.done != 0).all()
    assert (info.start_index == 1).all()
    assert (info.intent_mode == 2).all()
    assert (w.intent.mode == 0).all()
    w.set_start_weights([0, 1])
    _, info = w.step(torch.zeros(w.n, dtype=torch.int64))
    assert (info.start_index == 0).all()
    assert (info.intent_mode == 0).all()
    assert (w.intent.mode == 2).all()
    w.set_start_weights([1, 0])
    w.reset()
    assert (w.intent.mode == 0).all()


def test_disabled_metadata_preserves_rng_and_rollout():
    load_builtins()
    cfg = small_cfg(env={'max_frames': 3, 'warmup_max': 0}, intent={'name': 'mixed_v1'})
    images = compile_cards(discover(FIXTURES / 'cards'))
    starts = [stg_rl.Start('example_ring', 0, 2)]
    a = EnvWrapper(cfg, images, starts, CPU, seed=9)
    b = EnvWrapper(cfg, images, starts, CPU, seed=9, start_intent_mixes=[FREE])
    a.reset(); b.reset()
    for _ in range(8):
        oa, ia = a.step(torch.zeros(a.n, dtype=torch.int64))
        ob, ib = b.step(torch.zeros(b.n, dtype=torch.int64))
        assert torch.equal(oa.target_xy, ob.target_xy)
        assert torch.equal(ia.intent_mode, ib.intent_mode)
        assert torch.equal(a.intent.gen.get_state(), b.intent.gen.get_state())


def test_mixed_intent_samples_per_start_and_preserves_unfinished_modes():
    from stgtrain.intent import MixedIntent
    cfg = small_cfg(intent={'name': 'mixed_v1'})
    it = MixedIntent(cfg, 8000, CPU, seed=17)
    it.set_start_mixes([cfg['intent']['mix'], {'follow': .3, 'anchor': .3, 'free': .4}])
    it.use_start_indices(torch.arange(8000) // 4000)
    it.reset_all()
    fractions = torch.stack([(it.mode.reshape(2, 4000) == m).float().mean(1) for m in range(3)], 1)
    assert torch.allclose(fractions, torch.tensor([[.6, .3, .1], [.3, .3, .4]]), atol=.035)
    old_mode, old_target = it.mode.clone(), it.target.clone()
    it.use_start_indices(torch.ones(8000, dtype=torch.int64))
    mask = torch.arange(8000) < 4000
    it.reset(mask)
    assert torch.equal(it.mode[~mask], old_mode[~mask])
    assert torch.equal(it.target[~mask], old_target[~mask])


def test_engine_feature_reports_missing_api_clearly():
    if hasattr(stg_rl.VecEnv, 'current_start_indices'):
        pytest.skip('only relevant to pre-0.4.1 engine')
    cfg = small_cfg(intent={'name': 'mixed_v1', 'card_mix_enabled': True})
    with pytest.raises(RuntimeError, match='current_start_indices'):
        EnvWrapper(cfg, {}, [stg_rl.Start('unused', 0, 2)], CPU, seed=1, start_intent_mixes=[FREE])
