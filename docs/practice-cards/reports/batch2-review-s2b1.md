# Batch 2 独立审查：`th06_s2_b1` v2/v3

审查对象：`synth_laser_s2_b1_v2`、`synth_laser_s2_b1_v3`。审查依据为试产契约、两卡实际 `TASK.md`/`machine-spec.json`/`meta.toml`/`main.ecl`/`overlay.ecl`，以及当前机器报告。作者未参与本审查。

## 结论

两卡均为 **REVISE**，原因是任务规格文字与实际合成颜色不一致；这是可定位、低风险的文档修订，不涉及激光实现本身。

## `synth_laser_s2_b1_v2` — REVISE

### 核验结果

- `overlay.ecl` 实际创建两条 `color=15` 激光，`warn=45/active=120/fade=12`，宽度 8，`lz_speed=2.5fx`、棒长 88；生命周期 177 帧。两条原点分别为 `(-92+jitter,78)` 和 `(92-jitter,114)`，方向 0°/180°，每轮相向飞行，最多同时 2 条，均符合契约范围。
- 机器报告 rank 0..3、seed 1/7 全部退出码 0；诊断 `task_faults/contract_viol/pool_full/hits_ovf/events_ovf/reqs_dropped` 均为 0。关键帧实际符合 `end=5/155/230/330`、`start=0/67/142/242` 与自然回收节奏。seed 1/7 首轮 x 分别为 -95/+95 与 -92/+92，随机几何可观察。
- `main.ecl` 去除唯一 `SYNTHETIC_OVERLAY_ENTRY` 行后与底子逐字一致；底子哈希与 provenance 一致：`f54c27c8c3eb20b95ddd4dfd8e9eb3b0d739e8cb21fdda221d99b5d8faf3f3c8`。未发现 owner 专属接口、新敌人或额外 ECL。

### 必须修订

- `TASK.md` 第 5 行声明“颜色 14”，而实际脚本与 `machine-spec.json` 均为颜色 15。应把任务文字改成颜色 15；修改后机器报告与本审查哈希均需重新绑定。

### 当前五文件 SHA256

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `7791872d01b8c611e4709e3608b9e31f5c62f4947727e7784f5b2b5baf2d5814` |
| `machine-spec.json` | `60849f9dd1514f0aedc9a86381f5376f2efb8b7dd8509d81be77d3b39cc4c0dc` |
| `main.ecl` | `66afe4aaac7e500ee92fa587fcec6225a84a067237a66c87fa73ad9acae9a04a` |
| `overlay.ecl` | `29eed9128f0cf6c0873172c35f4c6547e99826b3c3a7169031b379879f8a26e4` |
| `meta.toml` | `9a13385b4645b563ba2b249b8ce06973a4a2115f796f8eb16ce7e8a7d7437769` |

## `synth_laser_s2_b1_v3` — REVISE

### 核验结果

- `overlay.ecl` 实际创建一条 `color=15`、长度 112、宽度 8 的固定原点旋转短段；`warn=45/active=120/fade=12`，`lz_omega=96bam`，生命周期 177 帧，六轮间隔 210 帧，最多同时 1 条。omega 在三态持续生效，机器关键帧显示角度从约 5.27°/3.16°继续推进到约 36.91°/34.80°及 73.83°/71.72°，符合激光语义。
- 机器报告 rank 0..3、seed 1/7 全部退出码 0；诊断六项均为 0。seed 1/7 首轮角度存在约 2.11°差异，后续轮次也可观察，随机化有效。
- `main.ecl` 去除唯一入口后与底子逐字一致；底子哈希与 provenance 一致：`f54c27c8c3eb20b95ddd4dfd8e9eb3b0d739e8cb21fdda221d99b5d8faf3f3c8`。未发现 owner 专属接口、新敌人或额外 ECL。

### 必须修订

- `TASK.md` 第 5 行声明“颜色 13”，而实际脚本与 `machine-spec.json` 均为颜色 15。应把任务文字改成颜色 15；修改后机器报告与本审查哈希均需重新绑定。

### 当前五文件 SHA256

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `b36ee1f3a7ef9e4f97ab7712fefc2ad973981c5e70563a1fb70e658d8ef9d1af` |
| `machine-spec.json` | `d2d3eed58a15a3d4541e90319bf6c454e8a84df5493fa65545c467a9c113213a` |
| `main.ecl` | `66afe4aaac7e500ee92fa587fcec6225a84a067237a66c87fa73ad9acae9a04a` |
| `overlay.ecl` | `289b5e491d38abdd276795484aadc36c132f899deadcc82980b356d8f7ccf0a8` |
| `meta.toml` | `9a71b8219c0dadbf6234eb481d740a907693d7125b5c25a0fb1f2bcf7019b433` |

## 审查范围外但已核对的共同项

两卡 `meta.toml` 均为 `source="synthetic"`、`data_kind="synthetic"`，继承底子 ranks/marks/time_limit/original_time_limit，`tags` 含 `laser`，`base_card`/`mutation_id`/provenance 完整；`last_expiry_frame=1350 <= time_limit=1500`。当前机器报告均为 `PASS`，但颜色文字修订后必须重新生成报告并由 reviewer 复核。

## 复审（颜色修订后）

根代理已将两卡 TASK.md 的颜色声明修订为 15，并重跑机器验收。复核当前工作树与机器报告的五文件 SHA256，报告中的 `file_sha256` 与当前文件逐项一致；两份报告均为 `ok=true`，rank 0..3 × seed 1/7 全部运行通过，诊断字段均为 0。

- `synth_laser_s2_b1_v2`: **PASS**。当前哈希：`TASK.md` `7e9b49c92d9aa9d8ef4a26cb5bf3ee2695b921c83ceca5276dd292746e51a5be`；`machine-spec.json` `60849f9dd1514f0aedc9a86381f5376f2efb8b7dd8509d81be77d3b39cc4c0dc`；`main.ecl` `66afe4aaac7e500ee92fa587fcec6225a84a067237a66c87fa73ad9acae9a04a`；`overlay.ecl` `29eed9128f0cf6c0873172c35f4c6547e99826b3c3a7169031b379879f8a26e4`；`meta.toml` `9a13385b4645b563ba2b249b8ce06973a4a2115f796f8eb16ce7e8a7d7437769`。
- `synth_laser_s2_b1_v3`: **PASS**。当前哈希：`TASK.md` `198983129234c8b7ffae206161f58676546c1c3d847feec29d936894d17954ba`；`machine-spec.json` `d2d3eed58a15a3d4541e90319bf6c454e8a84df5493fa65545c467a9c113213a`；`main.ecl` `66afe4aaac7e500ee92fa587fcec6225a84a067237a66c87fa73ad9acae9a04a`；`overlay.ecl` `289b5e491d38abdd276795484aadc36c132f899deadcc82980b356d8f7ccf0a8`；`meta.toml` `9a71b8219c0dadbf6234eb481d740a907693d7125b5c25a0fb1f2bcf7019b433`。
