"""结构摘要 / split 校验 / 摘录。合成夹具为手写格式样例（不含原作内容）。"""
import copy
import json

import pytest

from stgtranscribe import split_check, structure
from stgtranscribe import extract as X
from stgtranscribe import units as U
from stgtranscribe.thecl import parse

CFG = {"skip": {"instructions": ["laser_create"], "ex_ins_ids": [0]},
       "sprites": {"0": {"th06": "PELLET", "shape": 128, "name": "BULLET"}}}

SAMPLE = """
sub Sub0()
{
    move_velocity(1.5707964f, 2.0f);
    bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.09817477f, 4);
+500: //500
    enemy_delete(0);
}

sub Sub1()
{
    laser_create(0, 6, 0.3926991f, 0.0f, 0.0f, 500.0f, 500.0f, 32.0f, 30, 120, 16, 30, 14, 0);
}

sub Sub2()
{
    boss_set(0);
    move_position(192.0f, -32.0f, 0.0f);
    timer_callback_threshold(1200);
    timer_callback_sub("Sub3");
    life_callback_sub("Sub4");
+60: //60
    call("Sub5", 0, 0.0f);
}

sub Sub3()
{
!E    spellcard_start(2, -1, "ST_KEY_A");
!NHL    spellcard_start(2, 1, "ST_KEY_A");
!*    timer_callback_threshold(1500);
    call("Sub1", 0, 0.0f);
}

sub Sub4()
{
!E    spellcard_start(2, -1, "ST_KEY_B");
!*    ret();
}

sub Sub5()
{
Sub5_0:
+10: //10
    bullet_circle(0, 6, 8, 1, 2.0f, 0.0f, 0.0f, 0.0f, 4);
    jump(0, Sub5_0);
}

timeline Timeline0()
{
+100: //100
    enemy_create("Sub0", 60.0f, -32.0f, 0.0f, 8, -1, 300);
+20: //120
    enemy_create_mirror("Sub0", 324.0f, -32.0f, 0.0f, 8, -1, 300);
+400: //520
    enemy_create("Sub1", 100.0f, -32.0f, 0.0f, 8, -1, 300);
+300: //820
    read_msg(0);
+10: //830
    enemy_create("Sub2", 0.0f, 0.0f, 0.0f, 6000, -2, 100000);
}
"""

LOC = {"ST_KEY_A": "テスト符「甲」", "ST_KEY_B": "テスト符「乙」"}

GOOD = {
    "stage": 1,
    "waves": [
        {"id": "th06_s1_w01", "t_start": 100, "t_end": 120, "tail": 300},
        {"id": "th06_s1_w02", "t_start": 520, "t_end": 520, "tail": 200, "skip": "laser"},
    ],
    "bosses": [{"spawn_t": 830, "spawn_sub": "Sub2", "phases": [
        {"id": "th06_s1_b1", "kind": "nonspell", "entry": "Sub2", "start_label": "+60", "ranks": [0, 3],
         "time_limit": 1200, "time_limit_origin": "timer"},
        {"id": "th06_s1_b2", "kind": "spell", "entry": "Sub3", "ranks": [0, 3], "time_limit": 1500,
         "time_limit_origin": "timer", "spell_key": "ST_KEY_A", "skip": "laser"},
        {"id": "th06_s1_b3", "kind": "spell", "entry": "Sub4", "ranks": [0, 0], "time_limit": 900,
         "time_limit_origin": "estimated", "spell_key": "ST_KEY_B"},
    ]}],
}


@pytest.fixture
def ecl():
    return parse(SAMPLE, "/tmp/ecldata1.ecl.txt")


def errs(ecl, split):
    return split_check.check(split, ecl, 1, LOC, CFG)


def test_good_split_passes(ecl):
    assert errs(ecl, GOOD) == []


def mutate(fn):
    s = copy.deepcopy(GOOD)
    fn(s)
    return s


@pytest.mark.parametrize("fn, needle", [
    (lambda s: s.update(stage=2), "stage 应为 1"),
    (lambda s: s["waves"][0].update(id="th06_s1_x1"), "不合"),
    (lambda s: s["waves"][1].update(id="th06_s1_w01"), "重复"),
    (lambda s: s["waves"][0].update(t_end=110), "落在 0 个波次"),
    (lambda s: s["waves"][0].update(tail=2900), "> 3000"),
    (lambda s: s["waves"][1].update(t_start=100), "重叠"),
    (lambda s: s["waves"][1].pop("skip"), "必须标 skip"),
    (lambda s: s["waves"][0].update(skip="laser"), "机械检查没发现"),
    (lambda s: s["waves"][1].update(t_end=820), "对话"),
    (lambda s: s["bosses"][0].update(spawn_t=831), "找不到"),
    (lambda s: s["bosses"][0]["phases"][0].update(entry="Sub99"), "不存在"),
    (lambda s: s["bosses"][0]["phases"][0].update(start_label="Nope"), "start_label"),
    (lambda s: s["bosses"][0]["phases"][0].update(time_limit=1300), "不在原文"),
    (lambda s: s["bosses"][0]["phases"][2].update(time_limit_origin="timer"), "不在原文"),
    (lambda s: s["bosses"][0]["phases"][0].update(time_limit_origin="estimated"), "不能标 estimated"),
    (lambda s: s["bosses"][0]["phases"][1].update(spell_key="ST_NOPE"), "spell_key"),
    (lambda s: s["bosses"][0]["phases"][0].update(kind="spell", spell_key="ST_KEY_A"), "不在闭包"),
    (lambda s: s["bosses"][0]["phases"][1].update(kind="nonspell"), "非符的闭包"),
    (lambda s: s["bosses"][0]["phases"][2].update(ranks=[0, 5]), "越界"),
    (lambda s: s["bosses"][0]["phases"][2].update(ranks=[0]), "[lo, hi]"),
    (lambda s: s["bosses"][0]["phases"].pop(2), "Sub4 含 spellcard_start"),
    (lambda s: s["bosses"][0]["phases"][1].pop("skip"), "必须标 skip"),
])
def test_each_rule_has_a_negative(ecl, fn, needle):
    found = errs(ecl, mutate(fn))
    assert any(needle in e for e in found), found


def test_boss_subs_and_structure_render(ecl):
    assert U.boss_subs(ecl) == {"Sub2"}
    md = structure.render(ecl, 1, LOC)
    assert "**BOSS**" in md
    assert "テスト符「甲」" in md
    assert "间隙 400" in md
    assert "**含 laser**" in md


def test_extract_units_are_verbatim_and_annotated(ecl, monkeypatch):
    monkeypatch.setattr("stgtranscribe.config.th06_config", lambda: CFG)
    units = X.build_units(GOOD, ecl, 1, LOC)
    by_id = {u.id: (u, t) for u, t in units}
    assert set(by_id) == {"th06_s1_w01", "th06_s1_w02", "th06_s1_b1", "th06_s1_b2", "th06_s1_b3"}
    w, wt = by_id["th06_s1_w01"]
    assert w.time_limit == 120 + 20 + 300 and w.kind == "wave"
    assert w.subs == ["Sub0"]
    b1, bt = by_id["th06_s1_b1"]
    assert b1.subs == ["Sub2", "Sub5"]  # 回调目标不进内容闭包
    assert b1.time_limit == 1200 and "enemy_delete" not in b1.used_instructions
    b2, _ = by_id["th06_s1_b2"]
    assert b2.spell_name == "テスト符「甲」" and b2.skip == "laser"
    originals = set(ecl.lines)
    for _, text in units:
        for line in text.splitlines():
            if line.startswith((X.HEADER, X.SECTION, "// ")) or not line.strip():
                continue
            assert X.strip_annotation(line) in originals, line
    assert "x1=-132" in wt  # enemy_create x 换算
    assert "a7=5.625°=1024bam" in wt  # bullet 角度：π/32 = 65536/64
    assert "弹型→BULLET=128" in wt
    assert "[ENHL]" in wt


def test_write_unit(tmp_path, ecl, monkeypatch):
    monkeypatch.setattr("stgtranscribe.config.th06_config", lambda: CFG)
    unit, text = X.build_units(GOOD, ecl, 1, LOC)[0]
    mapping = "## 索引\n\n| `move_velocity` | translate | §7 |\n\n## §0 口径\nA\n## §7 移动\nB\n"
    d = X.write_unit(unit, text, tmp_path, mapping)
    assert (d / "out").is_dir()
    assert json.loads((d / "unit.json").read_text())["id"] == "th06_s1_w01"
    ex = (d / "mapping-excerpt.md").read_text()
    assert "## §7 移动" in ex and "§0 口径" in ex
