# Batch3 bars train source review — final round

I reviewed the frozen train-card sources and their current TASK/metadata/machine snapshots for `laser_sp_bars_01`, unchanged `laser_sp_bars_02`, and `laser_sp_bars_03`. I also read their final feasibility reports. The four card-file hashes below match `final/frozen-manifest.json` (SHA-256 `bb88d8aaaa9440648bfdacd4ef0703f08690680fcf1935ce9547b46636066c44`) and the feasibility reports' `card_file_sha256` fields. The engine laser manual and collision implementation support the geometry used here: warning is noncolliding; active laser width is full hit width; player radius is 2.5 px by default; the active bar tests a finite segment, not its infinite supporting line.

This is a source review with the supplied sampled feasibility evidence. It does not establish universal random-instance solvability or training benefit, nor does it by itself grant final card inclusion.

## Frozen card snapshots

| Card | Verdict | main.ecl | meta.toml | TASK.md | machine-spec.json |
|---|---|---|---|---|---|
| `laser_sp_bars_01` | **pass (source scope)** | `39e458a758e74583b82a1a4ec797f3db11bbb6c5ed19e8cc590f1f7d44445754` | `81f70a504d000e7515c88513c980e50d9f2d59eddfb82754722e7b85db01a58b` | `17c78b801294d42d256c1f38d413ae1a070bd9047775cb7084915c181d278b7a` | `6af2cc438adccb872362ae04035e83989f0d8e6f838b63ebf7ee6a9c5bc2549b` |
| `laser_sp_bars_02` | **pass (source scope)** | `3a5e41944bbd13992d00b37553e30a00c2f38f69d32fdde2244f7cddd635ee90` | `d27e673d16fdb6eb99d5627e9d890d913dc0040af0a3ef8658bbdef9a7951d59` | `79baa5137c4eaa7eb1b6afea17178fc7e97d6fd658f4ff88ca18404755c74ae0` | `0c84b34439b2ea49d83deea9094894dfda2b49f51e41be94f18b93435e085982` |
| `laser_sp_bars_03` | **pass (source scope; sampled fixed-point weakness)** | `d4bd04fcdf5e4454a74fa7b11a8ff2e9e61d934db19959458dcec3101ebcf94f` | `562093f086ed4b808d729a576ed012f33cf7ac51011d67b6e7f9872d7176e805` | `537a3c968e6a05ad56b7efbf7e93d04e39187654129d6dafcc0fad51a47c8e7c` | `8012636eff19d8b86f0930b5f0987848fda95b8fde4c8fa94a6b2f88a113bfb2` |

Feasibility report SHA-256 values: bars_01 `fcd3cd2905b6dbb60fd35c2235401ac205e1d6c14e15cdfc4159234d08764409`; bars_02 `efd1c5e11cc3070796bf1afdb4dc18ee17fb25a84f1384bb70029775a9ca6f53`; bars_03 `cc2711250843153aaf0e549e7e0ae5cfa34d5cbd13d196e88210b6a823ea0b4e`. The supplied final machine reports are PASS; that is a separate gate from this source verdict.

## Findings and evidence

### laser_sp_bars_01 — pass (source scope)

The current source (`main.ecl:43-58`, `TASK.md:5-15`) resolves both earlier fixed gaps. It emits four vertical bars per wave from x lanes `-192`, `-64±24`, `64±24`, and `192`; each lane moves toward the field interior while y increases. `(lane+wave)%4` assigns every x lane to each of the four y layers once in each four-wave cycle. Since waves run through 0..16, all 16 lane/layer combinations recur. For rank 0, even the minimum-length/minimum-origin envelope of those layers is `[0,156.8]`, `[152,308.8]`, `[292,448.8]`, and `[396,552.8]`; adjacent bands overlap and cover the full y clamp. Outer lanes cover the side boundaries, and the inward-shifted inner lanes overlap the outer tracks across x. Warning remains static; only active frames move the finite segments, at a positive scalar speed with near/far unchanged.

The previous `x=96` stationary column and low-rank bottom-left bypass no longer follow from the source. In particular, each outer lane enters the bottom y layer every four waves; the minimum 80 px segment plus active downward travel crosses y=448 while still within a collision reach of the edge origin. The final sampled feasibility report is consistent: the offline heuristic succeeds 6/8; all stationary modes together succeed 0/80 (including the actual-spawn baselines). These finite samples do not prove every random instance is solvable.

### laser_sp_bars_02 — pass (source scope; retain sampled weakness)

Source and snapshot are unchanged from the prior pass. Horizontal finite bars enter from both sides, fixed edge rows recur, and the remaining y rows rotate through the field. Warning, active motion, lengths, signed coordinate displacement, and rank parameters stay within the task contract. The final feasibility report has 17/80 stationary successes and no new source-level universal bypass was established in this review. Keep that result visible in any inclusion decision; a source pass is not a claim that the sampled stationary weakness is absent.

### laser_sp_bars_03 — pass (source scope; sampled fixed-point weakness)

The previous round's claim that `(0,0)` was source-universally safe no longer holds. The current schedule (`main.ecl:5-36`) uses lane centers `[32,128,256,384]`, all four directions, pair separation 64, and independent per-direction normal offsets across `[-24,24]` px. Offsets move each diagonal centerline by up to 24 px normally (about 33.94 px in its `x+y` or `y−x` intercept). The deterministic intercept sets have a maximum 64 px gap, so the random support overlaps neighboring strips. This closes the old narrow centerline gap in *possible line geometry*.

I checked finite motion as well as supporting lines. The length-plus-active-travel ranges are 272–288, 322–346, 360–392, and 386–426 px by rank; warnings do not collide, and a supporting line only threatens the player if a finite active segment reaches the point. For example, `(192,0)` is the second `225deg` bar at lane 384 when normal offset is near zero: it is born at/near that point and then moves away during active. Other normal draws can leave it clear. Thus the source includes draws that hit this location and draws that miss it; intercept support alone is not proof that each episode covers it.

The supplied actual checks show a notable sampled weakness: the offline heuristic succeeds 8/8, but stationary baselines succeed 39/80 overall (37/72 fixed target trials plus 2/8 actual-spawn trials). `still_right_upper` at `(128,80)` and `still_top_right` at `(192,0)` each survive 8/8 rank×seed trials. Other fixed targets vary, so these two point results do not prove a source-universal safe region or a safe upper-right band for all RNG outcomes. They do show a repeatable weakness on the tested seeds that should stay explicit in candidate selection and follow-up evaluation. I found no remaining RNG-independent broad bypass in the current source, so the source verdict is limited PASS rather than revise; this is not a full random-pressure claim.

## Boundaries

The final source PASS for all three cards means their current source and declarations meet this review's assigned scope. It does not erase bars_02's 17/80 or bars_03's 39/80 stationary-success evidence, certify all random outcomes, or substitute for feasibility, loader, held-out, or final inclusion decisions. No card files or matrices were changed or rerun for this review.
