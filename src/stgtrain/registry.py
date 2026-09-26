"""注册表：模型 / 特征化器 / 意图生成器 / reward 项按配置里的名字选用（spec §4）。"""
from __future__ import annotations

import importlib
from typing import Callable, TypeVar

T = TypeVar("T")


class Registry:
    def __init__(self, kind: str):
        self.kind = kind
        self._items: dict[str, object] = {}

    def register(self, name: str) -> Callable[[T], T]:
        def deco(obj: T) -> T:
            if name in self._items:
                raise ValueError(f"{self.kind} 注册名重复：{name!r}")
            self._items[name] = obj
            return obj

        return deco

    def get(self, name: str):
        if name not in self._items:
            raise ValueError(f"未知的 {self.kind} {name!r}；已注册：{self.names()}")
        return self._items[name]

    def names(self) -> list[str]:
        return sorted(self._items)


MODELS = Registry("model")
FEATURIZERS = Registry("featurizer")
INTENTS = Registry("intent")
REWARD_TERMS = Registry("reward term")

# 各内置实现所在模块；后续 Task 逐个追加。import 即注册。
BUILTIN_MODULES: list[str] = [
    "stgtrain.intent",
    "stgtrain.intent_follow",
    "stgtrain.intent_gentle",
    "stgtrain.featurize.danger_topk_v1",
    "stgtrain.featurize.danger_topk_v2",
    "stgtrain.featurize.danger_topk_v3",
    "stgtrain.featurize.danger_topk_v4",
    "stgtrain.featurize.danger_topk_v5",
    "stgtrain.featurize.danger_topk_v6",
    "stgtrain.featurize.danger_topk_v7",
    "stgtrain.reward",
    "stgtrain.models.set_attn_v1",
    "stgtrain.models.set_attn_v2",
]


def load_builtins() -> None:
    for mod in BUILTIN_MODULES:
        importlib.import_module(mod)


def check_compat(requires: dict[str, tuple[int, ...]], spec: dict[str, tuple[int, ...]]) -> None:
    """模型要的特征键必须都由特征化器提供，且形状（去掉 batch 维）一致。"""
    for key, shape in requires.items():
        if key not in spec:
            raise ValueError(f"模型要的特征 {key!r} 特征化器没提供（缺）；特征化器提供：{sorted(spec)}")
        if tuple(spec[key]) != tuple(shape):
            raise ValueError(f"特征 {key!r} 形状不符：模型要 {tuple(shape)}，特征化器给 {tuple(spec[key])}")
