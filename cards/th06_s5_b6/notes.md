## mapping §10.1②「只给大玉挂」比 decomp 的 `heightPx≥30` 窄
影响面：疑似全池（所有用 `ex_ins_call(4,2)` 且场上有 32px 刀 / 火弹的卡）
证据：`renkolab/local/vendor/th06-decomp/src/EnemyEclInstr.cpp:578`（E/N）与 `:619`（H/L）过滤条件是 `heightPx >= 30.0f && spriteOffset != 5`，每颗**独立** 1/4 命中（`:622-638`），每次调用最多 14（E/N）/ 52（H/L）颗。按 §3，弹型 7 FIREBALL、8 DAGGER 都是 32px，故原作也会改向 Stage5Func5 的刀。本卡实测（out/main.ecl，rank 2，`--at 324`）：刀在出生时逐颗抽签即可表达（无需 `sh_task`），但每颗刀要一个发射任务才不超 1024 op/帧；每次调用 52 颗上限没有内建能建模。
建议：改对照表 §10.1②——把「大玉」明确为「32px 弹型（6/7/8）」，并注明「窗口内出生的弹在发射时逐颗抽、窗口前的弹挂一次性任务」；52 颗上限只能作为近似写进 report，或引擎侧给「全场弹改向」内建。
