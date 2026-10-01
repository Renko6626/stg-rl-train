# Batch 3 held-out source re-review

Scope: the five frozen `04` layouts only (`stagger`, `corridor`, `sweep`, `aimed`, `bars`). This is a scoped re-review, not a clean-blind review: I reviewed earlier versions of these same held-out layouts. In the first review pass I also read the batch feasibility index, which listed aggregate statuses/counts for other card IDs; I did not open their card sources or reviews and did not use those aggregates here. The sweep author report separately discloses that an earlier `--all` validator call printed sibling card identifiers/statuses in truncated output, while saying no sibling card files or reviews were opened. I did not open training card sources or training reviews. Current four-file SHA sets all match the frozen manifest.

I re-read each current held-out ECL, `TASK.md`, `meta.toml`, `machine-spec.json`, and its author report. Laser movement semantics were checked against `/data/sunyunbo/www/stg-engine/docs/ecl-lang/9-lasers.md`. The five final machine reports each have `ok=true`, zero errors, and `mechanical_pass_independent_review_pending`; their recorded matrix is rank 0–3 × seeds 1 and 7. The source review below is separate from mechanical acceptance. The feasibility reports describe an observational heuristic, not a trained policy, and their selected trajectories are bound by the reports' SHA fields.

## Results

| Card | Scoped verdict | Moving heuristic | Stationary samples | Review conclusion |
|---|---|---:|---:|---|
| stagger 04 | **pass, finite evidence** | 8/8 | 34/80 | No target survives all eight rank/seed cases. Lower points now survive only 1–3/8 each; sampled corner/upper points vary from 3–6/8. The eight-phase source has no broad region I can show is excluded from every legal phase and random setting. |
| corridor 04 | **pass, finite evidence** | 8/8 | 3/80 | Stationary survival is confined in this sample to the bottom edge: the actual spawn location at rank 0/seed 7 once and `(192,448)` at rank 0/1, seed 7. No repeatable safe region appears in the checked targets. |
| sweep 04 | **pass, finite evidence** | 8/8 | 17/80 | `(192,0)` survives 7/8 samples, a strong empirical fixed-point result. The finite 180-frame sweep and allowed origins/angles include instances that cross that point; I find no source-guaranteed safe band from the parameter ranges. |
| aimed 04 | **pass, finite evidence** | 2/8 | 0/80 | Each group includes a direct birth-time line; no tested stationary location survives. Heuristic deaths are not evidence that the card is unsolvable. |
| bars 04 | **pass, finite evidence** | 7/8 | 18/80 | Stationary survival clusters at `(192,0)` (7/8), `(-192,448)` (5/8), and `(-128,80)` (4/8). Those are finite-seed observations; the 32-lane source schedules lines across both full player-coordinate axes and I found no broad region that all legal lane/joint settings leave untouched. |

These verdicts mean only that I found no remaining source/spec defect or source-guaranteed broad static bypass within this bounded re-review. They do not mean every random realization pressures every point, that all instances are survivable, or that the cards improve training. A stationary success is real evidence for that tested rank/seed/position, even when it does not establish a range-invariant safe zone. I did not request coordinate-specific tuning from these sampled points.

## Per-card review

### `laser_sp_stagger_04`

The current `main.ecl:32-78` implements the disclosed eight-phase layout: four diagonal quadrants, three overlapping center-y bands, random x within the phase's half-field, and a per-wave BAM perturbation. Paired origins remain at fixed normal separation; their direction is fixed from warning through expiry. The current `TASK.md:7,16-20,28` describes those broad domains and explicitly treats the checked coordinates as re-test points, not design targets. The old edge-anchor source and its observed lower bypass have been replaced; the current machine file and mechanics validate against the new SHA.

The current held-out report records 8/8 heuristic successes and 34/80 stationary successes. By fixed target, actual-spawn survival is 1/8; center-lower 1/8; left-lower 3/8; right-lower 3/8; left-upper 5/8; right-upper 4/8; top-left 3/8; top-right 5/8; bottom-left 6/8; bottom-right 3/8. No tested target survives all cases. The parameter windows place possible up/down diagonal rays throughout the lower and upper field, so the previous blanket conclusion of a persistent lower safe band is no longer supported. The finite baseline set still finds intermittent fixed-position survival, notably bottom-left; this must remain disclosed as a sample result, not generalized to every seed or nearby point.

### `laser_sp_corridor_04`

`main.ecl:25-26,37-88,91-97` retains the same pair spacing, uses continuous `lz_origin` updates only after the warning wait, then lets the laser entity fade and expire. Current `TASK.md:30-32` and the final machine report include the per-rank fade/expiry and terminal empty-field frames. I found no remaining source/spec mismatch in the continuous orthogonal handoff or bounds.

The final held-out run summary is 8/8 moving heuristic successes and 3/80 stationary successes. Two occur at `(192,448)` on seed 7/ranks 0 and 1; the third is the actual spawn point near `(-13.86,448)` on seed 7/rank 0. This is localized sampled survival on the bottom edge. Other tested stationary points die, so the evidence does not show a broad persistent safe area.

### `laser_sp_sweep_04`

The previous out-of-range geometry example is corrected in current `TASK.md:19-21`. All four examples now use origins inside the implemented bands, and their listed corner distances and bearings agree to rounding. `main.ecl:9-18,30-36,39-50` keeps the asymmetric origin ranges and installs positive/negative `lz_omega` only after warning; the manual confirms the result is continuous per-frame rotation during active/fade, with warning static.

The source-domain check matters for the frequent top-right survival. For `(192,0)`, a left-origin line can point at the corner from an allowed origin such as `(-150,100)`; the rank-specific allowed start-angle interval and 180-frame negative sweep contain that bearing for some valid BAM perturbations. Thus `(192,0)` is not a point that all source-allowed lines must miss, although the right-origin sweep alone does not aim at that corner. The 7/8 stationary successes are a strong result for these tested seeds and warrant keeping the caveat in the author/coordinator record, but the source ranges do not guarantee the same safe result for all random draws. I found no range-invariant safe band in the finite-length, positive-omega source geometry.

### `laser_sp_aimed_04`

`main.ecl:14-34` creates a center line with zero offset plus symmetric 8°, 16°, or 24° side lines from one of the three declared origins. Directions are computed once from that origin to the current player position; there are no later aim/omega/rotate writes. Current `TASK.md:18-20` has the corrected per-rank last-birth, expiry, and frame-1800 zero-laser snapshots matching the final machine report.

All 80 stationary tests die, while the sampled moving heuristic survives 2/8. The stationary result agrees with the intended direct-birth pressure. The six heuristic deaths are finite-checker failures, not proof of impossibility; the source review has no fixed-position bypass finding.

### `laser_sp_bars_04`

The current `main.ecl:28-91` schedules sixteen groups of four bars across 32 equal-spaced lane indices per direction. Warning geometry stays fixed; active motion uses positive speed and `lz_origin`; the source checks `lz_alive` before each write. Current `TASK.md:11-15` correctly binds activity and interval to the same `joint`: rank 0–3 overlap is respectively `158+18j`, `143+18j`, `128+18j`, and `113+18j`, so all values of `j∈{0,1,2,3}` retain overlap. The earlier impossible mixed-`joint` calculation is corrected.

The final report records peak visible/live lasers 16 and 7/8 moving heuristic successes. Stationary survival is 18/80, with the most frequent checked point `(192,0)` at 7/8, followed by `(-192,448)` at 5/8 and `(-128,80)` at 4/8. The lane schedule reaches all 32 fixed coordinates on each axis over its direction groups; speed, length, and joint offset vary, so not every random realization hits each coordinate. These observations are not a source-level proof of a universally safe region. They do show intermittent stationary survival and should remain reported as finite-sample evidence.

## Mechanical and feasibility evidence

All machine JSON files are under `docs/practice-cards/reports/batch3/final/<card_id>/`. Each has `ok=true`, `errors=[]`, and `acceptance_status=mechanical_pass_independent_review_pending`. All five held-out feasibility JSON reports match the current four card SHA values. Each successful selected trajectory hash below was recomputed from its file; full run rows and additional trajectory hashes are in the bound JSON report.

| Card | Moving sample | Selected stationary evidence |
|---|---|---|
| stagger 04 | rank 0/seed 1 heuristic: `3c8fd6f942ee4966a762d99f1dea09e8a3cb370e36a8871241616dd1e0a534e0` | actual spawn, rank 1/seed 7: `f724c34d137078ba70a622e2f972aeba3e6992b94d335ce96e6b9435b5ac5bac`; bottom-left rank 0/seed 1: `aa098adb4be35d6f9723fabbc3713818a8a055b7aef5574d61ca4bd26e9251d0` |
| corridor 04 | rank 0/seed 1 heuristic: `086d9f513a78cf2050a15d1b723b4dbc52a4ffe6d7e4889306846086fd38c1a4` | actual spawn rank 0/seed 7: `a4f66df9b4d4410241fd388803a0d91f4fe6d0d130a9a866c8155d815b97877f`; bottom-right rank 0/seed 7: `a5ea2429e5422f4b061f6bfa6adaec5abdd6fca8af938519c4a53e30e9eafd04` |
| sweep 04 | rank 0/seed 1 heuristic: `fc038c4e718d041bc14f4f95446e3f83c0e520ae4351be160d40c6b8ce852e0b` | top-right rank 0/seed 1 survives: `56d9dd07d93c849888ca97e30d1405a80213ccd196da1d39a33aab483e0150a8`; rank 3/seed 1 dies at the same target: `e07d1816ae7795107fcef0dac569b316426c827cc6b8222006596c0f2e8e3ccf` |
| aimed 04 | rank 0/seed 1 heuristic: `52b9c73bb72ec6a6beebc89c6c54fb464ae252f18b4ef614a9feca4a674609c5`; rank 1/seed 1 heuristic death: `738972ba1f6a75d545c48b7a4d361fa98e4e6015ab3a9f19c144ae4ac8158251` | none of the 80 stationary runs succeeds |
| bars 04 | rank 0/seed 1 heuristic: `3a694581004efa2394f2e75fc48f08c0f46cf83f998357f9a3355a0e58af41d8`; rank 2/seed 1 heuristic death: `d9badfd561870c4053875757546451de8a537289eafdd5f5bc80f83c33aa4720` | top-right rank 0/seed 1: `00e84689e6dc8ce109971d9f95d568a9bc9a5058f741a7c97f5ab5faf915b538`; bottom-left rank 0/seed 1: `1346e369f433601215a4a3d10b962daf8c240f149452ddf00fb95d62bf172785` |

## SHA256 binding

Frozen manifest: `docs/practice-cards/reports/batch3/final/frozen-manifest.json`, SHA256 `bb88d8aaaa9440648bfdacd4ef0703f08690680fcf1935ce9547b46636066c44`. The manifest's four-file values were independently recomputed from the five held-out directories and match. Author reports are included by their current hashes.

| Card | `main.ecl` | `meta.toml` | `TASK.md` | `machine-spec.json` | author report | final machine report | final feasibility report |
|---|---|---|---|---|---|---|---|
| stagger 04 | `86251ae78bba2e3ab7ed72e6c94930d1024a62e3017678b64c985c7ca09d8129` | `40538c594942073f32839d6d4ea2c3ef7a3532122549b2a798d88a2d920d4b10` | `54bede6f08f25727128502ed4ea77ab7b1bb15e3d2432ae446c90c448df792d5` | `2206f524e24d1786935215b0432e3eade116f25e12396b7d1d61c577fbef30c4` | `455da169aad902e04ce6c41a1eef78bd4f11f3d497d434bb18931e6655f56f29` | `e4d5485fb8b1233a3562e623acdb798fa0bd8bc9019a873090bea90bc00fd3c2` | `b7db92876522b562d611695dc96faa01190265fa421de040b21d2095a89ce0c1` |
| corridor 04 | `962ce277cee16c66bd4bac128487ba29a8e74f1d4fcbb5aa8ed805b7d2b715dc` | `eba3687b90de76c7447c1056d013a1d317d84761d4f0861fdde902edaec4a1db` | `b3d88c406e52b77577d825127f55c37d8b73e73db481faf57877ec1fce07908a` | `c06818521bf9e7948275e8be0c53b39a8fa9761b08db7fa0d8dfdd825b69f652` | `84befb94c3a859637141ad0f43d6a6ff8150332b8c5261f1a868fe4a32e75d6f` | `ec0d5d88ca7a02e93869b834cc1ad928767924ae9567017cef527d317b5336d1` | `a850f9206685ba0c7eca3e1edf55192dd72389e401b87e6967dc0e8a0b5c0167` |
| sweep 04 | `b537d82e9d0b748b4fd23e897cb0e4e1f645ac32353f472a61cbd4693863d4a7` | `4383090e06848fd16a6c80e64eb303016f0d27e0ee2995999757e4a5d1cdc277` | `3d785f4a7758af19ddb7819ab5199675586c4a88321d9344388a0c3d10ff7896` | `3e09d23424d32b81656dd8ad8811c086ac2d3a33ae271a2aa66422e46d57f303` | `0a3871c494b7207d029ee22f8f91a41e67f9958c1307a97635a392f6042e2ec8` | `27545eafd160be92686064ab6a08ba50616e1ae9cf1056aa99801ac3d850fdbf` | `a69dadf16cd11b1bd6685322c83b246c59fc9664fa77010caaf0cc9aa1cade14` |
| aimed 04 | `c466b5f6d096b3e04dfa852aa8bb8ad964bb686983fbc3fbb125d27e595124b7` | `b4bd074c8f84f8432d1577984f68c9233a1817cb6149d5179d650c442751cf29` | `0168cf6664eaf862ce25eacdfef0188307a288b670afe37d0d97733b31506bad` | `b24744cd2b2b612c3776d278b159c01e3a3f8574855b1762e00fda8d423a02b9` | `ef1442c04bbd8be806715a795aee37136fd02507eb581b23be37d1eafdb13f42` | `4ff9b5faee770a9d28e4cccbcfc4ee1047d827b7d275a317d98b669d265fa9e2` | `76cc7650846c5eedf91f17b98285201c082014e7ddb104e55431a8c7a75e2b31` |
| bars 04 | `dee59177160d8e750765d8c52924ae615c8860f26e30f307833730ffeda122bf` | `1414ab1f9dd7e462d25934da226a4555a29069b50099358e707aff015eff195b` | `874e10ab298399c2ed940dd8937ca8ca19c6bd87e50effb61b1803081ebf177b` | `eb981b8a01bc50705ba1983b357e98c30a989e5ff49e51cfb795147ed8026c88` | `9073e7a86ed5f56de3eecc8188936ce75007eb926e797b9b676d6fcf2ebd2780` | `bae4248c14f8f95d321745df3a04f1999de83c1d57b12f00e9e907393b7ae8ea` | `5aeffe4c73c32b0f6fe41452b019c83ef20df62e94695a5ac000bc66ebf4f7ce` |
