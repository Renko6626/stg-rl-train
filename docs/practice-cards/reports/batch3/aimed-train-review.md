# Aimed train cards: independent source review

Review scope: `laser_sp_aimed_01`, `_02`, and `_03`, using their four actual files under `/tmp/sunyunbo/stg-laser-batch3/`, the frozen specialist contract and assigned dispatch briefs, and the two author reports for 01/02 and 03. `laser_sp_aimed_04` and original ECL were not read. The final round addendum binds machine and finite true-player evidence. No training or all-random-solvability claim is made.

## Verdicts

| Card | Source verdict | Finding |
|---|---|---|
| `laser_sp_aimed_01` | **LIMITED PASS — candidate acceptance** | Round 1 fixes the interval; machine matrix passes and a finite true-player witness exists. |
| `laser_sp_aimed_02` | **LIMITED PASS — candidate acceptance** | Round 1 fixes the interval; machine matrix passes and a finite true-player witness exists. |
| `laser_sp_aimed_03` | **LIMITED PASS — candidate acceptance** | Final machine-spec snapshot and a finite true-player witness are bound to current files. |


Engine semantics were checked read-only against `docs/ecl-lang/9-lasers.md:59–65` and `crates/stg-core/src/world/laser.rs:169–178`: `lz_aim` computes the direction from the laser's own `(ox, oy)` to player 0, then adds the offset. It does not aim from the owning boss when those origins differ. The cards call it on the new laser handle, so the reported origin-based geometry is the correct interpretation. The source uses degree literals; machine-spec angle fields are observed normalized degrees, not raw BAM values.

## Per-card source findings

The findings and four-file SHAs in this section document the initial Round 0 snapshot only. The 01/02 interval finding is closed in Round 1; use the final SHAs and evidence in the final addendum below for current status.

### `laser_sp_aimed_01`

- **Historical P1, closed in Round 1.** The initial `main.ecl:11–26` used 179-frame group starts. Current source uses rank-specific `period=110/105/99/95`, `groups=13/14/15/15`, an opening `wait(90)` inside the pattern, two one-frame intra-group waits, then `wait(period - 2)`. Group-start intervals now match the brief, with final line births 1416/1461/1482/1426. Current TASK and machine-spec agree.
- Other inspected source requirements match: 3 lines per group; 560px length; off=0 direct line with ±18° side offsets; integer-pixel x domains `[-96,-64]`, `[-16,16]`, `[64,96]` from exclusive-upper-bound `rand`; one `lz_aim` at each laser's birth and no later angle/omega/rotation/anchor update; rank 0–3 widths 6/8/10/12, warnings 90/75/60/45, active 150/166/184/202 and fade 12. The fixed boss at `(0,64)` is invulnerable and explicitly `ENEMY_NO_BODY`; the phase duration is 1800. TASK states the clamp and does not claim movement feasibility.
- Independently derived from the source: first line birth 94; 8 groups start at 94, 273, 452, 631, 810, 989, 1168, 1347, with each group’s next lines at +1/+2; final line birth 1349. Last expiry across ranks is rank3 at 1608 (`1349 + 45 + 202 + 12` under the authored frame convention). Since the longest warning+active lifetime is 252 and the period is 179, at most two groups overlap: 6 visible/live lines, below both concurrency budgets. These calculations do not cure the interval deviation.
- **Frozen-file SHA256:** `main.ecl` `091da87f6cad007d1fbfc76ee42da1532a6cb02af0a2186123ce1dc6df17720a`; `meta.toml` `6c7ce0c9fdf632aedea54b2fd6b2419a1a324e66ed9a7f2c3d650184dd014723`; `TASK.md` `c18fa7de874154ed2d190b358d60fed5e11804192596fcc85543e1b82011bddd`; `machine-spec.json` `7ae8592af14d2d90bebf49d50ec1c6514509122639785dc25cdf6fc74218ba2e`.

### `laser_sp_aimed_02`

- **Historical P1, closed in Round 1.** The initial source used 179-frame group starts. Current `main.ecl:6–28` sets periods `110/105/99/95`, counts `13/14/15/15`, an opening `wait(90)` inside the phase pattern and `wait(period - 2)` after two one-frame intra-group waits. Current TASK and machine-spec agree.
- Other inspected source requirements match: 3-line central fan, common randomized x from `[-32,32]` inclusive via `rand(65)`, y=64, length 576px, offsets -22°/0°/+22°, and one-time birth `lz_aim` per line. Width, warning, active and fade are 6/8/10/12, 90/75/60/45, 150/168/186/204, and 12 respectively. There is no post-birth retarget/rotation. Boss/phase skeleton and TASK feasibility caveat match contract.
- Independently derived: first line birth 94; 8 groups start at 94, 273, 452, 631, 810, 989, 1168, 1347; last line birth 1349. Maximum expiry is rank3 frame 1610 (`1349 + 45 + 204 + 12`). Longest warning+active lifetime is 249, giving at most two overlapping groups and 6 lines. Again, this is within the concurrency budget but does not satisfy the required interval.
- **Frozen-file SHA256:** `main.ecl` `96ca865537bdc09085df50ca29fc4aafa133f14c9c8a22b769b77cba9592b423`; `meta.toml` `5167f9832cbb11d642a657994a35551aa44f5f6aed80afd7df122c13ed91fb3c`; `TASK.md` `31fa2e0a1ddef0ce9ff104c9451cb6d207f5e7164d3d7742f28be190d41676dc`; `machine-spec.json` `d39a2d27ad2a3c0a185100c672d022ac9548eb06950438060e3bffeb572688d0`.

### `laser_sp_aimed_03`

- **No source blocker found.** `main.ecl:6–16` emits three lines synchronously from alternating x=-176/+176 origins at y=64. Every line is aimed once at birth, with offsets 0°/-22°/+14°; there is no later retarget or angular motion. The direct ray addresses the stationary-target miss from all-nonzero offsets. Length is 560px. Rank settings and the fixed invulnerable no-body boss/1800-frame phase match the contract.
- `main.ecl:23–25, 52–60` sets rank-specific group periods to `[99,105]`, `[90,98]`, `[82,88]`, `[72,76]` inclusive and opening wait to `[90,91]`; all are within the assigned 60–110 group interval and the 90-frame opening rule. Randomness affects spawn phase/timing. It does not use an integer angle cast; `lz_aim` is applied to each newly created laser handle and engine semantics use that laser's origin.
- Independent upper-bound calculation from the exclusive `0..groups` loops and TASK maxima: first birth is at most frame 96; group counts are 14/15/16/19. Latest final-group starts are 1461/1468/1416/1464, respectively. Add within-group lines at the same frame and the declared `warn+active+fade` to get latest expiry 1725/1729/1674/1719, all before 1750. Worst overlap using shortest spacing and lifetime is 3/3/4/4 groups, hence 9/9/12/12 lines; within 16/20. Group periods are below each rank's `warn+active`, so the source schedule has no internal warning-or-active gap. The submitted machine-spec global observed bounds (first 95, last 1428, expiry 1683, concurrency 12) are consistent with being observed seed/rank samples rather than these all-random upper bounds; TASK gives the conservative formula separately.
- **Frozen-file SHA256:** `main.ecl` `353496f9017b69bdfddf49d4101cb366016259806440fe24761c01137658fcba`; `meta.toml` `a7009547a41fe41b7a0c9064d7675ff2cdb1f79b2fce9108877d575705033c5e`; `TASK.md` `a0f8de8fba326fe8b1948485c16ae71aee233d08a6f943e7a3b90ca5586debb4`; `machine-spec.json` `99c6eb2525d2006d3cd0a75facc5717bb889dc6edf9b23eabddb839a324e50b1`.

## Gate status

The initial author-stage evidence above is superseded for final status by the bound Round 1 machine and feasibility reports below. Final dispositions are limited to reviewed source, the required mechanical matrix, and finite true-player witnesses. They do not assert that every random instance is avoidable, that every edge point was exhaustively covered, or that training improves.

## Round 1 final snapshot review (2026-10-01)

### Current source and machine agreement

I reread the current three source snapshots from `/tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_0{1,2,3}/` and checked all four file hashes for each card against `final/frozen-manifest.json`. The source confirms:

- 01/02 now use rank periods 110/105/99/95 frames and 13/14/15/15 groups. `phase_begin` starts immediately; `aimed_pattern` begins with `wait(90)` (not a delay in `main`) and first line birth is frame 94. The two one-frame waits plus `wait(period - 2)` produce the declared start-to-start interval. Last line births are 1416/1461/1482/1426.
- 03 retains three same-frame lines alternating between x=-176/+176. Its periods are randomized within inclusive 99–105, 90–98, 82–88, and 72–76 frame bands, with 14/15/16/19 groups and opening wait 90–91. The final machine-spec SHA is `09751ff…557ac`; ECL/TASK/meta hashes remain the previously reviewed values.
- Every group has a direct `off=0deg` laser plus side offsets whose absolute values are within 8–60°. Each new laser handle receives one `lz_aim` call at birth; no later angle, omega, rotation, or anchor mutation appears. I verified read-only against engine docs/source that `lz_aim` computes player 0 relative to laser `(ox,oy)` and then adds the offset, so these sources aim from the laser origin rather than boss owner. The source uses degree literals, not `int as angle`; 01/02's `int as fx` random x values convert integer pixels to Q16.16 and match the TASK exclusive-upper-bound `rand(n)` domains.
- Each script has one fixed boss with `set_invuln(65535)` and explicit `set_enemy_flag(ENEMY_NO_BODY, 1)`, plus no ordinary bullets. Ranks 0–3 map to Easy/Normal/Hard/Lunatic, widths 6/8/10/12, required warnings, and fade 12. 01/02 stay under 1500 last-birth / 1750 expiry; 03's measured latest is 1428/1683 and its TASK random-upper-bound derivation stays under those limits. Source-derived max count bounds are 9/9/12, zero internal warning/effective idle gap, within 16 visible and 20 live.

All three bound machine reports say `ok=true`, `errors=[]`, and cover ranks 0–3 × seeds 1/7 with eight complete 1860-frame runs, six zero diagnostics, `PHASE_ENDED@1803`, keyframe coverage without errors, and successful harness/trace cross-check. Aggregate measured bounds are 01: first/last/expiry `94/1482/1738`, peak visible/live 9; 02: `94/1482/1740`, peak 9; 03: `95/1428/1683`, peak 12. The machine JSON's `acceptance_status` remains `mechanical_pass_independent_review_pending`; this report supplies the independent source semantics for these three train cards. It does not prove correctness over the entire random domain.

### Finite true-player evidence

The three feasibility JSONs bind to the same four card SHAs as the frozen manifest. They record ranks 0–3, seeds 1/7, CPU `stg_rl` 0.4.1 / engine 24, `hit_extra=[2,2]`, and player clamp x `[-192,192]`, y `[0,448]`. The non-policy observational heuristic finishes with `done=2` on 4/8, 4/8, and 3/8 episodes for cards 01/02/03 respectively. I checked each counted-success trajectory exists, hashes to its JSON SHA, and its last row contains `done=2`. This is a finite physical survival witness for those named rank/seed runs, not trained-policy evidence.

Across these reports there are zero stationary-baseline episodes that both finish `SUCCESS` and have `stationary_qualified=true`. Qualified stationary windows are at least 120 frames; they are not evidence of whole-card survival, and all sampled fixed-point baselines ultimately terminate in `DEATH`. Targets not reached or not proven retain their explicit status. Heuristic deaths and unsuccessful stationary probes are `NOT_PROVEN`, not evidence of mathematical impossibility. The spawn, edge, and corner targets are discrete samples; they do not exhaust every clamp-boundary point or every random sequence.

### Snapshot and code bindings

File order below is `main.ecl / meta.toml / TASK.md / machine-spec.json`. All listed current source SHAs were checked against the manifest. The manifest SHA256 is `bb88d8aaaa9440648bfdacd4ef0703f08690680fcf1935ce9547b46636066c44`.

| Card | Four-file SHA256 | Author report SHA256 | Machine JSON SHA256 | Feasibility JSON SHA256 | Feasibility index SHA256 |
|---|---|---|---|---|---|
| 01 | `790e41c56727898e475cf12380b83c3a5a493fd7463b3978309e234e9305ba8d` / `6c7ce0c9fdf632aedea54b2fd6b2419a1a324e66ed9a7f2c3d650184dd014723` / `d3b497088355eff009775ad8d0bde8c8cf67221c908c1d7785f2ca798d6cc742` / `0cc2e36cadbd945affc44ff589cac7779b1cf0593276806e2fb5eaffe3b6e44a` | `aimed-0102-author.md`: `d8d2b86b8ff2a312c4b0ee20eefae44b5173385c6f8ae28f77565e94ba69fbad` | `2fa9651b9bc6440fb49197e17c010dfc2ad74513a86ea325ca9c2e58ce7d7ad4` | `fbb43393bc5915f50f4a81e3272e852cdeca98b2efcf5e16260d1ec97913789b` | `4450febc1a602a88178b50de0c60c88c65e00395cccdf5c6697ad9f64ee4a41b` |
| 02 | `610742bdba3e9ae4213493f343cb6f9ca330a775e4147852ae826a3d05aeaf92` / `5167f9832cbb11d642a657994a35551aa44f5f6aed9a7f2c3d650184dd014723` / `e7965f054bfea806883886ccd82e901333d5890de1bc7158f6f48a4a4740f1a3` / `825b62c694178b671c8ad0968f0aab887bf07c06d07c212f8838ecbf50030e0e` | `aimed-0102-author.md`: `d8d2b86b8ff2a312c4b0ee20eefae44b5173385c6f8ae28f77565e94ba69fbad` | `9f8830b416594e9f0d9643d68b8e329d7473bf5ea17e360e894aca86451fb2e8` | `42e7f74dc41b1714289b8d3851646d41f05dd760338ed5bfcd75b69783bc5029` | `bf127de18023bc6835fa208df1f5b2cdf97cefa999694c7addb8bcf4ffa1c99d` |
| 03 | `353496f9017b69bdfddf49d4101cb366016259806440fe24761c01137658fcba` / `a7009547a41fe41b7a0c9064d7675ff2cdb1f79b2fce9108877d575705033c5e` / `a0f8de8fba326fe8b1948485c16ae71aee233d08a6f943e7a3b90ca5586debb4` / `09751ff733ac8d17d855897d83e108b9bdf2c7bc957ed141d7f3f06bb4e557ac` | `aimed-03-author.md`: `94e9e575b5238899dcccfa27f8b426e3e128412e184d17d21275bb328fa72189` | `21fa3db562149a807bc06c1eefd21b448908310f5c2ef1bd389b92c319ace6ba` | `0b1a76411ee20ef4f43dacb83fa0e9abee7f8cd7c679777b9dbbdaa853aa9e7c` | `ff0aecd69a0a0dba87272beb6d9ae974aa6860c41ab3c7da4e40f4e7df285e82` |

Machine validator code SHA256: `src/stgtrain/specialist_validate.py` `0bf52940255c0c4f8d08896adbc42ac6e4b39ce229ad37e1bed4f778c283e909`; trace source fingerprint `dd267e137118483efb2cced40094b539dcd2cce23ee25021f068535c819d9c35`; trace source file SHA `tools/laser_trace/src/main.rs` `479b60359c93ff1b0dea9232bdfc7210603ec121e5c4d8d9709edeb8aedd50c0`; executable SHA `669f316844e5527e261345d939e08e44de59ebff4d1374d53c2c81470beb5a82`; harness SHA `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`. Feasibility code SHA256: `src/stgtrain/specialist_feasibility.py` `02afa09a64d91a94eecee9b61d7deeb28aac81e4d489d713accb58622cd60681`; each feasibility index's report SHA matches its JSON file. Machine reports bind engine commit `5dfc08d45f8f0c359c301de94d6fe7bb399df889`, core/compiler/derive source SHAs `dcb97316b86c3177d3cfe8cd548648f963e4323374e686336ce27d26337feda6` / `3dfaf21fccf2296c7ea2bba2e2eeac5a53f3904d0f7f1c5689569d783792c787` / `8df365b4eefb4ff92e63cb20ab8c0f51a0ba28d8d29f48eaa34c9021c16f40db`, and `stg_rl=0.4.1`, `ENGINE_VER=24`, table hash `37a7ff12fe40e24e`.

**Final review status:** 01/02/03 are accepted as limited train-card candidates under the finite source+mechanical+physical-witness scope above. Heuristic failures remain `NOT_PROVEN`; no card is declared universally solvable, and no learning outcome is claimed. Held-out 04 was not read or used.
