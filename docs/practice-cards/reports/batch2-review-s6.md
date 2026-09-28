# Batch 2 独立 Luna 审查：synth_laser_s6_b1_v2/v3

审查日期：2026-09-28。审查者不是这两张卡的作者。依据为当前五文件、`laser-pilot-contract.md`、两份完整机器报告及 stg-harness 激光语义；没有把作者注释当作验收依据。

## synth_laser_s6_b1_v2 — PASS

- 结构与来源：五文件齐全；删除 `main.ecl` 唯一 `SYNTHETIC_OVERLAY_ENTRY` 后与 `cards/th06_s6_b1/main.ecl` 逐字相同；`meta` 的 source/data_kind/base_card/mutation_id、ranks/marks/time_limit 与底子一致；provenance 的底子 ECL SHA256 为 `3a391eb0832e52b03fb46fc1ddc70a92a8ed64bdc3b262466b920e4edfc4ea90`。
- 实际脚本：overlay 只创建 color 15 激光，不创建敌人或调用 `$self`、`aim_player`、`set_invuln`；开场 `wait(120)`，每 240 帧两条 `laser(..., 360, width, 60, 90, 12)`，最多两条同时存活。width 按 rank 0/1/2/3 为 6/6.5/7/8，均在 6..12；warn/active/fade 为60/90/12，满足契约。
- 几何：seed1 的首组实际原点约 `(-81,80)/(119,80)`、角度 `36.16°/143.84°`；seed7 及下一组也产生不同中心/角度。两条方向相对并在场中形成交叉。`lz_speed` 未使用，固定有限线的 start/end=0/360 与 TASK/spec 一致。
- 时序与回收：报告覆盖 rank0..3、seed1/7 共8次完整 `2700+60` 运行，全部 exit=0，诊断字段全为0；关键帧 state 0/1/2 与 285 帧回收一致。最后出生2283、`last_expiry_frame=2445 <= 2700`，报告无末帧 color15 激光。

当前文件 SHA256：

```text
TASK.md       161d318412963957171dc1e4547df599cd3da945a49763b311766a627310b029
machine-spec 5b9dcd2615914467c3736dbbae9a0d1db2f0f1d9f077ced0527a79c11ec4b6cf
main.ecl      d937d1370de0f4396d62b3b2167cf882929975db5621bf269e0042bdc87f6c07
overlay.ecl   eb7d4765a6709632480b7d70b5487baf5ce6e28b349bf05f76e1ee9e232d8025
meta.toml     f66367511c3b5127402dedc9e11d2ce121249fef7a7de162905f73904f4b54ad
```

## synth_laser_s6_b1_v3 — PASS

- 结构与来源：五文件齐全；入口行移除后底子逐字还原；`meta` 继承字段与 provenance 底子哈希正确，未发现留出同源或原卡改写。
- 实际脚本：overlay 只创建两条 color 15 激光，同一随机原点组成 V；`lz_omega` 在出生后立即设置，且按 rank 使用 ±32/48/64/80 BAM 每帧、每轮交替交换左右旋向。warn/active/fade 为60/90/12，最大并发2，满足契约及激光三态语义。
- 几何与随机：seed1 首组实际原点约 `(-52,80)`、角度 `61.57°/118.43°`，184帧转为 `72.12°/107.88°`，273帧为 `87.76°/92.24°`；下一组原点和开口不同。两条线保持相反旋向，且 warning 状态也按契约连续旋转。
- 时序与回收：报告覆盖 rank0..3、seed1/7 共8次完整 `2700+60` 运行，全部 exit=0，诊断字段全为0；关键帧与 state、旋转、285 帧回收一致。最后出生2283、`last_expiry_frame=2445 <= 2700`，末帧无新增 color15 激光。

当前文件 SHA256：

```text
TASK.md       81863b6319ae333839a9871511b53663b674f9b080296f41aa673c4e4d57db80
machine-spec 8837be2b1a867d1506a3284d5a4cdf576795512b9db254b583c97b41ac3829f1
main.ecl      d937d1370de0f4396d62b3b2167cf882929975db5621bf269e0042bdc87f6c07
overlay.ecl   480e392e8192fc9d9cd12279967e1b1369b3d531270819f8528b94b04e0aa236
meta.toml     2b8542af3b951ae2b7e6928f92934d70754ef54efcec2a0ca57dc93e12b6f716
```

两卡均建议进入下一阶段；本审查未修改卡目录、共享工具或机器报告。
