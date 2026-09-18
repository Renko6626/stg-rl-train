"""卡的弹量画像：每张卡 × 每档的弹峰值与场上均值。

用途是**策展**，不是验收：原作里确实有整段不发弹的波次（第 1 关几处发弹带 `!L` 粘滞前缀只在 Lunatic 生效、
第 2 关的「妖精雨」Sub7 全程只有体碰），这些卡忠实但在训练档下没有弹幕。
所以这里只分档 + 标记，不判 FAIL；由 `cards.py` / 评测划分决定用不用。

判据：`峰值 ≤ EMPTY_PEAK` 视为「空」——放进评测集就是白送一张满分卡。
"""
from __future__ import annotations

EMPTY_PEAK = 10
BUCKETS = ((0, "空"), (60, "稀"), (200, "中"), (10 ** 9, "密"))


def bucket(mean: float) -> str:
    if mean <= 5:
        return "空"
    for hi, name in BUCKETS[1:]:
        if mean < hi:
            return name
    return "密"


def low(rows: list[dict], rank: int, min_peak: int = EMPTY_PEAK) -> list[dict]:
    """某一档下弹量过低的卡（默认阈值 = 空卡判据）。"""
    return [r for r in rows if r["rank"] == rank and r["peak"] <= min_peak]


def render(rows: list[dict], rank: int) -> str:
    sel = sorted((r for r in rows if r["rank"] == rank), key=lambda r: -r["mean"])
    lines = [f"{'卡':16}{'峰值':>7}{'场上均值':>10}{'档':>5}"]
    for r in sel:
        lines.append(f"{r['id']:16}{r['peak']:7}{r['mean']:10.1f}{bucket(r['mean']):>5}")
    return "\n".join(lines)
