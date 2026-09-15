# th06_s1_b1 转写笔记（范例：boss 非符 + 尾调用链）

原文：`ecldata1.ecl.txt` Sub14（:368）+ Sub15–18（:395–566）。段边界：Sub14 `timer_callback_threshold(2100)`，
`!NHL life_callback_threshold(900)` → Sub26（夜符）/ `!E timer_callback_sub("Sub19")`。boss 登场在 Sub13，停在 (192, 96)。

## 结构

| 原文 | 卡 |
|---|---|
| Sub14 `+100 call("Sub15")` | `pattern` 先 `wait(100)` |
| Sub15–18 末尾 `set_int_rand_bound($I0, 3); call_equ(A,…,0); call_equ(B,…,1); call(C)`，从不 `ret` | 调度循环 `next`（mapping §2.4），后继表逐个照抄 |
| `move_rand_in_bounds(-π, π); move_speed(3.0); move_time_decelerate(60)` | `wander(3.0fx, 60)` |
| Sub15 七发中玉扇（H/L 颗数逐发递增，E 首发速度 3.0 其余 4.0） | `for i in 0..6` + 按发号查表 |
| Sub16 四发环玉环夹三发小玉环（**小玉只有 3 发**，最后一发环玉后 +120） | `for v in 0..4`，`v < 3` 才发小玉 |
| Sub17 `+110` 的环：`!N`/`!H`/`!L` 各一条，**E 不发**（粘滞） | `if rank == …` 三支，E 无 |
| Sub18 `cmp_int($I0, 0); jump_equ(2, Sub18_456)` 两支对称扫射，`jump_dec(0/2, …)` 16 次 | `if rand(2) == 0` 取正负方向，`for k1 in 0..16 { wait(2); … }` |
| `jump(4, Sub18_740)` + `+120: //124` | 16 发后 `wait(120)` |

## 近似

- `move_bounds_set` 的位置夹紧：我方没有，`wander` 里夹紧目标点。
- 调度的随机数与原作 RNG 序列不同（不追求重放一致）。

## 自检（2026-09-16）

- `run --rank 0..3 --frames 2400`：零 fault，`段结束：PHASE_ENDED@2103`，弹峰值 82 / 107 / 259 / 356。
- `--at 116`（rank 0，Sub15 首发）：1 颗 × 10 层，速度 3.000, 2.800, …, 1.200（`(1.0 − 3.0)/10` 步长），角度 = 自机方向。
