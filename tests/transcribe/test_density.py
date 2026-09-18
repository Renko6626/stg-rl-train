"""卡的弹量画像：分档、低密度筛查（验收器的补充判据，不 FAIL、只作策展依据）。"""
from stgtranscribe import density


def test_bucket_by_mean_bullets():
    assert density.bucket(0) == "空"
    assert density.bucket(3) == "空"          # 峰值个位数，等同没有弹幕
    assert density.bucket(30) == "稀"
    assert density.bucket(120) == "中"
    assert density.bucket(400) == "密"


def test_low_density_finds_empty_cards_at_rank():
    rows = [{"id": "a", "rank": 2, "peak": 0, "mean": 0.0},
            {"id": "b", "rank": 2, "peak": 8, "mean": 2.8},
            {"id": "c", "rank": 2, "peak": 300, "mean": 120.0},
            {"id": "a", "rank": 3, "peak": 400, "mean": 200.0}]
    assert [r["id"] for r in density.low(rows, rank=2)] == ["a", "b"]
    assert density.low(rows, rank=3) == []
    assert [r["id"] for r in density.low(rows, rank=2, min_peak=400)] == ["a", "b", "c"]


def test_render_table_marks_empty(tmp_path):
    rows = [{"id": "a", "rank": 2, "peak": 0, "mean": 0.0}, {"id": "c", "rank": 2, "peak": 300, "mean": 120.0}]
    out = density.render(rows, rank=2)
    assert "a" in out and "空" in out and "中" in out
    assert out.count("\n") >= 2
