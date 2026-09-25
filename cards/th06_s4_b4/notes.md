## 后台自动射击（shoot_interval）跨 sub 持续，按 sub 各写一个伴生任务会错

影响面：疑似同关 / 疑似全池（凡「A sub 设 `shoot_interval`，B sub 继续用/改它」的 boss 段）

证据：th06 decomp `EclManager.cpp:428-436`（`shoot_interval(n)` 写 `enemy->shootInterval` 并
`shootIntervalTimer.SetCurrent(0)`）与 `:980-987`（每帧更新的 `else` 分支里 `Tick()`，到点就用当前
`bulletProps` 开火并重置计时）。这个 `else` 分支在**任何** ECL sub 执行期间都照跑，且 `shootInterval`
是敌状态、`ret` 不恢复。本单元实测：`ecldata4.ecl.txt` Sub38 开头 `shoot_interval(20)` 后，紧接着
同步调用 Sub32/Sub28（180 帧）期间仍在按 20 帧自动开火，用的是模式 sub 重写的 `bulletProps`。

`mapping.md` §4.3 的「写法 A」（每个开火段挂一个伴生 `autoshoot` 任务）如果按 sub 各写一份，
伴生任务会在每个 sub 边界重新 `first = n`，把原作的连续计时器打断。正确做法：把
`shoot_interval` 状态（下一发帧 `nf` + 当前 `iv`）提到一个贯穿整个模式的调度任务里，
只在原作真正 `shoot_interval(n)` 的帧改 `iv`/`nf`，props 变化点（各 sub 的 `bullet_*`）同步重配。
本卡 `autoshoot` 是这一写法的实例（`out/main.ecl`）。

建议：在 `mapping.md` §4.3 写法 A 下补一句「计时器跨 sub 持续，写法 A 的伴生任务必须覆盖到下一次
`shoot_interval` 改动，不能每个 sub 各起一个」。
