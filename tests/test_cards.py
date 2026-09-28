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
