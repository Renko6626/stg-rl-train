import json
import subprocess

import pytest

from stgtrain.specialist_validate import (
    DIAGNOSTICS,
    diagnostic_errors,
    keyframe_errors,
    seed_matrix_errors,
    strict_json_loads,
    analyze_trace_frames,
    _fingerprint_paths,
    _trace_binary,
    _trace_build_sidecar,
    _trace_cache_is_valid,
    _trace_source_fingerprint,
    _sha256,
    spec_keyframe_coverage_errors,
    validate_machine_spec,
)


def machine_spec():
    frames = []
    for rank in range(4):
        for frame in (94, 200, 400, 600, 800, 1000):
            frames.append({
                "rank": rank, "frame": frame, "count_min": 1, "count_max": 2,
                "states": [0], "width_min": 6, "width_max": 12,
                "x_min": -192, "x_max": 192, "y_min": 0, "y_max": 448,
                "angle_min": 0, "angle_max": 360,
                "start_min": 0, "start_max": 0, "end_min": 1, "end_max": 640,
            })
    return {
        "schema_version": 1, "max_visible_lasers": 16, "max_live_lasers": 20,
        "first_spawn_frame": 93, "last_spawn_frame": 1500,
        "last_expiry_frame": 1750, "max_idle_gap": 90, "key_frames": frames,
    }


def test_strict_json_rejects_duplicate_keys_and_rank_frame_pairs():
    with pytest.raises(ValueError, match="重复键"):
        strict_json_loads('{"schema_version":1,"schema_version":1}')
    value = machine_spec()
    value["key_frames"].append(dict(value["key_frames"][0]))
    with pytest.raises(ValueError, match="重复关键帧"):
        strict_json_loads(json.dumps(value))


def test_machine_spec_requires_six_complete_frames_per_rank_and_v1_fields():
    spec = machine_spec()
    spec["key_frames"] = [row for row in spec["key_frames"] if not (row["rank"] == 2 and row["frame"] == 1000)]
    assert any("r2关键帧不足6个" in error for error in validate_machine_spec(spec, {"time_limit": 1800}))

    spec = machine_spec()
    del spec["key_frames"][0]["angle_max"]
    assert any("angle" in error for error in validate_machine_spec(spec, {"time_limit": 1800}))

    spec = machine_spec()
    spec["schema_version"] = 2
    assert any("schema_version" in error for error in validate_machine_spec(spec, {"time_limit": 1800}))


def test_machine_spec_enforces_contract_global_bounds():
    spec = machine_spec()
    spec["max_visible_lasers"] = 17
    spec["max_live_lasers"] = 21
    spec["max_idle_gap"] = 91
    errors = validate_machine_spec(spec, {"time_limit": 1800})
    assert any("16" in error for error in errors)
    assert any("20" in error for error in errors)
    assert any("90" in error for error in errors)


def test_machine_spec_rejects_only_completely_unconstrained_geometry_domain():
    spec = machine_spec()
    row = spec["key_frames"][0]
    row.update({"x_min": -4096, "x_max": 4096, "y_min": -4096, "y_max": 4096,
                "angle_min": 0, "angle_max": 360, "start_min": 0, "start_max": 640,
                "end_min": 0, "end_max": 640})
    errors = validate_machine_spec(spec, {"time_limit": 1800})
    assert any("完整引擎/契约域" in error for error in errors)

    spec = machine_spec()
    row = spec["key_frames"][0]
    row.update({"x_min": -320, "x_max": 192, "y_min": -96, "y_max": 448,
                "angle_min": 0, "angle_max": 360})
    assert not any("完整引擎/契约域" in error for error in validate_machine_spec(spec, {"time_limit": 1800}))


def test_frozen_v1_keyframe_coverage_rejects_six_zero_only_snapshots():
    spec = machine_spec()
    spec["key_frames"] = [{"rank": rank, "frame": frame, "count_min": 0, "count_max": 0}
                          for rank in range(4) for frame in (100, 200, 300, 400, 500, 600)]
    assert validate_machine_spec(spec, {"time_limit": 1800}) == []
    errors = spec_keyframe_coverage_errors(spec)
    assert any("state 0" in error for error in errors)
    assert any("state 1" in error for error in errors)
    assert any("frame 1800" in error for error in errors)


def test_full_mechanical_seed_matrix_requires_seeds_one_and_seven_but_allows_extras():
    assert any("种子1和7" in error for error in seed_matrix_errors((1,)))
    assert seed_matrix_errors((1, 7, 11)) == []


def test_trace_source_fingerprint_tracks_tool_and_engine_inputs(tmp_path):
    tool = tmp_path / "tool"
    engine = tmp_path / "engine"
    tool.mkdir()
    engine.mkdir()
    tool_src = tool / "main.rs"
    engine_src = engine / "core.rs"
    tool_src.write_text("fn main() {}\n")
    engine_src.write_text("pub const ENGINE: u32 = 1;\n")
    initial = _fingerprint_paths([tool, engine])
    tool_src.write_text("fn main() { /* changed */ }\n")
    tool_changed = _fingerprint_paths([tool, engine])
    engine_src.write_text("pub const ENGINE: u32 = 2;\n")
    assert initial != tool_changed
    assert tool_changed != _fingerprint_paths([tool, engine])


def test_cached_trace_requires_both_source_fingerprint_and_binary_hash(tmp_path):
    binary = tmp_path / "laser-trace"
    binary.write_bytes(b"built executable")
    digest = _sha256(binary)
    sidecar = {"source_fingerprint": "source-a", "binary_sha256": digest}
    assert _trace_cache_is_valid(binary, sidecar, "source-a")
    assert not _trace_cache_is_valid(binary, sidecar, "source-b")
    binary.write_bytes(b"modified executable")
    assert not _trace_cache_is_valid(binary, sidecar, "source-a")


def test_trace_rebuilds_when_cached_executable_no_longer_matches_sidecar():
    binary, build = _trace_binary()
    assert build.returncode == 0
    sidecar = _trace_build_sidecar(binary)
    smoke = subprocess.run([str(binary), "--help"], capture_output=True, text=True)
    if smoke.returncode:
        sidecar.unlink(missing_ok=True)
        binary.unlink(missing_ok=True)
        binary, build = _trace_binary()
    assert build.returncode == 0
    assert binary.read_bytes() != b"stale executable"
    original = json.loads(sidecar.read_text())
    original["source_fingerprint"] = "changed-source-fingerprint"
    sidecar.write_text(json.dumps(original))
    binary.write_bytes(b"stale executable")
    rebuilt, build = _trace_binary()
    evidence = json.loads(sidecar.read_text())
    assert build.returncode == 0
    assert rebuilt.read_bytes() != b"stale executable"
    assert evidence["source_fingerprint"] == _trace_source_fingerprint()
    assert evidence["binary_sha256"] == _sha256(rebuilt)
    assert evidence["cleaned_untrusted_target"]


def test_keyframe_checks_every_laser_including_non_special_color():
    expected = machine_spec()["key_frames"][0]
    good = {"color": 3, "state": 0, "width": 6, "ox": 0, "oy": 10,
            "deg": 45, "start": 0, "end": 100}
    bad = {**good, "color": 15, "width": 20}
    assert any("width" in error for error in keyframe_errors(expected, [good, bad]))
    assert keyframe_errors(expected, [good]) == []


def test_diagnostics_require_exactly_one_line_with_all_six_unique_zero_fields():
    valid = "诊断：" + " · ".join(f"{field} 0" for field in DIAGNOSTICS)
    assert diagnostic_errors(valid) == []
    assert diagnostic_errors(valid + "\n" + valid)
    missing = "诊断：" + " · ".join(f"{field} 0" for field in DIAGNOSTICS[:-1])
    assert diagnostic_errors(missing)
    repeated = valid + " · task_faults 0"
    assert diagnostic_errors(repeated)
    nonzero = valid.replace("pool_full 0", "pool_full 1")
    assert diagnostic_errors(nonzero)


def test_vecenv_measurement_reads_real_per_frame_laser_rows_without_color_filter():
    import stg_rl
    from stgtrain.specialist_validate import _measure_stream

    image = stg_rl.compile_sources([("stream.ecl", """
sub main() {
    loop {
        _ = laser(4, 1000.0fx, 1000.0fx, 90deg, 500.0fx, 12.0fx, 30, 120, 16);
        wait(60);
    }
}
""")])
    measured = _measure_stream(image, "stream", 0, 1, 8, {2: {}})
    assert measured["complete"]
    assert [row["frame"] for row in measured["samples"]] == list(range(1, 9))
    assert max(row["live"] for row in measured["samples"]) == 1
    assert measured["key_frames"][2][0]["width"] == pytest.approx(12.0)
    assert measured["key_frames"][2][0]["state"] == 0


def trace_frame(frame, lasers, spawned=(), expired=()):
    return {"rank": 0, "seed": 1, "frame": frame, "lasers": lasers,
            "spawned": list(spawned), "expired": list(expired),
            "diagnostics": {name: 0 for name in DIAGNOSTICS}, "bullet_count": 0,
            "enemy_count": 1, "player_alive": True, "segment_events": []}


def laser(index, generation, state=0):
    return {"id": {"index": index, "generation": generation}, "state": state,
            "width": 6, "x": 0, "y": 10, "angle": 90, "start": 0, "end": 100,
            "speed": 0, "omega": 0}


def test_trace_uses_handle_identity_for_same_count_replacement_last_spawn():
    result = analyze_trace_frames([
        trace_frame(1, [laser(0, 1)], [{"index": 0, "generation": 1}]),
        trace_frame(2, [laser(0, 2)], [{"index": 0, "generation": 2}], [{"index": 0, "generation": 1}]),
        trace_frame(3, [], (), [{"index": 0, "generation": 2}]),
    ])
    assert result["first_spawn_frame"] == 1
    assert result["last_spawn_frame"] == 2
    assert result["last_expiry_frame"] == 3
    assert result["spawned"] == [{"rank": 0, "frame": 1, "id": {"index": 0, "generation": 1}},
                                  {"rank": 0, "frame": 2, "id": {"index": 0, "generation": 2}}]
    assert result["expired"] == [{"rank": 0, "frame": 2, "id": {"index": 0, "generation": 1}},
                                  {"rank": 0, "frame": 3, "id": {"index": 0, "generation": 2}}]


def test_trace_requires_contiguous_frames_after_player_death():
    frames = [trace_frame(1, [laser(0, 1)], [{"index": 0, "generation": 1}]),
              trace_frame(2, [], (), [{"index": 0, "generation": 1}]), trace_frame(3, [])]
    frames[1]["player_alive"] = False
    result = analyze_trace_frames(frames, expected_frames=3)
    assert result["complete"]
    assert result["frame_count"] == 3


def test_trace_rejects_missing_schema_duplicate_rank_frame_and_peak_above_bound():
    frames = [trace_frame(1, [laser(0, 1)], [{"index": 0, "generation": 1}]),
              trace_frame(2, [laser(1, 1)], [{"index": 1, "generation": 1}], [{"index": 0, "generation": 1}])]
    del frames[0]["diagnostics"]
    assert analyze_trace_frames(frames)["errors"]

    frames = [trace_frame(1, []), trace_frame(1, [])]
    assert any("duplicate" in error for error in analyze_trace_frames(frames)["errors"])

    frames = [trace_frame(1, [laser(i, 1) for i in range(2)],
                          [{"index": 0, "generation": 1}, {"index": 1, "generation": 1}])]
    result = analyze_trace_frames(frames, max_live_lasers=1)
    assert any("max_live_lasers" in error for error in result["errors"])


def test_real_trace_compiles_small_ecl_and_continues_after_player_death(tmp_path):
    import json
    import subprocess

    from stgtrain.specialist_validate import _trace_binary

    card = tmp_path / "trace-smoke"
    card.mkdir()
    (card / "main.ecl").write_text(
        "sub main() { loop { _ = laser(0, 0.0fx, 384.0fx, 0deg, 640.0fx, 20.0fx, 0, 1200, 0); wait(1); } }\n"
    )
    binary, _ = _trace_binary()
    proc = subprocess.run([str(binary), str(card), "--rank", "0", "--seed", "1", "--frames", "12"],
                          check=True, capture_output=True, text=True)
    frames = [json.loads(line) for line in proc.stdout.splitlines()]
    result = analyze_trace_frames(frames, expected_frames=12)
    assert result["complete"]
    assert any(not frame["player_alive"] for frame in frames)
    assert [frame["frame"] for frame in frames] == list(range(1, 13))
