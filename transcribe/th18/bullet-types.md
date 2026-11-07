# TH18 弹型、颜色与基础半径

适用TH18 v1.00a，目标词表要求ENGINE_VER31及以后。

## 使用方式

`etSprite(id, type, color)` 中，`id` 是发射器槽，`type` 才是本表编号，`color` 是该弹型内部色号。EX SETSPRITE 换型时也应查本表，不能把 `type` 当成我方 appearance、ANM script 或贴图 sprite 编号。

表中半径为基础圆半径，EX动态几何另按实际机制处理。TH18已核type0–47；48/49未建立映射，不能照其他作品套用。

## 目标 appearance 与颜色

新词表在stg-engine `godot/ecl/game/touhou-bullets.ecl`。把该文件加入卡片编译目录，或复制所需常量；名字不是全局内建关键字。TH18行基址为 `352 + type*16`，`fire(shape,color,...)` / `sh_sprite(slot,shape,color)` 中直接保留原作色号，最终逻辑appearance=`shape+color`。

逻辑appearance与物理贴图格分开：弹池与RL TYPE保留逻辑编号；Godot、harness输出和Python预览通过生成布局取物理格。不要把 `run --at` 的物理sprite列当成原作type。物理图集采用64px格，小图居中留白，保持原生静态尺寸。

新48型不再套旧12形的8色→16色换色表。缺色槽无效，不取模补色；固定色火球/音符忽略输入color，所以16列均有效并共用首帧。有效色槽见下表。

## 48种弹型的新词表

半径列按易读小数显示，实际运行使用原生f32最近的Q16.16值；不会回落到旧图形行的半径。

| 原type | 目标名字 | 逻辑行基址 | 基础半径 | 有效色槽 |
|---:|---|---:|---:|---|
| 0 | `TH18_PELLET` | 352 | 2.4 | 0–15 |
| 1 | `TH18_PELLET2` | 368 | 2.4 | 0–15 |
| 2 | `TH18_INVERT_POPCORN` | 384 | 2.4 | 0–15 |
| 3 | `TH18_POPCORN` | 400 | 2 | 0–15 |
| 4 | `TH18_BALL` | 416 | 4 | 0–15 |
| 5 | `TH18_BALL2` | 432 | 4 | 0–15 |
| 6 | `TH18_RING_BALL` | 448 | 4 | 0–15 |
| 7 | `TH18_RING_BALL2` | 464 | 4 | 0–15 |
| 8 | `TH18_RICE` | 480 | 2.4 | 0–15 |
| 9 | `TH18_KUNAI` | 496 | 2.4 | 0–15 |
| 10 | `TH18_SHARD` | 512 | 2.4 | 0–15 |
| 11 | `TH18_TALISMAN` | 528 | 2.8 | 0–15 |
| 12 | `TH18_ARROWHEAD` | 544 | 2.4 | 0–15 |
| 13 | `TH18_BULLET` | 560 | 2.4 | 0–15 |
| 14 | `TH18_LUMPY_BALL` | 576 | 2.4 | 0–15 |
| 15 | `TH18_INVERT_RICE` | 592 | 2.4 | 0–15 |
| 16 | `TH18_STAR_R` | 608 | 4 | 0–15 |
| 17 | `TH18_COIN` | 624 | 4 | 0–2 |
| 18 | `TH18_BIG_BALL` | 640 | 8.5 | 0–7 |
| 19 | `TH18_BIG_BALL2` | 656 | 8.5 | 0–7 |
| 20 | `TH18_OVAL` | 672 | 7 | 0–7 |
| 21 | `TH18_DAGGER` | 688 | 6 | 0–7 |
| 22 | `TH18_BUTTERFLY` | 704 | 7 | 0–7 |
| 23 | `TH18_BIG_STAR_R` | 720 | 7 | 0–7 |
| 24 | `TH18_BIG_STAR_L` | 736 | 7 | 0–7 |
| 25 | `TH18_FIREBALL_RED` | 752 | 6 | 0–15 |
| 26 | `TH18_FIREBALL_PURPLE` | 768 | 6 | 0–15 |
| 27 | `TH18_FIREBALL_BLUE` | 784 | 4 | 0–15 |
| 28 | `TH18_FIREBALL_YELLOW` | 800 | 4 | 0–15 |
| 29 | `TH18_HEART` | 816 | 10 | 0–7 |
| 30 | `TH18_PULSE_BALL` | 832 | 7 | 0–7 |
| 31 | `TH18_ARROW` | 848 | 4 | 0–7 |
| 32 | `TH18_BUBBLE` | 864 | 14 | 0–3 |
| 33 | `TH18_GLOW_BALL` | 880 | 12 | 0–7 |
| 34 | `TH18_DROPLET` | 896 | 2.4 | 0–15 |
| 35 | `TH18_SPIN_RICE` | 912 | 3.2 | 0–15 |
| 36 | `TH18_SPIN_SHARD` | 928 | 3.2 | 0–15 |
| 37 | `TH18_STAR_L` | 944 | 4 | 0–15 |
| 38 | `TH18_LASER_CHUNK` | 960 | 4 | 0–15 |
| 39 | `TH18_NOTE_RED` | 976 | 4 | 0–15 |
| 40 | `TH18_NOTE_BLUE` | 992 | 4 | 0–15 |
| 41 | `TH18_NOTE_YELLOW` | 1008 | 4 | 0–15 |
| 42 | `TH18_NOTE_PURPLE` | 1024 | 4 | 0–15 |
| 43 | `TH18_REST` | 1040 | 5 | 0–7 |
| 44 | `TH18_YIN_YANG_R` | 1056 | 10 | 0–7 |
| 45 | `TH18_YIN_YANG_L` | 1072 | 10 | 0–7 |
| 46 | `TH18_BIG_YIN_YANG_R` | 1088 | 28 | 0–3 |
| 47 | `TH18_BIG_YIN_YANG_L` | 1104 | 28 | 0–3 |

### 两个可直接照写的转换

第一颗是TH18 type6环玉，第二颗是type8米弹，均使用各自基础半径；新米弹不再采用旧行64的半径2。

```ecl
const TH18_RING_BALL: int = 448;
const TH18_RICE: int = 480;
sub main() {
    _ = fire(TH18_RING_BALL, 2, 0fx, 96fx, 2fx, 90deg, none, none);
    _ = fire(TH18_RICE, 6, 32fx, 96fx, 2fx, 90deg, none, none);
    wait(120);
}
```

### 换型和动态几何的边界

原作SETSPRITE会重新读新type默认半径；当前目标xform `set_sprite` / `set_shape` / `set_color`仍只换外观，保留出生半径。基础表不提供通用动态半径/缩放setter。HITBOX/SIZE与换型刷新仍按实际攻击单列，不能把基础表完成当作全部EX几何已等价。
