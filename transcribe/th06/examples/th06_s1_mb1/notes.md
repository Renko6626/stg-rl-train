# th06_s1_mb1 转写笔记（范例：中 boss 非符 + 弹变换）

原文：`ecldata1.ecl.txt` Sub9（:169）攻击部分 + Sub5（:106）+ Sub6（:118）。段边界：Sub9 开头
`timer_callback_threshold(1440)` → 超时跳 Sub8（退场）；`!HL life_callback_threshold(500)` → Sub10（月符，含激光，另一个单元，skip）。

## 结构

| 原文 | 卡 |
|---|---|
| Sub9 `move_position(192, -32)` + `move_position_time_decelerate(60, 320, 128)` | 出生 `(0, -32)`，`pattern` 开头 `move_to(60, 128, 128, 2)` |
| `+160 bullet_circle_aimed(1, 6, 16, E1/N3/H5/L7, 2.0, …, 9)` | `ring_aimed(6)`，`flags 9` → `BURST` |
| `set_int($I4, 2)` … `jump_dec(192, Sub9_712, $I4)` | `for it in 0..2`，每轮先 `wait(10)`（跳回时间 192，下一条在 202） |
| `call("Sub5", 色, 角)` ×5（Sub5 立即 `ret`） | `sub5(i0, f0)` 同步调用，参数按值 |
| Sub5 `bullet_effects(…, 0.02f, -999.0f, …)` + `flags 21` | `BURST_ACCEL`：冲刺后沿自身方向永久加速 |
| `call("Sub6", 色, …)` ×5 | `sub6(i0)`，内部重抽 `$F0`/`$F1` |
| `+850` 退场、`+910 enemy_delete` | 两轮共 1488 帧，1440 超时先到，保留但跑不到 |

## 近似

- `set_int($F1, 1)`（原文把整数写进浮点变量）后 `$F1` 马上被 Sub6 重抽，无影响，删掉。
- 冲刺在出生帧少积一次加速度（我方 6.688 vs 原作 7.0），16 帧后对齐。

## 自检（2026-09-16）

- `run --rank 0..3 --frames 1740`：零 fault，`段结束：PHASE_ENDED@1443`，弹峰值 53 / 130 / 211 / 320。
- `--at` 数值锚点（rank 0）：
  - 帧 164 首环刚出：速度 6.688；帧 179：2.000（冲刺 16 帧结束，回到 speed1 = 2.0）。
  - 帧 281 Sub5 第 1 环（色 6、角 0）：速度 0.000；帧 282：0.020；帧 331：1.000（加速 0.02/帧）。
  - 帧 281 Sub5 第 2 环（色 2、角 1365bam = 7.5°）：速度 2.5 = 5 − 8 × 0.3125（冲刺中）。
