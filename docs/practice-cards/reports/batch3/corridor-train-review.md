# Corridor train review — final snapshots / contract v1

Independent review of train cards `laser_sp_corridor_01` through `_03`. I read only these three cards and their evidence; no held-out card was opened. Each four-file card snapshot matches both its current author handoff and `final/frozen-manifest.json`.

## Per-card verdicts

| Card | Source verdict | Actual finite-evidence outcome |
|---|---|---|
| `laser_sp_corridor_01` | `PASS` | `NOT_PROVEN`; quarantine. No controller found a surviving trajectory. |
| `laser_sp_corridor_02` | `PASS` | Limited finite qualification at ranks 0/1 only: observation-only cell follower completed both seeds at each rank. Ranks 2/3 remain `NOT_PROVEN`; quarantine those ranks pending evidence. |
| `laser_sp_corridor_03` | `PASS` | `NOT_PROVEN`; quarantine. No controller found a surviving trajectory. |

`PASS` here means the current source/TASK geometry, timing, and metadata agree for the reviewed contract requirements. It does not claim full-rank playability, all-random-instance solvability, or training benefit. The machine reports are mechanical passes (`ok=true`, zero errors, 8/8 complete runs); their JSON still labels independent review pending. The source review here is bound to the exact hashes below.

## Source review

**C01 — `laser_sp_corridor_01`: `PASS`.** In `main.ecl:18-38,47-87`, the origin now stays fixed for the whole warning and moves continuously only after activation. The active trajectory reflects at `x=±164`, sweeps both real x-edge collision bands, and returns through the center. This removes the prior warning-only edge approach. The continuous safe lane remains inside the center bounds; lines can extend beyond the field as allowed. `TASK.md:12-23` correctly separates beam-edge gap from player-center clearance: with `R=2.5+2=4.5px` per side, q=0 clearances are 51/43/35/31px at ranks 0..3, above thresholds 48/40/32/28. The joint q mapping gives speeds 1.10–1.14 / 1.12–1.16 / 1.14–1.18 / 1.16–1.20px/f; q=0 is both the narrowest and slowest case. Jitter is integer `[0,24]`, not an unbounded or incorrectly signed draw. The task's minimum active path margins to sweep the center are 21/23.4/44.2/79.3px. The fixed boss, no-body flag, phase, ranks, wave schedule, and standalone train metadata match contract v1.

**C02 — `laser_sp_corridor_02`: `PASS`.** In `main.ecl:18-38,47-95`, warning origins remain stationary; active movement is continuous between rank-specific center limits. Upper and lower groups turn at their limits and sweep the true top/bottom collision bands before returning through the center. For the upper beam, the player at y=0 can collide while the center traverses `C∈[g/2−R, g/2+width+R]`; the lower beam has the symmetric interval around `y=448`. Across q=0..8 and j=0..4, both active paths cross those full intervals. The farthest upper threshold is 24.5px from the rank2/3 lower reflector (plus at most 4px initial offset); the shortest active travel is 176px, so the path has ample distance, and per-frame movement is at most 1.20px versus a collision band at least 15px wide. Lines span `x=[-192,192]`. `TASK.md:11-22` uses the actual player-clearance formula: q=0 center clearances are 51/43/35/31px, above rank thresholds. q couples that gap to speed (1.10–1.14 / 1.12–1.16 / 1.14–1.18 / 1.16–1.20px/f), while `j∈[0,4]` is explicit and bounded. The conservative q=0 active path margins for sweeping the center are 5/3.4/20.2/55.3px; the rank0/1 margins are narrow but positive, and the current finite witness confirms two low ranks can be completed. The fixed boss, phase, schedule, and standalone train metadata match contract v1.

**C03 — `laser_sp_corridor_03`: `PASS`.** In `main.ecl:33-71,75-109`, each pair remains parallel and translates continuously during active life; pitch is constant within each rank and wave direction alternates. `TASK.md:9-22` uses the real field projections `x∈[-192,192]`, `y∈[0,448]`; the corridor center stays in the projected inner region while line endpoints may extend beyond the field. Its collision-aware center clearances are 57/47/39/35px, above 48/40/32/28px; active speeds are 0.72/0.80/0.90/1.00px/f and each 180-frame travel is 129.6/144/162/180px. TASK distinguishes 66–84 frame birth spacing from `max_idle_gap`; both the current machine report and source schedule give actual internal no-warning/no-active gap 0. Random offset endpoints and direction rules match the source. The fixed boss, phase, and standalone train metadata match contract v1.

No current source shows a fixed-edge shortcut across the tested episode set. The exact tested stationary evidence is still finite: canonical reports contain no full-episode stationary survivor, but some target runs fail before reaching their requested point, so that count alone is not a universal geometric proof. For C01/C03, current canonical and longer-horizon controllers found no surviving witness; this is `NOT_PROVEN`, not mathematical unsolvability. C02's observation-only follower provides actual finite witnesses only at ranks 0/1. Do not extend those witnesses to ranks 2/3 or to untested random combinations.

## Actual evidence bounds

All three canonical reports use ranks 0..3, seeds 1/7, 1860-frame maximum, frame skip 1, CPU/one thread, `hit_extra=[2,2]`, and the declared motor hold/delay settings. Each has 88 runs: eight heuristic episodes and eighty fixed-target/actual-spawn stationary episodes. All three have 0/8 heuristic successes and 0/80 full-episode stationary successes. These are failure-to-find evidence, not proof that the cards cannot be solved. The reports are:

| Card | Canonical H18 feasibility SHA256 |
|---|---|
| `laser_sp_corridor_01` | `ff5f7247d39af57a93be628cc5d197373a999ea1050573b35a2ff3eadf3daefa` |
| `laser_sp_corridor_02` | `2373dfcaf829ea9ca79c88da00607f5a347f6580542593ad51d1151a00e0f7d1` |
| `laser_sp_corridor_03` | `61b4d3c9150dc24c407f7450f527b9744c4f4df3df00107f59d05748403d3f7e` |

Supplemental H45 and H90 reports cover the same ranks/seeds and current four-file SHA sets. Each is an 8-episode controller run set (not a stationary-baseline report); every episode ended in death for all three cards. They strengthen the finite negative evidence but still do not establish impossibility.

| Card | H45 report SHA256 | H90 report SHA256 |
|---|---|---|
| `laser_sp_corridor_01` | `8f0eef2e6ce02103fc222a6b6ff2da5eab80abc350cd1c7a3c64ff83cd812de8` | `d30d28b41703322d3de4c0293bff18e0b71a52627908c2f6cadd4512ebae9ab2` |
| `laser_sp_corridor_02` | `7d395f8989b21143f4d8acc3fa96d692bf7be7d4e80959625edd6334ebadf646` | `bd8f89da60c44db448369f4ce0b3269014d56690844e1f086a8bc73135de3378` |
| `laser_sp_corridor_03` | `72a3464def4ae78f435a0f94ee7abf15afe6aee7378c123753dfe909af431521` | `12661120cfbbe39b2c815fc749dc46bb280757eefd230b6565105e114e8396a2` |

The separate current-observation cell follower report is classified `WITNESS_FOUND`; its independent review is `PASS` for finite-witness integrity. It completed C02 at ranks 0 and 1 for both seeds (1793/1747 frames, `done=2`) and did not complete C01/C03 or C02 ranks 2/3. It reads only current visible laser rows and player state; its failures remain `NOT_PROVEN`. All 24 recorded trajectory SHA/row/terminal checks were verified in the independent cell-probe review.

| Evidence | SHA256 |
|---|---|
| `corridor-cell-probe.json` | `fc990c4aa31fde0819afc3f0a3a5e287ad8bce8768093ae35e16a0811987865f` |
| `corridor-cell-probe-review.md` | `18e52e5935c1f4f14dce426e35c67ba8e1063d34db1c6b64be3c990058bc3ac7` |
| Canonical feasibility module compared by the probe | `02afa09a64d91a94eecee9b61d7deeb28aac81e4d489d713accb58622cd60681` |
| Cell-follower driver | `c556ff8cf851689a86626faa9348329bcf0ee0a8742fa4df488dc815c72a53d9` |

## Mechanical report bounds

Each final machine JSON has `ok=true`, an empty error list, eight complete rank×seed runs, visible/live laser maxima 8/8, and `max_idle_gap=0`. C01/C02 measure first birth 93, last birth 1485, global last expiry 1750; C03 measures first birth 95, last birth 1481, global last expiry 1721. The machine reports bind the exact four-file inputs listed below and independently trace actual laser identities/geometries against harness snapshots.

| Card | Final machine report SHA256 |
|---|---|
| `laser_sp_corridor_01` | `e4cf62997bb9a385500e43e0078dee5f0b53e967c6ce0a4b9d7e3f4f60dbf3a7` |
| `laser_sp_corridor_02` | `28f95e5c025ac4657bebc32392b8f655f36d1f40ed28a22160efaec8dcfb4c93` |
| `laser_sp_corridor_03` | `c6484b6999cfcbb6b264925ecba8cda0cc8770cb188eed9af1b79bb1a4f33e61` |

## Frozen snapshot identity

These values match the current author reports, final frozen manifest, machine reports, and feasibility reports. Any file edit invalidates evidence bound to that SHA.

| Card | `main.ecl` | `meta.toml` | `TASK.md` | `machine-spec.json` |
|---|---|---|---|---|
| `laser_sp_corridor_01` | `2a06fc8d99f64c3329eb00936343beb0fb5d711c20acf026bdddc69fad1799c2` | `280d374d49c280f24d8dee35b07c9a057d4f70eccce82504ca33038b709d207c` | `4f074081c324a28fac0da27d84fb5ff6cb66ca28d80c432f7bd253d279c95251` | `8540bea6e26a75084499a3845a965c3e15b2eaf422930fb754c99545d5e80099` |
| `laser_sp_corridor_02` | `6933461772b57146dcda295946ead8683b0f80f6f44f7cd8968f5440a4c1448b` | `ba0b492eaae3766d92253d461a72eff5ade589fe1fe52228b743b74ae46c9cf5` | `bbfcd143c05b53b8e81161c9b90c5db0217c8eb017628ad7322ce71f4ed4e10b` | `f15ef0b2ed11951dd7b2ae64d9aef29f4a43a599681a0178f132ef5db0572a0b` |
| `laser_sp_corridor_03` | `0bb5dbd2697b9bc271420a80178d0547e64e343f14afd8471a3b8bdfabd44a66` | `9edc3ebd6a18f0b0c8245b1bbae34e6fe616c8f3e3e5ab3d97acaa6baa659f59` | `6e938e665186a7af0aba01b06d2fe2df588d6c59cffa15022482f9cc9afb43d6` | `4fdad8aa85befa55a5270bb5a72079180faeac6b17c7ea965f987e44c66d017d` |

The frozen manifest SHA256 is `bb88d8aaaa9440648bfdacd4ef0703f08690680fcf1935ce9547b46636066c44`. No new simulations or trajectories were generated for this re-review.
