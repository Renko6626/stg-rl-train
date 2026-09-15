"""split.json 机械校验（spec §7.1）。返回错误清单，空 = 通过。

split.json 形状（与 contracts/split.md 一致）：

    {"stage": 1,
     "waves": [{"id", "t_start", "t_end", "tail", "ranks"?, "skip"?, "note"?}],
     "bosses": [{"spawn_t", "spawn_sub", "phases": [
         {"id", "kind": "nonspell"|"spell", "entry", "start_label"?, "parallel"?, "ranks",
          "time_limit", "time_limit_origin": "timer"|"estimated", "timer_sub"?, "hp_threshold"?,
          "spell_key"?, "skip"?, "note"?}]}]}
"""
from __future__ import annotations

import re

from . import units as U
from .thecl import EclFile

_REL_LABEL = re.compile(r"^\+\d+$")


def _ranks_ok(r, stage: int) -> str | None:
    if not (isinstance(r, list) and len(r) == 2 and all(isinstance(x, int) for x in r)):
        return "ranks 必须是 [lo, hi] 两个整数"
    lo, hi = r
    allowed = (4, 4) if stage == 7 else (0, 3)
    if not (allowed[0] <= lo <= hi <= allowed[1]):
        return f"ranks {r} 越界（Stage {stage} 允许 {list(allowed)} 内的连续区间）"
    return None


def _id_ok(uid, stage: int, letter: str) -> str | None:
    m = U.ID_RE.match(uid) if isinstance(uid, str) else None
    if not m:
        return f"id {uid!r} 不合 th06_s<关>_<w|mb|b><序号>"
    if int(m.group(1)) != stage:
        return f"id {uid} 的关卡号与 stage {stage} 不符"
    if m.group(2) != letter:
        return f"id {uid} 的类型应为 {letter}"
    return None


def _check_skip(errs: list[str], uid: str, item: dict, ecl: EclFile, subs: list[str], cfg: dict | None) -> None:
    found = U.skip_reasons(ecl, subs, cfg)
    declared = item.get("skip")
    if found and not declared:
        errs.append(f"{uid}: 闭包含 {'/'.join(found)}，必须标 skip")
    if declared and not found:
        errs.append(f"{uid}: 标了 skip={declared!r}，但机械检查没发现激光/不可转 ex_ins/对话")


def check(split: dict, ecl: EclFile, stage: int, loc: dict, cfg: dict | None = None) -> list[str]:
    errs: list[str] = []
    if split.get("stage") != stage:
        errs.append(f"stage 应为 {stage}")
    ids: set[str] = set()

    def claim(uid) -> None:
        if uid in ids:
            errs.append(f"id {uid} 重复")
        ids.add(uid)

    bosses = U.boss_subs(ecl)
    creates = U.timeline_creates(ecl)
    boss_creates = [i for i in creates if U.create_target(i) in bosses]
    minion_creates = [i for i in creates if U.create_target(i) not in bosses]
    dialogue = [i for i in U.timeline(ecl).instrs if i.name in U.DIALOGUE_OPS]

    # ── 波次 ──
    waves = split.get("waves", [])
    spans = []
    for w in waves:
        uid = w.get("id")
        claim(uid)
        if e := _id_ok(uid, stage, "w"):
            errs.append(e)
        ts, te, tail = w.get("t_start"), w.get("t_end"), w.get("tail", 0)
        if not all(isinstance(v, int) for v in (ts, te, tail)) or ts > te or tail < 0:
            errs.append(f"{uid}: t_start ≤ t_end 且 tail ≥ 0，均为整数")
            continue
        if (e := _ranks_ok(w.get("ranks", [4, 4] if stage == 7 else [0, 3]), stage)):
            errs.append(f"{uid}: {e}")
        limit = U.OPENING_BUFFER + (te - ts) + tail
        if limit > U.MAX_TIME_LIMIT:
            errs.append(f"{uid}: 120 + (t_end − t_start) + tail = {limit} > {U.MAX_TIME_LIMIT}，拆成更小的波")
        inside = [i for i in minion_creates if ts <= i.time <= te]
        if not inside:
            errs.append(f"{uid}: [{ts}, {te}] 内没有出怪")
        if any(ts <= i.time <= te for i in dialogue):
            errs.append(f"{uid}: 波次范围内有对话（read_msg/wait_msg），把对话排除在外")
        if any(ts <= i.time <= te for i in boss_creates):
            errs.append(f"{uid}: 波次范围内有 boss 登场")
        _check_skip(errs, uid, w, ecl, U.unit_closure(ecl, sorted({U.create_target(i) for i in inside})), cfg)
        spans.append((ts, te, uid))
    spans.sort()
    for (a0, a1, au), (b0, b1, bu) in zip(spans, spans[1:]):
        if b0 <= a1:
            errs.append(f"波次 {au} [{a0},{a1}] 与 {bu} [{b0},{b1}] 重叠")
    for i in minion_creates:
        hit = [u for s, e, u in spans if s <= i.time <= e]
        if len(hit) != 1:
            errs.append(f"timeline 行 {i.line}（帧 {i.time} {U.create_target(i)}）落在 {len(hit)} 个波次里，应恰好 1 个")

    # ── boss ──
    covered_spell_subs: set[str] = set()
    boss_list = split.get("bosses", [])
    declared_spawns = {(b.get("spawn_t"), b.get("spawn_sub")) for b in boss_list}
    for i in boss_creates:
        if (i.time, U.create_target(i)) not in declared_spawns:
            errs.append(f"timeline 帧 {i.time} 的 boss 登场 {U.create_target(i)} 没有在 bosses 里声明")
    for b in boss_list:
        if (b.get("spawn_t"), b.get("spawn_sub")) not in {(i.time, U.create_target(i)) for i in boss_creates}:
            errs.append(f"boss spawn_t={b.get('spawn_t')} spawn_sub={b.get('spawn_sub')} 在 timeline 里找不到")
        for p in b.get("phases", []):
            uid = p.get("id")
            claim(uid)
            letter = "mb" if isinstance(uid, str) and "_mb" in uid else "b"
            if e := _id_ok(uid, stage, letter):
                errs.append(e)
            if (e := _ranks_ok(p.get("ranks"), stage)):
                errs.append(f"{uid}: {e}")
            entry = p.get("entry")
            parallel = p.get("parallel", []) or []
            roots = [entry, *parallel]
            missing = [s for s in roots if s not in ecl.subs]
            if missing:
                errs.append(f"{uid}: sub 不存在 {missing}")
                continue
            label = p.get("start_label")
            if label is not None and not _REL_LABEL.match(str(label)) and label not in ecl.subs[entry].labels:
                errs.append(f"{uid}: start_label {label!r} 既不是 +N 也不是 {entry} 里的标签")
            subs = U.unit_closure(ecl, roots)
            timer_subs = subs + ([p["timer_sub"]] if p.get("timer_sub") in ecl.subs else [])
            kind = p.get("kind")
            keys = U.spell_keys(ecl, subs)
            if kind == "spell":
                sk = p.get("spell_key")
                if sk not in loc:
                    errs.append(f"{uid}: spell_key {sk!r} 不在符卡名表里")
                if sk not in keys:
                    errs.append(f"{uid}: spell_key {sk!r} 不在闭包的 spellcard_start 里（闭包里有 {keys}）")
            elif kind == "nonspell":
                if keys:
                    errs.append(f"{uid}: 非符的闭包里有 spellcard_start {keys}")
            else:
                errs.append(f"{uid}: kind 必须是 nonspell 或 spell")
            tl, origin = p.get("time_limit"), p.get("time_limit_origin")
            thr = sorted({v for v, _ in U.timer_thresholds(ecl, timer_subs)})
            if not isinstance(tl, int) or tl <= 0:
                errs.append(f"{uid}: time_limit 必须是正整数")
            elif origin == "timer":
                if tl not in thr:
                    errs.append(f"{uid}: time_limit {tl} 不在原文 timer_callback_threshold {thr} 里"
                                "（阈值写在别的 sub 就用 timer_sub 指明）")
            elif origin == "estimated":
                if thr:
                    errs.append(f"{uid}: 原文有 timer_callback_threshold {thr}，不能标 estimated")
            else:
                errs.append(f"{uid}: time_limit_origin 必须是 timer 或 estimated")
            _check_skip(errs, uid, p, ecl, subs, cfg)
            covered_spell_subs.update(subs)
    for s in U.spellcard_subs(ecl):
        if s not in covered_spell_subs:
            errs.append(f"{s} 含 spellcard_start，但不在任何 phase 的闭包里")
    return errs


def main(argv: list[str] | None = None) -> int:
    """python -m stgtranscribe.split_check <stage> <split.json> —— 切分 worker 自检用。"""
    import argparse
    import json
    import sys
    from pathlib import Path

    from . import config
    from .thecl import parse_file

    ap = argparse.ArgumentParser(prog="python -m stgtranscribe.split_check")
    ap.add_argument("stage", type=int)
    ap.add_argument("split", type=Path)
    a = ap.parse_args(argv)
    try:
        split = json.loads(a.split.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"读不了 {a.split}：{e}")
        return 1
    errs = check(split, parse_file(config.stage_file(a.stage)), a.stage, U.localization())
    if errs:
        print(f"✘ {len(errs)} 条错误：")
        print("\n".join(f"- {e}" for e in errs))
        sys.stdout.flush()
        return 1
    n = len(split.get("waves", [])) + sum(len(b.get("phases", [])) for b in split.get("bosses", []))
    print(f"OK：{n} 个单元")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
