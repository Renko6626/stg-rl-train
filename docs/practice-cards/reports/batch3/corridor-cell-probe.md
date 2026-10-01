# Corridor causal-motion probe

Status: **WITNESS_FOUND**.

This is a finite witness search with a different controller from canonical h18. It uses only the current visible observation; it does not inspect future ECL timing, future RNG, or opaque expiry. A zero-success result means NOT_PROVEN, not unsolvable.

Reproduce: `.venv/bin/python tools/corridor_motion_probe.py`

| Card | Rank | Seed 1 | Seed 7 |
|---|---:|---|---|
| laser_sp_corridor_01 | 0 | DEATH 698f | DEATH 386f |
| laser_sp_corridor_01 | 1 | DEATH 685f | DEATH 371f |
| laser_sp_corridor_01 | 2 | DEATH 315f | DEATH 272f |
| laser_sp_corridor_01 | 3 | DEATH 299f | DEATH 258f |
| laser_sp_corridor_02 | 0 | SUCCESS 1793f | SUCCESS 1747f |
| laser_sp_corridor_02 | 1 | SUCCESS 1793f | SUCCESS 1747f |
| laser_sp_corridor_02 | 2 | DEATH 1667f | DEATH 1621f |
| laser_sp_corridor_02 | 3 | DEATH 321f | DEATH 280f |
| laser_sp_corridor_03 | 0 | DEATH 1417f | DEATH 1385f |
| laser_sp_corridor_03 | 1 | DEATH 1321f | DEATH 1281f |
| laser_sp_corridor_03 | 2 | DEATH 1366f | DEATH 1308f |
| laser_sp_corridor_03 | 3 | DEATH 1255f | DEATH 1200f |

Card hashes unchanged during probe: `True` (before/after four-file SHA maps are in the JSON report).
stg_rl build: `{'tables_hash': '37a7ff12fe40e24e', 'version': '0.4.1', 'git_sha': '5dfc08d-dirty', 'engine_ver': '24'}`.

Each JSON run records the actual trajectory path and SHA256, requested action, executed buttons, player position, actual observed hit radius, focus state, and terminal result.
