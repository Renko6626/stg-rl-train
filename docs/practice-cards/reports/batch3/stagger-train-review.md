# Batch3 stagger train independent review

Review scope: `laser_sp_stagger_01`, `laser_sp_stagger_02`, and `laser_sp_stagger_03`; specialist contract v1 plus the 2026-10-01 public clarifications. I read each complete ECL/TASK/meta/spec, recomputed group timing and geometry, checked the engine laser/player collision implementation, and compared the frozen hashes to the machine and feasibility reports. The 01/02 results below include a hash check of every recorded trajectory. This review does not establish that all random instances are solvable or make a training-benefit claim.

## Verdicts

| Card | Independent review verdict | Feasibility / intake status |
|---|---|---|
| `laser_sp_stagger_01` | **PASS within round 3 source and sample scope** | Full legal center support now covers every row; the targeted edge probe found two qualified finite-seed survivors, not a universal row |
| `laser_sp_stagger_02` | **PASS within declared final source and sample scope** | No source-guaranteed empty column; no corner baseline completes; finite-seed safe placements remain possible |
| `laser_sp_stagger_03` | **PASS within declared final source and sample scope** | Six heuristic successes; two deaths remain `NOT_PROVEN`; no stationary baseline completes |

The current 01 verdict binds to its round 3 author report and `final-round3` evidence; the `final/frozen-manifest.json` entry for 01 is its superseded round 2 snapshot. Cards 02/03 retain their reviewed frozen-manifest hashes. Prior round 0–2 review content later in this file is historical for 01.

## Round 3 final review — `laser_sp_stagger_01`

The four round 3 card hashes in the author report match the actual card files, final-round3 machine report, final-round3 feasibility report, and edge-row probe. The round 3 author report SHA256 is `11e48754d327d4409b49abab7031cd016b6456493dc1f895a3a39c0b8a3d5f43`.

The changed source removes the prior universal edge gap across the complete declared parameter support. `phase=rand(5)` is constant for the card; since 5 is coprime with each wave count 13/14/16/18, the cycle visits every slot. For fixed separation `d`, `A=448-d`, the unjittered slot centers are `floor(A*k/(n-1))`. The maximum adjacent base-center steps at the largest span (`d_min`) are 28/27/24/23 px by rank. `jitter=rand(33)-16` supplies all integer offsets `[-16,16]`, a 32 px span, and the clamp to `[0,A]` preserves both endpoints. The adjacent slot supports therefore overlap and the first core-line center support is every integer in `[0,A]`; the second center support is every integer in `[d,448]`. Because all legal d are at most 168, these intervals overlap. I independently enumerated the complete `slot × d × jitter` domain for each rank and found exactly all 449 integer centers `0..448`, with no missing row. After collision expansion, no source-guaranteed vertical row remains immune to every allowed random position. A finite played episode may still leave a row unhit by chance; that is not the prior universal band.

Lasers remain stationary after creation, with the current position visible throughout their warning period; there are no active-phase jumps or future-RNG observations. The boss remains noncolliding, and the card remains pure lasers. The machine report is `final-round3/laser_sp_stagger_01/laser_sp_stagger_01.machine.json`, SHA256 `b0188f6b6e9b44ef1f929e7410182a344fc966a12df778b9ad4586141257981d`; it passes 8/8 rank×seed runs, max visible/live 12, no idle gap, and the existing timing limits. The canonical feasibility report is `final-round3/laser_sp_stagger_01/feasibility/laser_sp_stagger_01.json`, SHA256 `a5f65b7e1a51c2f3d47cbc64f41e2764b008ece29a7f23a777c0c167804b9315`; it binds the same card SHA set and records 7/8 moving heuristic successes, one heuristic death (`NOT_PROVEN`), and 15/80 full-episode stationary successes. The report covers only CPU ranks 0–3 × seeds 1/7 with frame skip 1, hit extra `[2,2]`, actual motor hold 2–6/delay 0–2, slow enabled, and horizon 18. All 88 trajectory SHA256 values and row counts match.

The targeted edge-row probe SHA256 is `d354479b828bef3883f97177e78b5a5fd2c8907a5e607f4e8d189187097f3592`; its card hash set matches the round 3 files, its driver SHA is `69e70a70b8b50631812bf1b2c6586920efe37490c30eae42bdd434adc4f1fbfb`, and its canonical module SHA is `02afa09a64d91a94eecee9b61d7deeb28aac81e4d489d713accb58622cd60681`. The 16 target trials use the same hit, motor, frame-skip and CPU physics settings, and record pre-step hit radius/focus plus actual motor-applied controls. All 16 trajectory files pass their declared SHA256 and row-count checks; 15/16 reach their target. Three trials complete the episode at y=438, with two meeting the stationary qualification: rank 0 seed 7 and rank 2 seed 7, each remaining at the target for 1,738 frames. The rank 1 seed 1 y=438 trial completes but misses the stationary criterion due to motor drift. A representative qualified causal witness is [`r0-s7-y438.jsonl`](/data/sunyunbo/www/stg-rl-train/runs/laser-specialist-batch3-validation/laser_sp_stagger_01/round3/edge-row-probe/r0-s7-y438.jsonl), SHA256 `f457d6beb9e28213c02bb5e5b24b356ba4497af06fd3eed0d077a53d91c0d092`; it reaches y≈438 by step 8 and then holds within the qualified tolerance through the completed episode. The other probe deaths or misses do not establish that their configurations are impossible to evade.

**Verdict: PASS within round 3 sample limits.** The universal source hole is gone, the new mechanical report passes, and the targeted real-player probe supplies a causal stationary witness under finite seeds. Two qualified edge-row survivors among 16 probes, plus the 15/80 canonical stationary survivors, are finite realized safe placements—not a universal lane. This review does not claim that every random episode is solvable, that all safe positions are gone, or that training improves.

### Round 3 current snapshot and packet hashes

| Artifact | SHA256 |
|---|---|
| `main.ecl` | `250efd7ef10003fb4ef232b6c15df9d9b55520784460e4359455ed8dab8ffc90` |
| `meta.toml` | `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e` |
| `TASK.md` | `767c900202c5ca49c85d954237027d127935cc9acc4be951f34c56ca72d44c53` |
| `machine-spec.json` | `f57ad85404b8a12c8b094e20c0cb30cb983781b6dd1b711bb92f5843666bf852` |
| Round 3 author report | `11e48754d327d4409b49abab7031cd016b6456493dc1f895a3a39c0b8a3d5f43` |
| Round 3 machine report | `b0188f6b6e9b44ef1f929e7410182a344fc966a12df778b9ad4586141257981d` |
| Round 3 feasibility report | `a5f65b7e1a51c2f3d47cbc64f41e2764b008ece29a7f23a777c0c167804b9315` |
| Edge-row probe packet | `d354479b828bef3883f97177e78b5a5fd2c8907a5e607f4e8d189187097f3592` |
| Probe driver | `69e70a70b8b50631812bf1b2c6586920efe37490c30eae42bdd434adc4f1fbfb` |

## Round 2 frozen-matrix review (historical for 01; current for 02/03)

The final frozen manifest SHA256 is `bb88d8aaaa9440648bfdacd4ef0703f08690680fcf1935ce9547b46636066c44`. For these three cards, its four-file hashes match both the final machine and feasibility reports and the current author reports. I verified the actual `/tmp` card file hashes against the manifest and checked all 88 per-card feasibility trajectories against their recorded SHA256 and row count (264 traces total). No training or additional full-matrix run was performed for this review.

### `laser_sp_stagger_01` — REVISE

The round 2 formula removes the former midfield gap, but exact interval extrema expose narrower permanent bands next to both edges. `phase=rand(5)` is drawn once outside the wave loop; because each declared `wave_count` (13/14/16/18) is coprime with the slot stride 5, a complete loop visits every slot exactly once regardless of phase. For a given wave, `d=separation` is in `[120,168]`, `[104,152]`, `[88,136]`, or `[72,120]`, and `y0=floor((448-d)*slot/(wave_count-1))`.

Let `R=width/2+4.5` px, using the largest player hit radius measured in the final feasibility traces. The top boundary laser at y=0 reaches through y=R. The closest nonzero first-core-line center is `floor((448-d_max)/(wave_count-1))`; the bottom boundary laser at y=448 reaches upward through `448-R`, and the closest non-edge second-core-line center is `448-ceil((448-d_max)/(wave_count-1))`. These bounds are independent of seed and of the per-wave separation draws:

| Rank | `d_max` | `R` | Nearest first core center | Guaranteed top gap | Nearest second core center | Guaranteed bottom gap |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 168 | 7.5 | 23 | 8 px | 424 | 9 px |
| 1 | 152 | 8.5 | 22 | 5 px | 425 | 6 px |
| 2 | 136 | 9.5 | 20 | 1 px | 427 | 2 px |
| 3 | 120 | 10.5 | 19 | none (overlap) | 428 | none (overlap) |

Therefore y=10 and y=438 are safe fixed rows, across all x and all RNG outcomes, for ranks 0–2. This is narrower than the prior midfield band, but it still permits an edge-adjacent no-input bypass. From the measured spawn y=448, y=438 is five 2 px slow-movement steps away (plus at most 2 frames of motor delay) before any laser spawns at frame 94. The first active lines arrive at frame 184/169/154 for ranks 0/1/2; from y=448, an upward path to y≈10 takes at most 98 frames at the configured 4.5 px/frame, plus up to 2 frames of delay. All lasers remain in warning during either path. This is a geometry-and-timing causal route under the declared movement setup; the final stationary-target set did not include y=10/438, so its 7/80 complete stationary successes do not test these exact rows.

The final mechanical report is `final/laser_sp_stagger_01/laser_sp_stagger_01.machine.json`, SHA256 `7f9157a7d4608aa32a7f46350834479a98f434bb29b1b77bba3b987e58952c64`. It passes 8/8 runs, with max visible/live 12, no idle gap, first spawn 94, last spawn 1471, and last expiry 1750. The final feasibility report is `final/laser_sp_stagger_01/feasibility/laser_sp_stagger_01.json`, SHA256 `d0e0421cd48016e09595d758de024804ea04ebd09fef1d3de995715501948a63`; its declared sample is CPU, ranks 0–3 × seeds 1/7, frame skip 1, hit extra `[2,2]`, motor hold 2–6 and delay 0–2, and an 18-frame prediction horizon. It records 8/8 heuristic successes and 7/80 complete stationary baselines. I verified all 88 trajectory hashes and row counts. A representative moving trace is [`laser_sp_stagger_01_r2_s7_heuristic.jsonl`](/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_01_r2_s7_heuristic.jsonl), SHA256 `e08c077487e2d98e5d82a0103132335a629c049343ee47774e979bc40b003e4d`; its 1,747 frames record multiple control directions, 74 distinct positions, and actual hit radius 2.5–4.5 px. These finite-sample results do not refute the source-proven rows above.

The new phase keeps all lasers static after birth: each warning line exposes its current geometry before activation, with no `lz_*` mutation or active-phase jump. The boss remains noncolliding and there are no ordinary bullets. At the worst measured width/hit radius, twelve full-width active lines cover at most 252 of 448 vertical pixels by a sum-of-widths upper bound, so this source does not create a forced full-height hazard at a snapshot; the 8/8 successful moving traces also show causal escapes for the tested seeds. This does not prove connected routes for every random sequence or remove the specific stationary edge lanes above.

**Required change:** adjust the joint edge/core spacing so the boundary beam's hit reach overlaps the nearest core beam's hit reach at every rank, including the integer slot extrema. Recompute both edge intervals before freezing; then rerun the real stationary check at safe-band centers and edges on the new SHA. Do not claim all-random feasibility from the source change.

### `laser_sp_stagger_02` — PASS within final sample limits

This card's final four-file hashes match the already reviewed round 1 source snapshot, so this final review checks its report identity and player evidence only. The final machine report SHA256 is `737643c58da67027ae228d0bb07ea57cf6d8b35b7c764497eee70e435aee7334`, with 8/8 runs, max visible/live 12, no idle gap, and timely first/last spawn and expiry. The final feasibility report SHA256 is `9037d63ba5631ff64c71501c66df5b0327e5f830494ddec25c9cc8204f16bd18`; it binds the manifest hashes and records 7/8 heuristic successes, 8/80 full-episode stationary successes, and no complete corner baseline. The one heuristic death remains `NOT_PROVEN`, not evidence of mathematical impossibility.

The eight stationary successes are finite realized positions (including edge-mid and right-side placements). The earlier source review enumerated the full permitted x geometry: after expanding all possible line centers by laser half-width and player hit radius, every player x can be covered by a core line for every rank. That rules out a source-guaranteed empty vertical column, while making no claim that every seed actually hits every x. The report remains bounded to seeds 1/7 and the configured movement settings; it does not establish that all random instances are solvable or that all incidental safe placements are gone. I verified all 88 trajectory hashes and row counts. The completed trace [`laser_sp_stagger_02_r0_s1_heuristic.jsonl`](/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_02_r0_s1_heuristic.jsonl), SHA256 `5a1115fa8e11194685f87692581af6f98c5334af49580f748b4d3d30729ce189`, records changing controls/positions and hit radius 2.5–4.5 px.

### `laser_sp_stagger_03` — PASS within final sample limits

Its final four-file hashes are unchanged from the previously reviewed source snapshot. The final machine report SHA256 is `d82146634708d5d0dde413a4cf404dc7ffa77fb5a7a0230f44c909f87b4237c5`; it passes 8/8 runs with max visible/live 12, no idle gap, and the declared end timing. The final feasibility report SHA256 is `7737c0a0b1381fe0edda1c6358d63448e1224dbffe91aeba4a2a2c6ce455c5de`; it binds the same four-file hashes, records 6/8 heuristic successes, and no complete stationary baseline. The two heuristic deaths remain `NOT_PROVEN`. I verified all 88 trajectory hashes and row counts. The completed trace [`laser_sp_stagger_03_r0_s1_heuristic.jsonl`](/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_03_r0_s1_heuristic.jsonl), SHA256 `ea139846115fca73b03ac2c74bd0988c28f81360eaf44ef69378dfbe9ebeee52`, records changing controls/positions and hit radius 2.5–4.5 px. This is a sampled pass only, with no all-random solvability or training-benefit claim.

### Round 2 manifest bindings

| Card | `main.ecl` | `meta.toml` | `TASK.md` | `machine-spec.json` | Machine report SHA256 | Feasibility report SHA256 |
|---|---|---|---|---|---|---|
| `stagger_01` | `8b768a5cea406bfe9f785bda211d8c30142f49d453356fcac906121f3299d4a0` | `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e` | `9bf1a63d23a66ea2d66bd94f2c294a1ed2f57c4f9d0a12ae7d27ac497dc8dbb3` | `181909f193da7d1f0e160876e9b0708bb060f4980407352ee2a94966385fefeb` | `7f9157a7d4608aa32a7f46350834479a98f434bb29b1b77bba3b987e58952c64` | `d0e0421cd48016e09595d758de024804ea04ebd09fef1d3de995715501948a63` |
| `stagger_02` | `b07234ecc57b0865790d6780f8a051794b193874ba76c185d965d6b50f714710` | `17f7b1694535793fd653cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948` | `4d1abd5618471d1ba83e3de9fd17a529e24d704a8a814c603c7f208da1319ebf` | `5f2a17d3049aa9081ab5d0f1fc8280224ee7398f1d423cccdfc761fea4d67dd7` | `737643c58da67027ae228d0bb07ea57cf6d8b35b7c764497eee70e435aee7334` | `9037d63ba5631ff64c71501c66df5b0327e5f830494ddec25c9cc8204f16bd18` |
| `stagger_03` | `738c7fcf2f5434229363fb67596b11da50c473f73021d1152eb4acfa40076c8c` | `9feee67b761abb3e48653bbb6b48fdf8365c2c5d25a775b791b439789a318f2e` | `9c7927b36d2cf12c1d6be7f4096048ad52e280bdd64c70bf79948bb5788329f4` | `fca3873924935837dbbb56a00154a19e42b33e530518912618d9a05e65afc9e9` | `d82146634708d5d0dde413a4cf404dc7ffa77fb5a7a0230f44c909f87b4237c5` | `7737c0a0b1381fe0edda1c6358d63448e1224dbffe91aeba4a2a2c6ce455c5de` |

## Round 1 re-review (historical snapshot)

### `laser_sp_stagger_01` — REVISE

The new edge beam in `main.ecl:43-45` alternates between y=448 and y=0 on successive waves. It is created with the same warn/active/fade durations as the two core lines, and there are no post-birth writes or active-phase jumps. Its same-edge return interval is 224/208/180/162 frames by rank, shorter than each rank's warn+active duration 300/285/270/255. The updated machine report measures at most 12 visible/live lasers (within 16/20), no idle gap, first spawn 94, last spawn 1471, and last expiry 1750. The round 1 report confirms 8/8 moving heuristic episodes complete, and no tested top/bottom corner baseline completes the episode.

However, the core lines still have a source-proven vertical reach limit. `y0` is at most 263 and `separation` is at most 168/152/136/120 for rank 0/1/2/3, so the highest possible core center is 431/415/399/383. At the measured maximum player hit radius 4.5 px, the complete hit reach is `width/2 + 4.5`: 7.5/8.5/9.5/10.5 px. The boundary line at y=448 begins its hit reach at 440.5/439.5/438.5/437.5, while the highest core line ends its reach at 438.5/423.5/408.5/393.5. Thus ranks 1, 2, and 3 have RNG-independent, full-width safe bands of about 16, 30, and 44 px, respectively, between those limits. For example, at rank 3, a player fixed at y=420 is at least 28 px from the boundary beam and 37 px from every possible core center; the largest combined half-width and hit radius is 10.5 px. No horizontal laser can hit that row at any x or random draw. The rank 0 gap is only about 2 px.

This is a broad guaranteed band, not a lucky sampled placement, so the interior stationary successes are consistent with the source. In the 80 stationary-target runs, 21 complete successfully; in particular, lower-row target tests at y≈392 complete 17/24 times. The gate targets y=392 rather than the guaranteed rank 2/3 band, so these samples do not replace the geometric proof. The measured setup is CPU, ranks 0–3 × seeds 1/7, `frame_skip=1`, `hit_extra=[2,2]`, motor hold 2–6 and delay 0–2; heuristic outcome is 8/8 success. I verified all 88 trajectory files against report SHA256 and recorded row count. The successful heuristic traces contain changing inputs/directions and positions; a representative is `/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_01_r3_s1_heuristic.jsonl`, SHA256 `bcb4e55d408fbd4a2646a6b3591aadfaf27f0129a6bfcc3251c4eaa3008a3070`.

**Required repair:** expand or reshape the joint core y-position range so the ranks 1–3 interior bands cannot remain outside every possible active core beam while preserving traversable channels. Recheck fixed targets inside the calculated bands and their boundaries on a new snapshot, then rerun the applicable machine, movement, and independent review gates. The current exact four-file hashes remain blocked for inclusion.

### `laser_sp_stagger_02` — PASS within round 1 sample limits

The edge line in `main.ecl:43-45` alternates at x=192 and x=-192 with the same group lifecycle, no post-birth mutation, and no active-phase jump. It returns to each edge every two groups, before the preceding edge line expires. The updated machine report measures at most 12 visible/live lasers (within 16/20), no idle gap, first spawn 94, last spawn 1471, and last expiry 1750. I enumerated each rank's complete source ranges for `x0=-192+((97*wave+u)%264)`, `u=0..16`, and the second line `x0+gap_base+v`, `v=0..48`, across every declared wave. Expanding those possible centers by half-width plus the measured 4.5 px hit radius covers the full integer player x range `[-192,192]`; there is no source-proven vertical safe column left between the core lines and the two boundary lines. This union check does not say every realized random sequence will hit every x.

The round 1 feasibility report covers 8 rank×seed heuristic runs: 7 complete successfully; rank 2 seed 1 ends in death and remains `NOT_PROVEN`, not evidence of an impossible instance. All 80 stationary baselines are bound to the current snapshot; eight complete successfully (two at actual spawn, one center-lower, two right-lower, three right-upper), while no top/bottom corner baseline completes the episode. Some right-side targets qualify for long stationary periods before later death. These are finite placements in the tested random sequences, not a source-guaranteed band: other tested ranks/seeds die at the same target positions, and every x remains reachable by the source's permitted core-line geometry. This is within the stated goal of removing the persistent edge-corner bypass; it does not establish that no interior seed-specific safe column exists or that every random instance is solvable.

The reported engine setup is CPU, ranks 0–3 × seeds 1/7, `frame_skip=1`, `hit_extra=[2,2]`, enabled motor with hold 2–6, delay 0–2, and slow mode; actual movement traces record hit radius 2.5–4.5 px and nonconstant inputs/directions. I verified the SHA256 and row count for all 88 report trajectories. A representative completed moving trace is `/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_02_r0_s1_heuristic.jsonl`, SHA256 `5a1115fa8e11194685f87692581af6f98c5334af49580f748b4d3d30729ce189`.

### Current round 1 snapshot bindings

| Card | `main.ecl` | `meta.toml` | `TASK.md` | `machine-spec.json` | Machine report SHA256 | Feasibility report SHA256 |
|---|---|---|---|---|---|---|
| `stagger_01` | `4c55b45c98acffe2e0d489aa11a1aa032871e3a8a1ea8b73d670c3d65ff998d7` | `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e` | `66b27523eb35b1dc056e88b1f9988dc896625d82b930d5097a7f69fbb2c124af` | `8cfad9a28295df6c54eff547467c0c5e8b6909c693a5946c5c1d90323670b2f9` | `2e46de6bc3df31ede5380993060a63c9f2e78767092e3fde5542a51d1a0b1e09` | `8d1ca48655ee30febd9ae3b40151304e4f9644e55fd12574c5d9256b68819d32` |
| `stagger_02` | `b07234ecc57b0865790d6780f8a051794b193874ba76c185d965d6b50f714710` | `17f7b1694535793fbed63cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948` | `4d1abd5618471d1ba83e3de9fd17a529e24d704a8a814c603c7f208da1319ebf` | `5f2a17d3049aa9081ab5d0f1fc8280224ee7398f1d423cccdfc761fea4d67dd7` | `cf7a6e90712877b287c5b8dc05ca0c3e66a64bd2ab7dc434ce3beb961ab64ade` | `0d7d903bd39d518eb1924b69773cd3a549ea7e6d3c8fd586298e8cff4163f25d` |
| `stagger_03` | `738c7fcf2f5434229363fb67596b11da50c473f73021d1152eb4acfa40076c8c` | `9feee67b761abb3e48653bbb6b48fdf8365c2c5d25a775b791b439789a318f2e` | `9c7927b36d2cf12c1d6be7f4096048ad52e280bdd64c70bf79948bb5788329f4` | `fca3873924935837dbbb56a00154a19e42b33e530518912618d9a05e65afc9e9` | `5295273f9f5754e49386632409a292834eed439309b6990bd47926a68bd0027b` | `6f7769f783b0c81fd24e808dba2834889f2bd223606197e2b3a0f1c4cd5a6061` |

The 01/02 feasibility reports each bind these current card hashes and contain 88 trajectories. The 03 row carries forward its previously reviewed card snapshot; its feasibility report remains the same 8-rank/seed report cited earlier.

## Round 0 findings (historical snapshots only)

### Original round 0 findings

### `laser_sp_stagger_01` — REVISE

The lower corners are reproducible stationary safe positions. In `main.ecl:39-42`, `y0=(wave*97+rand(17))%264`, so `y0∈[0,263]`. For rank 0, `separation=120+rand(49)∈[120,168]`; therefore every beam center is at or below `263+168=431`. Each horizontal segment spans x `[-320,320]`, while the player's bottom boundary is y=448. The closest possible center is 17 px away. Engine collision expands the laser's half-width by player hit radius (`stg-engine/crates/stg-core/src/world/collide.rs:261-289`); even width 6 and the default 2.5 px hit radius reach only 5.5 px. The source therefore leaves the bottom edge outside every laser's hit strip. The TASK's “up to 432px” is also one pixel above the exact source maximum, which is 431px.

The actual-player check confirms this is exploitable under the recorded motion configuration (`hit_extra=[2,2]`, `frame_skip=1`, motor hold 2–6, delay 0–2). Each card report contains 88 trajectories; I verified all 88 files per card against their recorded SHA256 and row count. For 01, `still_bottom_left` and `still_bottom_right` are `QUALIFIED` and episode `SUCCESS` in all 8 rank×seed combinations. They record 1,642–1,704 stationary frames after reaching the corner. A representative trace is [`laser_sp_stagger_01_r0_s1_baseline_-192.0_448.0.jsonl`](/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_01_r0_s1_baseline_-192.0_448.0.jsonl), SHA256 `49377223c0e0a65a9cb0af361e5063741881fe094fba62232f8afd487f061a7d`; it reaches the lower-left target at step 87, then remains at `(-190.347,448)` through frame 1792. Center and lower-side stationary targets at y≈392 also qualify in all 8 cases, though some episodes later end in death.

**Required repair:** revise the joint vertical position ranges so active lines can cover the real bottom boundary and remove the observed long-lived lower safe lanes. Keep all line centers in a deliberate bounded range, preserve viable inter-line spacing, and update the TASK's exact endpoints. Re-run the stationary edge/center checks and the full real-motion gate on the changed snapshot; then rerun machine validation and request independent review. A source-only geometric argument cannot clear the all-random feasibility question.

### `laser_sp_stagger_02` — REVISE

The recorded routes repeatedly exploit the right edge. `main.ecl:39-42` places the first vertical line at `x0=-192+((wave*97+rand(17))%264)`, and the second at `x0+separation`; both lines are stationary and extend through the whole player height. The TASK says the first-line maximum is about 72 and the second can reach 240; exact integer maxima from the source are 71 and 239. Those one-pixel differences are documentation corrections, while the material defect is the actual stationary route.

The player checker used the same real engine/motor configuration as for 01 and recorded 88 trajectories; all 88 hashes and row counts match. `still_top_right` and `still_bottom_right` are `stationary_qualified` in all 8 rank×seed cases. Each survives the full episode in 6/8 cases; in the remaining cases the player stays at the target for hundreds of frames before death. The top-right stationary duration ranges from 616 to 1,537 frames, and bottom-right from 752 to 1,673. For example, [`laser_sp_stagger_02_r0_s1_baseline_192.0_0.0.jsonl`](/tmp/sunyunbo/stg-laser-batch3/trajectories/laser_sp_stagger_02_r0_s1_baseline_192.0_0.0.jsonl), SHA256 `ea3ab94820fde44995f9f25c56eb4f3effe332d9cc53af293c2b8774c19906ba`, reaches the top-right at step 255 and remains at `(192,3.545)` through frame 1792. Bottom-right is also a full-episode success for 6/8 combinations. These observations show a long-lived fixed-edge bypass, not that the entire card is unavoidably dead or that every seed is safe there.

**Required repair:** alter the joint x placement so fixed right-edge positions are intersected by active vertical lines often enough to remove the persistent routes while keeping readable open channels. Correct the TASK endpoints. Re-run right-edge stationary baselines and movement checks for the revised ranks/seeds; rerun machine validation and independent review against the new four-file SHA set.

### `laser_sp_stagger_03` — PASS within declared sample limits

The source matches the declared relay: four fixed parallel lines per group, alternating horizontal/vertical without rotation or movement. The 640 px segments cover the player bounds; horizontal centers are generated within `[-112,448]` and vertical centers within `[-192,192]`. Group spacing is 98 frames; the maximum warn+active+fade lifetime is 267 frames, so at most three groups (12 lasers) can coexist. Rank-specific lifetimes give last natural expiry at frames 1718/1723/1728/1733, matching the TASK and machine spec. Rank width/warn/active are 6/90/150, 8/75/170, 10/60/190, 12/45/210. Position jitter is bounded and jointly applied to each group; `int as fx` is used for coordinates and there is no integer-to-angle BAM cast. I found no source-level contract or timing defect in the frozen snapshot.

The real-player report is `feasibility/laser_sp_stagger_03/738c7fcf2f54/laser_sp_stagger_03.json`, SHA256 `6f7769f783b0c81fd24e808dba2834889f2bd223606197e2b3a0f1c4cd5a6061`. It is bound to the same four card hashes above. Its declared sample is ranks 0–3 × seeds 1/7, CPU, `frame_skip=1`, `hit_extra=[2,2]`, enabled motor with `hold=[2,6]`, `delay=[0,2]`, slow movement enabled, and an 18-frame prediction horizon. The player starts at speed 4.5 px/frame and hit radius 2.5 px; the successful JSONL rows record the actual per-frame `want`, `buttons`, `actual_dir`, coordinates, speed, and hit radius (2.5–4.5 px). I verified all 88 report trajectories against their SHA256 and row count.

The heuristic completes 6/8 sampled episodes: rank/seed `0/1`, `1/1`, `2/1`, `2/7`, `3/1`, and `3/7`. Each successful trace has multiple recorded movement directions and changing positions, and ends with report status `SUCCESS`. The remaining `0/7` and `1/7` episodes end in death. Those two outcomes are `NOT_PROVEN` failures of this short-horizon heuristic; they do not establish that those instances are impossible to evade. The six successful trace SHA256 values are:

| Rank / seed | Frames | Trace SHA256 |
|---|---:|---|
| 0 / 1 | 1793 | `ea139846115fca73b03ac2c74bd0988c28f81360eaf44ef69378dfbe9ebeee52` |
| 1 / 1 | 1793 | `ae57599e6518637424aba5754d7359a0822594187a39613817e80add0734fa79` |
| 2 / 1 | 1793 | `03eb164c704d19b9725e2aa64d853296713bac7517aaf7c5bc49e28fab050183` |
| 2 / 7 | 1747 | `40343b0527feff72cd1d3e03196579fd2d5ec0f9f91227ce7f59f664ee86b7cc` |
| 3 / 1 | 1793 | `2f9aaf619c0c8999a3d0ca664f2e6f8028ffb191b05dae63f7ed17b462413bb5` |
| 3 / 7 | 1747 | `6373d655f3f588c9a0dbd4c2e86429df7c07920cf9a28c2451816dd829741045` |

The 80 stationary-target baselines all eventually end in `DEATH`; 46 qualify for at least the required 120 stationary frames, and none both qualifies and completes the episode. The longest qualified hold is 1,397 frames before death. Some targets were not reached or did not remain stationary long enough, so this is evidence against a persistent bypass at the tested locations, not proof that no stationary-safe point exists anywhere. Together with the six successful moving trajectories, the sample supports PASS for the tested ranks/seeds and declared movement setup. It does not prove feasibility over the full random domain, other seeds, or policies with different movement settings.

## Round 0 snapshot and evidence hashes (historical)

The following card hashes match the corresponding author snapshot and machine report:

| Card | `main.ecl` | `meta.toml` | `TASK.md` | `machine-spec.json` |
|---|---|---|---|---|
| `stagger_01` | `022f16b4e0eab4b8fac3185ffadf0b0fd1c199d3934d87f5266e2aae207d8039` | `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e` | `9dcd19649c2f284f79480320500dc55abc44f9daeb02ce8de7967d8ea7621ab2` | `46e860d1a79b635f56973c4b4441060a5f719da848b938a0e85d661895f704e1` |
| `stagger_02` | `253445e0a839739b3fed63b86cae8f9e1d98fed77cc4ef2346e5e520a2b02bbc` | `17f7b1694535793fbed63cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948` | `c7179aa316e00ef0000737ceffd20b10c7e4f65a33df08a6d8b808e33444603a` | `07b66cc96d492a388d36099a8b4d62b1b9d0fa934443153d25f526ec69256ba5` |
| `stagger_03` | `738c7fcf2f5434229363fb67596b11da50c473f73021d1152eb4acfa40076c8c` | `9feee67b761abb3e48653bbb6b48fdf8365c2c5d25a775b791b439789a318f2e` | `9c7927b36d2cf12c1d6be7f4096048ad52e280bdd64c70bf79948bb5788329f4` | `fca3873924935837dbbb56a00154a19e42b33e530518912618d9a05e65afc9e9` |

Machine reports: `laser_sp_stagger_01.machine.json` SHA256 `f61d7a7794fbe850b05892a1e6ecab0e9b605e9e2ac0c54f03c9a6f8521e7a05`; `laser_sp_stagger_02.machine.json` SHA256 `7e091a10b5b43517bde59a171f84407ea142da7ebbd12fea9c8826452888a39e`; `laser_sp_stagger_03.machine.json` SHA256 `ca23f0821f0c1b62212b2f3e38108f18feaf0f32f16b81880dca4256de835cad`.

Feasibility reports: [stagger01 JSON](feasibility/stagger01/laser_sp_stagger_01.json), SHA256 `c3e05d854e82a978985040d9aa01315ebd0c1a3d6fd6be793f4a4a0af2670903`; [stagger02 JSON](feasibility/stagger02/laser_sp_stagger_02.json), SHA256 `ebb79380a499a5325631939addaa2d973d28df6aef5b0aafda100a07781d2552`; [stagger03 JSON](feasibility/laser_sp_stagger_03/738c7fcf2f54/laser_sp_stagger_03.json), SHA256 `6f7769f783b0c81fd24e808dba2834889f2bd223606197e2b3a0f1c4cd5a6061`. Their report configs and per-run records retain ranks/seeds, hit extra, motor settings, outcomes and trajectory hashes.

Review scope is tied to these exact hashes. Any card file change invalidates its finding and requires the applicable machine/feasibility gates and this independent review to be rerun.
