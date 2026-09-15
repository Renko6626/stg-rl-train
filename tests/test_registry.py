import pytest

from stgtrain.registry import Registry, check_compat


def test_register_and_get():
    r = Registry("thing")

    @r.register("a")
    class A:
        pass

    assert r.get("a") is A
    assert r.names() == ["a"]


def test_duplicate_and_unknown_raise():
    r = Registry("thing")
    r.register("a")(object)
    with pytest.raises(ValueError, match="重复"):
        r.register("a")(object)
    with pytest.raises(ValueError, match="a"):
        r.get("nope")


def test_check_compat():
    spec = {"bullets": (64, 7), "cond": (4,)}
    check_compat({"bullets": (64, 7)}, spec)
    with pytest.raises(ValueError, match="缺"):
        check_compat({"enemies": (8, 6)}, spec)
    with pytest.raises(ValueError, match="形状"):
        check_compat({"bullets": (32, 7)}, spec)
