"""按 split.json 原样摘录单元（spec §7.2 输入）：source.txt / unit.json / mapping-excerpt.md。

source.txt 的每一行 = 原文逐字 +（可选）`  //@ 注释`。原样性由测试押运：去掉 `//@` 之后的部分必须与原文同一行完全一致。
"""
from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import config
from . import mapping as M
from . import units as U
from .thecl import EclFile, Instr

ANNOT = "  //@ "
HEADER = "// ===== "
SECTION = "// ----- "

# 参数角色：弧度角的参数下标 / x 坐标的参数下标
_BULLET_ANGLES = {op: (6, 7) for op in U.BULLET_OPS}
ANGLE_ARGS: dict[str, tuple[int, ...]] = {
    **_BULLET_ANGLES,
    "move_velocity": (0,), "move_angular_velocity": (0,), "move_rand": (0, 1), "move_rand_in_bounds": (0, 1),
    "move_at_player": (0,), "move_dir_time_decelerate": (1,), "move_dir_time_decelerate_fast": (1,),
    "move_dir_time_accelerate": (1,), "move_dir_time_accelerate_fast": (1,), "shoot_offset_polar": (0,),
}
MAYBE_ANGLE_ARGS: dict[str, tuple[int, ...]] = {
    "set_float": (1,), "math_float_add": (2,), "math_float_sub": (2,), "set_float_rand_bound": (1,),
    "set_float_rand_bound_min": (1, 2), "cmp_float": (1,), "call": (2,),
    # f0 / f1 的量纲取决于后面 bullet_* 的 flags（mapping §5）：0x40/0x80/0x100 时 f0 是角、f1 是速度；
    # 0x10 时 f0 是加速度、f1 是角；0x20 时 f0 是速度增量、f1 是角增量。所以只标「若为角度」，不当确定角度。
    "bullet_effects": (4, 5),
}
X_ARGS: dict[str, tuple[int, ...]] = {
    "enemy_create": (1,), "enemy_create_mirror": (1,), "enemy_create_random": (1,), "enemy_create_mirror_random": (1,),
    "move_position": (0,), "move_position_time_linear": (1,), "move_position_time_decelerate": (1,),
    "move_position_time_decelerate_fast": (1,), "move_position_time_accelerate": (1,),
    "move_position_time_accelerate_fast": (1,), "move_bounds_set": (0, 2),
}


def _angle_note(v: float, strict: bool) -> str | None:
    """strict：参数位确定是角度。非 strict：变量赋值类，值可能是角度也可能是速度——
    BAM 近整数（π 的整分数）直接标；否则只要不是 0.05 的整倍数（速度 / 增量常见值）就标「若为角度」。"""
    if v <= -990 or abs(v) > 7.0:
        return None
    bam = U.rad_to_bam(v)
    note = f"{math.degrees(v):.4g}°={round(bam)}bam"
    if strict:
        return note
    if abs(v) < 0.01:
        return None
    if abs(bam - round(bam)) <= 0.05:
        return note
    if abs(v * 20 - round(v * 20)) < 1e-4:
        return None
    return "若为角度:" + note


def annotate(i: Instr) -> str:
    notes = [f"[{i.ranks}]"]
    for idx in X_ARGS.get(i.name, ()):
        v = U._float(i.args[idx]) if idx < len(i.args) else None
        if v is not None:
            notes.append(f"x{idx}={'随机' if v <= -990 else f'{v - 192:g}'}")
    for table, strict in ((ANGLE_ARGS, True), (MAYBE_ANGLE_ARGS, False)):
        for idx in table.get(i.name, ()):
            v = U._float(i.args[idx]) if idx < len(i.args) else None
            if v is not None and (n := _angle_note(v, strict)):
                notes.append(f"a{idx}={n}")
    if i.name == "bullet_effects":
        notes.append("f0/f1 量纲看 flags(§5)")
    if i.name in U.BULLET_OPS and i.args:
        sp = config.th06_config()["sprites"].get(i.args[0])
        if sp:
            notes.append(f"弹型→{sp['name']}={sp['shape']}")
    return ANNOT + " ".join(notes)


def _annotated_lines(ecl: EclFile, start: int, end: int) -> list[str]:
    by_line = {i.line: i for b in [*ecl.subs.values(), *ecl.timelines.values()] for i in b.instrs}
    out = []
    for n in range(start, end + 1):
        raw = ecl.lines[n - 1]
        out.append(raw + annotate(by_line[n]) if n in by_line else raw)
    return out


def strip_annotation(line: str) -> str:
    k = line.find(ANNOT)
    return line if k < 0 else line[:k]


@dataclass
class Unit:
    id: str
    stage: int
    kind: str  # wave | nonspell | spell
    source_file: str
    ranks: list[int]
    time_limit: int
    original_time_limit: int
    time_limit_origin: str
    subs: list[str]
    source_ref: str
    spell_key: str | None = None
    spell_name: str | None = None
    timeline_range: list[int] | None = None
    tail: int | None = None
    entry: str | None = None
    start_label: str | None = None
    parallel: list[str] = field(default_factory=list)
    skip: str | None = None
    note: str = ""
    used_instructions: list[str] = field(default_factory=list)
    examples: list[str] = field(default_factory=list)


EXAMPLES = {
    "wave": ["th06_s1_w01"],
    "nonspell": ["th06_s1_mb1", "th06_s1_b1"],
    "spell": ["th06_s1_b4"],
}


def _ref(ecl: EclFile, subs: list[str], tl: tuple[int, int] | None) -> str:
    parts = [f"{tl[0]}-{tl[1]}"] if tl else []
    parts += [f"{ecl.subs[s].start_line}-{ecl.subs[s].end_line}" for s in subs]
    return f"{Path(ecl.path).name}:" + ", ".join(parts)


def build_units(split: dict, ecl: EclFile, stage: int, loc: dict) -> list[tuple[Unit, str]]:
    """→ [(Unit, source.txt 文本)]。假定 split 已通过 split_check。"""
    out: list[tuple[Unit, str]] = []
    tl = U.timeline(ecl)
    default_ranks = [4, 4] if stage == 7 else [0, 3]
    for w in split.get("waves", []):
        ins = [i for i in tl.instrs if w["t_start"] <= i.time <= w["t_end"]]
        creates = [i for i in ins if i.name.startswith(("enemy_create", "dummy_create"))]
        subs = U.unit_closure(ecl, sorted({U.create_target(i) for i in creates}))
        first = min(i.line for i in ins)
        while first - 1 > tl.start_line + 1 and ecl.lines[first - 2].strip().startswith("+"):
            first -= 1
        last = max(i.line for i in ins)
        limit = U.OPENING_BUFFER + (w["t_end"] - w["t_start"]) + w.get("tail", 0)
        unit = Unit(id=w["id"], stage=stage, kind="wave", source_file=Path(ecl.path).name,
                    ranks=w.get("ranks", default_ranks), time_limit=U.clamp_time_limit(limit),
                    original_time_limit=limit, time_limit_origin="wave", subs=subs,
                    source_ref=_ref(ecl, subs, (first, last)), timeline_range=[w["t_start"], w["t_end"]],
                    tail=w.get("tail", 0), skip=w.get("skip"), note=w.get("note", ""))
        text = [f"{HEADER}单元 {unit.id}（波次）· {unit.source_file} =====",
                "// 行尾 `//@` 之后是摘录器加的注释（[生效难度] + 换算），`//@` 之前是原文逐字。",
                f"{SECTION}timeline 帧 {w['t_start']}–{w['t_end']}（行 {first}–{last}）-----",
                *_annotated_lines(ecl, first, last)]
        for s in subs:
            b = ecl.subs[s]
            text += ["", f"{SECTION}sub {s}（行 {b.start_line}–{b.end_line}）-----",
                     *_annotated_lines(ecl, b.start_line, b.end_line)]
        out.append((unit, "\n".join(text) + "\n"))
    for boss in split.get("bosses", []):
        for p in boss["phases"]:
            roots = [p["entry"], *(p.get("parallel") or [])]
            subs = U.unit_closure(ecl, roots)
            key = p.get("spell_key")
            unit = Unit(id=p["id"], stage=stage, kind=p["kind"], source_file=Path(ecl.path).name,
                        ranks=p["ranks"], time_limit=U.clamp_time_limit(p["time_limit"]),
                        original_time_limit=p["time_limit"], time_limit_origin=p["time_limit_origin"],
                        subs=subs, source_ref=_ref(ecl, subs, None), spell_key=key,
                        spell_name=loc.get(key) if key else None, entry=p["entry"],
                        start_label=p.get("start_label"), parallel=list(p.get("parallel") or []),
                        skip=p.get("skip"), note=p.get("note", ""))
            text = [f"{HEADER}单元 {unit.id}（{'符卡' if unit.kind == 'spell' else '非符'}）· {unit.source_file} =====",
                    "// 行尾 `//@` 之后是摘录器加的注释（[生效难度] + 换算），`//@` 之前是原文逐字。",
                    f"// 入口 {p['entry']}" + (f"，从 {p['start_label']} 起" if p.get("start_label") else "")
                    + (f"；并行 {p['parallel']}" if p.get("parallel") else "")
                    + (f"；符卡「{unit.spell_name}」" if unit.spell_name else "")]
            for s in subs:
                b = ecl.subs[s]
                text += ["", f"{SECTION}sub {s}（行 {b.start_line}–{b.end_line}）-----",
                         *_annotated_lines(ecl, b.start_line, b.end_line)]
            out.append((unit, "\n".join(text) + "\n"))
    for unit, _ in out:
        names = {i.name for i in U.instrs_of(ecl, unit.subs)}
        if unit.kind == "wave":
            names |= {i.name for i in tl.instrs if unit.timeline_range[0] <= i.time <= unit.timeline_range[1]}
        unit.used_instructions = sorted(names)
        unit.examples = [str(config.TH06_DIR / "examples" / e) for e in EXAMPLES[unit.kind]]
    return out


def builtins_cheatsheet(reference_md: Path) -> str:
    """把 `docs/ecl-lang/7-reference.md` 压成「签名 + 一句话」的速查（6.3k → 2.2k token）。

    worker 每次整篇读参考手册都会把 6k token 压进上下文、并被后续每一步重发；
    真正需要反复查的只是内建函数的签名。拿不准语义时再去 grep 原文。
    """
    import re

    lines = ["# 内建函数签名速查（自动生成自 docs/ecl-lang/7-reference.md）",
             "# 只有签名 + 一句话；要完整语义去 grep 原手册，别整篇 read。", ""]
    for ln in Path(reference_md).read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- (`[^`]+`)\s*(?:—\s*(.*))?$", ln.strip())
        if m:
            desc = (m.group(2) or "").split("；")[0].split(";")[0][:70]
            lines.append(f"- {m.group(1)}" + (f" — {desc}" if desc else ""))
    return "\n".join(lines) + "\n"


def write_unit(unit: Unit, source_text: str, units_dir: Path, mapping_text: str) -> Path:
    d = units_dir / unit.id
    (d / "out").mkdir(parents=True, exist_ok=True)
    (d / "source.txt").write_text(source_text, encoding="utf-8")
    (d / "unit.json").write_text(json.dumps(asdict(unit), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (d / "mapping-excerpt.md").write_text(M.excerpt(mapping_text, set(unit.used_instructions)), encoding="utf-8")
    try:   # 没配 stg-engine 路径（如单测夹具）就跳过速查表，不影响摘录本身
        ref = config.engine_dir() / "docs" / "ecl-lang" / "7-reference.md"
    except Exception:
        ref = None
    if ref is not None and ref.exists():
        (d / "builtins.md").write_text(builtins_cheatsheet(ref), encoding="utf-8")
    return d
