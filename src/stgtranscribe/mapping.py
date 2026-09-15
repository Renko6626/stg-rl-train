"""mapping.md 的机器读取：索引表、按节切分、给单元拼摘录（spec §6「给 worker 裁剪」）。"""
from __future__ import annotations

import re

DISPOSITIONS = {"translate", "drop", "skip-unit"}

# 每个单元都要读的节：口径、全局换算、执行模型、弹型颜色、卡外壳模板。
ALWAYS = ["§0", "§1", "§2", "§3", "§13"]

_ROW_RE = re.compile(r"^\|\s*`([a-z_0-9]+)`\s*\|\s*([a-z-]+)\s*\|\s*(§\d+)\s*\|\s*$")
_HEAD_RE = re.compile(r"^## (§\d+)\b")


def load_index(text: str) -> dict[str, tuple[str, str]]:
    """索引表：指令名 → (处置, 节号)。"""
    out: dict[str, tuple[str, str]] = {}
    for line in text.splitlines():
        m = _ROW_RE.match(line)
        if m:
            out[m.group(1)] = (m.group(2), m.group(3))
    return out


def sections(text: str) -> dict[str, str]:
    """`## §N …` 起到下一个 `## ` 前的全文，键为 `§N`。"""
    out: dict[str, str] = {}
    cur: str | None = None
    buf: list[str] = []
    for line in text.splitlines():
        if line.startswith("## "):
            if cur is not None:
                out[cur] = "\n".join(buf).rstrip() + "\n"
            m = _HEAD_RE.match(line)
            cur = m.group(1) if m else None
            buf = [line]
        elif cur is not None:
            buf.append(line)
    if cur is not None:
        out[cur] = "\n".join(buf).rstrip() + "\n"
    return out


def excerpt(text: str, names: set[str]) -> str:
    """单元用到的指令 → 摘录：索引行 + 必读节 + 这些指令所在的节（按节号序）。"""
    idx = load_index(text)
    secs = sections(text)
    need = set(ALWAYS)
    rows = []
    unknown = []
    for n in sorted(names):
        if n in idx:
            disp, sec = idx[n]
            need.add(sec)
            rows.append(f"| `{n}` | {disp} | {sec} |")
        else:
            unknown.append(n)
    parts = [
        "# 对照表摘录（本单元用到的指令）\n",
        "完整版：`transcribe/th06/mapping.md`。以下只含本单元需要的节。\n",
        "| 指令 | 处置 | 节 |\n|---|---|---|\n" + "\n".join(rows) + "\n",
    ]
    if unknown:
        parts.append("⚠️ 对照表里没有这些指令（report 里写 blocked）：" + ", ".join(f"`{u}`" for u in unknown) + "\n")
    for sec in sorted(need, key=lambda s: int(s[1:])):
        if sec in secs:
            parts.append(secs[sec])
    return "\n".join(parts)
