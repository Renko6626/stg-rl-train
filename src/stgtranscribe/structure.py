"""给切分 dsh 看的结构摘要 structure.md（spec §7.1 输入）。"""
from __future__ import annotations

from . import units as U
from .thecl import EclFile, refs, unquote

GAP_MARK = 100  # 出怪间隙 ≥ 该帧数时在摘要里标一行分隔


def _x(tok: str) -> str:
    v = U._float(tok)
    if v is None:
        return tok
    if v <= -990:
        return "随机"
    return f"{v - 192:g}"


def timeline_section(ecl: EclFile, bosses: set[str]) -> list[str]:
    tl = U.timeline(ecl)
    out = [f"## timeline（{tl.name}，行 {tl.start_line}–{tl.end_line}）", "",
           "帧 = 块内绝对帧。x 已换算成我方坐标。BOSS = 该 sub 的 call 闭包里有 boss_set。", "",
           "| 帧 | 指令 | sub | x | y | 难度 | 行 | 备注 |", "|---|---|---|---|---|---|---|---|"]
    prev_t = None
    for i in tl.instrs:
        if prev_t is not None and i.time - prev_t >= GAP_MARK:
            out.append(f"| ↓ 间隙 {i.time - prev_t} 帧 | | | | | | | |")
        prev_t = i.time
        if i.name.startswith(("enemy_create", "dummy_create")):
            sub = U.create_target(i)
            note = []
            if "mirror" in i.name:
                note.append("镜像")
            if "random" in i.name:
                note.append("随机位置")
            if sub in bosses:
                note.append("**BOSS**")
            out.append(f"| {i.time} | {i.name} | {sub} | {_x(i.args[1])} | {i.args[2]} | {i.ranks} | {i.line} | {' '.join(note)} |")
        else:
            out.append(f"| {i.time} | {i.name} | | | | {i.ranks} | {i.line} | {', '.join(i.args)} |")
    return out


def sub_section(ecl: EclFile, bosses: set[str], loc: dict) -> list[str]:
    out = ["## sub 一览", "",
           "| sub | 行 | 末帧 | 发弹 | 标签 |", "|---|---|---|---|---|"]
    for name, b in ecl.subs.items():
        tags: list[str] = []
        n_bullets = sum(1 for i in b.instrs if i.name in U.BULLET_OPS)
        if name in bosses:
            tags.append("BOSS")
        for kind, target, i in refs(b):
            thr = ""
            if kind in ("life_callback", "timer_callback"):
                thr_name = "life_callback_threshold" if kind == "life_callback" else "timer_callback_threshold"
                thrs = [f"{j.args[0]}[{j.ranks}]" for j in b.instrs if j.name == thr_name]
                thr = f" 阈值 {','.join(thrs)}" if thrs else ""
            tags.append(f"{kind}→{target}[{i.ranks}]{thr}")
        for i in b.instrs:
            if i.name == "spellcard_start":
                key = unquote(i.args[2]) or ""
                tags.append(f"符卡 {key}「{loc.get(key, '?')}」id {i.args[1]}[{i.ranks}]")
            elif i.name == "boss_set":
                tags.append(f"boss_set({i.args[0]})")
            elif i.name == "spellcard_flag_timeout" and i.args[0] != "0":
                tags.append("耐久卡")
            elif i.name == "life_callback_threshold" and i.args[0] == "0":
                tags.append("life_callback_threshold(0)")
        reasons = U.skip_reasons(ecl, [name])
        if reasons:
            tags.append("**含 " + "/".join(reasons) + "**")
        end = max((i.time for i in b.instrs), default=0)
        out.append(f"| {name} | {b.start_line}–{b.end_line} | {end} | {n_bullets} | {'; '.join(tags)} |")
    return out


def render(ecl: EclFile, stage: int, loc: dict | None = None) -> str:
    loc = U.localization() if loc is None else loc
    bosses = U.boss_subs(ecl)
    head = [f"# 结构摘要：Stage {stage}（{ecl.path}）", "",
            "由 `stgtranscribe.structure` 生成。原文逐字在上面的文件里，这里只列结构。", ""]
    return "\n".join(head + timeline_section(ecl, bosses) + [""] + sub_section(ecl, bosses, loc)) + "\n"
