"""worker 的「疑似普遍问题」便笺：收集 / 去重 / 标记已分诊。"""
import pytest

from stgtranscribe import notes


def _mk(work, kind, uid, text):
    d = work / ("units/" + uid + "/out" if kind == "transcribe" else "review/" + uid)
    d.mkdir(parents=True, exist_ok=True)
    (d / "notes.md").write_text(text, encoding="utf-8")


def test_collect_reads_both_phases_and_skips_empty(tmp_path):
    _mk(tmp_path, "transcribe", "th06_s1_w01", "## 对照表 §4.3 停火边界\n影响面：疑似全池\n证据：…\n")
    _mk(tmp_path, "review", "th06_s2_b3", "## 弹池上限\n影响面：疑似同关\n")
    _mk(tmp_path, "transcribe", "th06_s3_b5", "   \n")      # 空的不算
    got = notes.collect(tmp_path)
    assert [(n["id"], n["kind"], n["title"]) for n in got] == [
        ("th06_s1_w01", "transcribe", "对照表 §4.3 停火边界"),
        ("th06_s2_b3", "review", "弹池上限"),
    ]
    assert got[0]["scope"] == "疑似全池" and got[1]["scope"] == "疑似同关"
    assert "证据" in got[0]["body"]


def test_multiple_notes_in_one_file(tmp_path):
    _mk(tmp_path, "transcribe", "th06_s1_w02", "## 甲\n影响面：只此单元\n\n## 乙\n影响面：疑似全池\n")
    got = notes.collect(tmp_path)
    assert [n["title"] for n in got] == ["甲", "乙"]
    assert [n["scope"] for n in got] == ["只此单元", "疑似全池"]


def test_new_and_mark_triaged(tmp_path):
    _mk(tmp_path, "transcribe", "th06_s1_w01", "## 甲\n影响面：疑似全池\n")
    _mk(tmp_path, "review", "th06_s1_w01", "## 乙\n影响面：疑似全池\n")
    all_ = notes.collect(tmp_path)
    assert len(notes.new_only(all_, tmp_path)) == 2
    notes.mark_triaged([all_[0]], tmp_path)
    left = notes.new_only(notes.collect(tmp_path), tmp_path)
    assert [n["title"] for n in left] == ["乙"]
    notes.mark_triaged(left, tmp_path)
    assert notes.new_only(notes.collect(tmp_path), tmp_path) == []


def test_render_groups_by_scope(tmp_path):
    _mk(tmp_path, "transcribe", "th06_s1_w01", "## 甲\n影响面：只此单元\n")
    _mk(tmp_path, "review", "th06_s2_b3", "## 乙\n影响面：疑似全池\n")
    out = notes.render(notes.collect(tmp_path))
    assert out.index("疑似全池") < out.index("只此单元"), "影响面大的排前面"
    assert "th06_s2_b3" in out and "乙" in out
