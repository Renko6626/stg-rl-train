# sweep_04 author handoff

Status: **READY/FROZEN (author round 1, author stage only)**. Card: `laser_sp_sweep_04`, contract v1, `sweep`, `held-out`. The held-out source review found a documentation example outside the declared right-source y band; the example and its calculations are corrected below. No ECL source change was needed. Four card files are frozen at these SHA256 values:

| File | SHA256 |
|---|---|
| `main.ecl` | `b537d82e9d0b748b4fd23e897cb0e4e1f645ac32353f472a61cbd4693863d4a7` |
| `meta.toml` | `4383090e06848fd16a6c80e64eb303016f0d27e0ee2995999757e4a5d1cdc277` |
| `TASK.md` | `3d785f4a7758af19ddb7819ab5199675586c4a88321d9344388a0c3d10ff7896` |
| `machine-spec.json` | `3e09d23424d32b81656dd8ad8811c086ac2d3a33ae271a2aa66422e46d57f303` |

The pattern has ten staggered pairs. First laser birth is frame 93; left/right births are offset by 44 frames. Per-rank pair intervals are 147/148/149/151 frames. Last births by rank are 1460/1469/1478/1496 (right side); last natural recoveries are 1742/1736/1730/1733. Warn durations are 90/75/60/45, active is 180, fade is 12. The six required diagnostics were each present once and zero in every full run.

| Rank | Width | Left/right omega (BAM/frame) | Left base angle | Peak lasers / frame |
|---:|---:|---:|---:|---:|
| 0 | 6 | −36 / +36 | 34° | 4 / 284 |
| 1 | 8 | −48 / +48 | 42° | 4 / 285 |
| 2 | 10 | −60 / +60 | 50° | 4 / 286 |
| 3 | 12 | −72 / +72 | 58° | 4 / 288 |

Right base angle is 165°. Each laser receives an independent inclusive BAM perturbation `rand(5461) - 2730`, i.e. raw BAM `[-2730,2730]` (about ±15°). `rand(n)` is half-open `[0,n)`; origins use integer-pixel ranges before `int as fx`: left x `[-174,-150]`, y `[100,350]`; right x `[150,174]`, y `[150,300]`. Length is 390 px. Omega is set only after the warning expires, so warning lines stay still; the active and fading lines turn continuously.

The TASK gives the joint worst-case movement bounds. At the far endpoint, rank 0 is about 1.35 px/frame and rank 3 about 2.70 px/frame. The corrected corner examples use origins inside the implemented bands and show that these four points are reachable by some allowed continuous sweeps. They do not establish edge closure, universal pressure, or that any particular random sequence visits every point. The coordinator subsequently reported held-out player results of 8/8 heuristic successes and 17 stationary successes; sampled stationary survival is therefore present and remains for coordinator review.

Validation evidence:

- `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_04` → `OK`.
- Full matrix: `/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_04 --rank R --seed S --frames 1860`, all ranks 0–3 with seeds 1 and 7 → exit 0. Logs: `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_04/r{0..3}-s{1,7}.log`. Each run reported peak laser count 4, zero live lasers at frame 1860, phase end at frame 1803, and all six diagnostics once at zero.
- `--at` snapshots cover opening birth, second-side warning, warning-to-active boundary, pair handover, continuous movement, last-spawn `f-1/f/f+1`, late active tail, final fade frame, rank-specific expiry, time_limit 1800, phase end 1803, and run end 1860. Seed 1 snapshots are `key-r*-f*.log` and `boundary-r*-f*.log`; seed 7 geometry and terminal checks are `seed7-r*-f*.log`, `lastspawn-r*-s7-*.log`, and `terminal-r*-s7-*.log` under `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_04/`. Both seeds show changing positions and angles.
- `machine-spec.json` parses as strict JSON, has 56 unique `(rank, frame)` rows (14 per rank), and every positive-count frame declares state and all geometry fields. It includes last-fade, per-rank expiry, frame 1800, phase end 1803, and run end 1860 zero snapshots for each rank. Last-spawn boundary rows use angle range `[0,360]` because an older active left beam may cross the normalized 0° boundary there; machine-spec v1 cannot encode a wrapped interval as two ranges.
- Single-card self-check: `UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_04 --seeds 1 7 --json /tmp/sunyunbo/stg-laser-batch3/logs/sweep_04/machine-validator-final.json` → `MECHANICAL PASS · independent review pending (0 errors)`. The report binds all four current hashes and records the full rank × seed matrix.

The unseeded range is broader than the two required seeds. Full randomized feasibility and interpretation of the 17 stationary successes remain with the coordinator and independent held-out re-review; READY/FROZEN is only the author handoff state.

Scope note: an initial validator call used `--all` with the batch parent after the single-card directory call returned “no cards”. That command automatically scanned sibling directories and printed sibling card identifiers/statuses in truncated output. I saw that output, did not open sibling card files or review reports, and did not use sibling results in this card's repair. I stopped using collection mode immediately; all later validation targeted only `laser_sp_sweep_04`. No sibling files were edited.
