# TH18 子弹编号与弹种

> **版本**：跨版本，TH18 v1.00a 与 TH16 v1.00a；2026-11-05 核查，地址均带作品前缀。原生事实和目标映射分表保存；目标表以 stg-engine 内建 12 行图集为准。

## 当前要求与核查结论

2026-11-05初查发现旧12形映射存在4项同形同半径、11项同形不同半径、33项缺直接弹形，历史数据见[核查报告](../../docs/investigations/2026-11-05-th18-radius-alignment.md)。随后用户授权完整大表：引擎ENGINE_VER31追加TH06十型与TH18四十八型，按作品保存基础半径，静态贴图可共用。旧192项保持原值，不自动迁移旧卡。

当前TH18新词表已覆盖全部48型：基础半径按原作f32转为最近Q16.16，贴图来自本作普通飞行态。目标继续采用现有半径相加公式，出生减速/出生无判定按已接受取舍省略；动画、绘制偏移及特殊混合不据此声称原作视觉或完整碰撞等价。引擎维护入口为 `docs/bullet-catalog.md`，清单与烘焙生成器见 `godot/assets/bullet/catalog.json` / `godot/tools/slice_bullet_sheet.gd`。

## 使用方式

`etSprite(id, type, color)` 中，`id` 是发射器槽，`type` 才是本表编号，`color` 是该弹型内部色号。EX SETSPRITE 换型时也应查本表，不能把 `type` 当成我方 appearance、ANM script 或贴图 sprite 编号。

名称沿用社区常用英文别名，便于识别；它们不是从 exe 中恢复的原生枚举名。尺寸是原生表的基础圆半径，已按易读小数显示；EX 尺寸覆盖、缩放及出生态要另算。

## 编号表

色槽列记录原生调色记录中已配置的索引；“固定/脚本”表示由具体脚本控制，不能强套 16 色或 8 色。未核越界色号的处理，不据此添加取模或钳制。

| type | 弹种别名 | ANM script | 基础半径 | 已配置色槽 |
|---:|---|---:|---:|---|
| 0 | Pellet | 35 | 2.4 | 0–15 |
| 1 | Pellet2 | 36 | 2.4 | 0–15 |
| 2 | InvertPopcorn | 37 | 2.4 | 0–15 |
| 3 | Popcorn | 38 | 2 | 0–15 |
| 4 | Ball | 39 | 4 | 0–15 |
| 5 | Ball2 | 40 | 4 | 0–15 |
| 6 | RingBall | 41 | 4 | 0–15 |
| 7 | RingBall2 | 42 | 4 | 0–15 |
| 8 | Rice | 43 | 2.4 | 0–15 |
| 9 | Kunai | 44 | 2.4 | 0–15 |
| 10 | Shard | 45 | 2.4 | 0–15 |
| 11 | Talisman | 46 | 2.8 | 0–15 |
| 12 | Arrowhead | 47 | 2.4 | 0–15 |
| 13 | Bullet | 48 | 2.4 | 0–15 |
| 14 | LumpyBall | 49 | 2.4 | 0–15 |
| 15 | InvertRice | 50 | 2.4 | 0–15 |
| 16 | StarR | 51 | 4 | 0–15 |
| 17 | Coin | 52 | 4 | 0–2 |
| 18 | BigBall | 72 | 8.5 | 0–7 |
| 19 | BigBall2 | 73 | 8.5 | 0–7 |
| 20 | Oval | 74 | 7 | 0–7 |
| 21 | Dagger | 75 | 6 | 0–7 |
| 22 | Butterfly | 76 | 7 | 0–7 |
| 23 | BigStarR | 77 | 7 | 0–7 |
| 24 | BigStarL | 78 | 7 | 0–7 |
| 25 | FireballRed | 108 | 6 | 固定/脚本 |
| 26 | FireballPurple | 109 | 6 | 固定/脚本 |
| 27 | FireballBlue | 110 | 4 | 固定/脚本 |
| 28 | FireballYellow | 111 | 4 | 固定/脚本 |
| 29 | Heart | 81 | 10 | 0–7 |
| 30 | PulseBall | 79 | 7 | 0–7 |
| 31 | Arrow | 82 | 4 | 0–7 |
| 32 | Bubble | 80 | 14 | 0–3 |
| 33 | GlowBall | 315 | 12 | 0–7 |
| 34 | Droplet | 107 | 2.4 | 0–15 |
| 35 | SpinRice | 53 | 3.2 | 0–15 |
| 36 | SpinShard | 54 | 3.2 | 0–15 |
| 37 | StarL | 55 | 4 | 0–15 |
| 38 | LaserChunk | 158 | 4 | 0–15 |
| 39 | NoteRed | 317 | 4 | 固定/脚本 |
| 40 | NoteBlue | 318 | 4 | 固定/脚本 |
| 41 | NoteYellow | 319 | 4 | 固定/脚本 |
| 42 | NotePurple | 320 | 4 | 固定/脚本 |
| 43 | Rest | 321 | 5 | 0–7 |
| 44 | YinYangR | 324 | 10 | 0–7 |
| 45 | YinYangL | 325 | 10 | 0–7 |
| 46 | BigYinYangR | 326 | 28 | 0–3 |
| 47 | BigYinYangL | 327 | 28 | 0–3 |

## TH16 可以复用的范围

- **type 0–43**：两作每条原生描述记录的前 `0x110` 字节全部一致；包含主 ANM script、16 组颜色记录、基础半径及相关元数据。对应 44 个主 ANM 脚本正文也全部一致，共用的 `bullet1.png` 至 `bullet5.png` 解码 RGBA 像素完全一致。因此这些弹型的编号、名称识别及已配置颜色记录可以复用。
- **type 44–47**：本机 TH18 表新增的阴阳玉，主脚本 324–327，使用 `bullet6.png`。44/45 为较小的正/负角速度版本；46/47 为大阴阳玉，脚本同时设 X/Z 角速度。这里的旋转指视觉动画，不代表运动轨迹带角速度。
- 本机 TH16 表只核出 0–43 的连续有效记录；社区 `ECL-info.md` 虽放在 th16 目录，却还列出 44–49，不能将目录名当作逐作支持证明。TH18 本表确认到 47，48/49（Diamond/Tear）未建立对应，不得直接派给 worker。

记录 stride 分别为 TH16 `0x114`、TH18 `0x118`；TH18 从 `+0x110` 起的新增/差异字段没有在本轮解释。两作基础数据相同也不等于碰撞公式、出生计时和 EX 行为完全相同。

## 证据与边界

- [结构化核查记录](../../docs/investigations/2026-11-05-th16-th18-bullet-types.json)：两作 exe、ANM、Ghidra 导出 SHA256、逐型数据及对照结果。
- TH16 已命名 Ghidra 导出：`bullet_pool_spawn`（`th16:0x412cb0`）读取 `g_bullet_render_desc + type*0x114`；主脚本在 `+0x0`，基础半径在 `+0x104`。符号落盘脚本为 renkolab `tooling/ghidra/scripts/apply_th16_bullet_names.py`。
- TH18 表基址 `th18:0x4c5f90`，stride `0x118`；初始化在 `th18:0x425992` 附近读半径，换型在 `th18:0x42640a` 附近重读。本机 `docs/investigations/2026-10-22-th18-geometry/` 的既有 48 项几何核查与本轮全部数值一致。旧报告及 CSV 仍是本机未入库资料，主要数字与出处已保存在上述本轮 JSON。
- 本轮使用项目已有 `tooling/pe_read.py` 读常量数据，复用 Ghidra 与标准 thtk 的既有导出；没有自行反汇编、重建数据库、复制原作资产入库或运行游戏。

下表给出内建图集可直接表达的映射和缺口；当前 TH18 原型统一使用 appearance 0 的行为不能当作正式映射。

## 目标 appearance 与颜色

新词表在stg-engine `godot/ecl/game/touhou-bullets.ecl`。把该文件加入卡片编译目录，或复制所需常量；名字不是全局内建关键字。TH18行基址为 `352 + type*16`，`fire(shape,color,...)` / `sh_sprite(slot,shape,color)` 中直接保留原作色号，最终逻辑appearance=`shape+color`。

逻辑appearance与物理贴图格分开：弹池与RL TYPE保留逻辑编号；Godot、harness输出和Python预览通过生成布局取物理格。不要把 `run --at` 的物理sprite列当成原作type。物理图集采用64px格，小图居中留白，保持原生静态尺寸。

新48型不再套旧12形的8色→16色换色表。缺色槽无效，不取模补色；固定色火球/音符忽略输入color，所以16列均有效并共用首帧。颜色事实仍见本页原生表，逐色裁片依据见[贴图核查](../../docs/investigations/2026-11-05-th18-bullet-textures.json)。

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

原作SETSPRITE会重新读新type默认半径；当前目标xform `set_sprite` / `set_shape` / `set_color`仍只换外观，保留出生半径。本轮新增完整基础表，没有增加通用动态半径/缩放setter。HITBOX/SIZE与换型刷新仍按实际攻击单列，不能把基础表完成当作全部EX几何已等价。

### 目标表与验证证据

- 唯一维护输入：stg-engine `godot/assets/bullet/catalog.json` 与 `source_th06.png` / `source_th18.png`。
- 生成物：`atlas-layout.json`、`godot/assets/bullets.png`、`crates/stg-core/src/tables/touhou_appearances.rs`、`godot/ecl/game/touhou-bullets.ecl`；再经harness bake-tables生成运行时表。
- 当前1120逻辑项、635物理图格，旧192前缀不变；普通弹出生直接带半径，不需要额外xform。
- 本轮验证与训练wheel来源见[接入记录](../../docs/investigations/2026-11-05-touhou-bullet-catalog.md)。历史教材检查保留在[原验证记录](../../docs/investigations/2026-11-05-th18-textbook-verification.md)。
