"""弹幕预览出图：解析 harness 输出、选帧、图集取格与旋转；有 harness + 图集时跑真卡出图。"""
from pathlib import Path

import pytest
from PIL import Image

from stgtranscribe import config, preview

AT_TEXT = """\
run: cards/x
     seed 1 · rank 3 · 294 帧 · 无输入（不按键）

峰值：弹 1630（帧 293）· 敌 25（帧 424）· 任务 51（帧 425）· 道具 0（帧 0）· 自机弹 0（帧 0）
末帧 294：弹 1630 · 敌 15 · 任务 31 · 道具 0 · 自机弹 0
段结束：PHASE_ENDED@783 · SPELL_CAPTURED — · SPELL_FAILED — · STAGE_CLEARED —
诊断：task_faults 0 · contract_viol 0 · pool_full 0 · hits_ovf 0 · events_ovf 0 · reqs_dropped 0

帧 293 · 活敌 2 只（池索引升序）
   idx          x          y       hp  sprite
     0       0.00       0.00     1000       0
     1    -154.68     108.00        1       3

帧 293 · 活弹 3 条（池索引升序）
   idx          x          y angleBAM       deg     speed  sprite
     0      41.32      70.16    11918     65.47     7.480      86
     9     -21.00     -26.20    60320    331.35     1.600      54
    17     -56.96     170.06     8997     49.42     1.600      86
"""


def test_parse_at_tables():
    snap = preview.parse_at(AT_TEXT)
    assert snap.frame == 293
    assert [(e.x, e.y, e.sprite) for e in snap.enemies] == [(0.0, 0.0, 0), (-154.68, 108.0, 3)]
    assert [(b.x, b.y, b.deg, b.sprite) for b in snap.bullets] == [
        (41.32, 70.16, 65.47, 86), (-21.0, -26.2, 331.35, 54), (-56.96, 170.06, 49.42, 86)]


def test_parse_summary():
    s = preview.parse_summary(AT_TEXT)
    assert (s.peak_bullets, s.peak_frame, s.phase_end) == (1630, 293, 783)
    s2 = preview.parse_summary(AT_TEXT.replace("PHASE_ENDED@783", "PHASE_ENDED —"))
    assert s2.phase_end is None


def test_parse_at_empty_bullets():
    text = AT_TEXT.split("帧 293 · 活弹")[0] + "帧 293 · 活弹 0 条（池索引升序）\n   idx          x          y angleBAM       deg     speed  sprite\n"
    assert preview.parse_at(text).bullets == []


def test_pick_frames_includes_peak_and_stays_in_range():
    fs = preview.pick_frames(end=783, peak=293, n=8)
    assert len(fs) == 8 and fs == sorted(set(fs))
    assert 293 in fs and fs[0] >= 1 and fs[-1] <= 783
    assert preview.pick_frames(end=5, peak=3, n=8) == [1, 2, 3, 4, 5]


def test_cell_box_row_major_16px():
    assert preview.cell_box(86) == (96, 80, 112, 96)   # KUNAI(80) 色 6 → 第 5 行第 6 列
    assert preview.cell_box(0) == (0, 0, 16, 16)
    assert preview.cell_box(192 + 5) == preview.cell_box(5)   # 越界号回卷，同 layer.gdshader


def test_rotation_matches_bridge_basis():
    # 贴图朝上；桥 bullet_basis 给 angle + 90°。PIL rotate 是逆时针为正。
    assert preview.pil_rotation(-90.0) % 360 == 0      # 朝上飞 → 不转
    assert preview.pil_rotation(0.0) % 360 == 270      # 朝右飞 → 顺时针 90°
    assert preview.pil_rotation(90.0) % 360 == 180     # 朝下飞 → 转半圈


HAS_ASSETS = config.harness_bin().exists() and preview.atlas_path().exists()
EXAMPLE = config.TH06_DIR / "examples" / "th06_s1_w01"


@pytest.mark.skipif(not HAS_ASSETS, reason="没有 stg-engine release harness 或弹图集")
def test_render_sheet_real_card(tmp_path):
    out = preview.render_card(EXAMPLE, rank=2, out_dir=tmp_path, n_frames=4, cols=2)
    sheet = Image.open(out["sheet"])
    assert sheet.size == (2 * preview.FIELD_W, 2 * (preview.FIELD_H + preview.HEADER_H))
    # 至少有一格画了弹：峰值帧那格里非背景像素多于自机与标题
    colors = sheet.getcolors(maxcolors=1 << 20)
    assert colors is not None and len(colors) > 50


@pytest.mark.skipif(not HAS_ASSETS, reason="没有 stg-engine release harness 或弹图集")
def test_render_gif_real_card(tmp_path):
    out = preview.render_card(EXAMPLE, rank=2, out_dir=tmp_path, n_frames=4, cols=2, gif_step=30, gif_frames=120)
    gif = Image.open(out["gif"])
    assert gif.n_frames == 4 and gif.size == (preview.FIELD_W, preview.FIELD_H + preview.HEADER_H)


COUNTS_TEXT = """\
  frame  bullet   shot  enemy   item   task   fault   viol
      0       0      0      0      0      1       0      0
     81       0      0      1      0      3       0      0
    162       0      0      9      0     19       0      0
    243     660      0     11      0     23       0      0
    324     616      0     17      0     35       0      0
    729      50      0      1      0      3       0      0
    810       0      0      1      0      2       0      0

峰值：弹 798（帧 507）· 敌 25（帧 424）
"""


def test_parse_counts():
    assert preview.parse_counts(COUNTS_TEXT) == [(0, 0), (81, 0), (162, 0), (243, 660), (324, 616), (729, 50), (810, 0)]


def test_active_window_bisects_sample_gaps():
    first, last = 190, 760          # 真实的第一 / 最后有弹帧
    count_at = lambda f: 1 if first <= f <= last else 0  # noqa: E731
    calls = []
    def spy(f):
        calls.append(f)
        return count_at(f)
    assert preview.active_window(preview.parse_counts(COUNTS_TEXT), spy, end=783) == (190, 760)
    assert len(calls) <= 2 * 8      # 每侧二分 ≤ log2(81) 次左右
    assert preview.active_window([(0, 0), (60, 0)], count_at, end=60) == (1, 60)   # 全程无弹：原样
    assert preview.active_window(preview.parse_counts(COUNTS_TEXT), lambda f: 1 if f >= 190 else 0, end=700) == (190, 700)


def test_pick_frames_with_start():
    fs = preview.pick_frames(end=760, peak=507, n=8, start=190)
    assert fs[0] == 190 and fs[-1] == 760 and 507 in fs and len(fs) == 8
