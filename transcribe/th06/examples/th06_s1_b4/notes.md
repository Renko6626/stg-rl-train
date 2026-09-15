# th06_s1_b4 转写笔记（范例：符卡 + 减速转向弹变换 + 拆任务）

原文：`ecldata1.ecl.txt` Sub29（:883）→ Sub30（:889，宣言、`timer_callback_threshold(1500)`、移到中央、
`bullet_rank_influence(-1.0f, 1.0f, -3, 6, 0, 0)`）+ Sub31（:905，攻击循环）。卡名 `ST_ECLDATA1_SUB23_0` = 闇符「ディマーケイション」。

## 结构

| 原文 | 卡 |
|---|---|
| Sub30 `move_position_time_decelerate(120, 192, 96)` + `+120 ret` | `pattern` 先 `move_to` + `wait(120)` |
| `bullet_rank_influence(-1, 1, -3, 6, 0, 0)` | rank 16 下 `c1 += 1`：环 12→13、16→17、28→29、20→21，扫射 1→2 |
| Sub31 `+0/+60/+120` 三对 `bullet_circle_aimed(2, …, 68)`，每对前各一个 `bullet_effects(40, 1, …, ±π/2, 1.5)` | `rings()`：`TURN_R` / `TURN_L` 两个发射器槽，第二个环错开 `a1` |
| `+180` 两轮 × 两向扫射 `bullet_fan_aimed(1, 6, 1, 1, %F0, 0, %F1, π/32, 132)` | `sweeps()`：`AIM_S3` / `AIM_S4`（E/N 速度 3，H/L 速度 4） |
| `jump_dec(180, Sub31_1648, $I4)` 12 次、`jump_dec(180, Sub31_1588, $I5)` 2 轮 | `for rep in 0..2 { for ka … for kb … }` |
| `+244 jump(0, Sub31_0)` | 两个任务的周期都是 336 帧，同帧出生保持同步 |

**为什么拆任务**：4 个 xformdef 在同一个 sub 里占 48 字 locals，再调 `wander` 超 64（mapping §2.4 容量红线）。

## 近似

- `-0.57119864f` = −5957.8 BAM 取 −5958，`0.14279966f` = 1489.3 取 1489，12 发累计误差 4 BAM（≈0.02°）。
- 符卡超时 = 收卡失败（`SPELL_FAILED`），原作非耐久卡同样判失败。

## 自检（2026-09-16）

- `run --rank 0..3 --frames 1800`：零 fault，`段结束：SPELL_FAILED@1503`，弹峰值 147 / 161 / 185 / 361。
- `--at` 数值锚点（rank 0，首对环在帧 124 发出，初速 3.0）：
  - 帧 144：速度 1.575（`step_speed` 线性减速到一半）；帧 164：0.075。
  - 帧 165：朝向 +90°（90° → 180°）、速度 1.500。
  - 帧 347：首发扫射弹减速结束，重新瞄自机，速度 3.000。
