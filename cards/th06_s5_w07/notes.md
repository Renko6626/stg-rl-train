## unit.json 的 note 把 move_velocity 的第一参当成速度

影响面：疑似全池
证据：`unit.json:31` note 写「直下 2.5」；`source.txt:140` 原文 `move_velocity(0.0f, 2.5f)` 行尾注释为 `a0=0°=0bam`；decomp `EclManager.cpp:330-335` 明示 `args.pos.x→enemy->angle`、`.y→enemy->speed`，即 0° = +x 水平向右，不是直下。同一长编队的 `th06_s5_w08` 对同一 Sub1/9/10/11 用的就是「水平穿越场地」。
建议：改切分 / unit.json note 生成逻辑（把 `move_velocity(a, s)` 记成 `a=角度、s=速度`）。本单元 `unit.json` 属只读输入，未改动，卡与 report 已按原文修正。
