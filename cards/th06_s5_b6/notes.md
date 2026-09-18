## mapping §10.1① 只停「时停窗口内发的弹」，decomp 是全场弹都停

影响面：疑似同关（Sakuya 的 ex_ins_4 时停卡：Sub43 / Sub67 等都会再撞）

证据：`renkolab/local/vendor/th06-decomp/src/BulletManager.cpp:668`

```
    if (g_GameManager.isTimeStopped)
    {
        return CHAIN_CALLBACK_RESULT_CONTINUE;   // 整帧跳过所有 bullet 的 OnUpdate
    }
```

即 `ex_ins_call(4,1)` 之后，**时间停止前已经在飞的弹也冻住**（本单元 Sub57 的 +20 环在 +50
才停）。mapping §10.1① 的原型只把「窗口内发的弹」发成 0 速挂 `wait_signal`，窗口前的弹会
继续飞，位置/启动时刻与原作不一致。

本单元的做法（`out/main.ecl` 的 `bigball_a..d`）：给窗口前的环弹挂每弹任务，出生 +50 帧
`set_speed(0,…)` 刹停、+170 帧恢复本层速率；4 层速率各写一份任务（xformdef 的 `@N` 是后置
延迟，无法表达「先飞 50 帧再停」，故不能用 xformdef 的零任务槽方案）。跑了 `--at 340/430`
核实位置与改向。

建议：改对照表 §10.1①，补一句「窗口前已存在的弹需自行停车（逐弹任务按层写死速率；xformdef
的 `@N` 是后置延迟，做不了定时停车）」，并把它从「已知偏差」里区分出来。

## mapping §10.1②「只给大玉挂」比 decomp 的 `heightPx≥30` 窄

影响面：疑似全池（所有用 `ex_ins_call(4,2)` 且场上有 32px 刀 / 火弹的卡）

证据：`renkolab/local/vendor/th06-decomp/src/EnemyEclInstr.cpp:578`（E/N）与 `:619`（H/L）
的过滤条件是 `heightPx >= 30.0f && spriteOffset != 5`。按 mapping §3，TH06 弹型 7 FIREBALL、
8 DAGGER 都是 32px，故原作也会随机改向 Stage5Func5 的刀；mapping §10.1② 的注意里写「只给
大玉挂，别给小弹挂」，把「大玉级（heightPx≥30）」窄成了「大玉」。

本单元实测：H/L 的 Stage5Func5 刀共 7 轮 × 9 点 × 3 颗 = 189 颗，逐颗 `sh_task` 会额外占近
190 个任务槽（池上限 256，本卡实测任务峰值 122）。故按 mapping 从简、未给刀挂改向任务
（`out/report.md` 已声明）。

建议：改对照表 §10.1②——把「大玉」明确为「32px 弹型（6/7/8）」，并注明逐颗挂任务会撞任务池
256、需按卡权衡；或引擎侧提供低开销的「全场弹改向」内建。
