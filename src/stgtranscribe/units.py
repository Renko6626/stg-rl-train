"""单元模型的共用部分：id 规则、内容闭包、跳过判定、boss 识别、原文阈值、符卡名。"""
from __future__ import annotations

import json
import math
import re
from functools import lru_cache

from . import config
from .thecl import EclFile, Instr, closure, unquote

ID_RE = re.compile(r"^th06_s([1-7])_(w|mb|b)(\d{1,2})$")
OPENING_BUFFER = 120
MAX_TIME_LIMIT = 3000

# 单元内容闭包：同步调用 + 生成的使魔。回调 / 中断通向别的段，不跟。
CONTENT_KINDS = {"call", "spawn"}
BULLET_OPS = {
    "bullet_fan_aimed", "bullet_fan", "bullet_circle_aimed", "bullet_circle", "bullet_offset_circle_aimed",
    "bullet_offset_circle", "bullet_random_angle", "bullet_random_speed", "bullet_random",
}
DIALOGUE_OPS = {"read_msg", "wait_msg"}


def unit_closure(ecl: EclFile, roots: list[str]) -> list[str]:
    return closure(ecl, roots, kinds=CONTENT_KINDS)


def instrs_of(ecl: EclFile, subs: list[str]) -> list[Instr]:
    return [i for s in subs if s in ecl.subs for i in ecl.subs[s].instrs]


def skip_reasons(ecl: EclFile, subs: list[str], cfg: dict | None = None) -> list[str]:
    """机械判定：闭包里含激光 / 不可转的 ex_ins 编号 / 对话 → 返回原因列表（去重有序）。"""
    cfg = cfg or config.th06_config()
    skip_ins = set(cfg["skip"]["instructions"])
    skip_ex = set(int(x) for x in cfg["skip"]["ex_ins_ids"])
    out: list[str] = []
    for i in instrs_of(ecl, subs):
        if i.name in skip_ins:
            r = "laser"
        elif i.name in ("ex_ins_call", "ex_ins_repeat") and i.args and _int(i.args[0]) in skip_ex:
            r = f"ex_ins_{_int(i.args[0])}"
        elif i.name in DIALOGUE_OPS:
            r = "dialogue"
        else:
            continue
        if r not in out:
            out.append(r)
    return out


def _int(tok: str) -> int | None:
    try:
        return int(tok)
    except ValueError:
        return None


def _float(tok: str) -> float | None:
    t = tok[:-1] if tok.endswith("f") else tok
    try:
        return float(t)
    except ValueError:
        return None


def boss_subs(ecl: EclFile) -> set[str]:
    """call 闭包里出现 `boss_set(非负)` 的 sub（即登场后会成为 boss 的敌的入口）。"""
    direct = {n for n, b in ecl.subs.items() if any(i.name == "boss_set" and _int(i.args[0] or "-1") not in (None, -1)
                                                    and (_int(i.args[0]) or 0) >= 0 for i in b.instrs)}
    return {n for n in ecl.subs if direct.intersection(closure(ecl, [n], kinds={"call"}))}


def timeline(ecl: EclFile):
    return next(iter(ecl.timelines.values()))


def timeline_creates(ecl: EclFile) -> list[Instr]:
    return [i for i in timeline(ecl).instrs if i.name.startswith(("enemy_create", "dummy_create"))]


def create_target(i: Instr) -> str:
    return unquote(i.args[0]) or ""


def timer_thresholds(ecl: EclFile, subs: list[str]) -> list[tuple[int, str]]:
    """闭包内 `timer_callback_threshold(N>0)`：[(N, 生效难度)]。"""
    out = []
    for i in instrs_of(ecl, subs):
        if i.name == "timer_callback_threshold":
            v = _int(i.args[0])
            if v and v > 0:
                out.append((v, i.ranks))
    return out


def spell_keys(ecl: EclFile, subs: list[str]) -> list[str]:
    keys: list[str] = []
    for i in instrs_of(ecl, subs):
        if i.name == "spellcard_start" and len(i.args) >= 3:
            k = unquote(i.args[2])
            if k and k not in keys:
                keys.append(k)
    return keys


def spellcard_subs(ecl: EclFile) -> list[str]:
    return [n for n, b in ecl.subs.items() if any(i.name == "spellcard_start" for i in b.instrs)]


@lru_cache(maxsize=1)
def localization() -> dict:
    p = config.decoded_dir() / "text" / "localization-by-language" / "ja.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def rank_letters(ranks: list[int]) -> str:
    lo, hi = ranks
    return "".join("ENHLX"[r] for r in range(lo, hi + 1))


def rad_to_bam(rad: float) -> float:
    return rad * 65536.0 / (2.0 * math.pi)


def clamp_time_limit(t: int) -> int:
    return min(int(t), MAX_TIME_LIMIT)
