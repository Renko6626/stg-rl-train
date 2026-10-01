# batch3 机械工具独立审查

日期：2026-10-01。范围仅为 standalone 卡加载兼容及机械验收工具；审查错峰01/02当前机器报告与当前候选快照。未评估玩家可躲性、卡片设计质量、训练收益或其余18张卡。

## 结论

**Round 0 为 REVISE；Round 1 对机械工具集成为 PASS，独立语义审查仍待完成。** 原始世界逐帧采集以 `(pool index, generation)` 识别激光，逐帧计 birth/expiry，死亡后继续推进。Round 1 当前三份 stagger 报告覆盖 rank 0..3 × seed 1/7 × 1860 帧，六项诊断每次运行均为零，声明关键帧已按 rank×seed 验证。expiry 仍按句柄消失帧定义。初审三项 P2 的修订及本轮边界见文末。

当前候选 `main.ecl/meta.toml/TASK.md/machine-spec.json` 的哈希逐项与两份机器报告相同。`cards.py` 的专项 metadata 例外显式要求 standalone/synthetic 字段、拒绝底子血缘字段；`train_starts` 排除 held-out；普通 synthetic 仍要求 `base_card`，相应负例和回归测试存在。报告也正确把已安装 `stg_rl 0.4.1 / ENGINE_VER 24 / git_sha 5dfc08d-dirty` 与 path-dependency 引擎 commit `5dfc08d45f8f0c359c301de94d6fe7bb399df889` 分开陈述，没有声称二者构建身份相同。

## 发现

### Round 0 P2 — 缓存的 laser-trace 二进制没有与当前源码绑定

位置：[specialist_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/specialist_validate.py:294)。`_trace_binary()` 只在 `/tmp/.../trace-target/release/laser-trace` 不存在时构建；存在时无条件使用。报告记了 executable SHA，但没有 `tools/laser_trace` 源码、Cargo manifest/lock 与该二进制之间的构建指纹。两份当前报告的 `trace_build` 均为 `{"cached": true}`。因此工具源码或依赖变更后，验收可以继续执行旧二进制并返回 PASS；单独记录二进制 SHA 不能证明该 SHA 来自当前 Rust 源码。

最小修正：把 Rust 源、`Cargo.toml`/`Cargo.lock` 和相关引擎源身份组成构建指纹；缓存指纹不匹配时重建，并将这些哈希及实际 build/cached 状态写入报告。重验两张候选卡，并做一次源码指纹变化后必须重建的探针。

### Round 0 P2 — 命令行允许省略契约要求的 seed 7

位置：[specialist_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/specialist_validate.py:602)。默认值 `[1, 7]` 正确，但 `--seeds` 接受任意集合；`all_runs_complete` 按传入 seeds 数量计算。调用 `--seeds 1` 时，工具仍可在四个 rank 都完成后报告完整并 PASS，违反契约固定要求的 seed 1/7 矩阵。当前两份报告的 seed 列表确实是 `[1,7]`，所以本项不否定这两份既有轨迹证据。

最小修正：正式验收固定强制包含 `{1,7}`（可另加诊断种子），或把非契约 seed 集合标为非正式且不得输出 PASS。回归探针：显式只给 seed 1 应被拒绝/失败；默认命令仍须产生 8 组 rank×seed 机械测量。

### Round 0 P2 — schema 门没有强制关键帧覆盖，也接受全局宽范围

位置：[specialist_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/specialist_validate.py:94) 与 [keyframe_errors](/data/sunyunbo/www/stg-rl-train/src/stgtrain/specialist_validate.py:148)。目前只要求每 rank 至少6个不同 frame；没有要求预警、生效、交接、运动、末轮回收和 time-limit 关键帧都被覆盖。几何只要求区间有限有序及 width 区间包含该 rank 宽度；例如整场 `x/y/angle/start/end` 范围可作为“合法”快照约束。因此 machine-spec 可以缺少重要状态或声明几乎无筛选力的快照，仍通过 schema 门。合同把覆盖类型及“范围足以检出该帧机制错误”列为要求，但当前报告中的 `ok` 不证明这两项。

最小修正：将关键帧用途作为机器可校验字段/类别，按契约要求每 rank 覆盖各类，并对角度、场界与激光长度等字段应用有意义的全局合法范围；机制相关的紧度仍由独立审查者按真实脚本裁定。添加缺少末轮/收尾帧、全场范围快照必须失败的负例。当前两份报告列出9帧/rank且实际快照字段完整；这项是机器门保证不足，不是已观察到的两份报告漏帧。

## 已核对的实现与报告证据

- `laser_trace` 调用顺序为 `compile_units → World::new_game(seed, rank, image) → InputFrame::empty(world.frame()) → step`；每次 step 后读取 `World::frame()` 与公开 LaserPool 状态。帧号从1开始与 harness 定义一致，rank/seed 为参数直传，没有 VecEnv autoreset；death 后持续推进的测试覆盖12帧。
- 连续采样验证 frame 1..1860；trace schema 缺字段/未知字段、重复 `(rank,frame)`、重复 handle、转换事件不匹配、诊断缺失/非零及峰值越界都会产生错误。JSON 对象重复键和有效 rank/frame 对重复也拒绝；机器 spec 顶层及关键帧未知字段拒绝。
- expiry 由上一帧身份集减当前身份集得到，而不是激光数量变化；已有 same-count handle replacement 测试覆盖末次出生/回收边界。当前两份报告均给出 first spawn 94、last spawn 1471、last expiry transition 1750、last presence 1749，最大 visible/live 为8/8、内部 idle gap 为0。
- harness 对拍检查 rank0/seed1 声明关键帧的 x/y/angle/start/end/width/speed/omega/state，容差0.011；rank×seed 全矩阵另做 harness run、诊断和 trace 测量。该抽样对拍有意义，但不代替每个 rank/seed 的 harness 逐帧对拍。
- standalone metadata 测试覆盖 forged 字段拒绝、held-out 排除以及 ordinary synthetic 缺底子拒绝。该异常按 `synthetic_kind=laser_specialist` 与 `generation_mode=standalone` 收窄。

## 快照与 SHA256

以下均为本次读取的当前内容。机器报告内四个候选文件 SHA 已逐项与 `/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01` 和 `_02` 现存文件核对一致。

| 文件 | SHA256 |
|---|---|
| `docs/practice-cards/laser-specialist-contract.md` | `3002dd8851028331a275e305097e4a527bb47b16b193e5d1a7c4f961ab910dfe` |
| `src/stgtrain/cards.py` | `764d473a39f6802ca3a9bd2d29efdbb4d279f9c60bcdd1116a570b076c6d19ed` |
| `tests/test_cards.py` | `5f259a0484c94a73fe3389f6f0f0d3fef8c4e30a3b911b82db67ecbb7f4831aa` |
| `src/stgtrain/specialist_validate.py` | `15ec618304f7e8639dd5d60790f039f2a4ee5a7924507195dee0a2638a7c9f8a` |
| `tests/test_specialist_validate.py` | `b74280fa799cff2602ff83b6a7f43ccdb1cad09f0ea1419fde67bededf19c2c9` |
| `tools/laser_trace/Cargo.toml` | `c36bf605a0c8ee0ca2d524a74c5eb019fa06dcbe7dbd506454c10796353a7bad` |
| `tools/laser_trace/Cargo.lock` | `95095052d65eaed259cc2cecb5700222bb288c60abb38cdf8e78382ad5c7cda3` |
| `tools/laser_trace/src/main.rs` | `479b60359c93ff1b0dea9232bdfc7210603ec121e5c4d8d9709edeb8aedd50c0` |
| `docs/practice-cards/reports/batch3/machine-trace-author.md` | `0c5934aeb2dbf1132fcd016cf44172a303b8b99d77c6137d6e8171b96b0568ad` |
| `docs/practice-cards/reports/batch3/laser_sp_stagger_01.machine.json` | `f61d7a7794fbe850b05892a1e6ecab0e9b605e9e2ac0c54f03c9a6f8521e7a05` |
| `docs/practice-cards/reports/batch3/laser_sp_stagger_02.machine.json` | `7e091a10b5b43517bde59a171f84407ea142da7ebbd12fea9c8826452888a39e` |

两份机器报告各自 SHA 均已在上表列明；它们绑定的候选四文件 SHA 可直接从各 JSON 的 `file_sha256` 读取，且与当前暂存卡快照匹配。报告 `validator.sha256` 与当前 validator 一致；trace executable SHA 均为 `669f316844e5527e261345d939e08e44de59ebff4d1374d53c2c81470beb5a82`。引擎身份按报告记录为 commit `5dfc08d45f8f0c359c301de94d6fe7bb399df889`，core/compiler/derive source SHA 分别为 `dcb97316b86c3177d3cfe8cd548648f963e4323374e686336ce27d26337feda6`、`3dfaf21fccf2296c7ea2bba2e2eeac5a53f3904d0f7f1c5689569d783792c787`、`8df365b4eefb4ff92e63cb20ab8c0f51a0ba28d8d29f48eaa34c9021c16f40db`；相关工作树 diff 是空树哈希 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

## Round 1 复审（2026-10-01）

**PASS：本次机械工具集成范围内，初审三项已修复或按明确边界收窄。** 当前机器 PASS 明确标为 `mechanical_pass_independent_review_pending`；这只证明声明快照和 rank×seed 机械轨迹门通过，仍要求非作者阅读真实脚本并审核随机范围语义。没有把有限矩阵或单卡机械 PASS 当作全参数域正确性的证明。

- **Round 0 finding 1 closed.** `_trace_binary()` 现在每次都执行 Cargo build；sidecar 同时绑定 trace source、相关引擎 crate 源/manifest、workspace lock、toolchain、Cargo/Rust 版本与 executable SHA。指纹失配先清理隔离 target 再建；build 前后源码和矩阵前后 source/binary 都复核。三个当前报告的 source fingerprint 为 `dd267e137118483efb2cced40094b539dcd2cce23ee25021f068535c819d9c35`，executable SHA 为 `669f316844e5527e261345d939e08e44de59ebff4d1374d53c2c81470beb5a82`，矩阵后值相同；状态为 `cargo_verified_cache`，意为经当前 Cargo 命令核验过的缓存。新增测试覆盖源变化、二进制哈希不符与失配清理重建。
- **Round 0 finding 2 closed.** `seed_matrix_errors()` 拒绝缺少 seed 1 或 7 的集合，同时允许附加非负且不重复的诊断 seed。当前三份报告记录 `required=[1,7]`、`provided=[1,7]`；新增回归测试明确 seed 1 alone 失败。
- **Round 0 finding 3 closed within mechanical scope.** validator 现在要求每 rank 有实际预警/生效/收缩状态快照、首末出生边界、中段、末句柄回收后的空场、frame 1800 空场，并在轨迹中核验实际状态、波次交叠和运动帧覆盖。全引擎/契约域同时放开的几何快照会被拒绝，合法原点范围如 x=-320/y=-96 与归一角度 `[0,360]` 可通过。代码没有试图用任意宽度阈值证明作者声明的全部随机域；报告明确把几何范围对整域的语义充分性留给独立源码审查。这与本轮裁定一致，不再作为机械工具阻塞项。

当前01/02文件 SHA 已变化，Round 0 表格是旧快照历史记录；Round 1 三卡机器报告的 `file_sha256` 与其当前 tmp 候选逐项匹配。三份报告均 `ok=true`、`acceptance_status=mechanical_pass_independent_review_pending`、无错误，`keyframe_coverage.errors=[]`。工具作者报告称新增 focused tests **36 passed**，`cargo fmt --check` 通过；本复审未重复全套或全批验收。

Round 1 当前证据 SHA256：

| 文件 | SHA256 |
|---|---|
| `src/stgtrain/specialist_validate.py` | `0bf52940255c0c4f8d08896adbc42ac6e4b39ce229ad37e1bed4f778c283e909` |
| `tests/test_specialist_validate.py` | `a198451b378f4ef597d9f686d3c4c5db7fa8304e1e7062c41b582dac543a90dc` |
| `tools/laser_trace/Cargo.toml` | `c36bf605a0c8ee0ca2d524a74c5eb019fa06dcbe7dbd506454c10796353a7bad` |
| `tools/laser_trace/Cargo.lock` | `95095052d65eaed259cc2cecb5700222bb288c60abb38cdf8e78382ad5c7cda3` |
| `tools/laser_trace/src/main.rs` | `479b60359c93ff1b0dea9232bdfc7210603ec121e5c4d8d9709edeb8aedd50c0` |
| `docs/practice-cards/reports/batch3/machine-trace-author.md` | `b69faf9e822ecdebd554dd6cff71778255cf5dabf1ff7a2d5f7aa8ae22f14f1e` |
| `docs/practice-cards/reports/batch3/laser_sp_stagger_01.machine.json` | `0e3eac8944ce56a98d7c9b805c74eae524a3216239786a987ed90c9a51c82c12` |
| `docs/practice-cards/reports/batch3/laser_sp_stagger_02.machine.json` | `aa57f6ab5f7a3922d48c4ab48e02d105bd2baa310801aa804f9dc125e947c755` |
| `docs/practice-cards/reports/batch3/laser_sp_stagger_03.machine.json` | `1c6e93b585bf60da491e1317afa285e824f78c77e90213285417cdc76a37f795` |

Current candidate file SHA values are embedded in these three machine reports and were checked against their current temporary snapshots. The contract remains SHA256 `3002dd8851028331a275e305097e4a527bb47b16b193e5d1a7c4f961ab910dfe`.
