# TH06 → stg-engine `.ecl` 对照表

> 2026-09-16 主会话逐条读 th06-decomp（CC0，`EclManager.cpp` / `EnemyEclInstr.cpp` / `BulletManager.cpp` /
> `EnemyManager.cpp`）编写。**这是转写的唯一语义依据**：别凭 ZUN 指令名猜语义，也别凭对别的 ECL 版本的记忆。
> 出处写作 `EclManager.cpp:357`（renkolab `local/vendor/th06-decomp/src/` 下的行号）。
> 我方语言以 stg-engine `docs/ecl-lang/` 为准；本文只讲**怎么从 TH06 翻过去**。
>
> 本文每个 ```ecl 围栏都是完整程序，被训练仓 `tests/transcribe/test_mapping.py` 真编译。

**读法**：先读 §0–§2（全局换算与执行模型，每个单元都用得到），再按 §索引 查本单元用到的指令所在节。单元里有 `laser_*` 就通读 §14。
处置三类：`translate` 翻译 · `drop` 丢弃（纯表现 / 由卡外壳接管 / 无敌下不可达）· `skip-unit` 整个单元不转。

## 索引

| 指令 | 处置 | 节 |
|---|---|---|
| `nop` | drop | §11 |
| `enemy_delete` | translate | §6 |
| `jump` | translate | §2 |
| `jump_dec` | translate | §2 |
| `set_int` | translate | §2 |
| `set_float` | translate | §2 |
| `set_int_rand_bound` | translate | §2 |
| `set_int_rand_bound_min` | translate | §2 |
| `set_float_rand_bound` | translate | §2 |
| `set_float_rand_bound_min` | translate | §2 |
| `set_var_self_x` | translate | §2 |
| `set_var_self_y` | translate | §2 |
| `set_var_self_z` | drop | §2 |
| `math_int_add` | translate | §2 |
| `math_int_sub` | translate | §2 |
| `math_int_mul` | translate | §2 |
| `math_int_div` | translate | §2 |
| `math_int_mod` | translate | §2 |
| `math_inc` | translate | §2 |
| `math_dec` | translate | §2 |
| `math_float_add` | translate | §2 |
| `math_float_sub` | translate | §2 |
| `math_float_mul` | translate | §2 |
| `math_float_div` | translate | §2 |
| `math_float_mod` | translate | §2 |
| `math_atan2` | translate | §2 |
| `math_norm_angle` | translate | §2 |
| `cmp_int` | translate | §2 |
| `cmp_float` | translate | §2 |
| `jump_lss` | translate | §2 |
| `jump_leq` | translate | §2 |
| `jump_equ` | translate | §2 |
| `jump_gre` | translate | §2 |
| `jump_geq` | translate | §2 |
| `jump_neq` | translate | §2 |
| `call` | translate | §2 |
| `ret` | translate | §2 |
| `call_lss` | translate | §2 |
| `call_leq` | translate | §2 |
| `call_equ` | translate | §2 |
| `call_gre` | translate | §2 |
| `call_geq` | translate | §2 |
| `call_neq` | translate | §2 |
| `time_set` | translate | §2 |
| `move_position` | translate | §7 |
| `move_axis_velocity` | translate | §7 |
| `move_velocity` | translate | §7 |
| `move_angular_velocity` | translate | §7 |
| `move_speed` | translate | §7 |
| `move_acceleration` | translate | §7 |
| `move_rand` | translate | §7 |
| `move_rand_in_bounds` | translate | §7 |
| `move_at_player` | translate | §7 |
| `move_dir_time_decelerate` | translate | §7 |
| `move_dir_time_decelerate_fast` | translate | §7 |
| `move_dir_time_accelerate` | translate | §7 |
| `move_dir_time_accelerate_fast` | translate | §7 |
| `move_position_time_linear` | translate | §7 |
| `move_position_time_decelerate` | translate | §7 |
| `move_position_time_decelerate_fast` | translate | §7 |
| `move_position_time_accelerate` | translate | §7 |
| `move_position_time_accelerate_fast` | translate | §7 |
| `move_time_decelerate` | translate | §7 |
| `move_time_decelerate_fast` | translate | §7 |
| `move_time_accelerate` | translate | §7 |
| `move_time_accelerate_fast` | translate | §7 |
| `move_bounds_set` | translate | §7 |
| `move_bounds_disable` | translate | §7 |
| `bullet_fan_aimed` | translate | §4 |
| `bullet_fan` | translate | §4 |
| `bullet_circle_aimed` | translate | §4 |
| `bullet_circle` | translate | §4 |
| `bullet_offset_circle_aimed` | translate | §4 |
| `bullet_offset_circle` | translate | §4 |
| `bullet_random_angle` | translate | §4 |
| `bullet_random_speed` | translate | §4 |
| `bullet_random` | translate | §4 |
| `shoot_interval` | translate | §4 |
| `shoot_interval_delayed` | translate | §4 |
| `shoot_disable` | translate | §4 |
| `shoot_enable` | translate | §4 |
| `shoot_now` | translate | §4 |
| `shoot_offset` | translate | §4 |
| `shoot_offset_polar` | translate | §4 |
| `bullet_effects` | translate | §5 |
| `bullet_cancel` | translate | §4 |
| `bullet_sound` | drop | §11 |
| `bullet_rank_influence` | translate | §4 |
| `laser_create` | translate | §14 |
| `laser_create_aimed` | translate | §14 |
| `laser_index` | translate | §14 |
| `laser_rotate` | translate | §14 |
| `laser_rotate_from_player` | translate | §14 |
| `laser_offset` | translate | §14 |
| `laser_test` | translate | §14 |
| `laser_cancel` | translate | §14 |
| `laser_clear_all` | drop | §14 |
| `spellcard_start` | drop | §9 |
| `spellcard_end` | drop | §9 |
| `spellcard_effect` | drop | §11 |
| `spellcard_flag_timeout` | drop | §9 |
| `enemy_create` | translate | §6 |
| `enemy_create_mirror` | translate | §6 |
| `enemy_create_random` | translate | §6 |
| `enemy_create_mirror_random` | translate | §6 |
| `enemy_kill_all` | translate | §8 |
| `anm_set_main` | drop | §11 |
| `anm_set_poses` | drop | §11 |
| `anm_set_slot` | drop | §11 |
| `anm_death_effects` | drop | §11 |
| `anm_flag_rotation` | drop | §11 |
| `anm_interrupt_main` | drop | §11 |
| `anm_interrupt_slot` | drop | §11 |
| `boss_set` | drop | §9 |
| `boss_set_life_count` | drop | §9 |
| `boss_timer_set` | drop | §9 |
| `boss_timer_clear` | drop | §9 |
| `enemy_set_hitbox` | translate | §8 |
| `enemy_flag_collision` | translate | §8 |
| `enemy_flag_can_take_damage` | drop | §8 |
| `enemy_flag_interactable` | translate | §8 |
| `enemy_flag_invisible` | translate | §8 |
| `enemy_flag_death` | drop | §8 |
| `enemy_flag_disable_call_stack` | drop | §2 |
| `enemy_life_set` | drop | §8 |
| `death_callback_sub` | drop | §9 |
| `life_callback_threshold` | drop | §9 |
| `life_callback_sub` | drop | §9 |
| `timer_callback_threshold` | drop | §9 |
| `timer_callback_sub` | drop | §9 |
| `enemy_interrupt_set` | drop | §9 |
| `enemy_interrupt` | drop | §9 |
| `effect_sound` | drop | §11 |
| `effect_particle` | drop | §11 |
| `drop_items` | drop | §11 |
| `drop_item_id` | drop | §11 |
| `ex_ins_call` | translate | §10 |
| `ex_ins_repeat` | translate | §10 |
| `std_unpause` | drop | §11 |
| `debug_watch` | drop | §11 |
| `read_msg` | skip-unit | §6 |
| `wait_msg` | skip-unit | §6 |
| `boss_interrupt` | drop | §9 |
| `boss_wait` | drop | §9 |

`ex_ins_*` 的处置按编号分，见 §10；`read_msg` / `wait_msg` 是对话，切分时排除在单元之外，单元里出现即 skip。

---

## §0 口径

- 原文 = `thecl -g 6` 解码文本。行首 `!E` / `!NHL` / `!*` 是**难度前缀，粘滞**到下一个前缀（`!*` = 全难度）。
- `+N: //T`：`T` 是**块内绝对帧**（sub 从被调入那一刻起算）。`$I0` 写 / `%F0` 读，同一个变量。
- TH06 帧率 60，一帧一 step，与我方一致。
- **难度基线**：TH06 的动态 rank 开局恒为 16（`GameManager.cpp:70`），所有 rank 修正公式在 16 时按 §4.6 取值。
  转写一律按开局 rank 16 算，**不模拟 rank 随时间 / 死亡浮动**。

## §1 全局换算

| 量 | TH06 | 我方 | 例 |
|---|---|---|---|
| x 坐标 | `[0, 384]` | `x − 192` | `60.0f` → `-132.0fx` |
| y 坐标 | `[0, 448]`，向下 | 原值 | `-32.0f` → `-32.0fx` |
| 角度 | 弧度，0 = 右，y 向下顺时针 | `deg` / `bam`（同约定） | `1.5707964f` → `90deg`；`0.09817477f` → `1024bam` |
| 角速度 | 弧度 / 帧 | `bam` / 帧（angle） | `-0.024543693f` → `-256bam` |
| 速度 | px / 帧 | `fx` | `2.0f` → `2.0fx` |
| 加速度 | px / 帧² | `fx` | `0.05f` → `0.05fx` |
| 时间 | 帧 | 帧 | — |
| 难度 | 掩码 E/N/H/L | `global(GVAR_RANK)` 0/1/2/3 | 见 §2.2 |

- **角度优先写 `bam` 整数**：ZUN 的角度几乎都是 π 的整分数，`round(rad × 65536 / 2π)` 精确；`deg` 用于人读的整角。
  摘录的 `source.txt` 行尾已附换算注释，**照抄注释里的数，别心算**——一圈 65536，**π = 32768、π/2 = 16384、
  π/16 = 2048、π/32 = 1024、π/48 ≈ 683、π/128 = 256**。心算最常见的错是翻一倍（把 π/32 写成 2048）。
- 场界：TH06 场地 384×448，我方 `x ∈ [-192,192]`、`y ∈ [0,448]`，同尺寸。
- **判定**：TH06 自机判定是 ±1.25 的方框，弹是 `grazeSize/2` 的方框（`BulletManager.cpp:1383`、`Player.cpp:1279`）；
  我方是圆，自机半径 2.5，弹半径由弹型决定（§3）。**判定只能近似**，不要去调。

## §2 执行模型

### 2.1 块时间轴 → `wait`

TH06 解释器每帧执行「时间 == 当前帧」的指令，没到时间就停（`EclManager.cpp:118`）。所以：

- 相邻两个 `+N: //T` 之间的指令同帧执行；遇到 `//T` 即 `wait(T − 上一个 T)`。
- sub 被调入时时间从 0 起；**`ret` 回到调用方时恢复调用方的时间**（整个上下文出栈，`EclManager.cpp:272`）。
  所以调用方写的 `+N` 仍是相对于 call 那一刻：翻成同步 `sub` 调用后照常 `wait` 差值即可。
- 敌主任务 = 敌的 sub 链。我方新任务出生当帧不跑，比 TH06 晚 1 帧（TH06 在 `SpawnEnemy` 里当帧就执行，
  `EnemyManager.cpp:108`）——忽略。

### 2.2 难度前缀

同一时刻 `!E` / `!N` / `!H` / `!L` 各写一条的，折成「按 rank 取值」：

```ecl
sub main() {
    var rank: int = global(GVAR_RANK);
    var ways: int = 8;                       // !E
    if rank == RANK_NORMAL { ways = 14; }    // !N
    else if rank == RANK_HARD { ways = 20; } // !H
    else if rank >= RANK_LUNATIC { ways = 28; }  // !L
    loop { wait(1); }
}
```

- 只在某几档出现的指令（如 `!L shoot_disable();`）→ `if rank == RANK_LUNATIC { … }`。
- ⚠️ **粘滞最容易看漏**：

  ```text
      move_velocity(1.5707964f, 2.0f);
  !L    shoot_disable();
      bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.0f, 4);   ← 仍是 !L
      shoot_enable();                                              ← 仍是 !L
      shoot_interval_delayed(120);                                 ← 仍是 !L
  +40: //40
  !*    move_angular_velocity(-0.024543693f);                      ← 这里才回到全难度
  ```

  这只小怪 **E/N/H 一颗弹都不发**。摘录的 `source.txt` 每行行尾都标了生效难度，以那个为准。
- 回调链按难度分叉（如 `!NHL timer_callback_sub("Sub26")` vs `!E timer_callback_sub("Sub19")`）由切分处理，
  单元内只剩一条路。
- **Extra（ecldata7）**：Extra 难度只执行 `!*` 的指令；带 `!E`…`!L` 的行在 Extra 里**永不执行**，直接删。

### 2.3 变量

- `$I0`…`$I7` → `var i0: int` …；`$F0`…`$F3` → `var f0: fx`，**用在角度位上就声明成 `angle`**。
  同一个 `$F` 既当角度又当速度的，拆成两个变量。
- ⚠️ **同一个 sub 里变量名全局唯一**：不支持遮蔽，**两个平行的 `for i` 也算重复**（编译报「变量名重复声明」）。
  循环变量写 `i1`/`i2`/`k1`…；在 `if`/循环体里声明的变量出了块就不可见，要跨块用就提到块外先声明。
- 引擎变量：

  | TH06 | 我方 |
  |---|---|
  | `%SELF_X` / `%SELF_Y` | `$self_x + 192.0fx` / `$self_y`（**TH06 坐标系**；更好的写法是把与之比较的常量换算掉，直接用 `$self_x`） |
  | `%PLAYER_X` / `%PLAYER_Y` | `$player_x + 192.0fx` / `$player_y` |
  | `%PLAYER_ANGLE` | `aim_player()`（从敌中心瞄，与 TH06 一致，`EnemyEclInstr.cpp:208`） |
  | `$DIFFICULTY` | `global(GVAR_RANK)` |
  | `$PLAYER_SHOT` | 常量 `0`（固定按灵梦 A 算） |
  | `$SELF_LIFE` | 常量：该敌的初始血量（我方敌恒无敌，血量不变） |
  | `$SELF_TIME` | boss 计时器帧数：自己在任务里 `var t` 计数（从最近一次 `boss_timer_set`/`timer_callback_threshold` 起） |
  | `%SELF_Z` / `$SELF_Z` | 删（z 无意义） |

- 数学：`math_int_add($I3, $I3, 1)` → `i3 = i3 + 1;`；`math_inc($I7)` → `i7 = i7 + 1;`；`math_float_*` 同理。
  `math_norm_angle($F0)` 对 `angle` 变量是 no-op（BAM 天然回绕）。
- `math_atan2(out, x1, y1, x2, y2)` = 从点 (x1,y1) 指向 (x2,y2) 的角（`EnemyEclInstr.cpp:396`，参数名在源码里错位，
  以此为准）→ `out = atan2(y2 − y1, x2 − x1)`，坐标按 §1 换算。
- `set_var_self_x($F0)` → `f0 = $self_x`（注意坐标系，同上表）。
- 随机（TH06 `GetRandomF32InRange(r)` = `[0, r)`）：

  | TH06 | 我方 |
  |---|---|
  | `set_int_rand_bound($I0, n)` | `i0 = rand(n);` |
  | `set_int_rand_bound_min($I0, n, m)` | `i0 = rand(n) + m;` |
  | `set_float_rand_bound($F1, r)`（速度等） | `f1 = r / 256 * rand(256);` |
  | `set_float_rand_bound_min($F0, 6.2831855f, -3.1415927f)`（角度） | `f0 = rand(65536) as angle;`（整周） |
  | 角度区间 `[lo, lo + w)` | `lo + rand(W) as angle`（`W` = 宽度的 BAM 整数） |

```ecl
sub main() {
    var i0: int = rand(3);
    var f1: fx = 3.0fx / 256 * rand(256);        // [0, 3)
    var a0: angle = rand(65536) as angle;       // 整周
    var a1: angle = 45deg + rand(16384) as angle;  // [45°, 135°)
    loop { wait(1); }
}
```

### 2.4 控制流

- **`jump_dec(t, L, $I4)`**：`$I4` 先减 1，仍 > 0 就把时间设为 `t` 并跳到标签 `L`（`EclManager.cpp:130`）。
  `$I4 = N` 开始时，`L` 到 `jump_dec` 之间的循环体**共执行 N 次**。
- **`jump(t, L)`**：时间设为 `t` 跳到 `L`。向后跳 = 死循环；向前跳 = 跳过一段。
- **时间跟着跳**：跳回后，循环体里的 `+N: //T` 要按「`T − t`」等待。典型：

  ```text
  set_int($I4, 16);
  Sub18_172:
  +2: //2            ← jump_dec 把时间设回 0，所以每轮先等 2 帧
      bullet_...;
      jump_dec(0, Sub18_172, $I4);
  ```

  → `for k in 0..16 { wait(2); …; }`
- **`cmp_int` / `cmp_float` + `jump_lss/leq/equ/gre/geq/neq`**：比较结果寄存器 → `if` / `while`。
- **`call("SubX", a, b)`**：TH06 把**调用方整个上下文**（`$I0-7`、`$F0-3`）拷给被调方，再把 `$I0 = a`、`$F0 = b`；
  `ret` 时**整个恢复**（`EclManager.cpp:249-273`）。所以：被调方读到调用方的全部变量，写的全部不回传。
  → `sub SubX(i0: int, f0: fx, i1: int …)`，**被调方读了哪些变量就传哪些**；不需要返回值。
- `call_equ("Sub16", a, b, $I0, 0)` = `if i0 == 0 { Sub16(a, b, …); }`（其余 `call_*` 同理，`EclManager.cpp:274`）。
- **尾调用链**：TH06 boss 常写「sub 末尾随机 `call` 下一个 sub、从不 `ret`」（如 Sub15→Sub16→Sub17→Sub18→Sub15）。
  我方禁递归、调用深 ≤ 8，**翻成调度循环**：

  ```ecl
  sub attack_a() { wait(60); }
  sub attack_b() { wait(80); }
  sub attack_c() { wait(40); }

  async sub pattern() {
      var next: int = 0;
      loop {
          if next == 0 { attack_a(); }
          else if next == 1 { attack_b(); }
          else { attack_c(); }
          // 原文 attack 末尾：set_int_rand_bound($I0, 3); call_equ(...,0); call_equ(...,1); call(...)
          // 注意各 attack 的后继表不同，照原文逐个写
          var r: int = rand(3);
          if next == 0 { if r == 0 { next = 1; } else if r == 1 { next = 2; } else { next = 2; } }
          else if next == 1 { if r == 0 { next = 0; } else if r == 1 { next = 2; } else { next = 2; } }
          else { if r == 0 { next = 1; } else if r == 1 { next = 0; } else { next = 0; } }
      }
  }

  sub main() { spawn pattern(); loop { wait(1); } }
  ```

  ⚠️ `call_equ(A, …, $I0, 0); call_equ(B, …, $I0, 1); call(C, …)`：第一条命中就**不会返回**，所以是
  「0→A，1→B，其余→C」，不是依次调三个。
- **`time_set($I0)`**：块时间直接加 `$I0`（`EclManager.cpp:842`），等于把后面指令的等待缩短 `$I0` 帧。
- `enemy_flag_disable_call_stack`：只影响栈拷贝，丢弃。
- 容量红线：单任务 locals ≤ 64 字、调用深 ≤ 8、求值栈 ≤ 32。原文 sub 链很长时，把不相干的段拆到不同的 `async sub`。
- ⚠️ **xformdef 占 locals**：一个 sub 每引用一个 xformdef，就在**这个 sub** 的 locals 里占「物理槽数 × 3」字
  （`step_speed` 占 2 槽）。4 个 `@40 step_speed; turn; set_speed` 就是 48 字，再调一个带变量的 sub 就超 64。
  超了（报「locals 总量 … 超出上限 64」）→ **按弹种拆成几个并行 `async sub`**，同帧 `spawn`、各自数帧（范例 th06_s1_b4）。
- ⚠️ **`sh_xform` 与 `sh_fire` 写在同一个 sub 里**：xformdef 在引用它的 sub 入口暂存进该 sub 的 locals，
  在子 sub 里 `sh_xform`、回到调用方再 `sh_fire`，那段 locals 可能已被别的子 sub 覆写，弹的变换会静默错乱。

## §3 弹型与颜色

TH06 弹型号 = `bullet_*` 第 1 参（`BulletManager.cpp:48` 表）；色号 = 第 2 参（`spriteOffset`）。
**弹型名常量要抄进卡里**（引擎不认，取自 stg-engine `godot/ecl/game/bullets.ecl`）。

| TH06 | 名 | 原判定（半边长） | 我方弹型 | 我方半径 | 备注 |
|---|---|---|---|---|---|
| 0 | PELLET 小玉 | 2 | `BULLET = 128` | 3 | |
| 1 | RING_BALL 环玉 | 3 | `OUTLINE = 32` | 4 | |
| 2 | RICE 米弹 | 2 | `RICE = 64` | 2 | |
| 3 | BALL 中玉 | 3 | `BALL = 48` | 5 | |
| 4 | KUNAI 苦无 | 2.5 | `KUNAI = 80` | 3 | |
| 5 | SHARD 鳞弹 | 2 | `SHARD = 96` | 2 | |
| 6 | BIG_BALL 大玉 | 8 | `LASERHEAD = 176` | 5 | ⚠️ 判定偏小 |
| 7 | FIREBALL 火弹 | 5.5 | `AMULET = 112` | 5 | |
| 8 | DAGGER 刀弹 | 4.5 | `ARROWHEAD = 16` | 4 | |
| 9 | BUBBLE 气泡 | 16 | `LASERHEAD = 176` | 5 | ⚠️ 判定严重偏小 |

- **16px 弹（0–5、9）色号原样**：TH06 调色板顺序与我方图集一致（灰、暗红、红、暗粉、粉、暗蓝、蓝、暗青、青、暗绿、绿、黄绿…白）。
- **32px 弹（6、7、8）只有 8 色**：色号 `c` → 我方 `[0, 2, 4, 6, 8, 10, 13, 15][c]`。
- 色号是变量（`$I0`）的，照样用变量；32px 弹要查表：`var col: int = 0; if c == 1 { col = 2; } …`。
- 半径偏差是引擎弹型表决定的已知限制（spec §12），**不要换弹型去凑半径**。

## §4 发弹

### 4.1 发射参数是敌身上的粘滞状态

TH06 每只敌有一份 `bulletProps`（`EclManager.cpp:366-410`）：

- `bullet_*(sprite, color, count1, count2, speed1, speed2, angle1, angle2, flags)` **写满全部字段，并立即开火一次**
  （`shoot_disable` 期间只写不发）。
- `bullet_effects(i0, i1, i2, i3, f0, f1, f2, f3)` 写 `exInts` / `exFloats`，**粘滞**到下一次 `bullet_effects`（§5 用）。
- `shoot_offset(x, y, z)` 写出弹口偏移（相对敌，**不换算坐标**），粘滞。
- `shoot_offset_polar(a, r, z)`（NC 新增 opcode 200）= 出弹口 `(cos a · r, sin a · r)`，**覆盖** `shoot_offset`。
- 出弹点 = 敌位置 + 出弹口；自机狙角**从出弹点算**（`BulletManager.cpp:538`）→ 正好是我方 `sh_aim` 的基点。

→ 我方用**发射器槽**表达：一个 TH06 敌 = 一个任务里的 `sh_*` 槽。

```text
shoot_offset(ox, oy, _)          →  sh_offset(k, ox fx, oy fx);
shoot_offset_polar(a, r, _)      →  sh_offset(k, 0fx, 0fx); sh_offset_rad(k, a, r);
```

### 4.2 九条发弹指令（`BulletManager.cpp:82-170`）

记 `c1 = count1`（角度向颗数）、`c2 = count2`（层数）、第 `j` 层（`0..c2`）、第 `i` 颗（`0..c1`）：

- **速度**（除 random 两条）：`speed(j) = s1 − (s1 − s2) · j / c2` → `sh_speed(k, s1, (s2 − s1) / c2)`。
  钳位：`s1 ≠ 0` 时 `s1 ≥ 0.3`；`s2` **恒** `≥ 0.3`（`s2` 写 0 也按 0.3 算，`EclManager.cpp:387-401`）。
  `c1`、`c2` 小于 1 按 1。
- **角度**：

| 指令 | 角度 | 我方 |
|---|---|---|
| `bullet_fan_aimed` (67) | 以「自机方向 + a1」为中轴、间隔 a2 对称展开 | `sh_aim(k,1); sh_ring(k,0); sh_angle(k, a1, a2);` |
| `bullet_fan` (68) | 以 a1 为中轴、间隔 a2 对称展开 | `sh_aim(k,0); sh_ring(k,0); sh_angle(k, a1, a2);` |
| `bullet_circle_aimed` (69) | `自机 + i·2π/c1 + j·a2 + a1` | `sh_aim(k,1); sh_ring(k,1); sh_angle(k, a1, a2);` |
| `bullet_circle` (70) | `i·2π/c1 + j·a2 + a1` | `sh_aim(k,0); sh_ring(k,1); sh_angle(k, a1, a2);` |
| `bullet_offset_circle_aimed` (71) | `自机 + π/c1 + i·2π/c1 + a1`（**层间不错开**） | `sh_aim(k,1); sh_ring(k,1); sh_angle(k, a1 + (32768 / c1) as angle, 0deg);` |
| `bullet_offset_circle` (72) | 同上不瞄 | `sh_aim(k,0); …` |
| `bullet_random_angle` (73) | 每颗 `[a2, a1)` 随机，速度按层 | 逐颗 `fire`，见下 |
| `bullet_random_speed` (74) | 角度同 circle（不瞄），速度每颗 `[s2, s1)` 随机 | 逐颗 `fire` |
| `bullet_random` (75) | 角度 `[a2, a1)`、速度 `[s2, s1)` 都随机 | 逐颗 `fire` |

  fan 的展开方式与我方 `sh_ring(k,0)` 逐位同构（奇数颗正中一颗对准中轴），ring 与 `sh_ring(k,1)` 同构。
- `flags` 低位：`1` = 出生冲刺（§5）；`2/4/8` = 出生特效，**我方有意不模拟**（训练目标是泛化躲弹，不追原作逐帧时序）。
  TH06 出生特效期间弹**降速且无判定**（`BulletManager.cpp:683-707`，碰撞只在飞行状态做），16px 弹的时长取自
  `etama3.anm` script14–16：`2` = 10 帧 ×1/2、`4` = 16 帧 ×1/2.5、`8` = 32 帧 ×1/3。我方从第 1 帧起全速、有判定，
  所以弹的位置永久领先原作约 `5v` / `9.6v` / `21.3v` 像素（v = 弹速），出生即可伤人。部署侧要处理，见 stg-engine follow-ups D23#9；
  `0x200` = 带音效（丢弃）；其余位见 §5。

```ecl
const RICE: int = 64;
const BALL: int = 48;

async sub fairy() {
    set_invuln(65535);
    var rank: int = global(GVAR_RANK);
    // !E bullet_circle_aimed(1, 6, 16, 1, 2.0f, 1.5f, 0.0f, 0.0f, 9) / !L 同形 16 颗 × 7 层、s2 = 1.0
    var layers: int = 1;
    var s2: fx = 1.5fx;
    if rank == RANK_NORMAL { layers = 3; }
    else if rank == RANK_HARD { layers = 5; s2 = 1.2fx; }
    else if rank >= RANK_LUNATIC { layers = 7; s2 = 1.0fx; }
    sh_reset(0);
    sh_sprite(0, OUTLINE_T, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 16, layers);
    sh_speed(0, 2.0fx, (s2 - 2.0fx) / layers);
    sh_angle(0, 0deg, 0deg);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_fire(0);

    // bullet_fan_aimed(3, 1, 3, 10, 6.0f, 1.0f, 0.0f, 0.09817477f, 4)：中玉 3 颗 × 10 层
    sh_reset(1);
    sh_sprite(1, BALL, 1);
    sh_aim(1, 1);
    sh_count(1, 3, 10);
    sh_speed(1, 6.0fx, (1.0fx - 6.0fx) / 10);
    sh_angle(1, 0deg, 1024bam);            // π/32
    sh_fire(1);
    wait(60);
}

const OUTLINE_T: int = 32;

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 100, 0, 0, 0, fairy);
    loop { wait(1); }
}
```

random 族逐颗发：

```ecl
const RICE: int = 64;

async sub random_burst() {
    set_invuln(65535);
    // bullet_random(2, 6, 12, 1, 4.0f, 1.0f, 3.1415927f, -3.1415927f, 4)：12 颗，角度整周、速度 [1, 4)
    for i in 0..12 {
        var sp: fx = 1.0fx + 3.0fx / 256 * rand(256);
        var an: angle = rand(65536) as angle;
        _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
    }
    // bullet_random_speed(3, 6, 12, 1, 3.0f, 1.7f, 0.0f, 0.0f, 4)：环形 12 颗、速度 [1.7, 3)
    for j in 0..12 {
        var sp2: fx = 1.7fx + 1.3fx / 256 * rand(256);
        _ = fire(RICE, 6, $self_x, $self_y, sp2, (j * 65536 / 12) as angle, none, none);
    }
    wait(60);
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 100, 0, 0, 0, random_burst);
    loop { wait(1); }
}
```

### 4.2b TH06 的 640 发弹池与「等效截止」（密集卡必读）

TH06 的弹池是**硬上限 640**（`BulletManager.hpp:125` `Bullet bullets[640]`）：池满时
`SpawnBulletPattern` 从失败那颗起**整批放弃**（`BulletManager.cpp:534-548`）。所以原作画面里的同屏弹数
永远 ≤ 640，密集段的后半截其实**根本没发出来**。

我方弹池 8192、没有这个上限，而且出界回收更晚（64px 边距 vs 原作约 8px），照抄原文指令会得到明显更密的画面。
**验收硬上限是 1024**（`validate` 第 2 层），撞上就 FAIL。

**统一口径（2026-09-18 定，免得每个单元各自拍数）**：

1. **只在无截止时该档峰值 > 1024 才做等效截止**；≤ 1024 的照抄，即便它已超过原作的 640。
   （理由：口径一致、可复现；代价是我方同屏弹数普遍多于原作，这是**已知偏差**，写进 report 即可。）
2. 截止方式优先级：① 离线按 640 池重放拟合「某类弹 `$frame ≥ N` 不发」的静态截止（最忠实，见
   `th06_s3_w12` 的做法）；② 做不到时按轮数 / 颗数折减。**两种都要在 `report.md` 写明依据、改前改后的实测峰值**。
3. 截止**只动会撞上限的那一档**，其余档照抄。
4. 截完自检：`run --rank <档>` 峰值 ≤ 1024 且 `validate` 通过。

> 更彻底的解法是引擎侧给 ECL 一个只读「当前活弹数」，让卡直接按 640 gate，不必逐单元离线拟合——
> 已记 stg-engine follow-ups，未实现前按上面的口径来。

### 4.3 自动射击 `shoot_interval`

TH06（`EclManager.cpp:428-440`、`980-989`）：

- `shoot_interval(n)`：此后每 `n` 帧用**当时的** `bulletProps` 自动开一次火；`n = 0` 停。
- `shoot_interval_delayed(n)`：同上，但计时器初值随机 `[0, n)`。
- **帧对齐**：`RunEcl` 同一帧先执行到期指令、再走移动与开火计时（`EclManager.cpp:116` 起的主循环、`:980-987`），
  设定帧本身就 tick 一次——原作首发在设定帧之后第 `n − 1` 帧（delayed：第 `n − 1 − rand(n)` 帧）。
  我方写法 A 用 `first = n`（delayed：`n − rand(n)`）再 `wait(first)`，**统一晚 1 帧、开火次数与原作一致**，这是接受的近似。
- 自动开火与块时间轴无关，只要敌活着就一直打；`shoot_disable` 期间不发。
- `shoot_now()`：立即用 `bulletProps` 开一次火。

**写法 A（常见：配一次参数、之后只靠自动射击）**——伴生任务，带「打到第几帧为止」参数
（原文后面若有 `shoot_interval(0)` 或参数改变，按原文时间算出 `until`）。
**停火守卫用 `>`**：原作在 `until` 那一帧先执行 `shoot_interval(0)` 再计时，所以原作开火帧 `k` 须满足 `k < until`；
我方 `first = k + 1`（见上「帧对齐」），等价于 `first ≤ until` 才开火 ⇒ 守卫写 `first > until` / `t + interval > until`。
（2026-09-16 曾误改成 `>=`、2026-09-17 核实同帧 tick 后改回；`>=` 会在边界上少打一轮，概率约 1/n。）

```ecl
const KUNAI: int = 80;

async sub autoshoot(interval: int, delayed: int, until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_count(0, 6, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    var t: int = 0;
    var first: int = interval;
    if delayed != 0 { first = interval - rand(interval); }
    if first > until { return; }
    wait(first);
    t = first;
    loop {
        sh_fire(0);
        if t + interval > until { return; }
        wait(interval);
        t = t + interval;
    }
}

async sub fairy() {
    set_invuln(65535);
    spawn autoshoot(120, 1, 10000);
    move_vel(0, 90deg, 2.0fx, 0);
    wait(300);
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 100, 0, 0, 0, fairy);
    loop { wait(1); }
}
```

**写法 B（参数在自动射击期间还会变）**：在主任务里自己数帧，每帧 `wait(1)` 时判断是否到了开火帧。

### 4.4 `bullet_cancel`

全场敌弹转点（`EclManager.cpp:891`）→ `clear_bullets_at(0.0fx, 224.0fx, 1024.0fx, 0);`（不给星）。

### 4.5 `shoot_disable` / `shoot_enable`

只影响 `bullet_*` 与自动射击是否真的发弹，不影响参数写入。转写时：disable 期间的 `bullet_*` 只配置发射器、不 `sh_fire`。

### 4.6 `bullet_rank_influence(sl, sh, a1l, a1h, a2l, a2h)`

rank 16 下的修正量（`Enemy.hpp` 的 `BulletRank*Inner`，C 整数除法向零截断）：

- 速度修正 `rs = 16·(sh − sl)/32 + sl`：`s1 ≠ 0` 时 `s1 += rs`，`s2 += rs / 2`。
- 颗数修正 `16·(a1h − a1l)/32 + a1l`（整数）加到 `c1`；层数同理用 `a2*` 加到 `c2`。
- 默认值（`sl = −0.5, sh = 0.5`、颗数全 0）修正为 0。**`spellcard_start` 与生命 / 时间回调会把它重置为默认**。
- 例：`bullet_rank_influence(-1.0f, 1.0f, -3, 6, 0, 0)` → 速度 +0，`c1 += 16·9/32 − 3 = 1`。

## §5 弹变换：`bullet_effects` + `flags` → `xformdef`

`bullet_effects(i0, i1, i2, i3, f0, f1, f2, f3)` 设参数，`bullet_*` 的 `flags` 选行为（`BulletManager.cpp:316-380` 设定，
`710-890` 逐帧）。xformdef 参数必须是编译期常量，**每组不同参数写一个 xformdef**，用 `sh_xform(k, NAME)` 挂上。

| flags 位 | 行为（TH06） | xformdef |
|---|---|---|
| `0x1` | 出生后 16 帧内额外速度 5→0 线性衰减 | `add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx();` |
| `0x10` | 前 `i0` 帧（`≤0` 视为永久）加速度 `f0`；`f1 ≤ −999` 沿弹自身方向，否则沿固定角 `f1` | 沿自身：`@D set_accel(f0); stop_fx();`；固定角 θ：`@D set_gravity(f0·cosθ, f0·sinθ); stop_fx();` |
| `0x20` | 前 `i0` 帧每帧 `speed += f0`、`angle += f1` | `set_accel(f0); @D set_ang_vel(f1); stop_fx();` |
| `0x40` | 每 `i0` 帧一周期：速度从当前值线性减到 0，周期末 **转 `f0`**、速度设为 `f1`（`f1 < 0` 保持原速），共 `i1` 次 | 每周期 `@I step_speed(0fx, I); turn(f0); set_speed(f1);` |
| `0x100` | 同上，周期末**朝向设为** `f0` | 每周期 `@I step_speed(0fx, I); set_angle(f0); set_speed(f1);` |
| `0x80` | 同上，周期末**朝向自机 + `f0`**（从弹当前位置瞄） | 每周期 `@I step_speed(0fx, I); aim_player(f0); set_speed(f1);` |
| `0x400` | 碰左右上下场界反弹，速度变 `f0`（`<0` 不变），共 `i0` 次 | `bounce_arm(15, n);`（n ≤ 3） |
| `0x800` | 同上但只左右上 | `bounce_arm(7, n);` |

- 一段 xformdef 最多 16 物理槽；`step_speed` 占 2 槽，所以 `0x40` 族**最多写 3 个周期**再加收尾。超出部分做近似，写进 report。
- `0x40` 族最后一个周期结束后速度保持 `f1` 不再减速（TH06 清掉该位）——xformdef 在 `set_speed(f1)` 处自然结束。
- `f1 < 0`（保持原速）且一次开火里各层速度不同 → 按层拆成多个发射器 / 多个 xformdef。
- `0x1` 与 `0x10` 叠加（如 `flags = 19`）：`0x10` 的计时也从出生算起，`@D` 写成 `@(D−16)` 接在冲刺之后：
  `add_speed(5.0fx); @16 set_accel(-0.3125fx); @(D-16) set_accel(f0); stop_fx();`（`D−16` 请算成数字）。
- 反弹后改速度、反弹 > 3 次：做不到，近似并在 report 写明。

```ecl
const RICE: int = 64;

// bullet_effects(40, 1, -1, -1, 1.5707964f, 1.5f, -1.0f, -1.0f) + flags 68(0x40|4)：减速 40 帧→转 +90°→速度 1.5
xformdef DECEL_TURN_R { @40 step_speed(0fx, 40); turn(90deg); set_speed(1.5fx); }
// bullet_effects(60, 1, -1, -1, 0.0f, -1.0f, …) + flags 132(0x80|4)：f1<0 保持原速——原速 3.0 时写死 3.0
xformdef DECEL_AIM { @60 step_speed(0fx, 60); aim_player(0deg); set_speed(3.0fx); }
// bullet_effects(-1, -1, -1, -1, 0.02f, -999.0f, …) + flags 21(0x10|4|1)：冲刺 + 永久沿向加速 0.02
xformdef BURST_ACCEL { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_accel(0.02fx); }
// flags 2560(0x800|0x200) + bullet_effects(…, 2.0f …, i0 = 2)：左右上反弹 2 次
xformdef BOUNCE2 { bounce_arm(7, 2); }

async sub shooter() {
    set_invuln(65535);
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 12, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_xform(0, DECEL_TURN_R);
    sh_fire(0);
    wait(120);
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 100, 0, 0, 0, shooter);
    loop { wait(1); }
}
```

## §6 敌人生成与退场

### 6.1 timeline 与 sub 里的 `enemy_create*`

`enemy_create("SubX", x, y, z, life, item, score)`（`EnemyManager.cpp:92`、`144-320`）：

| 指令 | 位置 | 附加 |
|---|---|---|
| `enemy_create` | `(x, y)` | — |
| `enemy_create_mirror` | `(x, y)`（**坐标不镜像**） | `invertX`：此后该敌**水平速度取反**（`EnemyManager.cpp:870`） |
| `enemy_create_random` | `x ≤ −990` → `[0, 384)` 随机；`y ≤ −990` → `[0, 448)` 随机 | — |
| `enemy_create_mirror_random` | 同上 | `invertX` |

→ `spawn_enemy((x − 192) fx, y fx, 1, 0, 0, 0, SubX(mirror, …))`，血量 / 掉落 / 分数一律填 `1, 0, 0, 0`（小怪无敌，D8）。

- **镜像只取反水平速度**：`move_velocity(a, s)` → `move_vel(0, 180deg − a, s, 0)`；`move_angular_velocity(w)` → `−w`；
  `move_axis_velocity(vx, …)` → `−vx`。**弹的角度不镜像**，出弹口不镜像，`move_position` 绝对坐标不镜像。
  镜像敌上的 `move_*_time_*`（插值移动）在 TH06 会发散，遇到按「目标点 x 关于起点镜像」近似并写进 report。
- timeline 在 boss 在场时不出怪（`!g_Gui.BossPresent()`），`boss_wait(n)` 让 timeline 停到 boss 离场——切分已排除，单元内不会遇到。
- 随机 x：`(rand(384) - 192) as fx`；随机 y：`rand(448) as fx`。

### 6.2 退场

- `enemy_delete(0)` → `die();`（任何 sub 里都能直接结束；敌无掉落无分数，只是退场）。
- **出界即删**：TH06 敌「进过场地之后再出界」立即删除（`EnemyManager.cpp:540-552`，判定带贴图尺寸）。
  我方要飞出 256px 才回收，期间还会继续射击 → **每只小怪挂一个出界守卫**：

```ecl
const PELLET_T: int = 128;

// 与 TH06 一致：先进过场地，再离开（留 16px 贴图余量）就退场
async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

async sub fairy(mirror: int) {
    set_invuln(65535);
    spawn oob_guard();
    var a: angle = 90deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.0fx, 0);
    wait(10000);
}

sub main() {
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, fairy(0));
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, fairy(1));
    loop { wait(1); }
}
```

- `read_msg` / `wait_msg`（对话）：切分时排除；单元里出现 → skip-unit。

### §6.1b 子敌不继承父敌状态 / 敌默认判定框（2026-09-19，第 5 关 b4 的便笺）

`enemy_create*` 出来的子敌是**从模板重置**的（`EnemyManager.cpp:104` `*newEnemy = this->enemyTemplate;`），
**不继承父敌的 `shoot_offset` 与 bullet 属性**（模板里 `shootOffset = (0,0,0)`，`EnemyManager.cpp:68`）。
父敌设过 `shoot_offset(0,-12,0)` 再造子敌，子敌出弹口仍是自身中心——**别给子敌补 `sh_offset`**。

**判定框一定要写**：我方引擎 `set_hitbox` 的默认是 **12**，TH06 敌默认 `hitboxDimensions = (12,12,12)`
（`EnemyManager.cpp:50`）按 §8 的 `min(w,h)/3` 只有 **4**——不写就是原作的 3 倍。取值分两种：

- 段内有 `enemy_set_hitbox` → 照 §8 换算。
- **段内没有（中段起的 boss 最常见）→ 不是默认 4，而要沿 boss 的回调链往上游找**
  （`life_callback_sub` / `timer_callback_sub` / `death_callback_sub` / `enemy_interrupt_set` 都是同一只敌接力，
  判定框跟着敌走、不随段重置），取链上最近一次 `enemy_set_hitbox`。TH06 boss 段普遍是
  `(56,56,32) → 18.67fx`，中 boss 的某些形态是 `(40,56,32) → 13.33fx`。
  链上确实一次都没设过，才用默认 `set_hitbox(4.0fx)`。

## §7 敌人移动

TH06 三种移动模式（`EclManager.cpp:933-977`）：

- **模式 0**：恒定轴速度（`move_axis_velocity`、插值结束后速度清零）。
- **模式 1（极坐标）**：每帧 `angle += 角速度`、`speed += 加速度`，再换算速度。
  `move_velocity` / `move_angular_velocity` / `move_speed` / `move_acceleration` / `move_at_player` 进入此模式。
- **模式 2（插值）**：`move_*_time_*`，到时停在目标点、速度清零。

### 7.1 对照

| TH06 | 我方 |
|---|---|
| `move_position(x, y, _)` | `move_to(0, (x−192) fx, y fx, 0);` |
| `move_axis_velocity(vx, vy, _)` | `move_vel_xy(0, vx, vy, 0);` |
| `move_velocity(a, s)` | `ang = a; spd = s; move_vel(0, ang, spd, 0);` |
| `move_speed(s)` | `spd = s; move_vel(0, ang, spd, 0);` |
| `move_angular_velocity(w)` / `move_acceleration(acc)` | 记下 `w` / `acc`，**等待期间逐帧积分**（见下） |
| `move_at_player(off, s)` | `ang = aim_player() + off; spd = s; move_vel(0, ang, spd, 0);` |
| `move_rand(lo, hi)` | `ang = lo + rand(W) as angle;`（只改角，不改模式） |
| `move_rand_in_bounds(lo, hi)` | 同上 + 靠近边界时反射（`EclManager.cpp:626`），见 `wander` 例 |
| `move_position_time_*(t, x, y, _)` | `move_to(t, (x−192) fx, y fx, E);` |
| `move_dir_time_*(t, a, s)` | 位移 `s·t/2` 沿 `a`：`move_to(t, $self_x + cos(a) * d, $self_y + sin(a) * d, E);`，`d = s * t / 2` |
| `move_time_*(t)` | 用**当前** `ang`/`spd`，同上 |
| `move_bounds_set(x0, y0, x1, y1)` | 记下边界（换算 x），供 `wander` 反射与夹紧目标点 |
| `move_bounds_disable` | 不再夹紧 |

缓动 `E`（`EclManager.cpp:949-966`）：`linear` → `0`；`decelerate` → `2`（QuadOut）；
`decelerate_fast` → `5`（CubicOut，原为四次，近似）；`accelerate` → `1`（QuadIn）；`accelerate_fast` → `4`（CubicIn，近似）。

- **`move_to` 要写在速度动词之后**，这样到点即停（与 TH06 插值结束清速一致，见 ecl-lang 3 篇「位置层与速度层」）。
- `ang` / `spd` 请在任务里用变量**自己记住**，别读 `$self_angle`（近乎静止时不更新）。

### 7.2 极坐标模式下的等待

有非零角速度或加速度时，原文每个 `+N` 的等待改成逐帧积分：

```ecl
const PELLET_T: int = 128;

async sub swirl_fairy(mirror: int) {
    set_invuln(65535);
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    var acc: fx = 0fx;
    var sgn: int = 1;
    if mirror != 0 { sgn = -1; ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40: move_angular_velocity(-0.024543693f)  ;  下一条在 +80
    w = -256bam;
    if sgn < 0 { w = 256bam; }
    for k1 in 0..40 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +80: move_angular_velocity(0.019634955f)  ;  下一条在 +180
    w = 205bam;
    if sgn < 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +180: move_angular_velocity(0.0f)
    w = 0deg;
    wait(9820);
}

sub main() {
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, swirl_fairy(0));
    loop { wait(1); }
}
```

### 7.3 boss 随机游走

`move_rand_in_bounds(-π, π); move_speed(3.0f); move_time_decelerate(60);` 是 boss 最常见的一句：

```ecl
// bx0..by1 是我方坐标下的 move_bounds（TH06 (32,48)-(352,144) → (-160,48)-(160,144)）
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                 // (-π, π)，16384 = π/2
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

async sub boss() {
    set_invuln(65535);
    loop {
        wander(3.0fx, 60, -160.0fx, 48.0fx, 160.0fx, 144.0fx);
        wait(120);
    }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss);
    loop { wait(1); }
}
```

## §8 判定与标志

| TH06 | 我方 |
|---|---|
| `enemy_set_hitbox(w, h, _)` | `set_hitbox((min(w,h) / 3) fx);`（TH06 体碰用 `hitbox/1.5` 的方框，`EnemyManager.cpp:585`） |
| `enemy_flag_collision(0/1)` | `set_enemy_flag(ENEMY_NO_BODY, 1 − v);` |
| `enemy_flag_interactable(0/1)` | 同上（不可交互的敌不参与体碰） |
| `enemy_flag_invisible(0/1)` | `set_enemy_flag(ENEMY_NO_BODY, v);`（**方向与上面两条相反**：隐形 = 不体碰）<br>decomp `EnemyManager.cpp:583` 用 `!isInvisible` 门控整个体碰 / 受击块 ⇒ `v=1` 要给 `NO_BODY=1`。我方没有隐形位，同时屏蔽受击是可接受的近似。<br>2026-09-18 更正：原先写「同上（1 − v）」，方向反了（第 5–6 关 worker 便笺指出）。|
| `enemy_flag_can_take_damage` | 丢弃（我方敌恒 `set_invuln(65535)`） |
| `enemy_flag_death` / `enemy_life_set` | 丢弃（无敌，永不被击破） |
| `enemy_kill_all()` | `kill_all_enemies(KILL_SILENT);`（**会跳过调用者自己**；TH06 跳过 boss，boss 调时一致） |

## §9 boss 与段结构（全部由卡外壳接管）

TH06 的段落靠回调串起来（`EnemyManager.cpp:340-447`）：

- `life_callback_threshold(h)` + `life_callback_sub(S)`：血量低于 `h` 时**跳转**（不是调用）到 S。
- `timer_callback_threshold(t)` + `timer_callback_sub(S)`：boss 计时满 `t` 帧跳转到 S，并清弹、清杂兵。
- `death_callback_sub(S)`：被击破时跳转到 S。
- `enemy_interrupt_set(i, S)` + timeline `boss_interrupt(b, i)`：从外部让 boss 跳到 S。
- `spellcard_start` / `spellcard_end` / `spellcard_flag_timeout`：宣言 / 收卡 / 耐久卡标记。
- `boss_set` / `boss_set_life_count` / `boss_timer_set` / `boss_timer_clear`：UI 与计时器。

**单元只含一段**，以上指令只用于**确定段边界**（切分已做），在卡里全部丢弃，由外壳表达：

- 非符 → `phase_begin(0, pattern, TIME_LIMIT, 0);`
- 符卡 → `spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, FLAGS, 0);`，`spellcard_flag_timeout(1)`（耐久卡）→ `FLAGS = SPELL_SURVIVAL`，否则 0。
- `TIME_LIMIT` = `unit.json` 的 `time_limit`（已钳到 3000）。
- 原文 `spellcard_start` 之后的「移到中央 + 暂不可伤」前奏属于攻击的一部分，照写进 `pattern`。
- **符卡练习入口**：原文有形如 `call("Sub32"); enemy_flag_death(3); timer_callback_sub(...); life_callback_threshold(0); +60: call("宣言"); call("模式")`
  的 sub（ecldata1 的 Sub34/35/36）——它就是一张自包含的卡，最适合照抄结构。

## §10 `ex_ins_call(id, 参数)` / `ex_ins_repeat(id)`

`ex_ins_call` 立即执行一次；`ex_ins_repeat(id)` 让函数此后**每帧**执行（`id = −1` 停，`EclManager.cpp:829-841`、`1034`）。
函数表 `EclManager.cpp:26`，实现 `EnemyEclInstr.cpp:414` 起：

| id | 函数 | 处置 | 写法 |
|---|---|---|---|
| 0 | CirnoRainbowBallJank：全场弹变色 + 停住（`param 0`）/ 随机方向加速（`param 1`） | **translate** | 见 §10.2（2026-09-19 由 skip-unit 改判）|
| 1 | ShootAtRandomArea：在敌周围 `±p/2 × ±0.375p` 的随机点用 `bulletProps` 开火 | translate | `sh_offset(k, 随机, 随机); sh_fire(k);` |
| 2 | ShootStarPattern：用 `$I2`/`$I3` 计数画五角星轨迹发弹（`EnemyEclInstr.cpp:480`） | translate | 逐帧照源码算，写在 `for` 里 |
| 3 | PatchouliShottypeSetVars：按自机设 `$I1,$I2,$I3` | translate | 灵梦 A：`i1 = 0; i2 = 3; i3 = 1;` |
| 4 | Stage56Func4：时停开关（`param` 0/1）/ 大弹随机改向（`param ≥ 2`） | **translate** | 见 §10.1（2026-09-19 由 skip-unit 改判）|
| 5 | Stage5Func5：每 9 帧沿自机方向铺 9 颗弧形弹（`EnemyEclInstr.cpp:655`） | translate | 照源码算 |
| 6 | BatWingEffect：蝠翼粒子 | drop | |
| 7 | Stage6Func7：激光网格 | skip-unit | |
| 8 | Stage6Func8：在每颗大弹位置生成弹 | skip-unit | |
| 9 | Stage6Func9：静止小弹按距离加速 | skip-unit | |
| 10 | HandleBatTransformation：蝠翼 + bomb 期间隐身 | drop | |
| 11 | Stage6Func11：静止小弹随机加速 | skip-unit | |
| 12 | Stage4Func12：在激光上发弹（`EnemyEclInstr.cpp:1069`） | **translate** | 见 §14.4（2026-09-25 由 skip-unit 改判）|
| 13 | StageXFunc13：以场地中心为圆心、`$F3` 为半径的 N 个点每 6 帧开火（`EnemyEclInstr.cpp:1086`） | translate | 照源码算，中心 `(0, 224)` |
| 14 | StageXFunc14：沿激光铺弹（`EnemyEclInstr.cpp:1110`） | **translate** | 见 §14.4（2026-09-25 引擎加激光读口后由 skip-unit 改判）|
| 15 | StageXFunc15：大弹附近的静止小弹加速 | skip-unit | |
| 16 | FlandreFinalContextUpdate：按剩余血量设 `$F2/$F3/$I5`（`EnemyEclInstr.cpp:1210`） | translate | 血量取满血常量（无敌）；计时 ≥ 7200 帧时按 0 血 |
| 17–19 | NC 新增，decomp 无对应 | skip-unit | |

跳过编号的机器可读表在 `config.toml` 的 `[skip] ex_ins_ids`。

### §10.1 `ex_ins_4`（咲夜的时停）的写法：**把窗口压平**（2026-09-19 重写）

**decomp 事实**（`EnemyEclInstr.cpp:562` 写 `isTimeStopped`）：窗口期间
`Player::OnUpdate`（`Player.cpp:158`）与 `BulletManager::OnUpdate`（`BulletManager.cpp:668`）
**整帧早退** —— 自机不能动、不能开火、不会被撞死，全场弹一格不挪、也不判定；
`bossTimer` 不 tick（`EnemyManager.cpp:735`）。还在跑的只有**敌方 ECL 与敌人自身的移动**。

⇒ **整个窗口对玩家是纯空转，等价于「瞬间把弹摆好、boss 瞬移」**。所以默认写法不是「停驻再放行」，
而是**把窗口压成 1 帧**（`wait(1)` 让子任务落弹，实际 2 帧）：

1. 算出 boss 在窗口里那条滑行的**终点**（§7.3 的 `move_rand_in_bounds + move_speed + move_time_decelerate(T)`），
   但**不真的滑**；
2. 窗口里每一批弹的出弹原点 = 滑行曲线上那一刻的采样点。`move_to(…, easing 2)` 是 **QuadOut**，
   即 `e(t) = 1 − (1−t)²`；第 k 批在 `t = (批间隔·k)/T`，位置 `p0 + (p1−p0)·e(t)`；
3. 弹**直接按真速出生**（不再 0 速 + `wait_signal`），boss 用 `move_to(0, x, y, 0)` 瞬移到终点；
4. `ex_ins_call(4, 2)` 在窗口里调 N 次 ⇒ 每颗弹累计被改一次的概率是 `1 − (3/4)^N`，压成**一次抽签**
   （每次抽中都是均匀角，分布等价）。N=6 → `3367/4096`；N=7 → `3549/4096`。

**压平白捡的四件事**：① 符卡时限不再烧窗口那 78–152 帧，**总轮数自动与原作一致**（原作 `bossTimer`
本来就不 tick；旧的停驻写法会少三分之一轮）；② 自机不再白得一段无威胁的免费走位；③ 停驻变换、
「随机速度弹靠常驻任务冻结」（旧 §10.1①b）、「刀停在平均冻结半径」这些近似全部消失；
④ 任务槽压力消失——改向任务变成一次性，抽完即退。

**两个工程约束**（都实测过）：
- **任务指令预算 1024 op/任务/帧**：一批 9 点 × 3 颗的刀阵约 200 op，7–10 批放一个任务里会被截断 ⇒
  **一批派一个 `spawn` 任务**。`spawn` 出来的子任务**下一帧**才执行，且同帧派的会**在同一帧**一起落弹。
- **发射器槽是每任务私有的四个**（0..3）：子任务各用自己的 0 号，不会互相踩。用 `sh_*(4, …)` 会
  静默 no-op 并计 `contract_viol`。

```ecl
const KNIFE: int = 16;

// 一批 = 滑行曲线上一个采样点摆一圈弹；(sx, sy) 是那一刻的 boss 位置，boss 实体已在终点，
// 所以出弹口偏移要补上 (sample − self)。
async sub wave(sx: fx, sy: fx, k: int) {
    sh_reset(0);
    sh_sprite(0, KNIFE, 6);
    sh_aim(0, 1);                       // 原作 aimMode = FAN_AIMED：自机狙（从出弹点算）
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_angle(0, 0deg, 5461bam);         // ±π/6
    sh_speed(0, 2.0fx, 0fx);            // 真速，不停驻
    var a: angle = 0deg;
    for i in 0..9 {
        a = a + 7281bam;                // 每点 40°，示意用
        sh_offset(0, sx - $self_x + 96.0fx * cos(a), sy - $self_y + 96.0fx * sin(a));
        sh_fire(0);
    }
}

async sub boss() {
    set_invuln(65535);
    var ex: fx = $self_x;
    var ey: fx = $self_y;
    var tx: fx = 64.0fx;                // 实战里按 §7.3 的随机游走算，这里写死示意
    var ty: fx = 120.0fx;
    var t: fx = 0fx;
    var u: fx = 0fx;
    wait(60);
    // ── ex_ins_call(4,1) …… ex_ins_call(4,0)：整窗压成下面这 1 帧 ──
    for k in 0..7 {
        t = k * 9.0fx / 60;             // 原作每 9 帧一批、滑行 60 帧
        u = 1.0fx - t;
        spawn wave(ex + (tx - ex) * (1.0fx - u * u), ey + (ty - ey) * (1.0fx - u * u), k);
    }
    move_to(0, tx, ty, 0);              // boss 瞬移到滑行终点
    wait(1);                            // 让各批当帧落弹
    // ── 窗口结束 ──
    loop { wait(60); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 112.0fx, 1000, 0, 0, 1, boss);
    loop { wait(600); }
}
```

**实测**（`transcribe/work/proto/collapse`）：同一帧内 `move_to(0,…)` 三次、每次 `sh_fire`，
三颗弹准确落在三个瞬移点。全池落地见第 5 关 b2/b3/b5/b6/b8/b9 六张卡——峰值与旧的停驻版一致
（b3 290/305、b5 63/191、b9 503→500 / 729→731），均值下降是因为弹不再被冻在场上。

**② 大弹随机改向（`ex_ins_call(4, 2)`）**

decomp（`EnemyEclInstr.cpp:564-648`）：扫全场弹，只挑 `heightPx ≥ 30`（即**所有 32px 弹型**：
6 大玉 / 7 火球 / 8 小刀）且没改过色的，每颗 **1/4 概率**命中，一次调用最多改
**14 颗（E/N）/ 52 颗（H/L）**；命中后改色并重设角度——离自机 > 128px 时取随机角
（E/N 限 `[π/4, π]`，H/L 全周），≤ 128px 时取「自机方向 + π/2 + 随机全周」（两支都是均匀分布）。

压平后写法分两种：
- **弹在窗口里出生**（刀阵）：角度在发射那一刻就定 ⇒ 在摆弹循环里直接抽，不用任务。
- **弹在窗口前就在场**（先发的大玉环）：给它挂一个**一次性**任务，等纪元跳变抽一次就退。

```ecl
const EPOCH: int = 20;                  // 脚本可写全局槽（≥16）
const BIG: int = 176;

async sub bigball() {                   // sh_task(k, bigball)：一次性，抽完即退
    var seen: int = global(EPOCH);
    while global(EPOCH) == seen { wait(1); }
    if rand(4096) < 3367 { set_angle(0, rand(65536) as angle); }   // N=6 次 ⇒ 1−(3/4)^6
}

async sub boss2() {
    set_invuln(65535);
    set_global(EPOCH, 0);
    sh_reset(1);
    sh_sprite(1, BIG, 2);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 16, 1);
    sh_speed(1, 1.2fx, 0fx);
    sh_angle(1, 0deg, 0deg);
    sh_task(1, bigball);
    sh_fire(1);
    wait(60);
    set_global(EPOCH, global(EPOCH) + 1);   // —— 压平后的 ex_ins_call(4,2)：一次抽签 ——
    loop { wait(60); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 120.0fx, 1000, 0, 0, 1, boss2);
    loop { wait(600); }
}
```

**注意**：① 每次调用的 14/52 上限在我方按概率近似（原作扫描按池序，先吃到的是先发的弹）；
颗数远超上限时在 report 里说明。② 窗口前就飞出屏幕的弹，任务再调 `set_angle` 会计一次
`contract_viol`（悬垂句柄，P4-b 吞成 no-op）——与原作「那颗弹已经没了」同义，只是引擎会计数，
在 report 里说明即可。

**已知偏差（写进 report）**：boss 在窗口里的滑行变成瞬移。窗口内自机被冻、看得见但动不了，
对玩家不可反应，故等价；只有在做**有头录像**时能看出是「瞬移」而不是「滑行」。

**什么时候仍然要用「停驻 + 放行」**：只有**不冻自机**的冻弹机制，典型是琪露诺的 `ex_ins_0`
（见 §10.2，decomp 里它根本不写 `isTimeStopped`）。那种窗口里玩家照常能动，时间不能压。

### §10.2 `ex_ins_0`（琪露诺「パーフェクトフリーズ」）的写法（2026-09-19 新增）

decomp `EnemyEclInstr.cpp:415-461`：扫全场弹，**每颗都**把 `spriteOffset` 设成 **15**（换色，纯表现），然后按参数：

| param | 行为 |
|---|---|
| 0 | `speed = 0` + 速度向量清零 —— 全场弹**原地冻住** |
| 1 | `exFlags |= 0x10`（笛卡尔加速）、`ex4Acceleration = 随机方向 × 0.01`、计时清零、`ex5Int0 = 220`<br>—— 每颗弹**朝各自随机方向以 0.01 px/帧² 加速 220 帧** |

和 §10.1 是同一套工具：**换色 + 冻住**走 xform（零任务槽），**随机方向加速**要逐颗不同的方向 ⇒ 弹挂任务。
卡内所有会被波及的弹，出生时就要带上这段变换 / 任务。

```ecl
const ICE: int = 32;
const EPOCH: int = 20;

xformdef FREEZE {            // param 0：等信号 → 变色 + 冻住（`set_color` 只换色轴，保住形状）
    wait_signal(0);
    set_color(15);
    set_speed(0fx);
}

async sub scatter() {        // param 1：等纪元 → 随机方向 0.01 加速，220 帧后停
    var seen: int = global(EPOCH);
    loop {
        var now: int = global(EPOCH);
        if now != seen {
            seen = now;
            var a: angle = rand(65536) as angle;
            set_gravity(0, cos(a) * 0.01fx, sin(a) * 0.01fx);
            wait(220);
            stop_fx(0);
            return;
        }
        wait(1);
    }
}

async sub cirno() {
    set_invuln(65535);
    set_global(EPOCH, 0);
    sh_reset(0);
    sh_sprite(0, ICE, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 24, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, FREEZE);      // 这一波会被「冻住」波及
    sh_task(0, scatter);      // 同一波之后还要被「散开」波及时，两个都挂
    sh_fire(0);
    wait(120);
    pulse_signal(0);                          // ex_ins_call(0, 0)：冻住
    wait(120);
    set_global(EPOCH, global(EPOCH) + 1);     // ex_ins_call(0, 1)：随机方向加速
    wait(300);
}

sub main() {
    _ = spawn_enemy(0.0fx, 120.0fx, 1000, 0, 0, 1, cirno);
    loop { wait(600); }
}
```

**注意**：① 一波弹同时要「冻」和「散」时，`sh_xform` 与 `sh_task` 都挂（变换零槽、任务一颗一槽，注意任务池 256）；② `set_gravity` 的两参是每帧加速度，原作是 `0.01`；③ **换色只有 xform 有**（`set_color` 不在弹挂任务的九个 setter 里）；反正换色是纯表现，任务分支按 §11 丢弃即可；④ 冻住后弹**仍有判定**（原作也是）。

## §11 丢弃（纯表现 / 音效 / 道具）

`nop`、`anm_*`、`effect_sound`、`effect_particle`、`spellcard_effect`、`bullet_sound`、`drop_items`、`drop_item_id`、
`std_unpause`、`debug_watch`：删掉，不留注释。它们不影响弹、判定、时序。

## §12 整单元跳过

§10 表中 skip-unit 的 `ex_ins` 编号、对话 `read_msg` / `wait_msg`。（`laser_*` 九条 2026-09-25 起可转，见 §14。）
切分器已按 `config.toml` 的 `[skip]` 机械判定；转写时发现漏判，`report.md` 写 `status: blocked` 并给原因。

## §13 卡外壳模板

### 13.1 波次卡

```ecl
// th06_s1_w01：Stage 1 道中第 1 波（原文 timeline 帧 100–1174）
const TIME_LIMIT: int = 1400;     // unit.json 的 time_limit
const PELLET_T: int = 128;

async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

async sub sub0(mirror: int) {
    set_invuln(65535);
    spawn oob_guard();
    var a: angle = 90deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.0fx, 0);
    wait(10000);
}

// 导演任务：按 timeline 相对帧出怪。原文第一只在帧 100 ⇒ 开场先等 (100 - t_start) 帧，
// 并保证开场 120 帧内没有致命弹到达出生点（不够就整体后移并写进 report）。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    wait(16);
    _ = spawn_enemy(-124.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    wait(64);
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    loop { wait(1); }
}

async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, wave, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
```

- 导演敌放在 `(0, 0)`：场内（不会被越界回收）、屏幕最上沿、无体碰。
- `TIME_LIMIT` = 最后一只怪出生帧 − 第一只出生帧 + 尾部余量 + 开场缓冲，≤ 3000。

### 13.2 boss 段卡

```ecl
// th06_s1_b3：Stage 1 boss 符卡「夜符「ナイトバード」」（原文 Sub27 + Sub28，时限 1500）
const TIME_LIMIT: int = 1500;
const SPELL_ID: int = 2;
const PELLET_T: int = 128;

async sub pattern() {
    // 原文 Sub27：move_position_time_decelerate(120, 192.0f, 96.0f, 0.0f); +120 …
    move_to(120, 0.0fx, 96.0fx, 2);
    wait(120);
    loop {
        // 原文 Sub28 的发弹循环翻译在这里
        wait(60);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
```

- boss 出生点：本段起始位置。原文段开头有移动的，出生在移动起点；不知道的，出生在 `(0, 96)`。
- 前一段留下的变量状态（如 `$F0` 累加的相位）按原文初值重建，写进 report。

## §14 激光（2026-09-25 起可转）

引擎激光池见 stg-engine `docs/ecl-lang/9-lasers.md`（语法）与 spec `docs/superpowers/specs/2026-09-25-laser-pool-design.md` §2、§9.1、§12（原作机制与转写口径）。
原作是**一种**直线激光：射线原点 + 角度 + 射线上 `[start, end]` 一段；每帧 `end += speed`、`start = max(start, end − startLength, 0)`；
三态 预警（不判）→ 生效（判）→ 收缩（不判）；`start ≥ 640` 回收（`BulletManager.cpp:959-1100`）。角度和原点**只由 ECL 改**，结构体里没有角速度。

### 14.1 逐条对照（`EclManager.cpp:456-530`）

| 原作 | 我方 | 说明 |
|---|---|---|
| `laser_index(i)` | 局部变量 `lz_i` | 只是选「下一条 create 存进敌人指针表的第 i 格」。每个用到的 i 开一个 `var lz_i: int`；跨 sub 用到的句柄**作为参数传给被调 sub**（红魔乡只有 Extra Sub46 → Sub47 一处） |
| `laser_create(sprite, color, a, sp, st, en, sl, w, T0, T1, T2, hb0, hb1, flags)` | `lz_i = laser(col, ox, oy, a, en, w/2, T0, T1, T2);` 再按 §14.2 补 `lz_start` / `lz_speed` | 原点 = 敌位置 + **当时生效的 `shoot_offset`**（`EclManager.cpp:460`） |
| `laser_create_aimed(…)` | 同上，建完**立刻** `lz_aim(lz_i, a)`（角度位先填 `0bam`） | 原作从激光原点（= 敌 + `shoot_offset`）瞄准，`lz_aim` 同基点，精确一致。**别用 `aim_player() + a`**：它从敌自身瞄，`shoot_offset ≠ 0` 时差一个小角度 |
| `laser_rotate(i, a)` | `lz_rotate(lz_i, a)` | 一次性加角度。**逐帧照翻**：红魔乡的 `laser_rotate` 全在逐帧循环里，照翻与原作逐位等价 |
| `laser_rotate_from_player(i, a)` | `lz_aim(lz_i, a)` | 红魔乡未使用 |
| `laser_offset(i, x, y, _)` | `lz_origin(lz_i, $self_x + x, $self_y + y)` | 原点 = 敌位置 + 参数（**不加** `shoot_offset`，`EclManager.cpp:506`）。**逐条照翻**，不要改成 `lz_anchor`：`lz_anchor` 在相位 5 读敌人移动后的位置，会领先原作一帧 |
| `laser_test(i)` | `lz_alive(lz_i)` | 红魔乡未使用 |
| `laser_cancel(i)` | `lz_cancel(lz_i)` | 提前进入收缩 |
| `laser_clear_all` | 删掉 | 只清敌人指针表，激光照样活着；我方句柄本来就在局部变量里 |

### 14.2 参数换算

| 原作参数 | 换算 | 理由 |
|---|---|---|
| `w`（宽） | **`w / 2`** | 我方画多宽判多宽；原作判定半高是 `w/4`、画面是 `w`（spec 裁定 ④）。例：`32.0f` → `16.0fx` |
| `a`（角度） | 同 §1：弧度 → `bam` | 可以是变量（`%F3`），照样用变量 |
| `en`（end） | `laser()` 的 `len` | |
| `st`（start）、`sl`（startLength） | `speed = 0` 时：有效 `start = max(st, en − sl, 0)`，非 0 才写 `lz_start(lz, start)` | 原作第一帧就按 `sl` 把 start 拽到位。例：第 4 关 `(64, 500, 500)` → `lz_start(lz, 64.0fx)`；Extra `(32, 420, 388)` → `lz_start(lz, 32.0fx)` |
| `sp`（speed）≠ 0 | `laser(…, len = en, …)` 后 `lz_speed(lz, sp, sl)` | 飞棒：`lz_speed` 令 `end = start`，从近端长出去。红魔乡的飞棒都是 `st = en = 0`，与原作一致 |
| `T0 / T1 / T2` | `warn / active / fade` 原样 | 原作 `startTime / duration / despawnDuration`。`T0 = 0` 出生即生效 |
| `hb0 / hb1` | 丢弃 | CC0 在预警期 / 收缩期的判定窗；th06nc 只在生效态判定（renkolab `bullet/th06nc/01` §3.1） |
| `sprite` | 丢弃 | 纯外观：`0` = 截面光条，`1` = 圆弹拉伸的梭形（帕秋莉、芙兰）。我方只画光条 |
| `color` | `sprite = 0`：`[0, 2, 4, 6, 8, 10, 13, 15][color]`（8 色，同 32px 弹）；`sprite = 1`：原样（BALL 是 16 色） | 纯外观，别为它纠结 |
| `flags` | 红魔乡全是 0，丢弃 | 位 0 只选收缩方式（变窄 / 淡出） |

- **非整数 BAM 的逐帧转角**：`0.008267349f` = 86.23 bam，取整成 `86bam`，生效 120 帧累计差约 0.15°，可接受，写进 report。
  累计误差超过 0.5° 时改用累积取整：第 k 帧转 `round(a × (k+1)) − round(a × k)`。
- **镜像**：同弹，角度 `180deg − a`，`lz_rotate` 的增量取负，`lz_origin` 的 x 取负。
- **难度前缀**：同 §2.2，粘滞前缀照常作用于 `laser` / `lz_*`。

### 14.3 时序

- 原作 ECL 在 `BulletManager` 更新之前执行，所以「本帧 create → 本帧推进」，与我方（相位 2 建、相位 5 推进）一致，不用补帧。
- 原作生效恰好 `T1` 帧、预警恰好 `T0` 帧、收缩恰好 `T2` 帧，我方同口径（引擎有逐帧对拍测试）。
- 符卡结束 / boss 死亡时原作全局清弹会把激光一起收掉；我方卡外壳的符卡结算走全屏清弹 field，激光同样被取消，不用额外写。

### 14.4 `ex_ins_call(12)` / `ex_ins_call(14)`：在激光上 / 沿激光发弹

两条都是「遍历该敌 `lasers[0..8]` 里还活着的激光，按激光几何放弹」，用**当前发射参数**（`bulletProps`）开火。
我方用激光读口直接读当前几何：`lz_x(lz) / lz_y(lz)`（原点）、`lz_angle(lz)`（角度）、`lz_near(lz) / lz_far(lz)`（`start` / `end`），
死活用 `lz_alive`。**别在脚本里另维护几何副本**，读口读到的就是引擎此刻的值。「活着」含收缩态（原作判的是 `inUse`），与 `lz_alive` 一致。

- **12 号 Stage4Func12**（第 4 关，`EnemyEclInstr.cpp:1069`）：每条活激光开一次火，出弹点 = **敌位置** + 沿激光方向 64 px
  （注意是敌位置，不是激光原点）。
- **14 号 StageXFunc14**（Extra Sub47，`EnemyEclInstr.cpp:1110`）：每条活激光，从 `start` 起每 48 px 开一次火直到 `< end`，
  出弹点 = **激光原点** + `d × (cos a, sin a)`。`end = 420`、`start = 32` 时是 d = 32, 80, …, 416 共 9 发。

```text
ex_ins_call(12, 0)   →   // 对本敌建过的每个 lz_i（i = 0..7，逐个展开）：
                          if lz_alive(lz_i) == 1 {
                              var a: angle = lz_angle(lz_i);
                              sh_offset(k, 64.0fx * cos(a), 64.0fx * sin(a));   // 相对敌
                              sh_fire(k);
                          }
                          sh_offset(k, ox, oy);                                 // 发完恢复原出弹口

ex_ins_call(14, 0)   →   if lz_alive(lz_i) == 1 {
                              var a: angle = lz_angle(lz_i);
                              var d: fx = lz_near(lz_i);
                              while d < lz_far(lz_i) {
                                  // 出弹点是绝对坐标：用发射器的绝对偏移模式，或按 §4 的写法换算成相对敌的偏移
                                  …开火于 (lz_x(lz_i) + d * cos(a), lz_y(lz_i) + d * sin(a))…
                                  d = d + 48.0fx;
                              }
                          }
```

`sh_*` 的绝对偏移写法以 stg-engine `docs/ecl-lang/4-bullets.md` 的发射器节为准；完整可运行的「沿激光铺弹」例子见
stg-engine `docs/ecl-lang/9-lasers.md`「读几何」节。

### 14.5 已知差异（写进 report，不要去凑）

1. 原作 `hb0 / hb1` 判定窗被丢弃：第 4 关有一条预警 90、`hb0 = 70`，CC0 在第 70–90 帧有一个缩在中点的小判定盒；th06nc 已删。
2. 激光没有擦弹（stg-engine follow-ups D27 第 1 条）。
3. 原作指针表是「敌人 × 格号 → 激光槽」，激光回收后槽被别人复用时，原作的 `laser_rotate` 会改到别人的激光；我方句柄带代际，只是 no-op。
4. `sprite = 1` 的梭形外观画不出来（纯外观）。

### 14.6 范例：第 1 关中 boss Sub12（两条交叉扫射）

原文：两条 π/8、7π/8 的激光，宽 32，预警 30 / 生效 120 / 收缩 16；`+30` 起 120 帧每帧 `laser_rotate(0, +0.00827)` / `(1, −0.00827)`；
`+60` 随机移动 120 帧后 `jump` 回开头。

```ecl
async sub midboss_sweep() {
    set_invuln(65535);
    loop {
        // laser_index(0/1) + laser_create(0, 6, …)：色 6（sprite 0 → 8 色表 [6] = 13），宽 32 → 16
        var lz_0: int = laser(13, $self_x, $self_y, 4096bam, 500.0fx, 16.0fx, 30, 120, 16);
        var lz_1: int = laser(13, $self_x, $self_y, 28672bam, 500.0fx, 16.0fx, 30, 120, 16);
        wait(30);
        for k in 0..120 {          // set_int($I4, 120); +1 循环体; jump_dec → 帧 31..150 各转一次
            wait(1);
            lz_rotate(lz_0, 86bam);    // 0.008267349 rad = 86.23 bam，取整（§14.2）
            lz_rotate(lz_1, -86bam);
        }
        wait(60);
        wait(120);                  // move_rand_in_bounds + move_time_decelerate(120)：移动略
    }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 0, midboss_sweep);
    loop { wait(600); }
}
```

### 14.7 范例：第 2 关 boss Sub27（三根飞棒自机狙）

原文：`shoot_offset(0, 8, 0)` 后 `laser_create_aimed(0, 6|5, 0 / ±π/8, 4.0, 0, 0, 192, 6, 0, 9999, 30, …)`，三根一组，每 50 帧一组共 3 组。

```ecl
async sub boss_spears() {
    set_invuln(65535);
    for k in 0..3 {
        // 原点 = 敌位置 + shoot_offset(0, 8)；aimed ⇒ 建完立刻 lz_aim（从激光原点瞄，同原作）
        var l0: int = laser(13, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l0, 0bam);
        lz_speed(l0, 4.0fx, 192.0fx);
        var l1: int = laser(10, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l1, 4096bam);
        lz_speed(l1, 4.0fx, 192.0fx);
        var l2: int = laser(10, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l2, -4096bam);
        lz_speed(l2, 4.0fx, 192.0fx);
        wait(50);
    }
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 0, boss_spears);
    loop { wait(600); }
}
```
