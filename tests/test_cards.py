import pytest
import stg_rl

from conftest import FIXTURES
from stgtrain.cards import EvalSpec, allowed_ranks, compile_cards, discover, load_splits, train_starts


def test_discover_finds_fixture_cards():
    cards = discover(FIXTURES / "cards")
    assert list(cards) == ["example_calm", "example_ring"]
    assert cards["example_calm"].meta["ranks"] == [0, 2]
    assert cards["example_ring"].meta == {}


def test_discover_missing_dir_is_empty(tmp_path):
    assert discover(tmp_path / "nope") == {}


def test_load_splits():
    specs = load_splits(FIXTURES / "eval_splits.toml", default_episodes=32)
    assert specs == [EvalSpec(card="example_calm", ranks=(2,), episodes=4)]
    assert load_splits(FIXTURES / "missing.toml", 32) == []


def test_allowed_ranks_filters_by_meta():
    cards = discover(FIXTURES / "cards")
    assert allowed_ranks(cards["example_calm"], [0, 1, 2, 3, 4]) == [0, 1, 2]
    assert allowed_ranks(cards["example_ring"], [1, 4]) == [1, 4]


def test_train_starts_excludes_eval_cards():
    cards = discover(FIXTURES / "cards")
    starts = train_starts(cards, {"example_calm"}, [2, 3])
    assert [(s.image, s.mark, s.rank) for s in starts] == [("example_ring", 0, 2), ("example_ring", 0, 3)]
    with pytest.raises(ValueError, match="起点"):
        train_starts(cards, {"example_calm", "example_ring"}, [2])


def test_compile_cards():
    images = compile_cards(discover(FIXTURES / "cards"))
    assert set(images) == {"example_calm", "example_ring"}
    assert all(isinstance(i, stg_rl.Image) for i in images.values())


def test_training_ranks_clamps_instead_of_dropping():
    from stgtrain.cards import training_ranks
    cards = discover(FIXTURES / "cards")
    calm = cards["example_calm"]                       # meta ranks = [0, 2]
    assert allowed_ranks(calm, [3, 4]) == []           # 严格过滤：这张卡没有 3/4 档
    assert training_ranks(calm, [3, 4]) == [2]         # 训练：钳到它最高的一档，不丢卡
    assert training_ranks(calm, [1]) == [1]            # 区间内原样
    assert training_ranks(calm, [0, 1, 2, 3]) == [0, 1, 2]   # 3 钳成 2 后与已有的 2 去重


def test_explicit_multi_roots_and_data_kind(tmp_path):
    from stgtrain.cards import Card
    original, synthetic = tmp_path / 'original', tmp_path / 'synthetic'
    for root, name, meta in [(original, 'base', 'source="th06"'), (synthetic, 'variant', 'source="synthetic"\ndata_kind="synthetic"\nbase_card="base"')]:
        d = root / name
        d.mkdir(parents=True)
        (d / 'main.ecl').write_text('sub main() {}')
        (d / 'meta.toml').write_text(meta)
    cards = discover([original, synthetic])
    assert cards['base'].data_kind == 'original'
    assert cards['variant'].data_kind == 'synthetic'
    assert Card('unknown', tmp_path, {'source': 'example'}).data_kind == 'unknown'
    assert Card('unknown', tmp_path, {}).data_kind == 'unknown'
    with pytest.raises(ValueError, match='起点'):
        train_starts(cards, {'base'}, [2])


def test_multi_roots_reject_duplicate_ids(tmp_path):
    for root in [tmp_path / 'a', tmp_path / 'b']:
        d = root / 'same'
        d.mkdir(parents=True)
        (d / 'main.ecl').write_text('sub main() {}')
    with pytest.raises(ValueError, match='重复'):
        discover([tmp_path / 'a', tmp_path / 'b'])


def test_card_manifest_maps_sources_without_changing_starts():
    from stgtrain.cards import Card, card_manifest
    cards = {'base': Card('base', FIXTURES, {'source': 'th06'}),
             'variant': Card('variant', FIXTURES, {'source': 'synthetic', 'base_card': 'base', 'mutation_id': 'rail'})}
    assert card_manifest(cards) == {'base': {'data_kind': 'original', 'source': 'th06', 'base_card': None, 'mutation_id': None},
                                    'variant': {'data_kind': 'synthetic', 'source': 'synthetic', 'base_card': 'base', 'mutation_id': 'rail'}}


def test_synthetic_shared_source_is_filtered_without_changing_original_pool(tmp_path):
    from stgtrain.cards import Card
    cards = {'held': Card('held', tmp_path, {'source': 'th06', 'source_ref': 'f:10-20'}),
             'base': Card('base', tmp_path, {'source': 'th06', 'source_ref': 'f:20-30'}),
             'variant': Card('variant', tmp_path, {'source': 'synthetic', 'base_card': 'base', 'source_ref': 'f:20-30'})}
    assert [s.image for s in train_starts(cards, {'held'}, [2])] == ['base']


def test_standalone_specialist_metadata_exception_is_strict_and_heldout_is_always_excluded(tmp_path):
    from stgtrain.cards import card_manifest

    root = tmp_path / 'cards'
    good = root / 'specialist_held'
    good.mkdir(parents=True)
    (good / 'main.ecl').write_text('sub main() {}')
    (good / 'meta.toml').write_text('''
title = "Held specialist"
source = "synthetic"
data_kind = "synthetic"
synthetic_kind = "laser_specialist"
generation_mode = "standalone"
family = "sweep"
layout_id = "specialist_held"
split = "held-out"
contract_version = 1
ranks = [0, 3]
marks = [0]
time_limit = 1800
tags = ["laser", "specialist"]
''')
    train = root / 'specialist_train'
    train.mkdir()
    (train / 'main.ecl').write_text('sub main() {}')
    (train / 'meta.toml').write_text((good / 'meta.toml').read_text().replace('held-out', 'train').replace('specialist_held', 'specialist_train'))

    cards = discover(root)
    assert [start.image for start in train_starts(cards, set(), [0, 3])] == ['specialist_train', 'specialist_train']
    assert card_manifest(cards)['specialist_held']['synthetic_kind'] == 'laser_specialist'


@pytest.mark.parametrize('field,value,message', [
    ('family', '"unknown"', 'family'),
    ('split', '"dev"', 'split'),
    ('contract_version', '2', 'contract_version'),
    ('ranks', '[0, 4]', 'ranks'),
    ('base_card', '"invented"', 'base_card'),
    ('source_ref', '"fake:1-2"', 'source_ref'),
    ('generation_mode', '"overlay"', 'generation_mode'),
])
def test_standalone_specialist_rejects_invalid_or_forged_metadata(tmp_path, field, value, message):
    root = tmp_path / 'cards'
    card = root / 'bad'
    card.mkdir(parents=True)
    (card / 'main.ecl').write_text('sub main() {}')
    metadata = '''
title = "Specialist"
source = "synthetic"
data_kind = "synthetic"
synthetic_kind = "laser_specialist"
generation_mode = "standalone"
family = "stagger"
layout_id = "bad"
split = "train"
contract_version = 1
ranks = [0, 3]
marks = [0]
time_limit = 1800
tags = ["laser", "specialist"]
'''
    lines = metadata.splitlines()
    line = next((line for line in lines if line.startswith(field + ' =')), None)
    result = metadata.replace(line, f'{field} = {value}') if line else metadata + f'\n{field} = {value}\n'
    (card / 'meta.toml').write_text(result)
    with pytest.raises(ValueError, match=message):
        discover(root)


def test_ordinary_synthetic_still_requires_base_card(tmp_path):
    card = tmp_path / 'synthetic'
    card.mkdir()
    (card / 'main.ecl').write_text('sub main() {}')
    (card / 'meta.toml').write_text('source="synthetic"\ndata_kind="synthetic"')
    with pytest.raises(ValueError, match='base_card'):
        discover(tmp_path)
