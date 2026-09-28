# 激光合成卡第二批独立审查（2026-09-27）

审查依据为当前磁盘上的 TASK、machine-spec、meta、main、overlay 与机器报告；文件哈希必须与报告一致。以下只记录已收到机器报告且已完成独立核对的卡。未有机器报告的卡不作 PASS。

## synth_laser_s2_b3 — PASS

脚本与机器几何基本符合修订后的规格：根级仅增加伴生 overlay，无 `spawn_enemy`、`$self`、`aim_player` 或 `set_invuln`；共享 engine RNG 每轮抽 x、初角和旋向，seed 1/7 在首条原点分别为 -57 / +82；Hard 使用 ±80 BAM/frame，Lunatic 使用 ±120 BAM/frame，快照角度变化与 `lz_omega` 在 warn、active、fade 三态持续旋转相符。width=8、长度360、warn60、active120、fade12，303帧进入fade、315帧消失；完整报告中 rank2/3 × seed1/7 共4次运行诊断全0、激光峰值1、末帧无激光。去掉 main 的唯一入口标记后与底子逐字一致，source provenance 和留出隔离检查通过。

首版 TASK 曾把次轮出生写成帧424；现版已明确修正为帧423，帧424观察到 timer=2。`wait(300)` 下完整出生序列为123、423、723、1023、1323、1623；当前新机器报告已绑定修正后的 TASK 哈希，故此项通过。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `18db62ca8e8afecd80d68f15e74ce8a1687fb5d9e330d04f323e8a75bc11c48b` |
| machine-spec.json | `5aff9a0194f405bbc5277187487922df1afb459b3097eecb4bbd0915e04961ef` |
| meta.toml | `93f777965c89350968d7f987516f93d1f04982c029f258bbacd2f8a6c0670b85` |
| main.ecl | `6fbd1043f0c70f419023f87d9aa77fa100094b2f6ff1cb3b29b87ee392eb9517` |
| overlay.ecl | `17498e1ac2a5e9518396d913d4cae992533aeb1d413c9508f72b9b5c4dc65d0a` |

机器报告：`ok=true`，4次完整运行；harness SHA-256 `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`，validator SHA-256 `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`，stg_rl 0.4.0。报告中的全部卡文件哈希与上述当前文件一致。

## synth_laser_s3_b1 — PASS

根级仅增加伴生 overlay；overlay 不建敌、不使用 owner / 玩家瞄准接口。每轮用共享 engine RNG 采样 center ∈ [-10,10]、half-gap ∈ [120,150]，seed 1/7 的初始位置不同。E/N/H/L 横移速度分别为1.0/1.25/1.5/2.0 px/frame；两侧从 center±half-gap 对称内收40帧、停10帧、再外移40帧，回到初始位置。最大速度下理论最小中心线间距80px，扣除两条width=8激光的总宽后净空72px。

机器报告覆盖rank0–3 × seed1/7共8次完整运行，全部exit=0、诊断为0、峰值2。帧124/168/184/214/254/288/300/334的数量、状态和范围与spec一致：收敛/恢复快照符合各rank速度缩放，fade于288开始并于300回收，下一轮于333出生、帧334已可见。报告中的两组seed未声称恰好抽到理论最小中心间距80px。另有首生122无激光、123两条timer=1、末次声明出生1383两条timer=1及末帧1860无激光。所有 rank/seed 的报告均显示不同的起始几何。main去掉唯一标记后与 `th06_s3_b1` 完全一致；底子来源哈希与 provenance 匹配，source-range留出检查无交集。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `ad8a6f9eb94cbbb6677b767b613bc92f35cde6c51d9a0e97f577c80f95d87b47` |
| machine-spec.json | `d9ebd7f6b42c739c1265c63313f45a503785a7af927d9b5058cc1940bb9becc6` |
| meta.toml | `37732f7d5f2cbe5f1ee2424bee65da0f8cf2c786118d7d9bea8a48dd1a582f51` |
| main.ecl | `31ed943fc65f1b9a43245cbb7a3784256a879b5b516014782a56b3fb659f7682` |
| overlay.ecl | `c0338e6fb2821ca8407dc0a98adbcf25a2ff9a12031a945b7fd7b2ba6741727a` |

机器报告：`ok=true`，8次完整运行；harness SHA-256 `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`，validator SHA-256 `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`，stg_rl 0.4.0。报告中的全部卡文件哈希与上述当前文件一致。

## synth_laser_s4_b1 — PASS

根级伴生任务不创建敌人、不调用owner接口。每240帧出生一条随机原点激光，`lz_aim(lz, 0deg)` 在出生时从激光原点瞄准player0，角度随后保持锁定；原点每轮随机，seed1/7快照不同。rank0/1/2/3完整width分别为6/8/10/12，warn60、active45、fade12，总寿命117，周期240，9轮最后出生2043、2160回收、overlay在2283结束，早于2400时限。

机器报告覆盖rank0–3 × seed1/7共8次完整运行，诊断为0、末帧新增激光为0。总激光峰值9包括底子原有color6四向激光；新增color15 overlay峰值为1，与spec一致。采样角度从x/y原点指向player0的(0,384)，脚本随后保持角度；rank宽度逐档匹配。入口去标记后底子逐字一致，source-range/provenance检查通过。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `194d14483fcad63f4525eaa34fc1811e454ca7729e3b69b27dc84a8a24bf4bd6` |
| machine-spec.json | `03d3b1ebc8f9b940ba0d7fe53bfc564700292ae9a8a3a5c34060cedd691157c9` |
| meta.toml | `85eeadef32de2ef3bcf452e952f8e00d6adf5b1215f8b0e32e29bd4ae75e09db` |
| main.ecl | `17e880d54f187528084db6c937229b4387c0bfa60336d6ff7a9d5e75b54ad900` |
| overlay.ecl | `ad5a1088a8342152ab7479e45cac9c0a3c4a3014ffd511697c84e274800b2dda` |

机器报告 `ok=true`，8次运行、errors为空；harness `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`、validator `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`、stg_rl 0.4.0；报告文件哈希与当前卡文件一致。

## synth_laser_s4_w10 — PASS

根级伴生任务只创建一组随机短棒，不增加敌人或调用owner接口。世界帧123一次生成两条，两个原点/方向分别抽样；rank0–3推进速度2/2.5/3/4px/frame，warn45、active90、fade12，总寿命147，单次有限任务在333帧左右结束。机器快照的end按速度增长、start遵循`max(0,end-96)`；帧258两条进入fade，270回收。8次完整运行诊断为0、总峰值2、末帧无新增激光。底子恢复、来源哈希和留出检查均通过。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `3752285ffd2152f81827c8ec243d7b495f33708b3f5b19c138178dc56ec70ce0` |
| machine-spec.json | `8fa8da5b851094ac38d779af634c2ef334984d29b6aaa85bd1480643a2775fc7` |
| meta.toml | `4a5f3ce5a9003689de07c9d4a596271aa601e5e8a1199ad8af1522d0e1d0daa3` |
| main.ecl | `23de0cd3304c48ae5e1cbf1d81c561020a040bbaa949a08551654ecf77ceea19` |
| overlay.ecl | `f8b0c1c2bccc74e4faff81dcd52dd887ef54d18939262f64d300dbdb1f20f497` |

机器报告 `ok=true`，8次运行、errors为空；harness `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`、validator `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`、stg_rl 0.4.0；报告文件哈希与当前卡文件一致。

## synth_laser_s5_b1 — PASS

脚本和机器报告显示单条水平光束从x=-90向右延伸，rank0–3 width为6/8/10/12，warn60、active120期间原点逐帧下移1px、fade12；8次运行诊断全0、峰值1，关键帧y位移符合脚本，帧315回收，新增激光在末帧归零。来源、底子哈希/逐字恢复、留出检查均通过。

TASK已修正通道表述：中心线距边界70px；width=12px时判定区边缘净空64px。当前机器报告绑定修订后的TASK哈希；代码和实测几何无需返工。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `6f42b8897b206b97d7aff4b9cd071d7ef41b1a156cfdb3c4a12332fcc2cbfd68` |
| machine-spec.json | `f4152f3a1cdb918fabda910a66bae6a7160def874ffed560fe5d3735aea90bc4` |
| meta.toml | `73fe3cb94546adda1201ebabc417f18d018925fd1b145aa5ac2c7b88764bdcc9` |
| main.ecl | `b6195d692358d23126a36ff9f4e1d1c486abeb582774f5e035361a5f77a8d2a1` |
| overlay.ecl | `859f35b4c60a040cb52719a8b2fcaca24863a12c30a010c79e3bb86bdfa74881` |

当前机器报告 `ok=true`，8次运行、errors为空；harness `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`、validator `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`、stg_rl 0.4.0，报告哈希与当前卡文件一致。

## synth_laser_s5_w05 — PASS

一次有限任务创建一条start=80/end=240、width=8的160px旋转段，初角和方向使用共享RNG，seed1/7关键帧角度不同；rank0–3速度幅值48/64/96/128 BAM/frame。帧124、168、184、214、254、288的状态和几何符合TASK，旋转在warn/active/fade三态都继续；帧300及末帧无激光。8次完整运行诊断为0、峰值1。底子入口只有一行、去标记逐字恢复，source/provenance和留出检查通过。

受审 SHA-256：

| 文件 | SHA-256 |
|---|---|
| TASK.md | `50838f74de0bfbffe7415783330b06e699c6cd63f8f22e0fc70b37c2a270f67b` |
| machine-spec.json | `d98eb6e8a420c63f3485dea3b59b07146121c410ebd27a3fb0b1b9d21844bf67` |
| meta.toml | `534998c3c5387d639ceeee57d63e874d3511564bbe40fa38374b5e40c1caa5e6` |
| main.ecl | `72d6bb9427273f8bede3bcb8b51aae818cd653bee0305887e786aa1395474e97` |
| overlay.ecl | `3936cfe37b7c4eadfd27b665c9e4339e7ef35f4b3084854a8248e0328327d3c7` |

机器报告 `ok=true`，8次运行、errors为空；harness `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`、validator `9afb1840bc468791f95903657be2f21d82c617cc7a3de8c854096f639d77abdc`、stg_rl 0.4.0；报告文件哈希与当前卡文件一致。

本报告未审计由我编写的 `synth_laser_s6_b1` / `synth_laser_s7_b1`；它们交由另一位Luna独立审查。机械验收和审查都不证明策略可解或玩家能躲。

## 本批核查边界

对已独立审查的8张（首批2张详见 `pilot-review.md`，本报告另含6张），我逐项确认了：机器规格正数量帧包含state与可核对的几何字段；machine-spec JSON没有重复键或重复关键帧；源码有限循环的最后一次出生和自然回收都在time_limit前，且机器报告在time_limit+60的末态没有新增激光；meta包含laser标签，title明确合成变异，base/source_ref/provenance与底子相符。每份官方报告里的TASK/spec/meta/main/overlay哈希均与当前文件一致。

动态瞄准的synth_laser_s4_b1当前machine-spec也给每个正数量关键帧增加了angle_deg∈[64.9,115.1]约束；范围由无输入harness的player0初始位置(0,384)及随机原点边界x∈[-100,100]、y∈[70,170]推出，报告实测角度均在范围内。它检查当前固定harness边界下的角度范围，不证明任意玩家位置下的一般动态瞄准关系或可躲性。

首批 `synth_laser_s1_b1` / `synth_laser_s2_b1` 的代码、任务规格和机器报告哈希与 `pilot-review.md` 所列版本一致；本次未改动它们。由我编写的S6/S7两卡不属于独立审查范围，须等A的交叉review后再计入10卡总门。

这些结论只覆盖机械规格、来源与报告一致性，不证明策略可解或玩家能躲；报告采样关键帧，不等于逐帧穷举。
