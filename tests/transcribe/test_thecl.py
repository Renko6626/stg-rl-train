"""thecl 文本解析器。合成夹具为手写格式样例（不含原作内容）；真数据测试缺本地原文即 skip。"""
import re

import pytest

from stgtranscribe import config
from stgtranscribe.thecl import closure, parse, parse_file, refs

SAMPLE = """
sub Sub0()
{
    enemy_set_hitbox(28.0f, 28.0f, 32.0f);
!E    bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.0f, 4);
!HL    bullet_fan_aimed(0, 6, 3, 1, 3.0f, 0.0f, 0.0f, 0.2f, 4);
!*    call("Sub1", 2, 0.5f);
+40: //40
    set_int($I4, 3);
Sub0_52:
+10: //50
    move_speed(%F0);
    jump_dec(40, Sub0_52, $I4);
+100: //150
!L!*    enemy_delete(0);
}

sub Sub1()
{
    death_callback_sub("Sub2");
    life_callback_sub("Sub2");
    ret();
}

sub Sub2()
{
    // a comment line
    effect_particle(17, 6, #ff8080ff);
    spellcard_start(2, -1, "ST_X, with comma");
}

sub Sub3()
{
    ret();
}

timeline Timeline0()
{
+100: //100
    enemy_create("Sub0", 60.0f, -32.0f, 0.0f, 8, -1, 300);
+16: //116
    enemy_create_mirror("Sub3", 324.0f, -32.0f, 0.0f, 32, -1, 300);
}
"""


@pytest.fixture
def ecl():
    return parse(SAMPLE, "sample.ecl.txt")


def test_blocks(ecl):
    assert list(ecl.subs) == ["Sub0", "Sub1", "Sub2", "Sub3"]
    assert list(ecl.timelines) == ["Timeline0"]


def test_times_and_sticky_ranks(ecl):
    ins = ecl.subs["Sub0"].instrs
    assert [(i.name, i.time, i.ranks) for i in ins] == [
        ("enemy_set_hitbox", 0, "ENHL"),
        ("bullet_fan_aimed", 0, "E"),
        ("bullet_fan_aimed", 0, "HL"),
        ("call", 0, "ENHL"),
        ("set_int", 40, "ENHL"),
        ("move_speed", 50, "ENHL"),
        ("jump_dec", 50, "ENHL"),
        ("enemy_delete", 150, "ENHL"),  # !L!* 叠写取最后一个
    ]


def test_ranks_reset_per_block():
    e = parse("sub A()\n{\n!H    ret();\n}\nsub B()\n{\n    ret();\n}\n")
    assert e.subs["B"].instrs[0].ranks == "ENHL"


def test_labels_record_time_at_position(ecl):
    line, time = ecl.subs["Sub0"].labels["Sub0_52"]
    assert time == 40
    assert ecl.lines[line - 1] == "Sub0_52:"


def test_args_keep_raw_tokens(ecl):
    call = ecl.subs["Sub0"].instrs[3]
    assert call.args == ('"Sub1"', "2", "0.5f")
    sp = ecl.subs["Sub2"].instrs[1]
    assert sp.args == ("2", "-1", '"ST_X, with comma"')
    assert ecl.subs["Sub2"].instrs[0].args == ("17", "6", "#ff8080ff")


def test_instr_line_numbers_point_at_source(ecl):
    for b in [*ecl.subs.values(), *ecl.timelines.values()]:
        for i in b.instrs:
            assert f"{i.name}(" in ecl.lines[i.line - 1]


def test_block_text_is_verbatim(ecl):
    b = ecl.subs["Sub1"]
    text = ecl.block_text("Sub1")
    assert text.splitlines()[0] == "sub Sub1()"
    assert text.splitlines()[-1] == "}"
    assert text == "\n".join(ecl.lines[b.start_line - 1 : b.end_line])


def test_timeline(ecl):
    t = ecl.timelines["Timeline0"]
    assert [(i.name, i.time, i.args[0]) for i in t.instrs] == [
        ("enemy_create", 100, '"Sub0"'),
        ("enemy_create_mirror", 116, '"Sub3"'),
    ]


def test_refs_and_closure(ecl):
    assert [(k, t) for k, t, _ in refs(ecl.subs["Sub0"])] == [("call", "Sub1")]
    assert sorted((k, t) for k, t, _ in refs(ecl.subs["Sub1"])) == [
        ("death_callback", "Sub2"),
        ("life_callback", "Sub2"),
    ]
    assert closure(ecl, ["Sub0"]) == ["Sub0", "Sub1", "Sub2"]
    assert closure(ecl, ["Sub3"]) == ["Sub3"]


def test_unknown_line_is_an_error():
    with pytest.raises(ValueError, match="line 3"):
        parse("sub A()\n{\n    what is this\n}\n")


# ── 真数据（本地 renkolab 原文；CI 上 skip）──────────────────────────────────────

INSTR_RE = re.compile(r"^(?:![A-Z*]+)*\s+[a-z_0-9]+\(.*\);\s*$")


@pytest.mark.skipif(not config.ecl_files(), reason="本地没有 th06nc 解码原文")
def test_real_files_parse_completely():
    files = config.ecl_files()
    assert len(files) == 7
    for f in files:
        e = parse_file(f)
        n_lines = sum(1 for ln in e.lines if INSTR_RE.match(ln))
        n_parsed = sum(len(b.instrs) for b in [*e.subs.values(), *e.timelines.values()])
        assert n_parsed == n_lines, f.name
        assert len(e.timelines) == 1, f.name


@pytest.mark.skipif(not config.ecl_files(), reason="本地没有 th06nc 解码原文")
def test_real_stage1_counts():
    e = parse_file(config.stage_file(1))
    assert len(e.subs) == 38
    tl = next(iter(e.timelines.values()))
    assert sum(1 for i in tl.instrs if i.name.startswith("enemy_create")) == 224
