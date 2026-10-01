import math
from pathlib import Path

import torch
import pytest

from stgtrain.specialist_feasibility import (
    done_status,
    point_to_laser_sq,
    predict_laser_row,
    score_path_clearance,
    _card_ranks,
    _requested_ranks,
    main,
    run,
    _trial,
)


def test_point_distance_matches_segment_and_capsule_edges():
    row = torch.tensor([0, 0, 0, 10, 20, 4, 0, 0, 0, 0, 0, 1], dtype=torch.float64)
    assert point_to_laser_sq((15, 0), row) == 0
    assert point_to_laser_sq((15, 7), row) == 9
    assert point_to_laser_sq((25, 0), row) == 25


def test_laser_prediction_applies_origin_angle_and_length_velocity():
    row = torch.tensor([2, 3, math.pi / 2, 4, 10, 2, 1, 0.1, 0.5, -1, 4, 0], dtype=torch.float64)
    predicted = predict_laser_row(row, 2)
    predicted = torch.tensor(predicted, dtype=torch.float64)
    assert torch.allclose(predicted[:2], torch.tensor([3.0, 1.0], dtype=torch.float64))
    assert torch.isclose(predicted[2], torch.tensor(math.pi / 2 + 0.2, dtype=torch.float64))
    assert torch.allclose(predicted[3:5], torch.tensor([6.0, 12.0], dtype=torch.float64))
    assert predicted[10] == 2
    assert predicted[11] == 0


def test_path_score_penalizes_collision_and_waits_until_warning_activates():
    active = torch.tensor([[0, 0, 0, 0, 30, 4, 0, 0, 0, 0, 0, 1]], dtype=torch.float64)
    warn = active.clone()
    warn[0, 11] = 0
    warn[0, 10] = 3
    active_score = score_path_clearance((10, 10), (0, -5), active, hit_r=2, horizon=2)
    warn_score = score_path_clearance((10, 10), (0, -5), warn, hit_r=2, horizon=2)
    assert active_score < 0
    assert warn_score > active_score


@pytest.mark.parametrize("point,expected", [
    ((10, 7), 1.0), ((10, 6), 0.0), ((10, 5), -1.0),
    ((23, 0), 1.0), ((22, 0), 0.0), ((21, 0), -1.0),
])
def test_clearance_uses_engine_rectangle_half_width_once(point, expected):
    row = torch.tensor([0, 0, 0, 0, 20, 4, 0, 0, 0, 0, 0, 1], dtype=torch.float64)
    actual = score_path_clearance(point, (0, 0), [row], hit_r=2, horizon=0)
    assert actual == pytest.approx(expected)


def test_card_rank_endpoints_expand_inclusively_and_requested_ranks_must_fit(tmp_path):
    card = tmp_path / "ranked"
    card.mkdir()
    (card / "meta.toml").write_text("ranks = [0, 3]\n", encoding="utf-8")
    assert _card_ranks(card) == [0, 1, 2, 3]
    assert _requested_ranks([0, 1, 2, 3], [0, 1, 2, 3]) == [0, 1, 2, 3]
    with pytest.raises(ValueError, match="requested ranks must be values from 0..3"):
        _requested_ranks([0, 1, 2, 3], [4])
    with pytest.raises(ValueError, match="not declared by card.*supported ranks \\[2\\]"):
        _requested_ranks([2], [0])
    assert _requested_ranks([2], None) == [2]


def test_run_rejects_rank_outside_card_metadata_before_engine_work(tmp_path):
    card = Path(__file__).parent / "fixtures/laser_cards/example_laser"
    with pytest.raises(ValueError, match="not declared by card.*supported ranks \\[2\\]"):
        run(card, all_cards=False, report_dir=tmp_path, seed_list=[1], include_baselines=False,
            max_frames=10, ranks=[0])


def test_cli_reports_out_of_range_rank_clearly(tmp_path, capsys):
    card = Path(__file__).parent / "fixtures/laser_cards/example_laser"
    with pytest.raises(SystemExit) as exc:
        main([str(card), "--json", str(tmp_path), "--ranks", "4"])
    assert exc.value.code == 2
    assert "requested ranks must be values from 0..3" in capsys.readouterr().err


def test_done_status_distinguishes_survival_death_and_open_episode():
    assert done_status(0) == "RUNNING"
    assert done_status(1) == "DEATH"
    assert done_status(2) == "SUCCESS"
    assert done_status(9) == "UNKNOWN_DONE_9"


@pytest.mark.parametrize("card", [
    Path(__file__).parent / "fixtures/cards/example_calm",
    Path(__file__).parent / "fixtures/laser_cards/example_laser",
])
def test_real_engine_trial_stops_at_requested_frame_limit(card, tmp_path):
    from stgtrain.registry import load_builtins

    load_builtins()
    result = _trial(card, rank=0, seed=1, trajectory_root=tmp_path, max_frames=40)
    assert result["status"] == "TIMEOUT"
    assert result["done"] == 3
    assert result["steps"] == result["engine_ep_frames"] == 40
    assert result["trajectory_bytes"] > 0


def test_real_motor_baseline_requires_settled_120_frame_dwell(tmp_path):
    from stgtrain.registry import load_builtins

    load_builtins()
    card = Path(__file__).parent / "fixtures/cards/example_calm"
    result = _trial(card, rank=0, seed=1, trajectory_root=tmp_path, max_frames=300,
                    baseline=(0.0, 400.0))
    assert result["target_reached_step"] is not None
    assert result["target_tolerance_px"] == 4.0
    assert result["stationary_required_frames"] == 120
    assert result["stationary_qualification_status"] == "QUALIFIED"
    assert result["stationary_qualified"] is True
    assert result["post_arrival_nonzero_direction_frames"] > 0
    assert result["stationary_frames_max"] >= 120
    assert result["stationary_max_drift_px"] is not None
    assert result["stationary_offset_from_target_px"] <= 4.0
    assert result["player_state_start"]["hit_radius_px"] == pytest.approx(2.5)
