# TH18 ordinary bullet geometry audit

> **版本**：TH18 v1.00a, imagebase `0x400000`; all addresses below belong to this build.
> **Sample**：`/data/sunyunbo/www/renkolab/local/th18.v1.00a/th18.exe`.
> **MD5**：`9969cac756098c1da05a81de45437a70` (computed again 2026-10-22).
> **Method**：read-only native instruction audit with GNU objdump; fresh read-only decompilation from the existing Ghidra project; raw PE data extraction. No rebuild, production edits, training, or gameplay execution.
> **Confidence**：✅ means directly confirmed native instructions/data, not Windows runtime acceptance. Reachability limits are identified separately.

## Result relevant to the current r3 extractor

The current source's ordinary-bullet radius path is correct for the circular native consumer: read `bullet+0x658`, multiply by `bullet+0xf38` only when `bullet+0x20 & 0x40`, and read the player's selected live radius from `+0x4799c` or `+0x479a0`. The task introduction's `+0x650` was inaccurate: the inspected source already reads `+0x658`, and `+0x650` is a motion speed parameter (written at `0x42515e`, consumed by velocity construction at `0x42409e`–`0x4240b3` and `0x424248`–`0x424263`). There is no evidence here that ordinary circular bullets are omitted because r3 reads the wrong radius offset.

However, native TH18 circular contact uses **`distance² < bullet_radius² + player_radius²`**, not `(bullet_radius + player_radius)²`. For positive radii, a downstream additive-radii collision approximation expands the dangerous area and is conservative. This difference alone cannot explain dangerous underestimation. The native consumer imposes no fixed `32` radius ceiling. The separate downstream audit subsequently confirmed that the current ordinary-radius path also has no such clamp; therefore a radius32 clamp is not a current r3 cause.

A rectangular bullet consumer also exists, with different units: the pair at `+0x658/+0x65c` is full width/height, halved by that consumer. **Do not infer ordinary type-specific rectangular bullets from this fact.** The normal initializer unconditionally sets the circle flag, and so does the type-change handler. No concrete native ordinary rectangular-bullet spawn was established by this audit.

## 1. Circular lethal geometry: exact formula

**Observation.** `0x4248d8` loads `bullet+0x658` into XMM1. `0x4248e9`/`0x4248ec` require the unscaled value to be greater than zero. `0x4248fd` selects shape using `flags & 0x10`. With circle flag set, `0x424912` copies the radius to XMM2. When `flags & 0x40`, `0x424917` loads `+0xf38` and `0x424946` multiplies it by the base radius instead. `0x42494b` calls `0x45cd90`, passing bullet position `+0x638/+0x63c` and that radius in XMM2.

**Hypothesis tested.** The float could be a diameter, sprite extent, squared radius, or ordinary radius combined additively with the player.

**Verification.** The actual consumer computes `dx*dx + dy*dy` at `0x45cdb9`–`0x45cdca`, squares the incoming bullet float and selected player float separately, then adds the two squares. Fresh Ghidra output in `consumers.txt` agrees with the raw instructions; the math does not depend on migrated field names.

Critical bytes:

```text
4248d8  f3 0f 10 8e 58 06 00 00  movss xmm1,[esi+0x658]
424946  f3 0f 59 d1              mulss xmm2,xmm1
45ce02  f3 0f 59 d3              mulss xmm2,xmm3   ; br * br
45ce06  f3 0f 59 c1              mulss xmm0,xmm1   ; pr * pr
45ce0a  f3 0f 58 c2              addss xmm0,xmm2
45ce0e  0f 2f e0                 comiss xmm4,xmm0 ; d² vs pr²+br²
45ce11  72 2d                    jb 0x45ce40      ; strictly below
```

**Result.** ✅ For finite ordinary positive values, with the hit state gates satisfied:

```c
br = b.f658;
if (b.flags20 & 0x40) br *= b.fF38;
pr = p.focus476cc ? p.f479a0 : p.f4799c;
if (p.flags4779c & 0x10) pr *= p.f4797c * 3.6f;
contact = (p.x620-b.x638)^2 + (p.y624-b.y63c)^2 < pr*pr + br*br;
```

No half factor is applied to `br` in this branch. No sprite width, sprite height, ANM rotation, color, or type table is read by the consumer. These are continuous logical playfield coordinate units, the same units as the extracted positions. Native `+0x658` is neither an already-expanded radius nor an already-squared value.

At exact equality, the lethal branch is not taken. Return codes are `1 = contact`, `2 = graze`, `0 = neither/disabled`. Contact calls `Player__die` only when not in dialog (`GUI+0x1b0`), not graze-only, player state not in `{2,3,4}`, and player invulnerability current timer `+0x47778 <= 0`; invulnerability can still return contact `1` without death. State/list eligibility is covered by the separate state audit.

**Concrete counterexamples.** With `pr=3`, `br=4`, native contact threshold is `sqrt(9+16)=5`. At `(dx,dy)=(6,0)`, native does not kill (`36 >= 25`), whereas additive radii would (`36 < 49`). At `(5,0)`, native still does not kill because the native comparison is strict. For a large `br=28`, native threshold is `sqrt(793)=28.160255...`; additive radii give `31`.

**Evidence.** `native-geometry.asm`, segments `0x4248a0`–`0x424950`, `0x45cd90`–`0x45ce8e`; fresh `consumers.txt` first function.

## 2. Rectangle consumer exists; ordinary type mapping must not be invented

**Observation.** When `flags20 & 0x10` is clear, `0x424909` passes a pointer to `bullet+0x658` to `0x45cc20`. Scaling path `0x424923`–`0x42493f` scales both `+0x658` and `+0x65c` before passing them. The consumer multiplies the first value by `0.5` at `0x45cc87` and the second at `0x45ccb1`. It constructs the player's axis-aligned bounds from live half extents and performs four separating-axis comparisons at `0x45ccd1`–`0x45cced`.

**Hypothesis tested.** Table field `type_record+0x10c` might select circle vs rectangle, making e.g. type17 rectangular because its value is zero while most other types have six.

**Verification.** Full normal initializer `0x424fe0` shows `0x425795: or [edi+0x20],0x10` **before** that table-field switch. Type-change handler likewise does `0x42647e: or [ebx+0x20],0x10`. The switch writes `bullet+0x674` (cancellation animation/script selection); all paths through the switch retain the circle flag. No bit10-clearing path was found in the audited `Bullet__on_tick`, initializer, `Bullet__run_ex`, or cancellation/recycle code. This is a bounded static audit, not a claim that arbitrary external mods cannot clear it.

**Result.** ✅ The native fallback rectangle's positive-size contact predicate is:

```c
s  = (b.flags20 & 0x40) ? b.fF38 : 1;
hx = b.f658 * s * 0.5f;
hy = b.f65c * s * 0.5f;
px = p.focus476cc ? p.f479b0 : p.f479a4;
py = p.focus476cc ? p.f479b4 : p.f479a8;
contact = abs(dx) <= hx + px && abs(dy) <= hy + py;
```

Equality counts as rectangle contact (only `ja`, strictly disjoint, excludes it). Bullet angle does not rotate this box. The circle's conditional player-scale multiplier is absent here. For `f658=f65c=4`, default player half extents `1.5`, the threshold is a `3.5 x 3.5` half-extent square: `(3.4,3.4)` hits; `(4,0)` misses. This cannot be represented exactly by a single angle-independent radius.

✅ All ordinary bullets using the audited initializer start in circular mode, including table type17. 🟡 No actual TH18 gameplay case entering the rectangular fallback was established, so rectangular support is not itself evidence of an observed r3 missed bullet.

**Evidence.** `0x424905`–`0x424944`, `0x45cc20`–`0x45cd34`, `0x42576a`–`0x425799`, `0x426440`–`0x426492`; `decompile.txt` initializer and EX handler. Cancellation-class data retained in CSV specifically to prevent misreading it as shape.

## 3. Player defaults and native card modification

**Observation.** Reset sets both circle floats to `3.0` and both pairs of rectangle half extents to `1.5`:

| Runtime field | Default | Writer | Reader |
| --- | --- | --- | --- |
| circle unfocused `+0x4799c` | 3 | `0x45ae99` | `0x45cdda` |
| circle focused `+0x479a0` | 3 | `0x45aea3` | `0x45cdd0` |
| rectangle unfocused X/Y `+0x479a4/+0x479a8` | 1.5 each | `0x45aeb7`/`0x45aead` | `0x45cc5a`/`0x45cc62` |
| rectangle focused X/Y `+0x479b0/+0x479b4` | 1.5 each | `0x45aed5`/`0x45aecb` | `0x45cc48`/`0x45cc50` |

`0x40c7b0` loads PLAYER_PTR and writes **only unfocused** circle `1.0` and rectangle half extents `0.5/0.5` at `0x40c7b5`, `0x40c7bf`, `0x40c7c9`. The existing vendor name is `CardAya::on_load`, and the project catalog associates it with SPEEDQUEEN/id29. Numeric behavior is independently confirmed from instructions; identity uses that existing named card mapping. Reset calls card virtual `+0x20` after resetting defaults (`0x45aef3`–`0x45af0c`), consistent with applying card load overrides after reset.

**Hypothesis tested.** Player radius might be a fixed character-dependent value, or focused/unfocused values might always be equal.

**Verification.** Circle and rectangle consumers select their fields using live `player+0x476cc`, and card load writes only one set. These are direct reads/writes, not assumptions from artwork or character lore.

**Result.** ✅ Runtime live reads are required to preserve this modifier. Ordinary default is `3/3`; the cited card yields `1` unfocused and `3` focused. Current r3's circle extraction selects the correct live field. Native default `radius3` encloses the default rectangle with half extents1.5; native card `radius1` likewise encloses the half-extents.5 rectangle, so substituting those circles for the player's rectangle is geometrically conservative before other laser-specific effects. Actual laser support is owned by the laser audit.

✅ Conditional circle modifier exists: if `player+0x4779c & 0x10`, multiply chosen circle radius by `player+0x4797c * 3.6` (`0x45cde2`–`0x45cdfb`, constant `0x4b9244`). This audit establishes the consumer, not a current native TH18 card that sets this flag. Do not assume this legacy path is active from visual scaling alone.

**Evidence.** `native-geometry.asm` player reset/card/consumer segments; `decompile.txt` reset; `consumers.txt` consumers. This also separates circle3 from the rectangle's half extents1.5: they are distinct native values, not two names for the same radius.

## 4. Bullet size source, EX overrides, and visual size

**Observation.** Normal initialization at `0x425992`–`0x4259a8` copies the float at `0x4c6094 + type*0x118` into both `bullet+0x658` and `+0x65c`. This is record base `0x4c5f90`, offset `+0x104`. Type-change at `0x42640a`–`0x42642c` repeats the lookup/write. The real table occupies48 records up to `0x4c9410` (next table). Raw values are exported in `bullet-type-sizes.csv`: base values range from2 (type3) through28 (types46/47), including2.4,2.8,3.2,4,5,6,7,8.5,10,12,14.

EX operation bit `0x20000000` is dispatched by `0x426fee`/`0x426ff9` to `0x4275b7`: nonnegative override float is written to both size fields; negative restores the type table float (`0x4275c0`–`0x4275dd`). Thus runtime `+0x658` is authoritative even when it differs from the base type record.

EX bit `0x400000` initializes a scalar interpolator at `+0xf08` and sets `flags20 & 0x40` (`0x426e21`–`0x426e9f`). Bullet tick evaluates it and stores `+0xf38` at `0x423eba`–`0x423ecc`. If interpolation ends at exactly1, it clears the flag (`0x423ee0`–`0x423eed`). `+0xf38` initializes to1 at `0x4252dc`. The collision dispatcher scales runtime size by this field as described above.

**Hypothesis tested.** Sprite dimensions, sprite class, or rendered scaling might be the lethal extent; conversely a base type-size lookup alone might suffice.

**Verification.** The killing consumer reads neither the type nor the sprite. Runtime size overrides and scalar interpolation are explicit. Drawing separately copies `+0xf38` to ANM scale `+0x84/+0x88` at `0x424f73`–`0x424f8a`; sprite dimensions are separately used for offscreen culling at `0x4247f5`–`0x42484f`. These consumers are distinct from `0x4248d8`–`0x42494b`.

**Result.** ✅ Visual sprite bounds are not the lethal hitbox. Some scale data are shared by both systems, but the base sprite pixel width/height and hit radius originate independently. ✅ Runtime radius can exceed the table maximum28 because of an EX size override or multiplication. The native kill path has no `min(32,...)` or fixed equivalent. The audit has not enumerated every shipped ECL to prove which stages actually use each large override/scale.

**Concrete size example and rejected clamp hypothesis.** A valid base type46/47 radius28 with scale2 produces native `br=56`. With default `pr=3`, native kills at center distance40 because `1600 < 3145`. This demonstrates why native size must be preserved. The separate downstream audit confirmed no actual radius32 clamp, so the earlier hypothetical clamp counterexample is rejected as a diagnosis of current r3. This audit has not proved that this exact scaled type appeared in the reported scene.

**Evidence.** `native-geometry.asm` table-copy, EX override/scale, update and draw segments; `bullet-type-sizes.csv`; raw PE offset for `.data` is `VA - 0x4c3000 + 0xc1a00`, `.text` is `VA - 0x401000 + 0x400`.

## Reproducibility and scope limits

Artifacts in this directory:

- `native-hitbox.md`: this report.
- `native-geometry.asm`: targeted objdump segments, including instruction bytes.
- `bullet-type-sizes.csv`:48 actual PE records, float values and literal hex bytes.
- `consumers.txt`: fresh read-only Ghidra output for circle, AABB, and native Aya tick.
- `decompile.txt`: fresh read-only Ghidra output for initializer, EX handler, reset, card load and bullet tick; some functions repeated because several requested addresses fall in the same function.
- `th18.asm`: full objdump text used to find candidate instructions; conclusions above point to confirmed instruction boundaries and function-local reads.

No Windows runtime or scene capture was performed. No ordinary-bullet omission is diagnosed from geometry alone. Positive findings establish the current live radius path, native sum-of-squares contact, distinct rectangle units, native card differences, and absence of a fixed ceiling in the audited native consumer. Per-type rectangle assumptions and sprite-size heuristics are rejected; downstream encoding, truncation, selection and policy compatibility require their own audit.


## Follow-up: which actual bullets are rectangles?

The additional native EX audit did not find a circle-to-rectangle selector. Full `Bullet__run_ex` (`0x425c60` onward, fresh decompilation saved here) writes the object flags at `+0x20` only by setting circle bit10 at `0x42647e`/`0x426659`, and setting scale bit40 at `0x426e9f`. Its many dynamically combined EX flags target `+0x684`, a different field. Bullet tick clears scale bit40 at `0x423eed` and changes bit200 at `0x424470`/`0x424511`; it preserves circle bit10. Recycling mask `0xfffffcbe` at `0x424bdf` also preserves bit10. Spawn sets bit10 unconditionally at `0x425795`.

This is stronger evidence than table defaults alone, but remains a bounded native-code result: **no actual ordinary rectangular type or shipped ECL switch has been established by this worker**, and the rectangle helper's presence is insufficient to name one. The coverage worker owns the additional22-file original-ECL scan. Visual needles, knives, arrows or elongated sprites must not be relabeled as rectangle hitboxes from their appearance.

A specific misleading name was excluded: ECL op712 can be labeled `hitboxRect` in existing symbols, but its native body at `0x435a6a` calls `0x4294b0`, the rectangular bullet-cancellation routine. It is not evidence of changing a spawned bullet's lethal shape.

Current extractor line239 already implements the player flag10 scalar branch, so neither the legacy player-scale consumer nor the live card radius is an omitted ordinary-circle modifier in the inspected r3 source.
