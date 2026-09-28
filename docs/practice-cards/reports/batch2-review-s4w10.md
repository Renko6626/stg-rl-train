# Batch 2 独立审查：`th06_s4_w10` v2/v3

审查范围：读取试产契约、两卡的 `TASK.md`、`machine-spec.json`、`main.ecl`、`overlay.ecl`、`meta.toml`，以及对应最终机器报告。机器报告均为 `PASS`；本报告另行核对源码语义和声明是否一致。

## `synth_laser_s4_w10_v2` — REVISE

定位：`cards-synthetic/synth_laser_s4_w10_v2/TASK.md` 的“关键帧预期”第二条。

依据：`overlay.ecl` 在世界帧 123 创建第一条激光，参数为 `warn=45`、`active=90`、`fade=12`；因此第一条在帧 123–167 处于预警，帧 168 才进入生效。第二条在帧 143 创建，帧 143 仍是预警。TASK 当前写成“帧143第一根生效、第二根首帧预警”，与脚本和机器报告的帧143状态（两条均为 `state=0`）矛盾，应改为第一条帧168生效、第二条帧188生效，或明确只描述帧143的双预警状态。

其余检查通过：

- `laser(15, ...)`，width=8；两条均用 `lz_speed(..., start_len=96)`，warn/active/fade 为 45/90/12，并发峰值 2，符合契约范围。
- 随机原点与方向在 seed 1/7 的机器关键帧中确有差异；机器报告关键帧显示第一条在帧124为预警，帧190为生效，端点推进符合短棒语义。
- `last_expiry_frame=290` 与第二条出生帧 143 加 45+90+12 相符；报告帧290新增激光归零。
- `main.ecl` 删除唯一 `SYNTHETIC_OVERLAY_ENTRY` 行后逐字恢复底子；overlay 无 `$self`、`aim_player`、`spawn_enemy` 或 owner 专属接口。
- metadata/provenance、底子 SHA 与最终机器报告文件 SHA 一致；报告 diagnostics 全为 0。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `b8463cbc7e00e20c5d4c389b943907a0f55dc4a8c663780dbf279fa9e8457b8b` |
| `machine-spec.json` | `2ef2ff111eaa3cd5df8712cd7ec74e74c51507e5d9d88f5de3a99dcfee26d4c8` |
| `main.ecl` | `23de0cd3304c48ae5e1cbf1d81c561020a040bbaa949a08551654ecf77ceea19` |
| `overlay.ecl` | `d71d2ed2dfabaa022029a9c66d22130730ca363a2fa2345b4a86a920257be706` |
| `meta.toml` | `66324b19d207f18edc95126ac13368e54c9d68c998f9d611eeeb6bbd15121d24` |

## `synth_laser_s4_w10_v3` — REVISE

定位：`cards-synthetic/synth_laser_s4_w10_v3/overlay.ecl` 的角度表达式，以及 `TASK.md` 和 `machine-spec.json` 的角度上限声明。

依据：脚本使用 `var a0: angle = 35deg + (rand(20481) as angle);`。`rand(20481)` 的上界对应 112.5°，所以实现范围是 `[35°, 147.5°]`，而 TASK 和 machine-spec 都声明 `[35°,145°]`。seed 1/7 的实际报告角度 136.76°/59.47° 均在声明范围内，但声明没有覆盖脚本可生成的完整范围。应将脚本上限收窄到 145°，或把 TASK/spec 上限改为 147.5°，并按修改后的文件重新跑机器验收。

其余检查通过：

- `laser(15, ..., 120.0fx, 8.0fx, 45, 100, 12)` 符合颜色、宽度、预警、生效和收缩约束；始终只有 1 条新增激光。
- `lz_origin` 在句柄存活期间每帧更新原点，报告显示 x 每帧约 +0.75、y 每帧约 +0.25，方向和 120px 长度保持；seed 1/7 初始原点与方向可观察不同。
- `last_expiry_frame=280`，机器报告帧282已无新增激光；完整 runs 的诊断字段全为 0。
- `main.ecl` 删除唯一 `SYNTHETIC_OVERLAY_ENTRY` 行后逐字恢复底子；overlay 不创建敌人、不调用 owner 专属接口。
- metadata/provenance、底子 SHA 与最终机器报告文件 SHA 一致。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `121b6b4ca4f99eb08e9bcc7233597a9a51364210e19650f2b2795c3c35479b8b` |
| `machine-spec.json` | `1b73add90cc5931205dd778bff5a81b0c374742681dc33773feb53b4bb27800e` |
| `main.ecl` | `23de0cd3304c48ae5e1cbf1d81c561020a040bbaa949a08551654ecf77ceea19` |
| `overlay.ecl` | `03b914a895e424c74711610fe857ea4e2ead1645fac410ac71fe9515c5af371f` |
| `meta.toml` | `d917fdc7e1e4f673becc709114a2f740536d5974457cfccd9354417136203806` |

## 结论

两卡均为 `REVISE`，不是 `BLOCK`：问题限于可定位的任务/规格声明与实现边界不一致；激光运行、底子隔离、来源元数据和诊断门均通过。修改后须更新五文件哈希并重新跑完整机器验收，再进行复审。

## 复审（最终修订）

根代理已按修订后的五文件重跑最终机器验收；两份机器报告均 `ok=true`、`errors=[]`，报告内文件 SHA 与当前工作区逐项一致。

### `synth_laser_s4_w10_v2` — PASS

作者已将 TASK 关键帧说明改为：帧 143 两条均处于预警，第一条帧 168、第二条帧 188 进入生效，解决了原相位错误。其余此前检查通过项保持不变：短棒推进、并发 2、warn/active/fade=45/90/12、帧 290 自然回收、color 15、底子恢复和来源隔离均与机器报告一致。

当前五文件 SHA256（与 `synth_laser_s4_w10_v2.machine.json` 一致）：

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `d7731f75f62fddcf7e2007a2c996c7e4ff5c2f222435da4c811e583522dc5179` |
| `machine-spec.json` | `2ef2ff111eaa3cd5df87126ac13368e54c9d68c998f9d611eeeb6bbd15121d24` |
| `main.ecl` | `23de0cd3304c48ae5e1cbf1d81c561020a040bbaa949a08551654ecf77ceea19` |
| `overlay.ecl` | `d71d2ed2dfabaa022029a9c66d22130730ca363a2fa2345b4a86a920257be706` |
| `meta.toml` | `66324b19d207f18edc95126ac13368e54c9d68c998f9d611eeeb6bbd15121d24` |

### `synth_laser_s4_w10_v3` — PASS

作者已将 TASK 与 machine-spec 的方向上限统一为真实实现的 147.5°（35°..147.5°），解决了 `35deg + rand(20481)` 的范围遗漏。其余此前检查通过项保持不变：单条平移线、原点每帧移动、长度 120、warn/active/fade=45/100/12、帧 280 自然回收、color 15、底子恢复和来源隔离均与机器报告一致。

当前五文件 SHA256（与 `synth_laser_s4_w10_v3.machine.json` 一致）：

| 文件 | SHA256 |
|---|---|
| `TASK.md` | `828c7649a253559219dc98b3677e4388c2bdcec61e79e712b9e7873b70c5be82` |
| `machine-spec.json` | `082e8257dff93e9de26b1c1d9bb271e359fb8a0d5415fa0ebb132795fea022b2` |
| `main.ecl` | `23de0cd3304c48ae5e1cbf1d81c561020a040bbaa949a08551654ecf77ceea19` |
| `overlay.ecl` | `03b914a895e424c74711610fe857ea4e2ead1645fac410ac71fe9515c5af371f` |
| `meta.toml` | `d917fdc7e1e4f673becc709114a2f740536d5974457cfccd9354417136203806` |

复审结论：两卡均 `PASS`，可进入下一步汇总；本 reviewer 未修改卡片或机器报告。
