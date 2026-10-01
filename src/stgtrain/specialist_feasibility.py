"""Offline, real-engine feasibility probes for laser-specialist cards.

This is a deterministic observational action heuristic for author diagnostics. It
uses only the current visible laser rows and engine-reported player position and
speed; it is not a trained policy and is not wired into training observations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shlex
import tomllib
from typing import Iterable, Sequence

import stg_rl
import torch

from . import actions
from .config import from_dict
from .envwrap import LASER_COLS, EnvWrapper
from .registry import load_builtins

FIELD_X = (-192.0, 192.0)
FIELD_Y = (0.0, 448.0)
COL = {name: i for i, name in enumerate(LASER_COLS)}
HORIZON = 18
PREDICTION_STRIDE = 1
PLAYER_SPEED_FAST = 4.5
PLAYER_SPEED_SLOW = 2.0


def done_status(done: int) -> str:
    return {0: "RUNNING", 1: "DEATH", 2: "SUCCESS", 3: "TIMEOUT"}.get(int(done), f"UNKNOWN_DONE_{int(done)}")


def _value(row: Sequence[float] | torch.Tensor, name: str) -> float:
    return float(row[COL[name]])


def predict_laser_row(row: Sequence[float] | torch.Tensor, frames: float) -> list[float]:
    """Predict a currently visible row under its reported per-frame velocities."""
    r = [float(x) for x in row]
    r[COL["x"]] += r[COL["vx"]] * frames
    r[COL["y"]] += r[COL["vy"]] * frames
    r[COL["angle"]] = (r[COL["angle"]] + r[COL["omega"]] * frames) % (2 * math.pi)
    r[COL["start"]] = max(0.0, r[COL["start"]] + r[COL["speed"]] * frames)
    r[COL["end"]] = max(r[COL["start"]], r[COL["end"]] + r[COL["speed"]] * frames)
    if r[COL["state"]] == 0:
        r[COL["t_active"]] = max(0.0, r[COL["t_active"]] - frames)
        if r[COL["t_active"]] <= 0:
            r[COL["state"]] = 1.0
    return r


def point_to_laser_sq(point: tuple[float, float], row: Sequence[float] | torch.Tensor) -> float:
    """Squared distance to the engine's oriented rectangular laser segment."""
    dx = float(point[0]) - _value(row, "x")
    dy = float(point[1]) - _value(row, "y")
    a = _value(row, "angle")
    along = dx * math.cos(a) + dy * math.sin(a)
    perp = dy * math.cos(a) - dx * math.sin(a)
    along_q = min(max(along, _value(row, "start")), _value(row, "end"))
    half = _value(row, "half_h")
    perp_q = min(max(perp, -half), half)
    return (along - along_q) ** 2 + (perp - perp_q) ** 2


def score_path_clearance(
    start: tuple[float, float],
    velocity: tuple[float, float],
    lasers: Iterable[Sequence[float] | torch.Tensor],
    *,
    hit_r: float,
    horizon: int = HORIZON,
    initial_velocity: tuple[float, float] | None = None,
    initial_frames: int = 0,
) -> float:
    """Minimum signed clearance over a short linear player path.

    Warnings become hazards when their visible countdown expires. Active rows
    are conservatively treated as active through the full prediction horizon.
    """
    rows = list(lasers)
    best = math.inf
    for t in range(0, int(horizon) + 1, PREDICTION_STRIDE):
        held = min(t, max(0, int(initial_frames))) if initial_velocity is not None else 0
        px = start[0] + (initial_velocity[0] * held if initial_velocity is not None else 0.0)
        py = start[1] + (initial_velocity[1] * held if initial_velocity is not None else 0.0)
        px += velocity[0] * (t - held)
        py += velocity[1] * (t - held)
        px = min(max(px, FIELD_X[0]), FIELD_X[1])
        py = min(max(py, FIELD_Y[0]), FIELD_Y[1])
        for original in rows:
            row = predict_laser_row(original, t)
            if row[COL["state"]] != 1:
                continue
            distance = math.sqrt(point_to_laser_sq((px, py), row))
            # `point_to_laser_sq` measures distance to the engine's rectangle,
            # whose cross section already extends by half_h on both sides.
            clearance = distance - hit_r
            best = min(best, clearance)
    if math.isinf(best):
        return 128.0
    return best


def _action_vector(action_id: int, *, fast_speed: float, slow_speed: float) -> tuple[float, float]:
    direction, slow = divmod(int(action_id), 2)
    moves = ((0, 0), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))
    dx, dy = moves[direction]
    sp = slow_speed if slow else fast_speed
    if dx and dy:
        sp *= math.sqrt(0.5)
    return (dx * sp, dy * sp)


def choose_action(obs, *, env_index: int = 0, horizon: int = HORIZON) -> int:
    """Pick one of the frozen 18 actions from current visible geometry only."""
    start = tuple(float(v) for v in obs.player_xy[env_index].tolist())
    radius = float(obs.player_hit_r[env_index])
    current_speed = float(obs.player_speed[env_index])
    current_focus = bool(obs.player_focus[env_index])
    ratio = PLAYER_SPEED_FAST / PLAYER_SPEED_SLOW
    fast_speed = current_speed if not current_focus else current_speed * ratio
    slow_speed = current_speed if current_focus else current_speed / ratio
    current_action = int(obs.prev_action[env_index]) if obs.prev_action is not None else 0
    held_count = int(obs.dir_held[env_index]) if obs.dir_held is not None else 0
    change_wait = max(0, 6 - held_count) + 2
    current_velocity = _action_vector(current_action, fast_speed=fast_speed, slow_speed=slow_speed)
    if obs.lasers is None or obs.lasers_mask is None:
        lasers = []
    else:
        lasers = obs.lasers[env_index][obs.lasers_mask[env_index]].tolist()

    best_action, best_score = 0, -math.inf
    for action_id in range(actions.NUM_ACTIONS):
        vx, vy = _action_vector(action_id, fast_speed=fast_speed, slow_speed=slow_speed)
        needs_change = (action_id // 2 != current_action // 2) or (action_id % 2 != current_action % 2)
        clearance = score_path_clearance(
            start, (vx, vy), lasers, hit_r=radius, horizon=horizon,
            initial_velocity=current_velocity if needs_change else None,
            initial_frames=change_wait if needs_change else 0,
        )
        px = min(max(start[0] + vx * horizon, FIELD_X[0]), FIELD_X[1])
        py = min(max(start[1] + vy * horizon, FIELD_Y[0]), FIELD_Y[1])
        # Keep room to maneuver while making survival clearance dominate.
        edge_room = min(px - FIELD_X[0], FIELD_X[1] - px, py - FIELD_Y[0], FIELD_Y[1] - py)
        score = clearance + 0.035 * min(edge_room, 64.0)
        # Favor a small stable action when two choices are effectively tied.
        score -= 0.001 * math.hypot(vx, vy)
        if score > best_score:
            best_action, best_score = action_id, score
    return best_action


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _card_dirs(path: Path, all_cards: bool) -> list[Path]:
    if path.is_file():
        path = path.parent
    if (path / "main.ecl").is_file():
        return [path]
    cards = sorted(p.parent for p in path.rglob("main.ecl")) if all_cards else []
    if not cards:
        raise ValueError(f"no main.ecl found at {path}; use --all for a card root")
    return cards


def _card_ranks(card: Path) -> list[int]:
    meta_path = card / "meta.toml"
    if not meta_path.is_file():
        return [0, 1, 2, 3]
    meta = tomllib.loads(meta_path.read_text(encoding="utf-8"))
    ranks = meta.get("ranks", [0, 3])
    if not isinstance(ranks, list) or len(ranks) != 2:
        raise ValueError(f"{card}: metadata ranks must be an inclusive [lo, hi] range")
    lo, hi = ranks
    if type(lo) is not int or type(hi) is not int or not (0 <= lo <= hi <= 3):
        raise ValueError(f"{card}: metadata ranks must be an inclusive range within 0..3")
    return list(range(lo, hi + 1))


def _requested_ranks(declared: list[int], requested: list[int] | None) -> list[int]:
    if requested is None:
        return list(declared)
    if not requested or any(type(rank) is not int or rank not in range(4) for rank in requested):
        raise ValueError("requested ranks must be values from 0..3")
    if len(set(requested)) != len(requested):
        raise ValueError("requested ranks must not contain duplicates")
    unsupported = sorted(set(requested) - set(declared))
    if unsupported:
        raise ValueError(f"requested ranks {unsupported} are not declared by card (supported ranks {declared})")
    return list(requested)


def _make_cfg(max_frames: int):
    return from_dict({
        "run": {"device": "cpu", "torch_threads": 1},
        "env": {"num_envs": 1, "threads": 1, "frame_skip": 1, "max_frames": max_frames,
                "warmup_max": 120, "bullets_cap": 64, "ranks": [0], "mirror": False,
                "hit_extra": [2.0, 2.0]},
        "intent": {"name": "lower_half_uniform_v1", "interval": [120, 120]},
        "motor": {"enabled": True, "hold": [2, 6], "delay": [0, 2], "slow": True},
        "ppo": {"num_steps": 16, "num_minibatches": 1, "compile": False, "cudagraphs": False},
    })


def _trial(card: Path, rank: int, seed: int, trajectory_root: Path, max_frames: int, baseline=None,
           stationary_spawn: bool = False) -> dict:
    card_id = card.name
    image = stg_rl.compile_dir(card)
    cfg = _make_cfg(max_frames)
    env = EnvWrapper(cfg, {card_id: image}, [stg_rl.Start(card_id, 0, rank)], torch.device("cpu"),
                     seed=seed, num_envs=1, mirror=False)
    obs = env.reset()
    start_xy = [float(x) for x in obs.player_xy[0].tolist()]
    player_state_start = {"hit_radius_px": round(float(obs.player_hit_r[0]), 4),
                          "speed_px_per_frame": round(float(obs.player_speed[0]), 4),
                          "focus": bool(obs.player_focus[0])}
    trajectory_root.mkdir(parents=True, exist_ok=True)
    tag = "heuristic" if baseline is None and not stationary_spawn else (
        "baseline_spawn" if stationary_spawn else f"baseline_{baseline[0]}_{baseline[1]}")
    trajectory = trajectory_root / f"{card_id}_r{rank}_s{seed}_{tag}.jsonl"
    rows: list[str] = []
    done = 0
    steps = 0
    target_reached = None
    target_reached_xy = None
    requested_target = tuple(baseline) if baseline is not None else (tuple(start_xy) if stationary_spawn else None)
    if stationary_spawn:
        target_reached, target_reached_xy = 0, [round(start_xy[0], 3), round(start_xy[1], 3)]
    post_arrival_nonzero_direction_frames = 0
    post_arrival_max_drift_from_target = 0.0
    stationary_frames = 0
    stationary_frames_max = 0
    stationary_origin = None
    stationary_current_max_drift = 0.0
    stationary_max_drift = 0.0
    stationary_settled_xy = None
    stationary_offset_from_target = None
    stationary_qualified = False
    stationary_required_frames = 120
    stationary_radius_px = 4.0
    target_tolerance_px = 4.0
    max_steps = max_frames + 2
    for step in range(max_steps):
        if stationary_spawn:
            action_id = 0
        elif baseline is None:
            action_id = choose_action(obs)
        else:
            target_x, target_y = baseline
            x, y = (float(v) for v in obs.player_xy[0].tolist())
            if target_reached is None and math.hypot(target_x - x, target_y - y) <= 4.0:
                target_reached = step
                target_reached_xy = [round(x, 3), round(y, 3)]
            action_id = 0 if target_reached is not None else _move_toward(x, y, target_x, target_y)
        x, y = (float(v) for v in obs.player_xy[0].tolist())
        sample_hit_r = float(obs.player_hit_r[0])
        sample_speed = float(obs.player_speed[0])
        sample_focus = bool(obs.player_focus[0])
        lasers = obs.lasers[0][obs.lasers_mask[0]] if obs.lasers is not None else []
        n_active = sum(int(float(row[COL["state"]]) == 1) for row in lasers)
        n_warn = sum(int(float(row[COL["state"]]) == 0) for row in lasers)
        nxt, info = env.step(torch.tensor([action_id], dtype=torch.int64))
        done = int(info.done[0])
        actual_buttons = int(info.buttons[0])
        actual_direction = actual_buttons & actions.DIR_MASK
        arrived = target_reached is not None
        if arrived and requested_target is not None:
            drift_from_target = math.hypot(x - requested_target[0], y - requested_target[1])
            post_arrival_max_drift_from_target = max(post_arrival_max_drift_from_target, drift_from_target)
        if arrived and not done:
            if actual_direction:
                post_arrival_nonzero_direction_frames += 1
                stationary_frames = 0
                stationary_origin = None
                stationary_current_max_drift = 0.0
                stationary_qualified = False
                stationary_settled_xy = None
                stationary_offset_from_target = None
            else:
                if stationary_origin is None:
                    stationary_origin = (x, y)
                    stationary_frames = 1
                    stationary_current_max_drift = 0.0
                else:
                    drift = math.hypot(x - stationary_origin[0], y - stationary_origin[1])
                    stationary_current_max_drift = max(stationary_current_max_drift, drift)
                    stationary_max_drift = max(stationary_max_drift, drift)
                    if drift > stationary_radius_px:
                        stationary_origin = (x, y)
                        stationary_frames = 1
                        stationary_current_max_drift = 0.0
                    else:
                        stationary_frames += 1
                stationary_frames_max = max(stationary_frames_max, stationary_frames)
                if stationary_frames >= stationary_required_frames:
                    stationary_settled_xy = [round(x, 3), round(y, 3)]
                    stationary_offset_from_target = (
                        math.hypot(x - requested_target[0], y - requested_target[1])
                        if requested_target is not None else None
                    )
                    stationary_qualified = (
                        stationary_current_max_drift <= stationary_radius_px
                        and stationary_offset_from_target is not None
                        and stationary_offset_from_target <= target_tolerance_px
                        and post_arrival_max_drift_from_target <= target_tolerance_px
                    )
        rows.append(json.dumps({"f": step, "x": round(x, 3), "y": round(y, 3), "want": action_id,
                                "buttons": actual_buttons, "actual_dir": actual_direction,
                                "hit_r": round(sample_hit_r, 4), "speed": round(sample_speed, 4),
                                "focus": sample_focus, "arrived": arrived,
                                "active": n_active, "warn": n_warn, "done": done},
                               separators=(",", ":")))
        steps = step + 1
        obs = nxt
        if done:
            break
    payload = ("\n".join(rows) + "\n").encode("utf-8")
    trajectory.write_bytes(payload)
    if not (baseline is not None or stationary_spawn):
        stationary_status = "NOT_APPLICABLE"
    elif target_reached is None:
        stationary_status = "NOT_REACHED"
    elif stationary_qualified:
        stationary_status = "QUALIFIED"
    elif post_arrival_max_drift_from_target > target_tolerance_px or (
        stationary_offset_from_target is not None and stationary_offset_from_target > target_tolerance_px
    ):
        stationary_status = "TARGET_NOT_PROVEN"
    else:
        stationary_status = "NOT_PROVEN"
    info = {
        "card": card_id, "rank": rank, "seed": seed, "mode": tag,
        "status": done_status(done), "done": done, "steps": steps,
        "engine_ep_frames": int(info.ep_frames[0]),
        "start_xy": start_xy,
        "end_xy": [round(float(x), 3) for x in obs.player_xy[0].tolist()] if not done else None,
        "target_xy": list(requested_target) if requested_target is not None else None,
        "target_reached_step": target_reached, "target_reached_xy": target_reached_xy,
        "target_tolerance_px": target_tolerance_px if requested_target is not None else None,
        "stationary_required_frames": stationary_required_frames if requested_target is not None else None,
        "stationary_radius_px": stationary_radius_px if requested_target is not None else None,
        "stationary_frames_max": stationary_frames_max if requested_target is not None else None,
        "stationary_max_drift_px": round(stationary_max_drift, 3) if requested_target is not None else None,
        "stationary_settled_xy": stationary_settled_xy,
        "stationary_offset_from_target_px": round(stationary_offset_from_target, 3)
        if stationary_offset_from_target is not None else None,
        "post_arrival_nonzero_direction_frames": post_arrival_nonzero_direction_frames,
        "post_arrival_max_drift_from_target_px": round(post_arrival_max_drift_from_target, 3)
        if requested_target is not None else None,
        "stationary_qualified": stationary_qualified,
        "stationary_qualification_status": stationary_status,
        "player_state_start": player_state_start,
        "trajectory": str(trajectory), "trajectory_sha256": hashlib.sha256(payload).hexdigest(),
        "trajectory_bytes": len(payload),
        "auto_reset_note": "stopped on first done; returned observation may be the next reset state",
    }
    return info


def _move_toward(x: float, y: float, tx: float, ty: float) -> int:
    dx, dy = tx - x, ty - y
    if abs(dx) < 1.5:
        dx = 0
    if abs(dy) < 1.5:
        dy = 0
    direction_by_sign = {(0, 0): 0, (0, -1): 1, (1, -1): 2, (1, 0): 3, (1, 1): 4,
                         (0, 1): 5, (-1, 1): 6, (-1, 0): 7, (-1, -1): 8}
    sx, sy = (0 if dx == 0 else (1 if dx > 0 else -1)), (0 if dy == 0 else (1 if dy > 0 else -1))
    return direction_by_sign[(sx, sy)] * 2 + 1


def _card_files_sha(card: Path) -> dict[str, str]:
    return {p.relative_to(card).as_posix(): _sha256(p) for p in sorted(card.rglob("*")) if p.is_file()}


def run(card_path: Path, *, all_cards: bool, report_dir: Path, seed_list: list[int],
        include_baselines: bool, max_frames: int, ranks: list[int] | None = None) -> dict:
    load_builtins()
    cards = _card_dirs(card_path, all_cards)
    _requested_ranks([0, 1, 2, 3], ranks)
    if not seed_list or len(set(seed_list)) != len(seed_list):
        raise ValueError("seeds must be non-empty and unique")
    trajectory_root = Path(os.environ.get("STG_SPECIALIST_TRAJECTORY_DIR", "/tmp/sunyunbo/stg-laser-batch3/trajectories"))
    version = stg_rl.build_info()
    tool_sha = _sha256(Path(__file__))
    report_dir.mkdir(parents=True, exist_ok=True)
    reports = []
    for card in cards:
        file_shas = _card_files_sha(card)
        declared_ranks = _card_ranks(card)
        rank_list = _requested_ranks(declared_ranks, ranks)
        card_runs = []
        for rank in rank_list:
            for seed in seed_list:
                card_runs.append(_trial(card, rank, seed, trajectory_root, max_frames))
                if include_baselines:
                    for name, target in (("still_spawn", None), ("still_center_lower", (0.0, 392.0)),
                                         ("still_left_lower", (-128.0, 392.0)), ("still_right_lower", (128.0, 392.0)),
                                         ("still_left_upper", (-128.0, 80.0)), ("still_right_upper", (128.0, 80.0)),
                                         ("still_top_left", (-192.0, 0.0)), ("still_top_right", (192.0, 0.0)),
                                         ("still_bottom_left", (-192.0, 448.0)), ("still_bottom_right", (192.0, 448.0))):
                        if name == "still_spawn":
                            result = _trial(card, rank, seed, trajectory_root, max_frames, stationary_spawn=True)
                            result["mode"] = "stationary_at_actual_spawn"
                            card_runs.append(result)
                        else:
                            result = _trial(card, rank, seed, trajectory_root, max_frames, baseline=target)
                            result["mode"] = name
                            card_runs.append(result)
        report = {
            "schema_version": 1, "checker": "offline observational heuristic; not a trained policy",
            "card": str(card), "card_id": card.name,
            "declared_rank_range": [declared_ranks[0], declared_ranks[-1]],
            "declared_ranks": declared_ranks,
            "card_file_sha256": file_shas,
            "stg_rl_version": version.get("version"), "stg_rl_build_info": version,
            "tool": str(Path(__file__).resolve()), "tool_sha256": tool_sha,
            "config": {"num_envs": 1, "threads": 1, "device": "cpu", "frame_skip": 1,
                       "hit_extra": [2, 2], "motor": {"enabled": True, "hold": [2, 6], "delay": [0, 2], "slow": True},
                       "max_frames": max_frames, "horizon": HORIZON, "prediction_stride": PREDICTION_STRIDE,
                       "ranks": rank_list, "seeds": seed_list, "mirror": False},
            "movement_bounds": {"x": list(FIELD_X), "y": list(FIELD_Y), "coverage": "player moves from engine spawn; baseline target is counted only if physically reached"},
            "runs": card_runs,
            "limitations": ["heuristic failure is NOT_PROVEN, not evidence of mathematical unsolvability",
                            "prediction is linear over current visible laser velocities and does not inspect ECL or future RNG",
                            "unknown future spawns, changing velocities and motor random draws can invalidate the short horizon",
                            "baselines that fail to reach a requested point report target_reached_step=null"],
        }
        out = report_dir / f"{card.name}.json"
        reproduce = [".venv/bin/python", "-m", "stgtrain.specialist_feasibility", str(card.resolve()),
                     "--json", str(report_dir.resolve()), "--ranks", *(str(r) for r in rank_list),
                     "--seeds", *(str(s) for s in seed_list), "--max-frames", str(max_frames)]
        if include_baselines:
            reproduce.append("--baselines")
        report["reproducible_cli"] = shlex.join(reproduce)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        reports.append({"card": card.name, "report": str(out), "runs": len(card_runs),
                        "report_sha256": _sha256(out)})
    summary = {"schema_version": 1, "tool_sha256": tool_sha, "reports": reports}
    (report_dir / "index.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="card directory, main.ecl, or card root")
    parser.add_argument("--all", action="store_true", help="scan all descendant cards")
    parser.add_argument("--json", type=Path, required=True, dest="report_dir", help="report output directory")
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 7])
    parser.add_argument("--ranks", type=int, nargs="+")
    parser.add_argument("--baselines", action="store_true", help="also run stationary position baselines")
    parser.add_argument("--max-frames", type=int, default=1860)
    args = parser.parse_args(argv)
    try:
        result = run(args.path, all_cards=args.all, report_dir=args.report_dir, seed_list=args.seeds,
                     include_baselines=args.baselines, max_frames=args.max_frames, ranks=args.ranks)
    except ValueError as exc:
        parser.error(str(exc))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
