## 逐颗 `fire` 复刻大 count 的 `bullet_random` 会撞单任务 1024 条/帧指令预算

影响面：疑似全池（所有把 `bullet_random` / `bullet_random_speed` 的 count>~28 逐颗 `fire` 的单元）

证据：
- 本单元首版把 Sub86_20 的 `bullet_random(7, 0, 32, 1, …)`（H 档 32 颗）逐颗 `fire` 写在同一 pattern 任务里：
  `stg-harness run out --rank 2 --frames 2700` →
  `✘ task fault ×1 … code 3 BUDGET 指令预算耗尽`，`峰值：弹 32（帧 124）`（32 颗都发出后任务被杀）；同卡 L 档
  （22 颗）`task_faults 0`。
- 把该环拆成 `spawn ring_part(16)` ×2 后，H/L 两档 `task_faults 0`（弹峰值 209 / 193）。
- 指令预算定义见 `stg-engine/docs/ecl-ops.md:405`、`docs/superpowers/specs/2026-09-24-engine-rl-round2-design.md:90`（单任务 1024 条/帧）。

建议：改对照表 §4.2 的 random 族逐颗 `fire` 示例 / §2.4 容量红线，加一句「逐颗 `fire` 的大 count 冒烟：
单任务一帧超过约 30 次 `fire`（含每颗 `rand`）会 `FAULT_BUDGET`，拆成 `spawn` 的并行 emitter 或分帧」。
只是提醒：引擎行为本身没问题。
