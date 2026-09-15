"""thecl（`thecl -g 6`）解码文本的解析器。

只认本仓实际出现的写法（2026-09-16 对 th06nc 7 个文件实测）：

- 块：`sub SubN()` / `timeline TimelineN()`，下一行 `{`，块尾 `}`。
- 时间标签：`+N: //绝对帧`——取 `//` 后的绝对帧（块内时间，从 0 起）。
- 难度前缀：行首 `!E` / `!NHL` / `!*` …，**粘滞**到下一个前缀；可叠写（`!L!*`，取最后一个）；
  每个块开头重置为全难度。
- 跳转标签：独占一行的 `名字:`，记录所在位置的块内时间。
- 注释：`// …` 独占一行，跳过。
- 指令：`名字(参数, …);`，参数保留原始记号（`3.0f` / `$I0` / `%F0` / `"Sub5"` / `#ff8080ff` / 标签名）。

认不出的非空行直接报错（带行号）——静默跳过一行等于摘录时漏一行原文。
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

RANK_ALL = "ENHL"

_BLOCK_RE = re.compile(r"^(sub|timeline)\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*$")
_TIME_RE = re.compile(r"^\+(\d+):\s*//\s*(\d+)\s*$")
_LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):\s*$")
_RANK_RE = re.compile(r"^!([A-Z*]+)")
_INSTR_RE = re.compile(r"^([a-z_][a-z_0-9]*)\((.*)\);\s*$")

# 引用别的 sub 的指令 → 引用种类（refs / closure 用）。参数下标 = 目标 sub 名所在位。
SUB_REFS: dict[str, tuple[str, int]] = {
    "call": ("call", 0),
    "call_lss": ("call", 0),
    "call_leq": ("call", 0),
    "call_equ": ("call", 0),
    "call_gre": ("call", 0),
    "call_geq": ("call", 0),
    "call_neq": ("call", 0),
    "death_callback_sub": ("death_callback", 0),
    "life_callback_sub": ("life_callback", 0),
    "timer_callback_sub": ("timer_callback", 0),
    "enemy_interrupt_set": ("interrupt", 0),
    "enemy_create": ("spawn", 0),
    "enemy_create_mirror": ("spawn", 0),
    "enemy_create_random": ("spawn", 0),
    "enemy_create_mirror_random": ("spawn", 0),
    "dummy_create": ("spawn", 0),
    "dummy_create_mirror": ("spawn", 0),
    "dummy_create_random": ("spawn", 0),
    "dummy_create_mirror_random": ("spawn", 0),
}


@dataclass(frozen=True)
class Instr:
    line: int  # 文件内 1 起行号
    time: int  # 块内绝对帧
    ranks: str  # RANK_ALL 的子序列，如 "HL"
    name: str
    args: tuple[str, ...]


@dataclass
class Block:
    kind: str  # "sub" | "timeline"
    name: str
    start_line: int  # 头行（`sub X()`）
    end_line: int  # 收尾 `}` 行
    instrs: list[Instr] = field(default_factory=list)
    labels: dict[str, tuple[int, int]] = field(default_factory=dict)  # 名 → (行号, 块内时间)


@dataclass
class EclFile:
    path: str
    lines: list[str]
    subs: dict[str, Block]
    timelines: dict[str, Block]

    def block(self, name: str) -> Block:
        return self.subs.get(name) or self.timelines[name]

    def block_text(self, name: str) -> str:
        """块原文（头行到收尾 `}`，逐字）。"""
        b = self.block(name)
        return "\n".join(self.lines[b.start_line - 1 : b.end_line])


def split_args(s: str) -> tuple[str, ...]:
    """按逗号切参数，引号内的逗号不切。"""
    out: list[str] = []
    cur: list[str] = []
    in_str = False
    for ch in s:
        if ch == '"':
            in_str = not in_str
        if ch == "," and not in_str:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail or out:
        out.append(tail)
    return tuple(out)


def _ranks(token: str) -> str:
    return RANK_ALL if token == "*" else "".join(c for c in RANK_ALL if c in token)


def parse(text: str, path: str = "") -> EclFile:
    lines = text.split("\n")
    subs: dict[str, Block] = {}
    timelines: dict[str, Block] = {}
    cur: Block | None = None
    time = 0
    ranks = RANK_ALL
    opened = False

    def err(n: int, msg: str) -> ValueError:
        return ValueError(f"{path or '<text>'} line {n}: {msg}: {lines[n - 1]!r}")

    for n, raw in enumerate(lines, start=1):
        s = raw.strip()
        if not s:
            continue
        if cur is None:
            m = _BLOCK_RE.match(s)
            if not m:
                raise err(n, "块外的非空行")
            cur = Block(kind=m.group(1), name=m.group(2), start_line=n, end_line=n)
            time, ranks, opened = 0, RANK_ALL, False
            continue
        if not opened:
            if s != "{":
                raise err(n, "块头后应为 {")
            opened = True
            continue
        if s == "}":
            cur.end_line = n
            (subs if cur.kind == "sub" else timelines)[cur.name] = cur
            cur = None
            continue
        if s.startswith("//"):
            continue
        m = _TIME_RE.match(s)
        if m:
            time = int(m.group(2))
            continue
        m = _LABEL_RE.match(s)
        if m:
            cur.labels[m.group(1)] = (n, time)
            continue
        body = s
        while True:
            m = _RANK_RE.match(body)
            if not m:
                break
            ranks = _ranks(m.group(1))
            body = body[m.end() :].lstrip()
        if not body:
            continue
        m = _INSTR_RE.match(body)
        if not m:
            raise err(n, "认不出的行")
        cur.instrs.append(Instr(line=n, time=time, ranks=ranks, name=m.group(1), args=split_args(m.group(2))))
    if cur is not None:
        raise ValueError(f"{path or '<text>'}: 块 {cur.name} 未闭合")
    return EclFile(path=path, lines=lines, subs=subs, timelines=timelines)


def parse_file(path: str | Path) -> EclFile:
    p = Path(path)
    return parse(p.read_text(encoding="utf-8"), str(p))


def unquote(tok: str) -> str | None:
    return tok[1:-1] if len(tok) >= 2 and tok[0] == tok[-1] == '"' else None


def refs(block: Block) -> list[tuple[str, str, Instr]]:
    """块内引用别的 sub 的指令：(种类, 目标 sub 名, 指令)。"""
    out = []
    for i in block.instrs:
        spec = SUB_REFS.get(i.name)
        if spec and len(i.args) > spec[1]:
            target = unquote(i.args[spec[1]])
            if target:
                out.append((spec[0], target, i))
    return out


def closure(ecl: EclFile, roots: list[str], kinds: set[str] | None = None) -> list[str]:
    """从 roots 出发沿引用可达的 sub（含 roots），按首次到达顺序。kinds=None 时跟全部引用种类。"""
    seen: list[str] = []
    stack = list(reversed(roots))
    while stack:
        name = stack.pop()
        if name in seen or name not in ecl.subs:
            continue
        seen.append(name)
        for kind, target, _ in reversed(refs(ecl.subs[name])):
            if kinds is None or kind in kinds:
                stack.append(target)
    return seen
