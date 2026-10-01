#!/usr/bin/env python3
"""Bounded real-engine cell-following witness probe for frozen corridor cards.

This offline diagnostic uses only the current observation. It is a different
controller from canonical specialist_feasibility.choose_action and does not
inspect ECL timing, future RNG, or hidden laser expiry.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import shlex
import sys

import stg_rl
import torch

ROOT = Path(__file__).resolve().parents[1]
CARDS = [Path(f"/tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_0{i}") for i in (1, 2, 3)]
OUT = Path("/tmp/sunyunbo/stg-laser-batch3/cell-probe")
TRAJ = OUT / "logs" / "trajectories"
X_BOUNDS = (-192.0, 192.0)
Y_BOUNDS = (0.0, 448.0)
COL = {name: i for i, name in enumerate(("x", "y", "angle", "start", "end", "half_h", "speed", "omega", "vx", "vy", "t_active", "state"))}
def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project_bounds(nx: float, ny: float) -> tuple[float, float]:
    vals = [nx*x + ny*y for x in X_BOUNDS for y in Y_BOUNDS]
    return min(vals), max(vals)


def line_box_point(q: float, nx: float, ny: float, player: tuple[float, float]) -> tuple[float, float] | None:
    """Nearest point to player on n·p=q, clipped along the line to the field."""
    tx, ty = ny, -nx
    s_lo, s_hi = -math.inf, math.inf
    for origin, tangent, lo, hi in ((nx*q, tx, *X_BOUNDS), (ny*q, ty, *Y_BOUNDS)):
        if abs(tangent) < 1e-10:
            if not lo <= origin <= hi:
                return None
            continue
        a, b = (lo-origin)/tangent, (hi-origin)/tangent
        s_lo, s_hi = max(s_lo, min(a, b)), min(s_hi, max(a, b))
    if s_lo > s_hi:
        return None
    s = min(max(tx*player[0] + ty*player[1], s_lo), s_hi)
    return nx*q + tx*s, ny*q + ty*s


def _rows(obs) -> list[list[float]]:
    if obs.lasers is None or obs.lasers_mask is None:
        return []
    return obs.lasers[0][obs.lasers_mask[0]].tolist()


def corridor_target(obs, previous_q: float | None) -> tuple[tuple[float, float], float, tuple[float, float]] | None:
    rows = _rows(obs)
    if len(rows) < 2:
        return None
    # Recover orientation from the first row and require the currently visible
    # family to be parallel modulo π. Align plane signs before projection.
    a0 = rows[0][COL["angle"]]
    nx, ny = -math.sin(a0), math.cos(a0)
    planes = []
    for row in rows:
        a = row[COL["angle"]]
        if abs(math.sin(a-a0)) > math.sin(math.radians(2.0)):
            return None
        x, y = row[COL["x"]], row[COL["y"]]
        vx, vy = row[COL["vx"]], row[COL["vy"]]
        ql = nx*x + ny*y
        if nx* -math.sin(a) + ny*math.cos(a) < 0:
            # A 180°-reversed row has the same physical band and q-plane.
            pass
        half = row[COL["half_h"]] + float(obs.player_hit_r[0])
        planes.append((ql, half, int(row[COL["state"]]), ql + nx*vx + ny*vy))

    px, py = (float(v) for v in obs.player_xy[0].tolist())
    q = nx*px + ny*py
    field_lo, field_hi = project_bounds(nx, ny)
    # Active expanded planes bound the one connected cell containing the player.
    below = [p+half for p, half, state, _ in planes if state == 1 and p+half <= q]
    above = [p-half for p, half, state, _ in planes if state == 1 and p-half >= q]
    lo = max(below, default=field_lo)
    hi = min(above, default=field_hi)
    if lo > hi:
        return None
    warnings = sorted((max(lo, p-half), min(hi, p+half))
                      for p, half, state, _ in planes
                      if state == 0 and p+half > lo and p-half < hi)
    merged: list[list[float]] = []
    for a, b in warnings:
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    cells = []
    cursor = lo
    for a, b in merged:
        if a-cursor >= 2.0:
            cells.append((cursor, a))
        cursor = max(cursor, b)
    if hi-cursor >= 2.0:
        cells.append((cursor, hi))
    if not cells:
        cells = [(lo, hi)]
    # Before the first active bar, enter the nearest wide warning-defined cell.
    # Later, favor the prior chosen cell; otherwise choose the nearest midpoint.
    candidates = []
    for a, b in cells:
        mid = (a+b)/2
        margin = (b-a)/2
        score = margin*0.04 - abs(mid-(previous_q if previous_q is not None else q))
        candidates.append((score, mid, a, b))
    _, target_q, cell_lo, cell_hi = max(candidates)
    target = line_box_point(target_q, nx, ny, (px, py))
    if target is None:
        return None
    # Return local projected motion direction too, for transparent trajectory logs.
    return target, target_q, (cell_lo, cell_hi)


def action_toward(obs, target: tuple[float, float]) -> int:
    px, py = (float(v) for v in obs.player_xy[0].tolist())
    dx, dy = target[0]-px, target[1]-py
    distance = math.hypot(dx, dy)
    if distance <= 4.0:
        return 1  # stationary, focused, and inside the target deadzone
    # The current character's actual speeds are 4.5 fast / 2.0 focused.
    focused = bool(obs.player_focus[0])
    speed = float(obs.player_speed[0])
    fast = speed if not focused else speed*(4.5/2.0)
    slow = speed if focused else speed*(2.0/4.5)
    desired = math.atan2(dy, dx)
    # Direction ids follow actions.py: right, down-right, down, ... (screen y+).
    direction_angles = (None, -math.pi/2, -math.pi/4, 0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, -3*math.pi/4)
    direction = min(range(1, 9), key=lambda d: abs(math.atan2(math.sin(desired-direction_angles[d]), math.cos(desired-direction_angles[d]))))
    return direction*2 + int(distance <= 60.0)


def config(max_frames: int) -> dict:
    from stgtrain.config import from_dict
    return from_dict({"run": {"device": "cpu", "torch_threads": 1},
        "env": {"num_envs": 1, "threads": 1, "frame_skip": 1, "max_frames": max_frames,
                "warmup_max": 120, "bullets_cap": 64, "ranks": [0], "mirror": False, "hit_extra": [2.0, 2.0]},
        "intent": {"name": "lower_half_uniform_v1", "interval": [120, 120]},
        "motor": {"enabled": True, "hold": [2, 6], "delay": [0, 2], "slow": True},
        "ppo": {"num_steps": 16, "num_minibatches": 1, "compile": False, "cudagraphs": False}})


def run_one(card: Path, rank: int, seed: int, max_frames: int) -> dict:
    from stgtrain import actions
    from stgtrain.envwrap import EnvWrapper
    from stgtrain.specialist_feasibility import choose_action as fallback
    image = stg_rl.compile_dir(card)
    env = EnvWrapper(config(max_frames), {card.name: image}, [stg_rl.Start(card.name, 0, rank)],
                     torch.device("cpu"), seed=seed, num_envs=1, mirror=False)
    obs = env.reset()
    start_xy = [float(v) for v in obs.player_xy[0].tolist()]
    actual_hit_r = float(obs.player_hit_r[0])
    trajectory = TRAJ / f"{card.name}_r{rank}_s{seed}.jsonl"
    done, steps, target_q, fallback_frames = 0, 0, None, 0
    with trajectory.open("w", encoding="utf-8") as f, torch.inference_mode():
        for step in range(max_frames+1):
            xy = [float(v) for v in obs.player_xy[0].tolist()]
            result = corridor_target(obs, target_q)
            if result is None:
                action = fallback(obs, horizon=18)
                fallback_frames += 1
                target_xy = None
                cell = None
            else:
                target_xy, target_q, cell = result
                action = action_toward(obs, target_xy)
            next_obs, info = env.step(torch.tensor([action], dtype=torch.int64))
            buttons = int(info.buttons[0])
            row = {"frame": step, "want": int(action), "buttons": buttons,
                   "x": round(xy[0], 4), "y": round(xy[1], 4),
                   "hit_r": round(float(obs.player_hit_r[0]), 4), "focus": bool(obs.player_focus[0]),
                   "target_xy": [round(x, 4) for x in target_xy] if target_xy else None,
                   "target_q": round(target_q, 4) if target_q is not None else None,
                   "cell": [round(v, 4) for v in cell] if cell else None,
                   "done": int(info.done[0]), "ep_frames": int(info.ep_frames[0])}
            f.write(json.dumps(row, separators=(",", ":"))+"\n")
            steps = step+1
            if int(info.done[0]):
                done = int(info.done[0])
                break
            obs = next_obs
    del env, obs
    return {"card": card.name, "rank": rank, "seed": seed, "done": done,
            "status": {0:"RUNNING",1:"DEATH",2:"SUCCESS",3:"TIMEOUT"}.get(done, f"UNKNOWN_{done}"),
            "steps": steps, "start_xy": [round(v, 4) for v in start_xy],
            "actual_hit_r": round(actual_hit_r, 4),
            "fallback_frames": fallback_frames, "trajectory": str(trajectory), "trajectory_sha256": sha(trajectory)}


def main() -> int:
    sys.path.insert(0, str(ROOT / "src"))
    # Small deterministic checks for projected bounds and clipped line points.
    assert project_bounds(0.0, 1.0) == Y_BOUNDS
    p = line_box_point(300.0, 0.0, 1.0, (0.0, 200.0))
    assert p == (0.0, 300.0) and abs(p[1]-300.0) < 1e-7
    p = line_box_point(0.0, math.sqrt(0.5), math.sqrt(0.5), (-192.0, 448.0))
    assert p is not None and abs(p[0]+192.0) < 1e-7 and abs(p[0]+p[1]) < 1e-7
    OUT.mkdir(parents=True, exist_ok=True)
    TRAJ.mkdir(parents=True, exist_ok=True)
    before = {str(card): {name: sha(card/name) for name in ("main.ecl", "meta.toml", "TASK.md", "machine-spec.json")} for card in CARDS}
    version = stg_rl.build_info()
    from stgtrain.registry import load_builtins
    load_builtins()
    from stgtrain import specialist_feasibility as canonical
    report = {"schema_version": 1, "classification": "finite witness probe; failures are NOT_PROVEN",
        "controller": "visible-geometry projected cell-following plus existing current-observation fallback",
        "different_from_canonical_h18": True, "uses_future_ecl_timing_rng_or_expiry": False,
        "canonical_h18_comparison": {"module_sha256": sha(Path(canonical.__file__))},
        "driver_sha256": sha(Path(__file__)), "stg_rl_build": version,
        "config": {"device":"cpu", "threads":1, "num_envs":1, "frame_skip":1, "hit_extra":[2,2],
                   "motor":{"enabled":True,"hold":[2,6],"delay":[0,2],"slow":True}, "max_frames":3600,
                   "ranks":[0,1,2,3],"seeds":[1,7]}, "cards":before, "runs":[]}
    for card in CARDS:
        for rank in range(4):
            for seed in (1, 7):
                report["runs"].append(run_one(card, rank, seed, 3600))
    after = {str(card): {name: sha(card/name) for name in ("main.ecl", "meta.toml", "TASK.md", "machine-spec.json")} for card in CARDS}
    report["cards_unchanged"] = before == after
    report["card_sha256_after"] = after
    report["status"] = "WITNESS_FOUND" if any(r["done"] == 2 for r in report["runs"]) else "NOT_PROVEN"
    report["reproducible_command"] = shlex.join([".venv/bin/python", "tools/corridor_motion_probe.py"])
    out = Path("docs/practice-cards/reports/batch3/corridor-cell-probe.json")
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    lines = ["# Corridor causal-motion probe", "", f"Status: **{report['status']}**.",
        "", "This is a finite witness search with a different controller from canonical h18. It uses only the current visible observation; it does not inspect future ECL timing, future RNG, or opaque expiry. A zero-success result means NOT_PROVEN, not unsolvable.",
        "", f"Reproduce: `{report['reproducible_command']}`", "", "| Card | Rank | Seed 1 | Seed 7 |", "|---|---:|---|---|"]
    for card in CARDS:
        name = card.name
        for rank in range(4):
            rs=[r for r in report["runs"] if r["card"]==name and r["rank"]==rank]
            by_seed = {r["seed"]: r for r in rs}
            lines.append(f"| {name} | {rank} | {by_seed[1]['status']} {by_seed[1]['steps']}f | {by_seed[7]['status']} {by_seed[7]['steps']}f |")
    lines += ["", f"Card hashes unchanged during probe: `{report['cards_unchanged']}` (before/after four-file SHA maps are in the JSON report).",
        f"stg_rl build: `{version}`.", "", "Each JSON run records the actual trajectory path and SHA256, requested action, executed buttons, player position, actual observed hit radius, focus state, and terminal result."]
    Path("docs/practice-cards/reports/batch3/corridor-cell-probe.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    print(json.dumps({"status":report["status"],"runs":len(report["runs"]),"cards_unchanged":report["cards_unchanged"],"report":str(out)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
