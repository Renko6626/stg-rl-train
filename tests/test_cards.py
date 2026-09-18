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
