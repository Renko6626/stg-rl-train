"""卡池：一张卡 = 一个目录（spec §2 / stg-engine docs/rl-card-pool.md §2）。"""
from __future__ import annotations

import tomllib
import re
import math
from dataclasses import dataclass
from pathlib import Path

import stg_rl


@dataclass(frozen=True)
class Card:
    id: str
    path: Path
    meta: dict

    @property
    def data_kind(self) -> str:
        """来源标签只用于数据管理，不进入策略观测；未知来源不冒充原作。"""
        source = self.meta.get("source")
        inferred = {"th06": "original", "synthetic": "synthetic"}.get(source, "unknown")
        explicit = self.meta.get("data_kind", inferred)
        if explicit not in ("original", "synthetic", "unknown") or explicit != inferred:
            raise ValueError(f"{self.id}: data_kind 与 source 不一致")
        return explicit

    @property
    def laser_intent_mix(self) -> dict[str, float] | None:
        value = self.meta.get("laser_intent_mix")
        if "laser_intent_mix" not in self.meta:
            return None
        keys = {"follow", "anchor", "free"}
        if not isinstance(value, dict) or set(value) != keys:
            raise ValueError(f"{self.id}: laser_intent_mix 须恰好包含 follow/anchor/free")
        if any(isinstance(v, bool) or not isinstance(v, (int, float)) for v in value.values()):
            raise ValueError(f"{self.id}: laser_intent_mix 必须是有限数值")
        try:
            vals = {k: float(value[k]) for k in keys}
        except (TypeError, ValueError) as exc:
            raise ValueError(f"{self.id}: laser_intent_mix 必须是有限数值") from exc
        total = sum(vals.values())
        if any(not math.isfinite(v) or v < 0 for v in vals.values()) or not math.isfinite(total) or total <= 0:
            raise ValueError(f"{self.id}: laser_intent_mix 必须非负、有限且和 > 0")
        return vals


@dataclass(frozen=True)
class EvalSpec:
    card: str
    ranks: tuple[int, ...]
    episodes: int


_SPECIALIST_FAMILIES = {"stagger", "corridor", "sweep", "aimed", "bars"}


def _standalone_specialist(meta: dict) -> bool:
    return meta.get("synthetic_kind") == "laser_specialist" and meta.get("generation_mode") == "standalone"


def _specialist_metadata_errors(card_id: str, meta: dict) -> list[str]:
    errors = []
    if not isinstance(meta.get("title"), str) or not meta.get("title", "").strip():
        errors.append("title须为非空字符串")
    if meta.get("source") != "synthetic" or meta.get("data_kind") != "synthetic":
        errors.append("须显式标记source/data_kind=synthetic")
    if meta.get("synthetic_kind") != "laser_specialist" or meta.get("generation_mode") != "standalone":
        errors.append("专项卡须标记synthetic_kind=laser_specialist且generation_mode=standalone")
    if meta.get("family") not in _SPECIALIST_FAMILIES:
        errors.append("family无效")
    if meta.get("layout_id") != card_id:
        errors.append("layout_id必须等于卡ID")
    if meta.get("split") not in ("train", "held-out"):
        errors.append("split须为train或held-out")
    if type(meta.get("contract_version")) is not int or meta.get("contract_version") != 1:
        errors.append("contract_version须为整数1")
    if meta.get("ranks") != [0, 3]:
        errors.append("ranks须为[0, 3]")
    if meta.get("marks") != [0]:
        errors.append("marks须为[0]")
    if type(meta.get("time_limit")) is not int or meta.get("time_limit") != 1800:
        errors.append("time_limit须为1800")
    tags = meta.get("tags")
    if not isinstance(tags, list) or any(not isinstance(tag, str) for tag in tags) or not {"laser", "specialist"}.issubset(set(tags)):
        errors.append("tags须包含laser和specialist")
    forged = ("base_card", "source_ref", "provenance", "mutation_id", "original_time_limit")
    for field in forged:
        if field in meta:
            errors.append(f"standalone专项卡禁止{field}")
    return [f"{card_id}: {error}" for error in errors]


def discover(cards_dir: str | Path | list[str | Path]) -> dict[str, Card]:
    """默认单目录保持旧池；合成卡仅在配置显式列出多个目录时加载。"""
    if isinstance(cards_dir, list):
        merged: dict[str, Card] = {}
        for root in cards_dir:
            found = discover(root)
            if duplicate := set(merged) & set(found):
                raise ValueError(f"卡 ID 重复：{sorted(duplicate)}")
            merged.update(found)
        return merged
    root = Path(cards_dir)
    if not root.is_dir():
        return {}
    out: dict[str, Card] = {}
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        if not any(d.glob("*.ecl")):
            continue
        meta_path = d / "meta.toml"
        meta = tomllib.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
        card = Card(id=d.name, path=d, meta=meta)
        card.laser_intent_mix  # Validate before compiling or constructing an environment.
        if _standalone_specialist(meta):
            errors = _specialist_metadata_errors(d.name, meta)
            if errors:
                raise ValueError("; ".join(errors))
        elif meta.get("synthetic_kind") == "laser_specialist":
            raise ValueError(f"{d.name}: 专项卡须使用generation_mode=standalone")
        elif card.data_kind == "synthetic" and not meta.get("base_card"):
            raise ValueError(f"{d.name}: 合成卡缺 base_card")
        out[d.name] = card
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


def source_ranges_overlap(a: str, b: str) -> bool:
    def ranges(text):
        filename, separator, tail = text.partition(':')
        if not separator:
            raise ValueError(f"无法解析source_ref: {text!r}")
        intervals = [(int(x), int(y or x)) for x, y in re.findall(r"(\d+)(?:-(\d+))?", tail)]
        if not filename or not intervals or any(x > y for x, y in intervals):
            raise ValueError(f"无法解析source_ref: {text!r}")
        return filename, intervals
    af, ar = ranges(a)
    bf, br = ranges(b)
    return af == bf and any(max(x, u) <= min(y, v) for x, y in ar for u, v in br)


def _synthetic_held_out(card: Card, cards: dict[str, Card], eval_ids: set[str]) -> bool:
    if card.data_kind != "synthetic":
        return False  # 原作历史划分保持不变；新增合成数据作更严格的血缘检查。
    if _standalone_specialist(card.meta):
        return card.meta.get("split") == "held-out"
    seen = set()
    current = card
    while current.meta.get("base_card") in cards:
        base_id = current.meta["base_card"]
        if base_id in eval_ids:
            return True
        if base_id in seen:
            raise ValueError(f"{card.id}: 合成卡血缘循环")
        seen.add(base_id)
        current = cards[base_id]
    reference = current.meta.get("provenance", {}).get("base_source_ref", current.meta.get("source_ref"))
    return bool(reference) and any(
        source_ranges_overlap(reference, cards[cid].meta["source_ref"])
        for cid in eval_ids if cid in cards and cards[cid].meta.get("source_ref")
    )


def train_starts(cards: dict[str, Card], eval_ids: set[str], ranks: list[int]) -> list[stg_rl.Start]:
    starts = [
        stg_rl.Start(image=cid, mark=int(mark), rank=r, weight=1.0)
        for cid, card in cards.items()
        if cid not in eval_ids and card.meta.get("base_card") not in eval_ids and not _synthetic_held_out(card, cards, eval_ids)
        for mark in card.meta.get("marks", [0])
        for r in training_ranks(card, ranks)
    ]
    if not starts:
        raise ValueError("没有可用的训练起点：卡池为空、全部划进了评测集，或 rank 全被 meta 过滤掉")
    return starts


def start_intent_mixes(cards: dict[str, Card], starts: list[stg_rl.Start], default: dict[str, float], enabled: bool = False) -> list[dict[str, float]]:
    """Return one normalized intent mix per start, preserving start order."""
    if not enabled:
        return [dict(default) for _ in starts]
    out = []
    for start in starts:
        mix = cards[start.image].laser_intent_mix or default
        total = sum(mix.values())
        out.append({k: float(mix[k]) / total for k in ("follow", "anchor", "free")})
    return out


def card_manifest(cards: dict[str, Card]) -> dict[str, dict]:
    """run元数据映射；课程/episode的card_id可关联来源，不改变策略输入。"""
    return {cid: {"data_kind": card.data_kind, "source": card.meta.get("source"),
                  "base_card": card.meta.get("base_card"), "mutation_id": card.meta.get("mutation_id"),
                  **({key: card.meta[key] for key in ("synthetic_kind", "generation_mode", "family", "layout_id", "split", "contract_version") if key in card.meta}),
                  **({"laser_intent_mix": card.laser_intent_mix} if "laser_intent_mix" in card.meta else {})}
            for cid, card in cards.items()}
