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
    """卡真正支持的档（严格过滤）。评测 / 录像用它判「这张卡有没有这一档」。"""
    lo, hi = card.meta.get("ranks", [0, 4])
    return [r for r in ranks if lo <= r <= hi]


def training_ranks(card: Card, ranks: list[int]) -> list[int]:
    """训练起点用的档：**钳**到卡支持的区间，而不是过滤掉。

    原作里不少符卡只存在于 E/N 或只存在于 H/L（`meta.ranks` 就是这个区间）。按 `ranks = [2]`
    严格过滤的话，9 张只有 E/N 档的卡（含第 5 关咲夜的三张时停卡）整张从训练里消失；
    钳到该卡可用的最高档（这里即 rank 1）就能纳进来——那本来就是这张卡最难的形态。
    """
    lo, hi = card.meta.get("ranks", [0, 4])
    return sorted({min(max(r, lo), hi) for r in ranks})


def compile_cards(cards: dict[str, Card]) -> dict[str, stg_rl.Image]:
    return {cid: stg_rl.compile_dir(card.path) for cid, card in cards.items()}


def train_starts(cards: dict[str, Card], eval_ids: set[str], ranks: list[int]) -> list[stg_rl.Start]:
    starts = [
        stg_rl.Start(image=cid, mark=int(mark), rank=r, weight=1.0)
        for cid, card in cards.items()
        if cid not in eval_ids
        for mark in card.meta.get("marks", [0])
        for r in training_ranks(card, ranks)
    ]
    if not starts:
        raise ValueError("没有可用的训练起点：卡池为空、全部划进了评测集，或 rank 全被 meta 过滤掉")
    return starts
