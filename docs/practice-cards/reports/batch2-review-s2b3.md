# Batch 2 independent review — `synth_laser_s2_b3_v2` / `v3`

审查依据：`laser-pilot-contract.md`、两卡当前磁盘上的 TASK/spec/meta/main/overlay、最终机器报告 `synth_laser_s2_b3_v2.machine.json` 与 `synth_laser_s2_b3_v3.machine.json`。本审查没有修改卡片或机器报告。两份机器报告均标记 `ok=true`，覆盖 rank 2/3、seed 1/7、2100+60 帧；运行诊断计数均为 0，颜色、宽度、段时序和自然回收均通过机器门。

## `synth_laser_s2_b3_v2` — REVISE

已核对：

- `overlay.ecl:13` 使用 `laser(15, ..., 360.0fx, 8.0fx, 60, 120, 12)`；颜色 15、宽度 8、warn/active/fade 均在契约范围内，且峰值为 1。
- `overlay.ecl:7` 的 `for round in 0..6` 与报告关键帧对应首帧 123、每 300 帧一轮、末轮 1623；机器报告的帧 124/184/214/254/303/315 几何与状态符合实际脚本，末次自然回收在 1815。
- 原点通过 `lz_origin` 平移，且每次写入前由 `lz_alive` 守卫；无新增敌人、无 owner 专属接口。删除 `main.ecl` 唯一入口后与 `cards/th06_s2_b3/main.ecl` 逐字一致。metadata 的 synthetic/data_kind/base_card/mutation_id、继承字段、laser 标签、source_ref 与 provenance 均齐全。
- seed 1/7 的机器关键帧出生原点与扇区不同，随机化可观察。

需要返修：

- `overlay.ecl:10-11` 写成 `30deg + (rand(31) as angle)` 与 `120deg + (rand(31) as angle)`。按 ECL 角度 cast 语义，`int as angle` 是 BAM 位穿透；`rand(31)` 只会增加原始 0..30 BAM（约 0..0.165°），实际角度约为 30..30.165° 或 120..120.165°，不是 TASK.md 声明的 30..60° / 120..150°。机器 spec 只给出过宽的 30..150° 区间，因此未捕获该规格与实现不一致。请使用明确的 BAM/角度换算，或收窄并同步 TASK/spec 为真实范围，然后重跑完整机器验收。

## `synth_laser_s2_b3_v3` — REVISE

已核对：

- `overlay.ecl:16-19` 创建两条颜色 15、宽度 8、长度 320、warn/active/fade 为 45/120/12 的激光；峰值 2，句柄写入有 `lz_alive` 守卫，机器诊断与回收均通过。
- `overlay.ecl:7` 的 6 轮与报告关键帧对应首帧 123、之后每 360 帧、末轮 1563，末次自然回收 1740；无新增敌人，原作 main 删除入口后逐字还原，metadata/provenance/source_ref 完整。
- seed 1/7 的首轮原点与角度可观察不同，rank 2/3 的 omega 幅值按声明变化。

需要返修：

- `overlay.ecl:10-11` 同样使用 `rand(31) as angle`，因此实际出生角仅约 45..45.165° 或 105..105.165°，而 TASK 声明的 45..75° / 105..135° 未实现。请修正角度随机化或同步规格后重跑机器验收。
- TASK.md 声明“两条的角度差应保持 180°”，但脚本在 `overlay.ecl:18-19` 给两条设置相反的 `lz_omega`。机器报告直接显示：rank2 seed1 在帧124 为 104.01°/286.12°，到帧169 为 80.28°/309.85°；角度差随时间改变，并不保持 180°。这与“相向反向扫”形态可以一致，但必须修正 TASK 的错误不变量，或改脚本使两条保持 180° 后再验收。建议保留反向 omega 并把 TASK 改为“出生时相差 180°，随后因反向 omega 逐帧分离”，同时在 spec 中声明可验证的角度关系。

## 当前五文件 SHA256

机器报告中的哈希与当前磁盘复算一致：

| card | TASK.md | machine-spec.json | main.ecl | overlay.ecl | meta.toml |
|---|---|---|---|---|---|
| `synth_laser_s2_b3_v2` | `ba105fe0a18d1defdd18a3b848f4200cec2c6e6aa1a74c2dac4c56533e734766` | `341d5333bf5885cd508f0c43c1171c21fa587473178b7e520f34afe38b935a8c` | `6fbd1043f0c70f419023f87d9aa77fa100094b2f6ff1cb3b29b87ee392eb9517` | `5aab23c8c31150e6fb4220cd8a33955155774b1712d1cf75f1dacd04cc5fe3d3` | `d8e9027b4a9a9be1484382083567d13836759b19e0106e23b56bf8cc7b8266ed` |
| `synth_laser_s2_b3_v3` | `2ba8a07d218509bd45a733cf03c4cb06940c3bcd5ab0cb2e5ebf45d9e263f5b2` | `0aa8f04a76c93a87ac1f1860d75c81ab5eb53679ead77bf1249c1c7111f8f473` | `6fbd1043f0c70f419023f87d9aa77fa100094b2f6ff1cb3b29b87ee392eb9517` | `97e3790bad961d571efc90ffb668851cacd5c41d9ee3ed782086b0b6f2a55f5b` | `e645b35854f149fda878f1ab9e8fcae91b516fedbf03713a2a8f4b41628ad0a9` |

结论：两卡机器门均 PASS，但独立源码/规格审查均为 **REVISE**；当前不应计入通过双门的可用卡池。修订后需更新 TASK/spec（必要时 overlay）、重新生成机器报告并以新哈希复审。

## 修订复审（当前版本）

根代理已修正随机角度并重跑完整机器验收。复核当前磁盘源码、TASK/spec、最终机器报告及哈希：两份报告均 `ok=true`，覆盖 rank 2/3、seed 1/7、完整 2160 帧；所有运行的 `task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 均为 0。当前机器报告中的五文件 SHA 与磁盘复算一致，底子 main 删除唯一入口后仍逐字还原。

### `synth_laser_s2_b3_v2` — PASS

- `overlay.ecl:10-11` 已改为 `rand(5462) as angle`；按 BAM 语义，5462 BAM 约 30°，实际出生角落在 30°..60° 或 120°..150°。报告关键帧实测 seed 1 为 131.54°、seed 7 为 49.30°，满足声明范围且 seed 差异可见。
- 颜色 15、宽度 8、长度 360、warn/active/fade 60/120/12、单条峰值、x/y 运动与反弹、末次回收 1815 均与 TASK/spec 和 overlay 一致。来源字段、provenance、laser 标签及原作保留检查通过。

### `synth_laser_s2_b3_v3` — PASS

- `overlay.ecl:10-11` 已改为 `rand(5462) as angle`；出生角符合 45°..75° 或 105°..135°。报告关键帧 seed 1 首帧为 115.49°/297.60°，seed 7 为 65.36°/243.25°，随机化及相对反向关系可观察。
- TASK/spec 已明确“出生时相差 180°；生效期间因相反 omega 按两倍 omega 改变”，与 `lz_omega` 实际语义一致。颜色 15、宽度 8、长度 320、warn/active/fade 45/120/12、双条峰值、相反 omega 幅值和末次回收 1740 均通过。

### 当前五文件 SHA256

| card | TASK.md | machine-spec.json | main.ecl | overlay.ecl | meta.toml |
|---|---|---|---|---|---|
| `synth_laser_s2_b3_v2` | `ba105fe0a18d1defdd18a3b848f4200cec2c6e6aa1a74c2dac4c56533e734766` | `341d5333bf5885cd508f0c43c1171c21fa587473178b7e520f34afe38b935a8c` | `6fbd1043f0c70f419023f87d9aa77fa100094b2f6ff1cb3b29b87ee392eb9517` | `5aab23c8c31150e6fb4220cd8a33955155774b1712d1cf75f1dacd04cc5fe3d3` | `d8e9027b4a9a9be1484382083567d13836759b19e0106e23b56bf8cc7b8266ed` |
| `synth_laser_s2_b3_v3` | `2ba8a07d218509bd45a733cf03c4cb06940c3bcd5ab0cb2e5ebf45d9e263f5b2` | `0aa8f04a76c93a87ac1f1860d75c81ab5eb53679ead77bf1249c1c7111f8f473` | `6fbd1043f0c70f419023f87d9aa77fa100094b2f6ff1cb3b29b87ee392eb9517` | `97e3790bad961d571efc90ffb668851cacd5c41d9ee3ed782086b0b6f2a55f5b` | `e645b35854f149fda878f1ab9e8fcae91b516fedbf03713a2a8f4b41628ad0a9` |

复审结论：两卡均 **PASS**，旧版 REVISE 发现已由当前脚本与规格修复，满足机器验收与独立源码审查双门。
