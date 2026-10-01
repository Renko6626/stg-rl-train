"""Strict v1 mechanical checks for standalone laser-specialist practice cards."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import os
import re
import subprocess
import sys
import tomllib
import tempfile
from pathlib import Path

import numpy as np
import stg_rl

from .cards import _specialist_metadata_errors


DIAGNOSTICS = ("task_faults", "contract_viol", "pool_full", "hits_ovf", "events_ovf", "reqs_dropped")
TOP_KEYS = {
    "schema_version", "max_visible_lasers", "max_live_lasers", "first_spawn_frame",
    "last_spawn_frame", "last_expiry_frame", "max_idle_gap", "key_frames",
}
RANK_WIDTH = {0: 6, 1: 8, 2: 10, 3: 12}
GEOMETRY = ("width", "x", "y", "angle", "start", "end")


def _reject_duplicate_keys(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError(f"重复键: {key}")
        out[key] = value
    return out


def strict_json_loads(text: str) -> dict:
    try:
        value = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except (json.JSONDecodeError, ValueError) as exc:
        if isinstance(exc, ValueError) and str(exc).startswith("重复键:"):
            raise
        raise ValueError(f"JSON无效: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("machine-spec必须是JSON对象")
    frames = value.get("key_frames")
    if isinstance(frames, list):
        seen = set()
        for row in frames:
            if not isinstance(row, dict) or "rank" not in row or "frame" not in row:
                continue
            if not _integer(row["rank"]) or not _integer(row["frame"]):
                continue
            key = (row["rank"], row["frame"])
            if key in seen:
                raise ValueError(f"重复关键帧: rank={key[0]}, frame={key[1]}")
            seen.add(key)
    return value


def _integer(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def validate_machine_spec(spec: dict, meta: dict) -> list[str]:
    errors = []
    if set(spec) != TOP_KEYS:
        errors.append(f"machine-spec顶层键不符合v1: 缺{sorted(TOP_KEYS - set(spec))} 多{sorted(set(spec) - TOP_KEYS)}")
    for name in ("schema_version", "max_visible_lasers", "max_live_lasers", "first_spawn_frame",
                 "last_spawn_frame", "last_expiry_frame", "max_idle_gap"):
        if not _integer(spec.get(name)):
            errors.append(f"{name}须为整数")
    if spec.get("schema_version") != 1 or isinstance(spec.get("schema_version"), bool):
        errors.append("schema_version须为1")
    if _integer(spec.get("max_visible_lasers")) and not 0 <= spec["max_visible_lasers"] <= 16:
        errors.append("max_visible_lasers须在0..16")
    if _integer(spec.get("max_live_lasers")) and not 0 <= spec["max_live_lasers"] <= 20:
        errors.append("max_live_lasers须在0..20")
    first, last, expiry, idle = (spec.get(k) for k in ("first_spawn_frame", "last_spawn_frame", "last_expiry_frame", "max_idle_gap"))
    limit = meta.get("time_limit", 1800)
    if _integer(first) and not 91 <= first <= 1500:
        errors.append("first_spawn_frame须在91..1500")
    if _integer(last) and (not _integer(first) or not first <= last <= 1500):
        errors.append("last_spawn_frame须不早于first且不晚于1500")
    if _integer(expiry) and (not _integer(last) or not last <= expiry <= 1750):
        errors.append("last_expiry_frame须不早于last_spawn且不晚于1750")
    if _integer(idle) and not 0 <= idle <= 90:
        errors.append("max_idle_gap须在0..90")
    if type(limit) is not int or limit != 1800:
        errors.append("专项契约time_limit须为1800")
    rows = spec.get("key_frames")
    if not isinstance(rows, list):
        errors.append("key_frames须为数组")
        return errors
    counts = {rank: 0 for rank in RANK_WIDTH}
    for index, row in enumerate(rows):
        where = f"key_frames[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{where}须为对象")
            continue
        rank, frame = row.get("rank"), row.get("frame")
        if not _integer(rank) or rank not in RANK_WIDTH:
            errors.append(f"{where}.rank须为0..3整数")
            continue
        counts[rank] += 1
        if not _integer(frame) or not 0 <= frame <= 1860:
            errors.append(f"{where}.frame须为0..1860整数")
        count_min, count_max = row.get("count_min"), row.get("count_max")
        if not _integer(count_min) or not _integer(count_max) or count_min < 0 or count_max < count_min or count_max > 20:
            errors.append(f"{where} count_min/count_max须为0..20且有序")
            continue
        allowed = {"rank", "frame", "count_min", "count_max"}
        if count_max > 0:
            allowed |= {"states"}
            for field in GEOMETRY:
                allowed |= {f"{field}_min", f"{field}_max"}
            states = row.get("states")
            if not isinstance(states, list) or not states or any(not _integer(s) or s not in (0, 1, 2) for s in states) or len(set(states)) != len(states):
                errors.append(f"{where}.states须为不重复的[0,1,2]子集")
            for field in GEOMETRY:
                lo, hi = row.get(f"{field}_min"), row.get(f"{field}_max")
                if not isinstance(lo, (int, float)) or isinstance(lo, bool) or not isinstance(hi, (int, float)) or isinstance(hi, bool) or not math.isfinite(lo) or not math.isfinite(hi) or lo > hi:
                    errors.append(f"{where}.{field}_min/max须为有限且有序数值")
            for field in ("x", "y"):
                lo, hi = row.get(f"{field}_min"), row.get(f"{field}_max")
                if isinstance(lo, (int, float)) and isinstance(hi, (int, float)) and (lo < -ENGINE_COORD_LIMIT or hi > ENGINE_COORD_LIMIT):
                    errors.append(f"{where}.{field}超出引擎坐标域[-{ENGINE_COORD_LIMIT},{ENGINE_COORD_LIMIT}]")
            for field in ("start", "end"):
                lo, hi = row.get(f"{field}_min"), row.get(f"{field}_max")
                if isinstance(lo, (int, float)) and isinstance(hi, (int, float)) and (lo < 0 or hi > LASER_LENGTH_LIMIT):
                    errors.append(f"{where}.{field}超出专项契约长度域[0,{LASER_LENGTH_LIMIT}]")
            angle_lo, angle_hi = row.get("angle_min"), row.get("angle_max")
            if isinstance(angle_lo, (int, float)) and isinstance(angle_hi, (int, float)) and (angle_lo < 0 or angle_hi > 360):
                errors.append(f"{where}.angle须为harness归一化角度[0,360]")
            wlo, whi = row.get("width_min"), row.get("width_max")
            if isinstance(wlo, (int, float)) and isinstance(whi, (int, float)) and not (wlo <= RANK_WIDTH[rank] <= whi):
                errors.append(f"{where}宽度范围不包含rank {rank}契约宽度{RANK_WIDTH[rank]}")
            if isinstance(wlo, (int, float)) and isinstance(whi, (int, float)) and (wlo < RANK_WIDTH[rank] - 0.011 or whi > RANK_WIDTH[rank] + 0.011):
                errors.append(f"{where}width范围须约束为rank {rank}契约宽度{RANK_WIDTH[rank]}")
            if all(isinstance(row.get(f"{field}_{bound}"), (int, float)) and not isinstance(row.get(f"{field}_{bound}"), bool)
                   for field in ("x", "y", "angle", "start", "end") for bound in ("min", "max")):
                full_domain = (
                    row["x_min"] <= -ENGINE_COORD_LIMIT and row["x_max"] >= ENGINE_COORD_LIMIT
                    and row["y_min"] <= -ENGINE_COORD_LIMIT and row["y_max"] >= ENGINE_COORD_LIMIT
                    and row["angle_min"] <= 0 and row["angle_max"] >= 360
                    and row["start_min"] <= 0 and row["start_max"] >= LASER_LENGTH_LIMIT
                    and row["end_min"] <= 0 and row["end_max"] >= LASER_LENGTH_LIMIT
                )
                if full_domain:
                    errors.append(f"{where}几何快照覆盖完整引擎/契约域，不能约束具体布局")
        unknown = set(row) - allowed
        if unknown:
            errors.append(f"{where}含v1未定义键: {sorted(unknown)}")
    for rank, count in counts.items():
        if count < 6:
            errors.append(f"r{rank}关键帧不足6个")
    return errors


def diagnostic_errors(output: str) -> list[str]:
    lines = [line for line in output.splitlines() if line.startswith("诊断：")]
    if len(lines) != 1:
        return ["诊断行缺失或重复"]
    pairs = re.findall(r"([A-Za-z_]+)\s+(\d+)", lines[0])
    return [f"{key}: 缺失、重复或非零" for key in DIAGNOSTICS
            if [value for name, value in pairs if name == key] != ["0"]]


def keyframe_errors(expected: dict, rows: list[dict]) -> list[str]:
    count_min, count_max = expected["count_min"], expected["count_max"]
    errors = []
    if not count_min <= len(rows) <= count_max:
        errors.append(f"激光数量不符: {len(rows)} not in [{count_min}, {count_max}]")
    if len(rows) > count_max:
        return errors
    if count_max == 0:
        return errors
    allowed_states = set(expected["states"])
    aliases = {"x": ("x", "ox"), "y": ("y", "oy"), "angle": ("angle", "deg"),
               "width": ("width",), "start": ("start",), "end": ("end",)}
    for index, row in enumerate(rows):
        state = row.get("state")
        if state not in allowed_states:
            errors.append(f"laser[{index}] state不符: {state}")
        if "width" in row and abs(float(row["width"]) - RANK_WIDTH.get(expected.get("rank"), float(row["width"]))) > 0.011:
            errors.append(f"laser[{index}] rank宽度不符: {row['width']}")
        for field, names in aliases.items():
            actual = next((row[name] for name in names if name in row), None)
            lo, hi = expected.get(f"{field}_min"), expected.get(f"{field}_max")
            if actual is None or not isinstance(actual, (int, float)) or not math.isfinite(actual) or actual < lo - 0.011 or actual > hi + 0.011:
                errors.append(f"laser[{index}] {field}={actual}超规格[{lo}, {hi}]")
    return errors


TRACE_FIELDS = {"rank", "seed", "frame", "lasers", "spawned", "expired", "bullet_count", "enemy_count", "player_alive", "segment_events", "diagnostics"}
TRACE_LASER_FIELDS = {"id", "state", "width", "x", "y", "angle", "start", "end", "speed", "omega"}
ENGINE_COORD_LIMIT = 4096
LASER_LENGTH_LIMIT = 640


def analyze_trace_frames(frames: list[dict], expected_frames: int | None = None,
                         max_visible_lasers: int | None = None,
                         max_live_lasers: int | None = None,
                         max_idle_gap: int | None = None) -> dict:
    """Validate an actual raw-World JSONL trace and derive identity-based transitions."""
    errors: list[str] = []
    seen_frames: set[tuple[int, int]] = set()
    previous: dict[tuple[int, int], dict] = {}
    spawned, expired, samples, snapshots = [], [], [], {}
    motion_frames, overlap_frames = [], []
    max_live = max_visible = max_idle = 0
    first_presence = last_presence = last_visible = None
    for row in frames:
        if not isinstance(row, dict) or set(row) != TRACE_FIELDS:
            errors.append("trace frame schema missing or unknown fields")
            continue
        rank, frame = row["rank"], row["frame"]
        if not _integer(rank) or not _integer(frame):
            errors.append("trace rank/frame must be integers")
            continue
        key = (rank, frame)
        if key in seen_frames:
            errors.append(f"duplicate rank/frame: rank={rank}, frame={frame}")
        seen_frames.add(key)
        if row.get("seed") is None or not _integer(row["seed"]):
            errors.append(f"rank={rank} frame={frame}: seed must be integer")
        diagnostics = row.get("diagnostics")
        if not isinstance(diagnostics, dict) or set(diagnostics) != set(DIAGNOSTICS):
            errors.append(f"rank={rank} frame={frame}: diagnostics schema missing or unknown fields")
        else:
            for name in DIAGNOSTICS:
                if not _integer(diagnostics[name]) or diagnostics[name] != 0:
                    errors.append(f"rank={rank} frame={frame}: diagnostic {name} missing/nonzero")
        if not _integer(row.get("bullet_count")) or not _integer(row.get("enemy_count")) or not isinstance(row.get("player_alive"), bool):
            errors.append(f"rank={rank} frame={frame}: count/player schema invalid")
        if not isinstance(row.get("segment_events"), list) or any(not isinstance(event, dict) or set(event) != {"kind"} or not _integer(event.get("kind")) for event in row.get("segment_events", [])):
            errors.append(f"rank={rank} frame={frame}: segment event schema invalid")
        laser_rows = row.get("lasers")
        if not isinstance(laser_rows, list):
            errors.append(f"rank={rank} frame={frame}: lasers must be an array")
            continue
        current: dict[tuple[int, int], dict] = {}
        for laser_row in laser_rows:
            if not isinstance(laser_row, dict) or set(laser_row) != TRACE_LASER_FIELDS:
                errors.append(f"rank={rank} frame={frame}: laser schema missing or unknown fields")
                continue
            identity = laser_row.get("id")
            if not isinstance(identity, dict) or set(identity) != {"index", "generation"} or not _integer(identity.get("index")) or not _integer(identity.get("generation")):
                errors.append(f"rank={rank} frame={frame}: laser handle schema invalid")
                continue
            handle = (identity["index"], identity["generation"])
            if handle in current:
                errors.append(f"rank={rank} frame={frame}: duplicate laser handle {handle}")
            current[handle] = laser_row
            if laser_row.get("state") not in (0, 1, 2):
                errors.append(f"rank={rank} frame={frame}: laser state invalid")
            for field in ("width", "x", "y", "angle", "start", "end", "speed", "omega"):
                value = laser_row.get(field)
                if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value):
                    errors.append(f"rank={rank} frame={frame}: laser {field} invalid")
            if isinstance(laser_row.get("angle"), (int, float)) and math.isfinite(laser_row["angle"]):
                laser_row["angle"] %= 360.0
        new_ids = set(current) - set(previous)
        gone_ids = set(previous) - set(current)
        for handle in sorted(new_ids):
            spawned.append({"rank": rank, "frame": frame, "id": {"index": handle[0], "generation": handle[1]}})
        for handle in sorted(gone_ids):
            expired.append({"rank": rank, "frame": frame, "id": {"index": handle[0], "generation": handle[1]}})
        for event_name, ids in (("spawned", new_ids), ("expired", gone_ids)):
            reported = row.get(event_name)
            want = sorted((i, g) for i, g in ids)
            try:
                got = sorted((item["index"], item["generation"]) for item in reported)
            except (TypeError, KeyError):
                got = None
            if got != want:
                errors.append(f"rank={rank} frame={frame}: {event_name} transition mismatch")
        if new_ids and set(previous) & set(current):
            overlap_frames.append(frame)
        for handle in set(previous) & set(current):
            before, after = previous[handle], current[handle]
            if any(before.get(field) != after.get(field) for field in ("x", "y", "angle", "start", "end")):
                motion_frames.append(frame)
        visible = sum(item.get("state") in (0, 1) for item in current.values())
        live = len(current)
        samples.append({"rank": rank, "frame": frame, "visible": visible, "live": live})
        max_visible, max_live = max(max_visible, visible), max(max_live, live)
        if live:
            first_presence = frame if first_presence is None else first_presence
            last_presence = frame
        if visible:
            if last_visible is not None:
                max_idle = max(max_idle, frame - last_visible - 1)
            last_visible = frame
        previous = current
        snapshots[frame] = laser_rows
    ordered_keys = sorted(seen_frames)
    if expected_frames is not None:
        if len(frames) != expected_frames or len(ordered_keys) != expected_frames:
            errors.append(f"incomplete trace: got {len(frames)} frames, expected {expected_frames}")
        elif ordered_keys != [(ordered_keys[0][0], index) for index in range(1, expected_frames + 1)]:
            errors.append("trace frames are not contiguous from frame 1")
    observed = {
        "max_visible_lasers": max_visible, "max_live_lasers": max_live,
        "max_idle_gap": max_idle,
        "first_spawn_frame": min((item["frame"] for item in spawned), default=None),
        "last_spawn_frame": max((item["frame"] for item in spawned), default=None),
        "last_expiry_frame": max((item["frame"] for item in expired), default=None),
        "first_presence_frame": first_presence, "last_presence_frame": last_presence,
        "frame_count": len(frames), "complete": not errors,
    }
    for name, limit in (("max_visible_lasers", max_visible_lasers), ("max_live_lasers", max_live_lasers), ("max_idle_gap", max_idle_gap)):
        if limit is not None and observed[name] > limit:
            errors.append(f"{name} observed {observed[name]} exceeds bound {limit}")
    observed["complete"] = not errors
    return observed | {"errors": errors, "spawned": spawned, "expired": expired,
                       "samples": samples, "key_frames": snapshots,
                       "motion_frames": motion_frames, "overlap_frames": overlap_frames}


def seed_matrix_errors(seeds: tuple[int, ...]) -> list[str]:
    errors = []
    if not {1, 7}.issubset(seeds):
        errors.append("正式矩阵必须包含契约种子1和7；可附加其它种子")
    if any(not _integer(seed) or seed < 0 for seed in seeds):
        errors.append("seeds须为非负整数")
    if len(set(seeds)) != len(seeds):
        errors.append("seeds不得重复")
    return errors


def spec_keyframe_coverage_errors(spec: dict) -> list[str]:
    """Structural coverage required by frozen v1; geometry tightness remains reviewed semantically."""
    errors = []
    rows = spec.get("key_frames")
    if not isinstance(rows, list):
        return ["key_frames须为数组"]
    for rank in RANK_WIDTH:
        rank_rows = [row for row in rows if isinstance(row, dict) and row.get("rank") == rank]
        active_rows = [row for row in rank_rows if row.get("count_max", 0) > 0]
        warning_rows = [row for row in active_rows if isinstance(row.get("states"), list) and 0 in row["states"]]
        live_rows = [row for row in active_rows if isinstance(row.get("states"), list) and 1 in row["states"]]
        fade_rows = [row for row in active_rows if isinstance(row.get("states"), list) and 2 in row["states"]]
        if not warning_rows:
            errors.append(f"r{rank}关键帧缺少有激光的预警(state 0)快照")
        if not live_rows:
            errors.append(f"r{rank}关键帧缺少有激光的生效(state 1)快照")
        elif warning_rows and not any(w["frame"] != a["frame"] for w in warning_rows for a in live_rows):
            errors.append(f"r{rank}预警与生效必须由不同帧快照覆盖")
        if not fade_rows:
            errors.append(f"r{rank}关键帧缺少有激光的收缩(state 2)快照")
        terminal = [row for row in rank_rows if row.get("frame") == 1800 and row.get("count_min") == 0 and row.get("count_max") == 0]
        if not terminal:
            errors.append(f"r{rank}关键帧缺少frame 1800零激光时限快照")
        if not any(row.get("count_min") == 0 and row.get("count_max") == 0 and row.get("frame") != 1800 for row in rank_rows):
            errors.append(f"r{rank}关键帧缺少自然回收后的零激光快照")
        if len(active_rows) < 3:
            errors.append(f"r{rank}少于3个有激光的关键帧，无法覆盖开场/中段/末段")
    return errors


def trace_keyframe_coverage_errors(spec: dict, measurements: list[dict]) -> list[str]:
    errors = []
    rows = spec.get("key_frames", [])
    for rank in RANK_WIDTH:
        per_rank = [m for m in measurements if m.get("rank") == rank]
        rank_rows = [row for row in rows if row.get("rank") == rank]
        if not per_rank:
            errors.append(f"r{rank}缺少机械轨迹，无法验证关键帧覆盖")
            continue
        firsts = [m["first_spawn_frame"] for m in per_rank if m["first_spawn_frame"] is not None]
        lasts = [m["last_spawn_frame"] for m in per_rank if m["last_spawn_frame"] is not None]
        expiries = [m["last_expiry_frame"] for m in per_rank if m["last_expiry_frame"] is not None]
        if not firsts or not lasts or not expiries:
            errors.append(f"r{rank}轨迹缺出生或回收事件，无法验证关键帧覆盖")
            continue
        first_spawn, last_spawn, last_expiry = min(firsts), max(lasts), max(expiries)
        keyframes = {row["frame"]: row for row in rank_rows}
        if not any(abs(row["frame"] - first_spawn) <= 1 and row.get("count_max", 0) > 0 for row in rank_rows):
            errors.append(f"r{rank}关键帧未覆盖首波出生边界f{first_spawn}±1")
        if not any(abs(row["frame"] - last_spawn) <= 1 and row.get("count_max", 0) > 0 for row in rank_rows):
            errors.append(f"r{rank}关键帧未覆盖末波出生边界f{last_spawn}±1")
        if not any(first_spawn < row["frame"] < last_spawn and row.get("count_max", 0) > 0 for row in rank_rows):
            errors.append(f"r{rank}关键帧缺少首末波之间的中段激光快照")
        if not any(row.get("frame") == last_expiry and row.get("count_min") == row.get("count_max") == 0 for row in rank_rows):
            errors.append(f"r{rank}关键帧未覆盖末句柄回收后的精确空场帧f{last_expiry}")
        states_at = lambda frame: {laser["state"] for m in per_rank for laser in m["key_frames"].get(frame, [])}
        warnings = [row["frame"] for row in rank_rows if row.get("count_max", 0) > 0 and 0 in row.get("states", []) and 0 in states_at(row["frame"])]
        actives = [row["frame"] for row in rank_rows if row.get("count_max", 0) > 0 and 1 in row.get("states", []) and 1 in states_at(row["frame"])]
        fades = [row["frame"] for row in rank_rows if row.get("count_max", 0) > 0 and 2 in row.get("states", []) and 2 in states_at(row["frame"])]
        if not any(w != a for w in warnings for a in actives):
            errors.append(f"r{rank}实测快照未分别覆盖预警和生效状态")
        if not any(last_expiry - 12 <= frame < last_expiry for frame in fades):
            errors.append(f"r{rank}实测快照未覆盖末次回收前的收缩状态")
        overlap = sorted(frame for m in per_rank for frame in m["overlap_frames"])
        if overlap and not any(frame in overlap and row.get("count_max", 0) > 0 for frame, row in keyframes.items()):
            errors.append(f"r{rank}关键帧未覆盖任何实测多波重叠交接")
        moving = sorted(frame for m in per_rank for frame in m["motion_frames"])
        if moving and not any(frame in moving and row.get("count_max", 0) > 0 for frame, row in keyframes.items()):
            errors.append(f"r{rank}激光实测有运动，但关键帧没有覆盖运动帧")
    return errors


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _trace_binary() -> tuple[Path, subprocess.CompletedProcess]:
    package = Path(__file__).resolve().parents[2] / "tools" / "laser_trace" / "Cargo.toml"
    target = Path("/tmp/sunyunbo/stg-laser-batch3/trace-target")
    binary = target / "release" / "laser-trace"
    sidecar = target / "laser-trace.build.json"
    target.mkdir(parents=True, exist_ok=True)
    source_before = _trace_source_fingerprint(package.parent)
    previous = None
    try:
        previous = json.loads(sidecar.read_text())
    except (OSError, json.JSONDecodeError):
        pass
    cache_valid = _trace_cache_is_valid(binary, previous, source_before)
    env = os.environ.copy()
    env["CARGO_TARGET_DIR"] = str(target)
    if not cache_valid:
        binary.unlink(missing_ok=True)
        sidecar.unlink(missing_ok=True)
        clean = subprocess.run(["cargo", "clean", "--manifest-path", str(package)],
                               capture_output=True, text=True, timeout=120, env=env)
        if clean.returncode:
            raise RuntimeError(f"laser-trace stale-target clean failed: {clean.stderr[-3000:]}")
    else:
        clean = None
    command = ["cargo", "build", "--offline", "--release", "--manifest-path", str(package)]
    build = subprocess.run(command, capture_output=True, text=True, timeout=900, env=env)
    if build.returncode:
        raise RuntimeError(f"laser-trace build failed: {build.stderr[-4000:]}")
    source_after = _trace_source_fingerprint(package.parent)
    if source_after != source_before:
        binary.unlink(missing_ok=True)
        raise RuntimeError("laser-trace/engine source changed during build; refusing executable")
    if not binary.is_file():
        raise RuntimeError("cargo build succeeded but laser-trace executable is missing")
    cargo_version = subprocess.run(["cargo", "--version"], capture_output=True, text=True, check=True).stdout.strip()
    rustc_version = subprocess.run(["rustc", "--version"], capture_output=True, text=True, check=True).stdout.strip()
    evidence = {"build_state": "cargo_verified_cache" if cache_valid else "cargo_rebuilt_after_fingerprint_miss",
                "cleaned_untrusted_target": not cache_valid,
                "build_command": command, "source_fingerprint": source_after,
                "binary_sha256": _sha256(binary), "cargo_version": cargo_version,
                "rustc_version": rustc_version, "engine_source_identity": _engine_source_identity()}
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=target, prefix="laser-trace.build.", suffix=".tmp", delete=False) as tmp:
        tmp.write(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
        tmp.flush()
        os.fsync(tmp.fileno())
        temp_path = Path(tmp.name)
    os.replace(temp_path, sidecar)
    return binary, build


def _fingerprint_paths(roots: list[Path]) -> str:
    digest = hashlib.sha256()
    for root in roots:
        root = root.resolve()
        files = sorted(path for path in (root.rglob("*") if root.is_dir() else [root]) if path.is_file())
        for path in files:
            relative = path.relative_to(root) if root.is_dir() else Path(root.name)
            digest.update(str(root).encode())
            digest.update(b"\0")
            digest.update(relative.as_posix().encode())
            digest.update(b"\0")
            digest.update(path.read_bytes())
    return digest.hexdigest()


def _trace_source_fingerprint(package_dir: Path | None = None) -> str:
    engine = Path("/data/sunyunbo/www/stg-engine")
    package_dir = package_dir or Path(__file__).resolve().parents[2] / "tools" / "laser_trace"
    roots = [package_dir / "Cargo.toml", package_dir / "Cargo.lock", package_dir / "src",
             engine / "Cargo.toml", engine / "Cargo.lock", engine / "rust-toolchain.toml",
             engine / "crates/stg-core/Cargo.toml", engine / "crates/stg-core/src",
             engine / "crates/stg-ecl-compiler/Cargo.toml", engine / "crates/stg-ecl-compiler/src",
             engine / "crates/stg-derive/Cargo.toml", engine / "crates/stg-derive/src"]
    return _fingerprint_paths(roots)


def _trace_build_sidecar(binary: Path) -> Path:
    return binary.parent.parent / "laser-trace.build.json"


def _trace_cache_is_valid(binary: Path, sidecar: dict | None, source_fingerprint: str) -> bool:
    return (binary.is_file() and isinstance(sidecar, dict)
            and sidecar.get("source_fingerprint") == source_fingerprint
            and sidecar.get("binary_sha256") == _sha256(binary))


def _tree_sha256(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        digest.update(path.relative_to(root).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
    return digest.hexdigest()


def _engine_source_identity() -> dict:
    engine = Path("/data/sunyunbo/www/stg-engine")
    paths = ["crates/stg-core/src", "crates/stg-core/Cargo.toml", "crates/stg-ecl-compiler/src",
             "crates/stg-ecl-compiler/Cargo.toml", "crates/stg-derive/src"]
    result = subprocess.run(["git", "-C", str(engine), "rev-parse", "HEAD"], capture_output=True, text=True, check=True)
    diff = subprocess.run(["git", "-C", str(engine), "diff", "--binary", "HEAD", "--", *paths],
                          capture_output=True, check=True)
    return {"git_commit": result.stdout.strip(),
            "core_source_sha256": _tree_sha256(engine / "crates/stg-core" / "src"),
            "compiler_source_sha256": _tree_sha256(engine / "crates/stg-ecl-compiler" / "src"),
            "derive_source_sha256": _tree_sha256(engine / "crates/stg-derive" / "src"),
            "core_compiler_manifest_sha256": hashlib.sha256(b"".join((engine / path).read_bytes() for path in paths if path.endswith("Cargo.toml"))).hexdigest(),
            "relevant_working_tree_diff_sha256": hashlib.sha256(diff.stdout).hexdigest()}


def _run_trace(binary: Path, card_dir: Path, rank: int, seed: int, frames: int) -> list[dict]:
    proc = subprocess.run([str(binary), str(card_dir), "--rank", str(rank), "--seed", str(seed), "--frames", str(frames)],
                          capture_output=True, text=True, timeout=300)
    if proc.returncode:
        raise RuntimeError(f"laser-trace exit={proc.returncode}: {proc.stderr[-3000:]}")
    rows = []
    for number, line in enumerate(proc.stdout.splitlines(), 1):
        try:
            value = json.loads(line, object_pairs_hook=_reject_duplicate_keys)
        except (json.JSONDecodeError, ValueError) as exc:
            raise RuntimeError(f"invalid JSONL at line {number}: {exc}") from exc
        rows.append(value)
    return rows


def _parse_harness_lasers(output: str, frame: int) -> list[dict] | None:
    match = re.search(rf"帧 {frame} · 活激光 (\d+) 条（池索引升序）\n", output)
    if not match:
        return None
    count = int(match.group(1))
    lines = output[match.end():].splitlines()
    rows = []
    for line in lines:
        parts = line.split()
        if parts and parts[0].isdigit():
            if len(parts) < 11:
                return None
            rows.append({"idx": int(parts[0]), "x": float(parts[1]), "y": float(parts[2]),
                         "angle": float(parts[4]) % 360.0, "start": float(parts[5]), "end": float(parts[6]),
                         "width": float(parts[7]), "speed": float(parts[8]), "omega": int(parts[9]),
                         "state": int(parts[10])})
        elif rows:
            break
    return rows if len(rows) == count else None


def _crosscheck_harness(harness: Path, card_dir: Path, keyframes: list[dict], trace_by_frame: dict[int, list[dict]]) -> list[str]:
    errors = []
    for expected in (row for row in keyframes if row["rank"] == 0):
        frame = expected["frame"]
        proc = subprocess.run([str(harness), "run", str(card_dir), "--rank", "0", "--seed", "1",
                               "--frames", "1860", "--at", str(frame)],
                              capture_output=True, text=True, timeout=180)
        if proc.returncode:
            errors.append(f"harness snapshot r0/seed1/f{frame} failed: {proc.returncode}")
            continue
        harness_rows = _parse_harness_lasers(proc.stdout, frame)
        trace_rows = trace_by_frame.get(frame)
        if harness_rows is None or trace_rows is None or len(harness_rows) != len(trace_rows):
            errors.append(f"harness snapshot r0/seed1/f{frame} laser count/snapshot missing")
            continue
        for index, (actual, trace) in enumerate(zip(harness_rows, trace_rows)):
            for field in ("x", "y", "angle", "start", "end", "width", "speed", "omega", "state"):
                if not math.isclose(actual[field], trace[field], abs_tol=0.011, rel_tol=0):
                    errors.append(f"harness snapshot r0/seed1/f{frame}/laser{index} {field} differs: {actual[field]} vs {trace[field]}")
    return errors


def _fx(row: np.ndarray, field: str) -> float:
    offset = stg_rl.OFFSETS["lasers"][field][0]
    return int.from_bytes(row[offset:offset + 4].tobytes(), "little", signed=True) / 65536.0


def _raw_rows(buffers: dict, count: int) -> list[dict]:
    count = int(count)
    out = []
    for row in buffers["lasers"][0, :count]:
        angle_off = stg_rl.OFFSETS["lasers"]["angle"][0]
        angle = int.from_bytes(row[angle_off:angle_off + 2].tobytes(), "little") * (360.0 / 65536.0)
        half = _fx(row, "half_h")
        state_off = stg_rl.OFFSETS["lasers"]["state"][0]
        out.append({"x": _fx(row, "x"), "y": _fx(row, "y"), "angle": angle,
                    "start": _fx(row, "start"), "end": _fx(row, "end"),
                    "width": half * 2, "state": int(row[state_off])})
    return out


def _measure_stream(image, card_id: str, rank: int, seed: int, frames: int, keyframes: dict[int, dict]) -> dict:
    buffers = stg_rl.alloc_buffers(1, 128, backend="numpy")
    env = stg_rl.VecEnv(1, 1, {card_id: image}, [stg_rl.Start(card_id, mark=0, rank=rank)],
                        frame_skip=1, max_frames=frames + 1, warmup_max=0, end_on=(),
                        bullets_cap=128, seed=seed, buffers=buffers)
    env.reset()
    samples = []
    snapshots = {}
    last_present, first_present, last_count_rise = None, None, None
    prior_count = 0
    max_live = max_visible = 0
    max_idle = idle = 0
    error = None
    for step in range(1, frames + 1):
        env.step(np.zeros(1, dtype=np.uint32))
        current = int(buffers["frame"][0])
        done = int(buffers["done"][0])
        if done:
            error = f"玩家或时限结束导致VecEnv reset (step={step}, frame={current}, done={done}); 后续帧不计为连续覆盖"
            break
        if current != step:
            error = f"帧流不连续: step={step}, frame={current}"
            break
        count = int(buffers["lasers_count"][0])
        rows = _raw_rows(buffers, count)
        visible = sum(row["state"] in (0, 1) for row in rows)
        live = len(rows)
        samples.append({"frame": current, "visible": visible, "live": live})
        max_live, max_visible = max(max_live, live), max(max_visible, visible)
        if live:
            first_present = current if first_present is None else first_present
            last_present = current
            if live > prior_count:
                last_count_rise = current
        if visible:
            idle = 0
        elif first_present is not None:
            idle += 1
            max_idle = max(max_idle, idle)
        prior_count = live
        if current in keyframes:
            snapshots[current] = rows
    return {"rank": rank, "seed": seed, "complete": error is None, "coverage_error": error,
            "first_presence_frame": first_present, "last_presence_frame": last_present,
            "last_spawn_count_rise_lower_bound": last_count_rise, "max_live_lasers": max_live,
            "max_visible_lasers": max_visible, "max_idle_gap": max_idle,
            "samples": samples, "key_frames": snapshots}


def _validate_card(card_dir: Path, harness: Path, seeds: tuple[int, ...]) -> dict:
    required = {"main.ecl", "meta.toml", "TASK.md", "machine-spec.json"}
    report = {"card": card_dir.name, "ok": False, "errors": [], "runs": [], "measurements": [], "key_frames": [],
              "seeds": list(seeds), "file_sha256": {}, "harness_sha256": None,
              "validator": {"version": "laser-specialist-v1-mechanical-trace", "sha256": _sha256(Path(__file__))},
              "python_version": sys.version.split()[0], "stg_rl": stg_rl.build_info(),
              "seed_matrix": {"required": [1, 7], "provided": list(seeds), "errors": seed_matrix_errors(seeds)},
              "independent_semantic_review": "pending",
              "keyframe_geometry_tightness": "engine/contract-domain bounds are machine checked; support over the declared random domain requires non-author review"}
    errors = report["errors"]
    errors.extend(report["seed_matrix"]["errors"])
    before = {p.name: _sha256(p) for p in card_dir.iterdir() if p.is_file()}
    report["file_sha256"] = before
    if not required.issubset(before):
        errors.append(f"缺少卡文件: {sorted(required - set(before))}")
    if set(card_dir.glob("*.ecl")) != {card_dir / "main.ecl"}:
        errors.append("standalone卡必须只有main.ecl一份ECL文件")
    if not harness.is_file():
        errors.append(f"harness不存在: {harness}")
    else:
        report["harness_sha256"] = _sha256(harness)
    try:
        meta = tomllib.loads((card_dir / "meta.toml").read_text())
    except (OSError, tomllib.TOMLDecodeError) as exc:
        meta = {}
        errors.append(f"meta.toml无效: {exc}")
    errors.extend(_specialist_metadata_errors(card_dir.name, meta))
    try:
        spec = strict_json_loads((card_dir / "machine-spec.json").read_text())
    except (OSError, ValueError) as exc:
        spec = {}
        errors.append(str(exc))
    errors.extend(validate_machine_spec(spec, meta))
    errors.extend(spec_keyframe_coverage_errors(spec))
    if errors:
        return report
    try:
        image = stg_rl.compile_dir(card_dir)
    except Exception as exc:
        errors.append(f"stg_rl编译失败: {exc}")
        return report
    check = subprocess.run([str(harness), "check", str(card_dir)], capture_output=True, text=True, timeout=120)
    report["compile_check"] = {"exit": check.returncode, "stdout": check.stdout, "stderr": check.stderr}
    if check.returncode:
        errors.append(f"harness check失败: {check.returncode}")
        return report

    try:
        trace_binary, trace_build = _trace_binary()
        sidecar = _trace_build_sidecar(trace_binary)
        build_evidence = json.loads(sidecar.read_text())
        actual_binary_sha = _sha256(trace_binary)
        if actual_binary_sha != build_evidence.get("binary_sha256"):
            raise RuntimeError("binary SHA no longer matches atomic build sidecar")
        source_now = _trace_source_fingerprint()
        if source_now != build_evidence.get("source_fingerprint"):
            raise RuntimeError("source fingerprint no longer matches built executable")
        report["trace_executable_sha256"] = actual_binary_sha
        report["trace_source_fingerprint"] = source_now
        report["engine_source_identity"] = build_evidence["engine_source_identity"]
        report["trace_build"] = build_evidence | {"exit": trace_build.returncode,
                                                  "stdout": trace_build.stdout, "stderr": trace_build.stderr}
    except Exception as exc:
        errors.append(f"laser-trace准备失败: {exc}")
        return report
    frame_map = {rank: {row["frame"]: row for row in spec["key_frames"] if row["rank"] == rank} for rank in RANK_WIDTH}
    all_measurements = []
    crosscheck_frames = {}
    for rank in RANK_WIDTH:
        for seed in seeds:
            proc = subprocess.run([str(harness), "run", str(card_dir), "--rank", str(rank), "--seed", str(seed), "--frames", "1860"],
                                  capture_output=True, text=True, timeout=180)
            output = proc.stdout + proc.stderr
            run_errors = diagnostic_errors(output)
            if proc.returncode:
                run_errors.append(f"exit={proc.returncode}")
            seg = re.search(r"^段结束：(.+)$", output, re.M)
            seg_frames = [int(value) for value in re.findall(r"@(\d+)", seg[1])] if seg else []
            if not any(1680 <= frame <= 1860 for frame in seg_frames):
                run_errors.append("段结束缺失或不在time_limit前后120帧窗口")
            report["runs"].append({"rank": rank, "seed": seed, "frames": 1860, "exit": proc.returncode,
                                   "errors": run_errors, "segment_frames": seg_frames,
                                   "diagnostic_line": next((line for line in output.splitlines() if line.startswith("诊断：")), None),
                                   "output": output})
            errors.extend(f"r{rank}/seed{seed}: {error}" for error in run_errors)
            try:
                trace_frames = _run_trace(trace_binary, card_dir, rank, seed, 1860)
                measured = analyze_trace_frames(trace_frames, expected_frames=1860,
                                                max_visible_lasers=spec["max_visible_lasers"],
                                                max_live_lasers=spec["max_live_lasers"],
                                                max_idle_gap=spec["max_idle_gap"])
            except Exception as exc:
                errors.append(f"r{rank}/seed{seed}: mechanical trace failed: {exc}")
                continue
            measured |= {"rank": rank, "seed": seed}
            all_measurements.append(measured)
            report["measurements"].append({key: value for key, value in measured.items()
                                           if key not in ("key_frames", "samples", "spawned", "expired", "errors")}
                                           | {"errors": measured["errors"],
                                              "per_frame_counts": [[sample["frame"], sample["visible"], sample["live"]]
                                                                   for sample in measured["samples"]]})
            errors.extend(f"r{rank}/seed{seed}: {message}" for message in measured["errors"])
            if rank == 0 and seed == 1:
                crosscheck_frames = measured["key_frames"]
            for frame, expected in frame_map[rank].items():
                rows = measured["key_frames"].get(frame)
                if rows is None:
                    errors.append(f"r{rank}/seed{seed}/f{frame}: 缺测关键帧")
                    continue
                frame_errors = keyframe_errors(expected, rows)
                errors.extend(f"r{rank}/seed{seed}/f{frame}: {message}" for message in frame_errors)
            report["key_frames"].append({"rank": rank, "seed": seed, "frame": frame, "lasers": rows, "errors": frame_errors})

    coverage_errors = trace_keyframe_coverage_errors(spec, all_measurements)
    report["keyframe_coverage"] = {"errors": coverage_errors}
    errors.extend(coverage_errors)

    completed = [sample for sample in all_measurements if sample["complete"]]
    if all_measurements:
        observed = {
            "max_visible_lasers": max(m["max_visible_lasers"] for m in all_measurements),
            "max_live_lasers": max(m["max_live_lasers"] for m in all_measurements),
            "max_idle_gap": max(m["max_idle_gap"] for m in all_measurements),
            "first_spawn_frame": min((m["first_spawn_frame"] for m in all_measurements if m["first_spawn_frame"] is not None), default=None),
            "last_spawn_frame": max((m["last_spawn_frame"] for m in all_measurements if m["last_spawn_frame"] is not None), default=None),
            "last_expiry_frame": max((m["last_expiry_frame"] for m in all_measurements if m["last_expiry_frame"] is not None), default=None),
            "first_presence_frame": min((m["first_presence_frame"] for m in all_measurements if m["first_presence_frame"] is not None), default=None),
            "last_presence_frame": max((m["last_presence_frame"] for m in all_measurements if m["last_presence_frame"] is not None), default=None),
        }
        report["observed_stream_bounds"] = observed
        for field in ("max_visible_lasers", "max_live_lasers", "max_idle_gap"):
            if observed[field] > spec[field]:
                errors.append(f"实测{field}={observed[field]}超过声明上界{spec[field]}")
        for field in ("first_spawn_frame", "last_spawn_frame", "last_expiry_frame"):
            if observed[field] != spec[field]:
                errors.append(f"实测{field}={observed[field]}与声明精确值{spec[field]}不符")
        crosscheck_errors = _crosscheck_harness(harness, card_dir, spec["key_frames"], crosscheck_frames)
        report["harness_trace_crosscheck"] = {"rank": 0, "seed": 1,
                                               "keyframes_checked": len([row for row in spec["key_frames"] if row["rank"] == 0]),
                                               "errors": crosscheck_errors}
        errors.extend(crosscheck_errors)
        report["actual_measurement_evidence"] = {
            "method": "本地laser-trace以与stg-harness run相同的compile_units/World::new_game/seed/rank/InputFrame::empty/step设置逐帧读取公开LaserPool API；id=(池index,generation)，角度归一到[0,360)。激光事件由handle集合差直接测得。visible=state0/1，live=所有state；并发/空档声明按上界比较，跨rank最早出生/最晚出生/最晚回收按精确极值比较。",
            "limits": "站桩使用机械 no-keys 轨迹，只证明脚本世界连续运行与激光身份/几何/时序；玩家可躲性由独立可行性工具判定。harness抽样快照按打印精度±0.011对拍。",
            "last_spawn_frame_verified": True,
            "all_runs_complete": len(all_measurements) == len(RANK_WIDTH) * len(seeds)
            and {1, 7}.issubset(seeds) and all(m["complete"] for m in all_measurements),
            "player_death_does_not_reset_world": True,
        }
        final_source_fingerprint = _trace_source_fingerprint()
        final_binary_sha = _sha256(trace_binary)
        report["trace_integrity_after_matrix"] = {"source_fingerprint": final_source_fingerprint,
                                                  "binary_sha256": final_binary_sha}
        if final_source_fingerprint != report.get("trace_source_fingerprint") or final_binary_sha != report.get("trace_executable_sha256"):
            errors.append("工具或引擎源码/可执行文件在矩阵运行期间改变，报告无效")
    after = {p.name: _sha256(p) for p in card_dir.iterdir() if p.is_file()}
    if before != after:
        errors.append("验收运行期间卡文件改变，快照报告无效")
    report["ok"] = not errors
    report["acceptance_status"] = "mechanical_pass_independent_review_pending" if report["ok"] else "mechanical_fail"
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="单张卡目录，或配合--all传入卡集合根目录")
    parser.add_argument("--all", action="store_true", help="验收root下所有直接子目录")
    parser.add_argument("--json", required=True, type=Path, help="JSON报告文件；--all时作为报告目录")
    parser.add_argument("--harness", type=Path, default=Path("/data/sunyunbo/www/stg-engine/target/release/stg-harness"))
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 7])
    args = parser.parse_args(argv)
    if args.all:
        cards = sorted(p for p in args.root.iterdir() if p.is_dir()) if args.root.is_dir() else []
    else:
        cards = [args.root]
    if not cards:
        parser.error("没有待验收卡")
    all_ok = True
    for card in cards:
        report = _validate_card(card, args.harness, tuple(args.seeds))
        target = args.json / f"{card.name}.machine.json" if args.all else args.json
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        status = "MECHANICAL PASS · independent review pending" if report["ok"] else "FAIL"
        print(f"{card.name}: {status} ({len(report['errors'])} errors)")
        for error in report["errors"]:
            print(error)
        all_ok &= report["ok"]
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
