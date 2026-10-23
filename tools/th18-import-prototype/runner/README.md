# TH18 prototype VM runner

An independent prototype consumer of the local `stg-core` and `stg-ecl-compiler` crates. It can compile generated target ECL or validate a lowered image with `EclImage::try_from_parts`; it does not interpret TH18 instructions. It starts `World::new_game(seed, 0, image)` and advances the real VM with empty player input. Collision and other world rules remain active; each trace row includes the player's actual position and life state.

Run from the training repository root:

```sh
CARGO_TARGET_DIR="$PWD/transcribe/work/th18-prototype/target" cargo check --offline --manifest-path tools/th18-import-prototype/runner/Cargo.toml
CARGO_TARGET_DIR="$PWD/transcribe/work/th18-prototype/target" cargo run --offline --manifest-path tools/th18-import-prototype/runner/Cargo.toml -- transcribe/work/th18-prototype/image.json > transcribe/work/th18-prototype/trace.jsonl
```

Input JSON:

Source mode reads and compiles the actual `.ecl` file. Its path is relative to the JSON configuration file; absolute paths also work:

```json
{"ecl":"girl-r1.generated.ecl","frames":610,"seed":1,"watch_globals":[16,17,19,64,65]}
```

Source mode rejects nonempty `code`, `subs`, or `entries` fields. There is no hidden precompiled image behind the source file. Compiler diagnostics report the source filename, line, and column.

The earlier bytecode mode remains available for comparison:

```json
{
  "code": [0],
  "subs": [{"entry": 0, "kind": "root", "params": []}],
  "entries": [],
  "root": 0,
  "frames": 160,
  "seed": 1,
  "watch_globals": [16]
}
```

`code` contains unsigned 32-bit VM words, including two's-complement immediates. Sub kinds are `root`, `async`, and `call`; parameter types are `int`, `fx`, and `angle`. `frames` and `seed` default to 160 and 1. Optional `engine_ver` must match the linked engine if supplied. `source_map` and other front-end metadata are ignored.

`watch_globals` reads slots 0–1023 through the public world view. Scripts can export a value to writable global slots 16–1023 with `SYS_SET_VAR` (701): push the slot, push the value, then invoke the syscall. `watch_locals` may be omitted or empty; nonempty requests fail because task locals have no public read API.

Each stdout line is one post-step JSON snapshot. `frame` is the post-step world frame; `vm_frame` is the frame executed by that step. The root is born at frame 0 and cannot run on its birth frame, so the first row (`frame=1`, `vm_frame=0`) contains no script execution. Root code first runs in the second row; an enemy task spawned there first runs in the third. Source time must be mapped by the front end with this launch delay accounted for.

`count` counts live bullets after cleanup, and `bullets` contains all their rows in pool-index order. The identity is `(index, generation)`. Positions, velocities, speeds, and radii ending in `_raw` use Q16.16; `angle` uses BAM (65536 per turn). `born_frame` records the engine spawn frame, and `age` is `frame - born_frame`. Movement already occurs on the spawn step. `polar()` supplies current angle/speed even when the stored polar representation is stale. `transform_head`, `xform_wait`, and `xform_next` are read-only cursor observations, not a dump of private transform storage. Bullets removed within the same step do not appear in the snapshot.

`checksum` is a 16-digit hexadecimal world checksum. `faults`, `contract_viol`, and the eight `pool_full` counters are cumulative. The runner writes and flushes the failing row, then exits nonzero when any is nonzero. Fault events identify the task, sub, and fault code. Image validation, unsupported observation requests, and file errors also exit nonzero; diagnostic text goes to stderr.

Keep generated images, traces, and Cargo build outputs under ignored `transcribe/work/th18-prototype/`. The runner uses public read APIs and never accesses private pool storage.
