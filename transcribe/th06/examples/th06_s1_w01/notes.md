# th06_s1_w01 转写笔记（范例：波次卡）

原文：`ecldata1.ecl.txt` timeline 帧 100–1064；小怪 Sub0（:2）、Sub2（:43）、Sub3（:61）、Sub4（:85）。

## 结构

| 原文 | 卡 |
|---|---|
| timeline `enemy_create` / `enemy_create_mirror` | `wave()` 里按相对帧 `spawn_enemy`，卡帧 = 120 + (原文帧 − 100) |
| Sub0 / Sub2 开头 `!L shoot_disable(); bullet_fan_aimed(…); shoot_enable(); shoot_interval_delayed(120);` | **粘滞 `!L`**：只有 Lunatic 才 `spawn pellet_autoshoot()` |
| Sub0 `move_velocity` + `+40`/`+120`/`+220` 三次 `move_angular_velocity` | `sub0()` 里逐帧积分 80 帧 / 100 帧，之后直飞 |
| Sub3 / Sub4（结构相同，只有发弹难度不同） | 合成一个 `popcorn(mirror, kind)` |
| Sub3 `+70 bullet_fan_aimed(1, 2, …, 3)` | `sh_*` 自机狙扇，`flags 3` → `BURST` |
| Sub3 `+130 move_acceleration + move_angular_velocity`、`+190` 角速度归零 | 60 帧积分转向加速，之后只加速 |
| `enemy_delete(0)` 在 +10000（实际靠出界删除） | `oob_guard()` 出界 `die()` |
| `anm_*` / `enemy_set_hitbox` / `anm_death_effects` | 丢弃 / `set_hitbox(9.33fx)` |

## 近似

- 小怪无敌（D8），原作死亡回调、掉落不模拟。
- 出生特效期 1/3 速不模拟（mapping §4.2）。
- 角速度 `0.019634955f` = 204.8 BAM/帧，取 205；`0.05235988f` = 546.1，取 546。

## 自检（2026-09-16）

- `check` OK；`run --rank 0..3 --frames 1700`：零 fault，`段结束：PHASE_ENDED@1403`，弹峰值 16 / 34 / 96 / 162。
- E/N/H 弹少是原作如此（只有 Sub3 发弹）。
