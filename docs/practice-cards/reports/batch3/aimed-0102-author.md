# Batch3 aimed_0102 author handoff — round 1

Both cards are **READY/FROZEN at the round 1 author snapshot**. The frozen contract-compliant machine validator reports `MECHANICAL PASS · independent review pending` for both. The previous 179-frame cadence is superseded; these files use rank-specific 95–110-frame group periods. No author card files changed after the SHA256 values below.

## laser_sp_aimed_01

Train layout: three lines per group from two side-offset origins plus one jittered center origin. The side rays use `+18deg` and `-18deg`; the center ray uses `0deg`. Each new line calls `lz_aim` once, then remains frozen. `rand(33)` samples `[0,33)`, producing inclusive integer-pixel x domains `[-96,-64]`, `[-16,16]`, and `[64,96]`; y=64px; length 560px.

| Rank | Width | Warn | Active | Period | Groups | Last line | Last recovery |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 Easy | 6px | 90 | 150 | 110 | 13 | 1416 | 1668 |
| 1 Normal | 8px | 75 | 166 | 105 | 14 | 1461 | 1714 |
| 2 Hard | 10px | 60 | 184 | 99 | 15 | 1482 | 1738 |
| 3 Lunatic | 12px | 45 | 202 | 95 | 15 | 1426 | 1685 |

`phase_begin` starts immediately and the pattern supplies the 90-frame opening. The first line is frame94, the last is frame1482. The 99-frame Hard period keeps the 15th group’s final line and natural recovery inside frames1500/1750; a 100-frame period would exceed the expiry bound. Three-line groups overlap at most three ways: measured/derived maximum visible and live counts are both 9, and the internal warning/effective idle gap is 0. `phase_begin` ended at frame1803 in every tested rank/seed run.

Four-file SHA256: `main.ecl` `790e41c56727898e475cf12380b83c3a5a493fd7463b3978309e234e9305ba8d`; `meta.toml` `6c7ce0c9fdf632aedea54b2fd6b2419a1a324e66ed9a7f2c3d650184dd014723`; `TASK.md` `d3b497088355eff009775ad8d0bde8c8cf67221c908c1d7785f2ca798d6cc742`; `machine-spec.json` `0cc2e36cadbd945affc44ff589cac7779b1cf0593276806e2fb5eaffe3b6e44a`.

## laser_sp_aimed_02

Train layout: each three-line central fan shares a newly sampled x in inclusive pixel range `[-32,32]`, y=64px, and length576px. Offsets are `-22deg`, `0deg`, `+22deg`. Each line aims once from its own origin at birth; existing lines do not track or rotate.

| Rank | Width | Warn | Active | Period | Groups | Last line | Last recovery |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 Easy | 6px | 90 | 150 | 110 | 13 | 1416 | 1668 |
| 1 Normal | 8px | 75 | 168 | 105 | 14 | 1461 | 1716 |
| 2 Hard | 10px | 60 | 186 | 99 | 15 | 1482 | 1740 |
| 3 Lunatic | 12px | 45 | 204 | 95 | 15 | 1426 | 1687 |

The phase starts immediately; the opening wait is inside the pattern. First line is frame94, last line frame1482. Maximum measured/derived visible and live counts are 9, with no internal warning/effective idle frame. The phase end event is frame1803 in every tested rank/seed run.

Four-file SHA256: `main.ecl` `610742bdba3e9ae4213493f343cb6f9ca330a775e4147852ae826a3d05aeaf92`; `meta.toml` `5167f9832cbb11d642a657994a35551aa44f5f6aed80afd7df122c13ed91fb3c`; `TASK.md` `e7965f054bfea806883886ccd82e901333d5890de1bc7158f6f48a4a4740f1a3`; `machine-spec.json` `825b62c694178b671c8ad0968f0aab887bf07c06d07c212f8838ecbf50030e0e`.

## Round 1 evidence and limits

Both compile checks completed `OK`:

```text
/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_01
/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_02
```

Each card then completed the full `rank=0..3 × seed=1/7 × 1860-frame` matrix. All 16 runs across the two cards exited 0; each diagnostic field (`task_faults`, `contract_viol`, `pool_full`, `hits_ovf`, `events_ovf`, `reqs_dropped`) appeared once and was 0. The final per-card mechanical reports are `/tmp/sunyunbo/stg-laser-batch3/reports/aimed-round1/laser_sp_aimed_01.machine.json` and `.../laser_sp_aimed_02.machine.json`; each reports `ok=true`, zero errors, 11 keyframes per rank, and an exact `f1800` empty snapshot. The validator logs are `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_0102/laser_sp_aimed_01-validator-r1.log` and `laser_sp_aimed_02-validator-r1.log`. Harness opening snapshots at frames92–96 confirm 0 lasers at92–93 and 1/2/3 lines at94/95/96.

The clamp-wide ray-length and nearest-origin clearance calculations are documented in each card's TASK. They do not establish that actual player movement can escape every random sequence. No round 1 moving-player feasibility or corner/top standing baseline was run by the author; those checks must bind these new hashes. The stationary no-input harness and the former 179-frame cadence are not evidence for the current movement gate. No training claim is made.
