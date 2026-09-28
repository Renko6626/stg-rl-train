# 激光合成卡试产契约（2026-09-27）

范围：10 张训练底子上的激光变异；不是原作忠实转写。原 cards/ 不改，合成产物在 cards-synthetic/；旧实验默认只读 cards/。

作者读取引擎 `.claude/skills/writing-danmaku-ecl/SKILL.md`、`docs/ecl-lang/9-lasers.md`、本文及每卡独立任务。作者只写自己卡目录；独立 Luna 审查者只写审查报告，必须读取任务规格、实际脚本及机器报告，不能把作者注释当预期。

## 激光语义

- width 是完整判定宽度，半宽 width/2；原创没有原作 width 减半换算。
- lz_speed 会重置 end=start，再每帧推进 end；start 随棒长推进。speed 是段推进速度，vx/vy 是原点实际位移。
- lz_omega 在三态都转；lz_rotate 是一次性转。每 N 帧跳转与连续转并非逐帧等价。
- aim_player 从 owner 瞄；lz_aim 从激光原点瞄；lz_origin 解除挂靠。
- 预警/收缩不判定，生效判定。守卫 lz_alive 后再写可能回收的句柄。
- RL omega 是实际 dang 的弧度/帧，包含 rotate；harness --at omega 是配置 BAM/帧。不要由后者0断言脚本运动缺失。
- 当前 stg_rl 0.4.0 已正确导出 rotate/origin/挂靠实际运动。出生帧初始几何设置不应报运动尖峰。

## 保留底子与参数

复制底子全部 ECL，唯一允许改动是在原 main 的 loop 之前插入一行带 `// SYNTHETIC_OVERLAY_ENTRY` 标记的 `spawn synth_overlay();`；删除该行必须逐字恢复底子。所有新增逻辑在 overlay.ecl，命名统一 synth_ 前缀，不能改原有发弹、reward或策略观测。overlay 是根 main 的伴生任务，不创建额外敌人，不调用 owner 专属接口（$self/aim_player/set_invuln），因而不增加敌人观测或抢占跟点目标；120帧开场缓冲，有限激光，避免同帧无限循环。以下参数仅为试产保守范围，不是原作实测或可解保证：最多新增4条同时活激光，常规width 6..12px，warn至少45帧，active最多120帧，fade最多15帧。不承诺机械验收证明卡可解。

## 元数据

合成 source='synthetic', data_kind='synthetic', base_card, mutation_id；继承底子ranks/marks/time_limit，tags追加laser；provenance保存base_source/base_source_ref及原ECL逐文件SHA256。原作source='th06'加载为data_kind='original'，其他未知来源保持unknown。

## 验收循环

先编译，再每个声明rank、seeds 1/7 各跑完整time_limit+60帧。退出码0不等于通过；要求诊断字段存在且task_faults/contract_viol/pool_full/hits_ovf/events_ovf/reqs_dropped全为0，解析缺失即失败。还须底子哈希/逐字还原、没有留出同源源区间、laser峰值/关键帧数量与任务声明匹配、实际overlay生效、段结束合理。采集关键帧激光几何，检查width/start/end/state、方向和运动；保存JSON机器报告。

不同Luna reviewer按规格审查全部脚本+机器报告，给pass/revise/block及定位；返工后完整重跑机器验收和独立审查。上限3轮，超限交主代理判断。通过两类验收才为入库候选。报告保存在docs/practice-cards/reports/，图片/大型临时产物不入库。

现有TH06转写后端及Opus抽检/逐条复核要求不变。跨仓skill此轮不修改，以本契约补齐激光入口和检查。
