# Batch 2 独立审查：`th06_s1_b1` v2/v3

审查者：Luna（非本组卡作者）  
审查依据：`laser-pilot-contract.md`、两卡实际五文件、对应 `.machine.json` 全量报告。

## 总结

两卡机器报告均为 `PASS`、`errors=[]`，覆盖 rank 0–3、seed 1/7 的完整 `time_limit+60` 运行；退出码为 0，`task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 全为 0。独立源码复核确认原作入口外仅有一行允许的 overlay 标记，移除该行后 `main.ecl` 与底子逐字一致，provenance 的底子哈希与实际底子匹配，overlay 不创建敌人、不调用 `$self`/`aim_player`/`set_invuln`。

两卡当前结论均为 **REVISE**：TASK.md 的颜色描述与实际脚本、machine-spec 和机器报告不一致。修正 TASK.md 后需要重新生成五文件哈希，并以新哈希重新绑定机器审查。

## `synth_laser_s1_b1_v2` — REVISE

定位：`cards-synthetic/synth_laser_s1_b1_v2/TASK.md:4` 写“颜色 12”；实际 `overlay.ecl:11-12` 两条 `laser()` 均使用颜色 15，`machine-spec.json` 的 `synthetic_color` 为 15，机器报告所有关键帧实际 `color=15`。

实际几何与规格一致：每轮两条平行竖线，原点 y=40、角度 90°、长度 360、宽度 10；warn/active/fade 为 60/90/12，首帧 123、每 210 帧一轮，最后出生 1803、自然回收声明 1965。报告关键帧确认 seed 1/7 首轮均为 x=120/192，第二轮分别为 -120/-48 与 60/132，随机化可观察；峰值 2 条，颜色和状态均正确。

来源隔离与入口保留通过；当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `ac321f5e1bb8ff36da1c076ae796092ca1dbfd645bed831f032eb4e93f72ac0b` |
| machine-spec.json | `e2d0a75b6933adef0222c7989bfbcc94bd4483e321d1ffe7568882e2c7058028` |
| main.ecl | `4a46d0172d5558e781279beb59fa22dfc49f770344a04e1b1e458c67fd91b426` |
| overlay.ecl | `afd73a299207e4118ccd5530348ff48aa248637290194a9ece153f2909049adc` |
| meta.toml | `0dc25cb0319736d94a3a1aff7d2329c7a6631765d0a8f8a43f0a5dfd33a14fa8` |

## `synth_laser_s1_b1_v3` — REVISE

定位：`cards-synthetic/synth_laser_s1_b1_v3/TASK.md:4` 写“颜色 13”；实际 `overlay.ecl:12` 使用颜色 15，`machine-spec.json` 的 `synthetic_color` 为 15，机器报告所有关键帧实际 `color=15`。

实际几何与规格一致：每轮一条斜向预警线，原点 y=60、长度 420、宽度 8，方向 45°/135° 交替；warn/active/fade 为 60/90/12，首帧 123、每 210 帧一轮，最后出生 1803、自然回收声明 1965。报告关键帧确认 seed 1/7 首轮 x=120，第二轮分别为 -120 与 60，方向均按轮次切换至 135°；峰值 1 条，状态、范围和颜色均正确。

来源隔离与入口保留通过；当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `a7bfae95d46cc3ab4a4a63ec01e2adbc643c310aa592c5a364b369eba0701246` |
| machine-spec.json | `012f303b6d9fdc974763a64477ee88fcec74a8ef84d23de0572720d2424ec061` |
| main.ecl | `4a46d0172d5558e781279beb59fa22dfc49f770344a04e1b1e458c67fd91b426` |
| overlay.ecl | `80b4ae891076d93b99641413dd5da3cf8c629eccf7fe6532d8c6beffd194ab13` |
| meta.toml | `f8401e9f0f43c34d4afc4140d138648fdb3793341c536287116b70e6de73080b` |

## 复审（颜色修订后）

根代理已重跑并刷新两份机器报告。复核确认两项旧发现均已解决：v2/v3 的 TASK.md 颜色描述现均为 15，与实际 `overlay.ecl`、`machine-spec.json` 和关键帧报告一致。两份刷新报告均为 `ok=true`、`errors=[]`，完整覆盖 rank 0–3、seed 1/7，诊断字段保持全零。

### `synth_laser_s1_b1_v2` — PASS

当前报告 `file_sha256` 与工作区五文件逐项一致：

| 文件 | SHA256 |
|---|---|
| TASK.md | `d50015ed2418ee721d5412e57daeda7933b4d7b68cc9c9b91c47ce87144d74d2` |
| machine-spec.json | `e2d0a75b6933adef0222c7989bfbcc94bd4483e321d1ffe7568882e2c7058028` |
| main.ecl | `4a46d0172d5558e781279beb59fa22dfc49f770344a04e1b1e458c67fd91b426` |
| overlay.ecl | `afd73a299207e4118ccd5530348ff48aa248637290194a9ece153f2909049adc` |
| meta.toml | `0dc25cb0319736d94a3a1aff7d2329c7a6631765d0a8f8a43f0a5dfd33a14fa8` |

### `synth_laser_s1_b1_v3` — PASS

当前报告 `file_sha256` 与工作区五文件逐项一致：

| 文件 | SHA256 |
|---|---|
| TASK.md | `7963b72169a39bca25a75858b1e917ffd2e91e76cdb3a7350bd07eacb1c1439a` |
| machine-spec.json | `012f303b6d9fdc974763a64477ee88fcec74a8ef84d23de0572720d2424ec061` |
| main.ecl | `4a46d0172d5558e781279beb59fa22dfc49f770344a04e1b1e458c67fd91b426` |
| overlay.ecl | `80b4ae891076d93b99641413dd5da3cf8c629eccf7fe6532d8c6beffd194ab13` |
| meta.toml | `f8401e9f0f43c34d4afc4140d138648fdb3793341c536287116b70e6de73080b` |
