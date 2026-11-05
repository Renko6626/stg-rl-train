# TH18 r3 downstream / laser audit, 2026-10-22

Read-only audit. TH18 v1.00a MD5 9969cac756098c1da05a81de45437a70. Native addresses below belong to that exe. Production files were not changed. Temporary reproductions use real production extractor and canonical sa_model_fill, not a mirrored algorithm. No training, broad evaluations, Windows run, or browser interaction performed.

## Proven defects / limitations with practical impact

### 1. Both ordinary Line and Infinite lasers are absent from the actual model

Observation: `renkolab/mods/th18.v1.00a/autoplay/native/th18_extract.c:149` excludes deletion state1; `:157` admits Infinite2/3/4; `:167` stores native state unchanged for BOTH classes. `stg-agent-proto/c/sa_model.c:139` skips every state >1. Shared graph expects warning0 / active1, not native states.

Native evidence extends the previously known Infinite issue to Line:

- Line initialization at **0x449108** writes `mov dword ptr [ebx+0x10],0x2`. The routine starts0x4490d0 and sets the actual Line native state2. Default state0 in `th18_extract` existing `tests/test_extract.c:158` is unrealistic for normal initialized Line.
- Manager0x4487d3 skips/deletes state1, not state2. Other native manager gates are flags&6 cancellation and flags&8 graze-only; at0x4487e9 it calls virtual tick+0x10.
- Line tick0x44a4f0..0x44a949 has no +0x10 state filter; it processes EX/movement and skips collision when out of bounds (return0x44a801); live path calls collision slot+0x34 with mode0 at **0x44a82e..0x44a834**.
- Line collision0x44a950 has no state filter. Its real geometry gates are len>16 at0x44a970/73 and width>3 at0x44a97e/85.
- Infinite collision **0x44ce93..0x44ce9e** explicitly accepts native2 or4; rejects3. Infinite tick state3 ->4 at0x44cce6..0x44cd06 when integer timer+0x1c >= start timer+0x7b8; collision call follows at0x44cdca..0x44cdd0. State4 ramp width becomes state2 at0x44cd20..2d; state2 later transitions5 (fade, excluded from collision)0x44cd30..68.

Independent check in actual r3 bundled DLL (imagebase0x10000000): `_sa_model_fill`0x10008410; **0x100089bc** loads laser state byte; **0x100089c4** `cmp bl,1`; **0x100089c7** `ja 0x100089b5` skips. This is present in the package, not merely current source.

Temporary real end-to-end reproduction `laser_repro.c` in this directory prints:

```
Line native_state=2 world_lasers=1 world_state=2 graph_lasers=0 half_h=4 len=100
Infinite native_state=2 world_lasers=1 world_state=2 graph_lasers=0 half_h=4 len=90
Infinite native_state=3 world_lasers=1 world_state=3 graph_lasers=0 half_h=4 len=90
Infinite native_state=4 world_lasers=1 world_state=4 graph_lasers=0 half_h=4 len=90
```

Candidate local fix (not implemented): map ordinary live Line2 -> shared active1, Infinite2/4 -> shared active1, Infinite3 -> shared warning0. Keep native1/Infinite5 excluded and retain actual geometry/flag gates. Do NOT map2/3/4 all to0: v8 token column12 is `(state==0)` and would tell the trained actor all hazards are warnings. Keep raw native state in diagnostic report if remapping world state. Existing Infinite countdown formula `ceil((start_timer-timer_float)/dt)+1`, minimum1 (`th18_extract.c:179..181`), has a native timing basis: the transition test happens before the manager increments timer0x4487f0 onward. At dt1,current20,target30 it is11 callbacks to first collision. Check this contract with a native-backed staged snapshot if repairing; do not bless current raw state propagation as valid.

### 2. First640 candidate truncation can discard the closest circular bullet BEFORE graph TopK

`world.h:9` sets capacity640; `th18_extract.c:97` simply drops eligible circular rows after first640 in linked-list traversal order. No proximity selection occurs. `sa_model_fill:70..85` later clamps640 and applies envelope, then graph sees at most those survivors. The graph's K64 cannot recover omitted native rows.

Temporary real extractor+fill reproduction uses641 native nodes, first640 at(0,100), final node(0,401), player(0,400): `native_nodes=641 world_bullets=640 dropped=1 graph_bullets=640 near_present=0`. Graph-only check with the near bullet placed in input row639 selects it correctly. This proves the loss occurs before ONNX.

Training differs: actual B/u1000 saved `runs/job-b3ef72c1ca44515d/20261006-151317-request-light-shift-k8/config.toml:18` has bullets_cap1024. Engine `crates/stg-rl/src/encode.rs:180..189` selects nearest cap by `(center distance squared,pool index)` before writing ascending pool order. Deploying a fixed640 raw tensor is expected graph shape; choosing the first640 unsorted hazards is a stronger adapter loss than training's proximity cap. Count threshold occurrence in actual logs before claiming it explains a particular death. A local nearest640 policy can preserve graph signature; changing caps/signature/model would require user architecture approval.

### 3. Unsupported geometry disables the whole AI frame

Shared plugin `renkolab/mods/_shared/stg-ai/native/plugin.c:428..431` returns before model and key replacement if ANY rectangular bullets, curved/unknown lasers, or unsupported enemies count is nonzero. It logs `unsupported_geometry`. This is more consequential than merely dropping those hazards from an otherwise running actor. Existing safety boundary awaits user's geometry choice. Do not silently change it in this audit.

## Exact graph6 path, expected lossy selection, and radius units

Actual model SHA256 **e47016c892fc7b0a9667b959d6e06ee10bff4261ea805022b7b8f4e04b7bc7f1**, verified from dist file AND r3 ZIP `TH18-AI/model/b-request-light-shift-k8-best.onnx`. Manifest agrees with graph input shapes and code.

Canonical flow:

1. `policy_model.c:255` calls canonical sa_model_fill on the actual world, immediately `:256` calls sa_onnx_run.
2. `sa_onnx.c:56..74` binds G_in directly: bullets640x5/bool640; enemies256x6/bool256; player5; target2; held inputs; lasers64x12/bool64; laser_start_len64. `:394` creates ORT tensors around that storage; `:432` runs. No second float conversion, coordinate scaling, radius inflation/halving, or state remapping here.
3. `export_onnx.py:247..264` constructs RawObs from the raw arrays. Canonical fill copies bullet x/y/vx/vy/radius unchanged (`sa_model.c:78..82`). Player radius is copied from world at`:58`.
4. Actual saved config and manifest: danger_topk_v8, frame=static, dt=false, bulletK64, enemyK8, laserK8, density enabled; 15dim player token; one shared bullet/laser attention layer.
5. Thus bullet TopK is **CURRENT edge distance** `||bullet-player|| - br - pr`, with **NO d_max cutoff and NO predictive horizon selection**, from `danger_topk_v6.py:47..60` / export`:153..159`. Manifest horizon60,d_max128 do not govern dt=false selection. Pos/vel/radius token scales are /192,/8,/8, inherited `v1.py:78..84`, then distance/time columns are trimmed. It is expected that only64 bullets receive individual tokens.
6. All surviving640 raw masked bullets, including the576 outside near set, feed density2x14x12 at32px cells (`v1.py:114..137`): count and approaching-speed sum. Density loses radii, exact position and detailed motion; y/x outside grid clamp to edge cells. Raw bullet envelope is separate: x[-256,256],y[-64,512] in `sa_model.h:45..47` / `sa_model.c:75`. Border inclusion is exact comparisons. No current evidence that ordinary TH18 coordinates are shifted/swapped by this path.
7. LaserK8 is nearest CURRENT rectangle distance, not future sweep/activation priority (`danger_topk_v8.py:56..63`). Other admitted laser rows receive no density representation. Equal-distance TopK tie ambiguity remains an expected known limit when >8 ties compete; not evidence for reported ordinary bullet miss. Model has no detailed future ECL trajectories.

Actual ONNX graph inspected: TopK constants64/8/8; bullet key producer `where <- sub_3 <- norm(relative)-radius-player_radius`; raw laser14 token output `stack_3`; no unknown alternate featurizer. `graph_probe.py` temporarily adds intermediate outputs without altering production ONNX.

### No maximum32 radius clamp downstream

Canonical fill accepts/copies any finite native br already extracted; there is no32 cutoff in fill or configured graph. Actual ORT input radius56 yields selected radius feature **7.0 (56/8)**. Therefore legitimate base28*scale2 must remain56; introducing a32 clamp would be a new underestimation. Radius scaling in TH18 happens upstream at extract`:93`; downstream does not scale it again. This is a useful negative finding, not a proposed fix.

### Player radius is effectively invisible to this trained actor

`danger_topk_v1.py:100..101` player token includes x,y,focus; v2/v4/v5 add prior action and hold durations, not hit radius or speeds. With static/dt=false, pr only subtracts a shared scalar from all bullet/enemy TopK keys, normally preserving rank; computed distances are discarded. Laser14 tokens also omit pr. Actual bundled ORT check pr3 ->30, otherwise identical valid input: identical selected indices and logits maxdiff0.0. This is an existing model information limitation, not proof that the actor internally guarantees any geometric clearance. Changing runtime pr alone does not inform it of changed card body size.

Actual training record config hit_extra=[0,2]. `envwrap.py:410..441` randomizes actual collision radius per episode, intentionally hidden from actor. Current engine base `tables.rs:204` raw163840 =2.5; character1 inherits via`:330`; RL env character1 at`env.rs:275..277`, hit_base+extra at`:361..365` after reset`:420`. Thus intended training body range2.5..4.5 (subject to snapshot/source identity; manifest is not a full physics snapshot). Saved env.json records stg_rl0.4.2/ENGINE_VER24/tables_hash37a7ff12fe40e24e. Do not call it a fixed known3px actor.

## Collision convention mismatch, separate from bugs

Circular native proof belongs to sibling native_hitbox audit: native TH18 circular fatal test is `d² < br²+pr²`; engine training `stg-core/src/world/collide.rs:94,101` is `d² <=(br+pr)²`. For the SAME positive br/pr values, training's geometric hazard is larger, e.g.br4/pr2 =>6px vs sqrt20=4.472px (extra1.528). This particular algebraic mismatch alone is conservative, not a reason that extracted raw br is too small. It does not establish learned-actor clearance guarantees or a universal comparison to training body2.5..4.5 when native card body changes. Exact adaptation could map to an effective radius, but that changes raw semantics per player state and must be proposed to the user, not silently implemented.

Laser current beam geometry DOES match native wrappers: Line default origin trim len/10 and effective0.8len (full length if+7bc&2), Infinite0.9len. Width<32 =>native passed width/2, half_h width/4; width>=32 =>Line half_h=(width-(width+16)/2)/2; Infinite denominator3 instead. Instructions0x44aa25..43 and0x44ced4..f5 confirmed, with0x45cf9f multiply0.5. Examples width16 ->half_h4, Infinite40 ->10.6667; do not halve again downstream. This raw beam rectangle is exact, but player-vs-beam geometry is not the same physics:

- Native consumer0x45cea0 rotates player into beam local coordinates0x45ced7..45cf3a; loads player local rectangle half extents +479a4/+479a8 or focus+479b0/+479b4 at0x45cf48..69 and0x45cfde..45cfff; fatal interval overlap0x45d000..26. It does NOT read circular radius+4799c/+479a0.
- Engine training laser collision `collide.rs:286..297` tests circle radius against rectangle distance; world.h:43..45 states that convention.
- For sibling-confirmed stock native extents1.5x1.5 and native circular radius3, circle3 encloses that local square, so a same-pr circle approximation is conservative. Training body2.5..4.5 also encloses stock1.5 square, but there is still no actor safety proof. Runtime card changes require explicit dimensional comparison, not blanket claims. A single scalar cannot represent arbitrary independent half extents or native rectangular bullet shapes.

This collision mismatch belongs to a geometry policy decision: retain approved approximation vs extend representation/training/physics. It is not fixed just by correcting native field offsets or state numbers. Don't expand graph/protocol/training during a read-only audit.

## Finiteness and motion caveats

Bullet extractor`:94` checks scaled radius,x,y finite; it does not check vx/vy finite. Canonical envelope rejects NaN positions through comparisons, but canonical fill has no independent radius/velocity finite filter. Lasers only validate len via `>16` and finite positive width; position/angle/target/speed/omega are not comprehensively filtered. Probe counts nonfinite actual input floats (`plugin.c:77..106`) but doesn't repair/reject them. ORT run only checks API status; argmax uses comparisons, no finite-logit check (`sa_model.c:170..177`). This is an observable edge risk, not evidence that valid retail objects actually have NaN or an authorized robustness feature.

Motion tokens are observations, not future script forecasts: bullet velocities dt-scaled (state2 halfspeed); Line omega adjacent observed angle difference; Infinite origin measured adjacent displacement, omega native+7a4*dt; length growth min(speed*dt,target-current). First-frame history zeros; ECL later redirects/width ramps/card drift need not be predictable. These are existing model limits and should not be confused with wrong current geometry.

## Recommended narrow next steps

- Correct native-to-shared laser state mapping (Line2->1, Infinite2/4->1, Infinite3->0), using native initialization/state transitions as the reproduction basis. Verify actual fill mask and warning token; preserve native diagnostic state. No graph signature/new model needed.
- If actual logs reach640/drop>0, address unsorted cap at the extractor before changing K/model; compare the omitted closest native hazard against actual input masks.
- Separate current source state/beam fixes from geometry scope decisions (circles vs native squared-sum; rectangular bullets; curved lasers; card body). User confirmation governs new geometry policy.
- Review actual r3 logs at reported failures: unsupported_geometry pass-through, native count/world count/input mask, radius/scaled radius, then graphK selection. No broad model benchmark necessary for this audit.

## Evidence / reproducibility

All temporary files are in this directory: `laser_repro.c` + binary + output; `graph_probe.py` + output; native-line-init.txt, native-line-collision.txt, native-infinite-collision.txt, native-laser-consumer.txt. C reproduction includes existing fixture utility helpers but calls actual production th18_extract.c and sa_model.c. Ordinary initialized Line2 comes from independent native0x449108, not the fixture's old0 assumption.

Commands executed: gcc -std=gnu11 -O1 -Wall -Wextra with production extractor and canonical sa_model.c; temporary binary run; project `.venv/bin/python graph_probe.py` with actual ONNX/CPU ORT; objdump instruction-boundary reads; SHA checks. No permanent tests were added, and no production binaries rebuilt.

r3 bundled extractor source SHA57db21b564c622252a636c86b3d8a24470fa7a3e6b097f10f89050c4bbdc1947 equals current source. Bundled DLL SHA06d874ef8c2edd8db1fd16dd90921ad370eeb2073a5b80ee4956221eb1710aff, temporarily extracted as bundled-stg_ai.dll for the actual compiled state-filter proof.

Exact reproduction commands (run from stg-rl-train):

```bash
gcc -std=gnu11 -O1 -Wall -Wextra -I/data/sunyunbo/www/stg-agent-proto/c -I/data/sunyunbo/www/renkolab/mods/th18.v1.00a/autoplay/native /tmp/sunyunbo/th18-geometry-audit-20261022/laser_repro.c /data/sunyunbo/www/renkolab/mods/th18.v1.00a/autoplay/native/th18_extract.c /data/sunyunbo/www/stg-agent-proto/c/sa_model.c -lm -o /tmp/sunyunbo/th18-geometry-audit-20261022/laser_repro
/tmp/sunyunbo/th18-geometry-audit-20261022/laser_repro
.venv/bin/python /tmp/sunyunbo/th18-geometry-audit-20261022/graph_probe.py
objdump -d -Mintel --start-address=0x4490d0 --stop-address=0x449114 /data/sunyunbo/www/renkolab/local/th18.v1.00a/th18.exe
objdump -d -Mintel --start-address=0x44ce80 --stop-address=0x44cf1d /data/sunyunbo/www/renkolab/local/th18.v1.00a/th18.exe
objdump -d -Mintel --start-address=0x45cea0 --stop-address=0x45d08f /data/sunyunbo/www/renkolab/local/th18.v1.00a/th18.exe
objdump -d -Mintel --start-address=0x100089bc --stop-address=0x100089d2 /tmp/sunyunbo/th18-geometry-audit-20261022/bundled-stg_ai.dll
```

Remaining gaps: no user real-frame failure capture reconstructed; no measured occurrence rate of cap640 or TopK contention; no Windows hook/live timer run; no proof the trained actor will avoid a newly represented hazard; native EX future mutation/card-specific geometry enumeration is outside this downstream audit. For training2.5..4.5, the saved config is direct run evidence; base2.5 is current engine source and expected table lineage, not an independent extraction of the historic Magnus wheel's table bytes.
