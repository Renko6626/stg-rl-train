"""卡池：一张卡 = 一个目录（spec §2 / stg-engine docs/rl-card-pool.md §2）。"""
from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

import stg_rl


@dataclass(frozen=True)
class Card:
    id: str
    path: Path
    meta: dict


@dataclass(frozen=True)
class EvalSpec:
    card: str
    ranks: tuple[int, ...]
    episodes: int


def discover(cards_dir: str | Path) -> dict[str, Card]:
    root = Path(cards_dir)
    if not root.is_dir():
        return {}
    out: dict[str, Card] = {}
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        if not any(d.glob("*.ecl")):
            continue
        meta_path = d / "meta.toml"
        meta = tomllib.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
        out[d.name] = Card(id=d.name, path=d, meta=meta)
    return out


def load_splits(path: str | Path, default_episodes: int) -> list[EvalSpec]:
    p = Path(path)
    if not p.exists():
        return []
    data = tomllib.loads(p.read_text(encoding="utf-8"))
    return [
        EvalSpec(card=e["card"], ranks=tuple(e.get("ranks", [2])), episodes=int(e.get("episodes", default_episodes)))
        for e in data.get("eval", [])
    ]


def allowed_ranks(card: Card, ranks: list[int]) -> list[int]:
    lo, hi = card.meta.get("ranks", [0, 4])
    return [r for r in ranks if lo <= r <= hi]


def compile_cards(cards: dict[str, Card]) -> dict[str, stg_rl.Image]:
    return {cid: stg_rl.compile_dir(card.path) for cid, card in cards.items()}


def train_starts(cards: dict[str, Card], eval_ids: set[str], ranks: list[int]) -> list[stg_rl.Start]:
    starts = [
        stg_rl.Start(image=cid, mark=int(mark), rank=r, weight=1.0)
        for cid, card in cards.items()
        if cid not in eval_ids
        for mark in card.meta.get("marks", [0])
        for r in allowed_ranks(card, ranks)
    ]
    if not starts:
        raise ValueError("没有可用的训练起点：卡池为空、全部划进了评测集，或 rank 全被 meta 过滤掉")
    return starts
