# TH18 EX 编号与参数

> **版本**：TH18 v1.00a；2026-11-05 根据两作既有 Ghidra 工程及导出与 TH16 v1.00a 对照。前半保留原作参数表，后半给我方操作与常见组合配方。原作 EX 名称不等于目标 xform 操作。

## 配置指令

| opcode / 名称 | 原作参数顺序 | EX 程序槽 |
|---|---|---|
| 609 etExSet | `id,index,async,type,a,b,r,s` | 指定 index |
| 610 etExSet2 | `id,index,async,type,a,b,c,d,r,s,m,n` | 指定 index |
| 611 etEx | `id,async,type,a,b,r,s` | 当前追加游标 |
| 612 etEx2 | `id,async,type,a,b,c,d,r,s,m,n` | 当前追加游标 |

`id` 是发射器编号，`index` 是 EX 记录编号，`type` 是下面的原始效果值。TH18 每颗弹复制 24 条记录，TH16 为 18 条；每条记录仍是 `0x2c` 字节。指定槽写入后，追加游标变为 `index+1`；追加写入后游标前进。

**短式 609/611 不清零 `c/d/m/n`。** 覆盖旧槽时，这四个字段仍可能来自之前的配置；未找到重置证据时，不能按未传参自动补零。长式也不自动覆盖由其他指令配置的 sub 字符串。

`type` 按单个效果标识分派；active 状态虽是位场，不代表可以在配置的 type 中任意 OR 多个效果。社区的 0–33 效果序号不直接作为 type：例如 ANGLE_ACCEL 的原始值是 8，WAIT 是 `0x80000000`，按有符号 int 显示为 `-2147483648`。

`async=0` 遇到其他持续效果通常停住，OFFSCREEN 有例外；非零允许不同效果并行。相同效果已经 active 时仍有停门。因此不能把 async 当线程，也不能把并行 EX 全部串成 wait 序列。

## 原始 type 对照

参数名按上表签名定位。下表未列出的参数，仅表示已核普通弹主路径未见读取；复杂配对记录、子模式和未解字段应继续读该行链接。名称是便于识别的别名，不是我方 xform 名称。“相同”均限报告列出的静态子集。

| type 十六进制 / 十进制 int | 效果 | 参数语义 | 与 TH16 对照 |
|---|---|---|---|
| `0x1` / 1 | [SPEEDUP](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-1) | 已核主路径无参数 | 相同（已核子集） |
| `0x2` / 2 | [ANIM](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-2) | a=ANM interrupt=7+low16(a) | 相同（已核子集） |
| `0x4` / 4 | [ACCEL](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-3) | a=持续时间；r=加速度标量；s=角参数；各版本解析不同；m=TH18瞄准偏移/随机幅度；TH16瞄准偏移见既有一手记录 | 不同 |
| `0x8` / 8 | [ANGLE_ACCEL](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-4) | a=持续时间；r=速度增量/帧；s=角速度；每步 angle += s*dt | 相同（已核子集） |
| `0x10` / 16 | [STEP / ANGLE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-5) | a=每段持续时间；b=段数上限；c=角/速子模式0..7；d=保存进私有状态；本轮未确定用途；r=角参数；c=5/6为随机幅度；s=目标速；<=-999990保留；c=7为当前速随机幅度；m=TH18角helper偏移/幅度 | 不同 |
| `0x40` / 64 | [BOUNCE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-6) | a=反弹事件次数上限；b=墙mask U/D/L/R=1/2/4/8；0x10抑制反射；0x20自定义尺寸；r=> -990时设置反弹处理后的speed，否则保留；s=b&0x20时宽；否则384；m=b&0x20时高；否则448 | 相同（已核子集） |
| `0x80` / 128 | [INVULN](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-7) | a=写入bullet+0x24计数 | 不同 |
| `0x100` / 256 | [OFFSCREEN](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-8) | a=最长保活倒计时；b=非0额外做视锥可见性检查 | 相同（已核子集） |
| `0x200` / 512 | [SETSPRITE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-9) | a=弹型索引；b=低15位颜色；0x8000触发ANM interrupt2 | 相同（已核子集） |
| `0x400` / 1024 | [DELETE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-10) | a=等于1时先把cancel script设-1 | 相同（已核子集） |
| `0x800` / 2048 | [PLAYSOUND](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-11) | a=声音id | 相同（已核子集） |
| `0x1000` / 4096 | [WRAP](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-12) | a=传送次数上限；b=墙mask U/D/L/R=1/2/4/8 | 相同（已核子集） |
| `0x2000` / 8192 | [SHOOTPREP / SHOOT](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-13) | a=aim模式；b=子弹起始effect_index；c=路数；d=层数；r=发射角/当前角/玩家角哨兵；s=第二角；m=首速；<=-999990保留父speed；n=末速 | 不同 |
| `0x4000` / 16384 | [SHOOT_DATA](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-14) | a=配对记录：sprite；b=配对记录：color；c=配对记录：非0删除父弹 | 相同（已核子集） |
| `0x8000` / 32768 | [REACT](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-15) | a=写入反应编号字段 | 未核（消费者） |
| `0x10000` / 65536 | [GOTO / LOOP](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-16) | a=目标EX记录index；b=<=0无条件跳；>0使用逐弹共享循环计数 | 相同（已核子集） |
| `0x20000` / 131072 | [MOVE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-17) | a=持续时间；b=低8位插值模式；0x100相对坐标；r=目标x；s=目标y | 相同（已核子集） |
| `0x40000` / 262144 | [VEL](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-18) | r=<-990保留角；[-990,990)字面；>=990朝玩家+r-999；s=<-990保留speed，否则直接赋speed | 相同（已核子集） |
| `0x80000` / 524288 | [VELADD](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-19) | a=写私有时限；r=附加位移方向；s=附加位移速度 | 相同（已核子集） |
| `0x100000` / 1048576 | [BRIGHT](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-20) | a=1/2选择混合标志，其余清相应模式位 | 相同（已核子集） |
| `0x200000` / 2097152 | [VELTIME / ACCELWEIRD](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-21) | a=持续时间/计算斜坡的分母；r=目标标量速；s=角参数；各版本解析不同；m=TH18瞄准偏移或随机幅度 | 不同 |
| `0x400000` / 4194304 | [SIZE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-22) | a=插值结束时间；b=插值模式；r=初始尺寸；s=最终尺寸 | 相同（已核子集） |
| `0x800000` / 8388608 | [SAVE / SAVEANGLE](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-23) | 已核主路径无参数 | 相同（已核子集） |
| `0x1000000` / 16777216 | [ENMCREATE / ENEMY](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-24) | a=子敌I0；b=子敌I1；c=子敌I2；d=子敌I3；r=子敌F0；s=子敌F1；m=子敌F2；n=子敌F3 | 相同（已核子集） |
| `0x2000000` / 33554432 | [LAYER](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-25) | a=渲染桶/层索引 | 相同（已核子集） |
| `0x4000000` / 67108864 | [DELAY](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-26) | a=等待时间；<1直接前进 | 相同（已核子集） |
| `0x8000000` / 134217728 | [LASER](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-27) | a=0线激光；1无限激光；其他值不创建；b=sprite；c=color；d=a0:非0删除父；a1:flags及起始effect_index/删父打包；r=角/哨兵；s=speed/保留哨兵；m=线:长度；无限:附加浮点字段（未核命名）；n=线:长度相关字段；无限:长度 | 不同 |
| `0x20000000` / 536870912 | [HITBOX](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-28) | r=>=0为动态半径；<0恢复当前弹型默认半径 | 相同（已核子集） |
| `0x80000000` / -2147483648 | [WAIT](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-29) | a=等待时间；<1直接前进 | 相同（已核子集） |
| `0x40000000` / 1073741824 | [HOMING（行为别名）](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md#ex-30) | a=持续时间；r=目标速度；s=瞄准角偏移；m=每步速度向量混合系数 | TH18新增 |

SHOOT_DATA 随相邻 SHOOTPREP 一起消费。LASER 也会读取下一条参数记录；社区称作 LASER_DATA 的 `0x10000000` 在普通弹上没有独立动作分支。不能将这些记录删除或当成下一次独立发射。`0x20` 未找到普通弹动作；社区 ACCEL_2 / NO_GRAZE_EFFECT 的序号不能直接换算为本作 type。

## 转写时必须保留的语义

- **进入时点**：ACCEL、STEP、VELTIME 的当前角、玩家位置和随机量在效果进入时读取；普通 sub 配置点的随机表达式则仍在配置时求值。不要合并同批逐弹随机。
- **TH18 百万角哨兵**：ACCEL/VELTIME 使用下表；STEP 也调用方向解析，但其子模式可能随后覆盖角并继续消耗随机数。VEL 使用另一套 ±990 阈值，SHOOT/LASER 又有自己的高角上界，不能统一套用。
- **STEP**：包含降速、段界改向及重复，不是一次普通角度补间。`d` 的消费尚未核清；遇到实际使用应单列核对。
- **HOMING**：`0x40000000` 每 tick 重读玩家，以 `r` 作为目标速度、`s` 作为瞄准偏角、`m` 作为速度向量混合系数；`v += (target_v-v)*m`。不要把它与 VELTIME 的一次目标采样混淆。
- **INVULN**：写的是逐弹保护计数；TH16 与 TH18 的递减位置不同。不能据名称推断弹失去对玩家的致死判定，详见报告消费者说明。
- **WAIT / DELAY**：WAIT 期间运动及已有持续效果继续；DELAY 还阻止通常运动/判定，但已有其他 handler 仍可能执行。到期可同 tick 续跑。
- **SETSPRITE / HITBOX / SIZE**：换型会重新读弹型默认半径；HITBOX 的负值恢复默认；SIZE 同时影响几何。按执行顺序更新状态，不能只替换显示图案。

### ACCEL / VELTIME 的 TH18 方向解析

设 `q` 为角参数（这两种效果均为 `s`），`m` 为偏移/幅度，`U` 为共享 RNG 的有符号均匀随机量：

| q 区间 | 效果进入时保存的方向 |
|---|---|
| q ≤ -999990 | 当前弹角 |
| -999990 < q < 999990 | 字面 q |
| 999990 ≤ q < 1999990 | 当前弹到玩家角 + m |
| 1999990 ≤ q < 2999990 | 字面 q |
| 2999990 ≤ q < 3999990 | 当前弹到玩家角 + m × U |
| 3999990 ≤ q < 4999990 | 当前弹角 + m × U |
| q ≥ 4999990 | 按 boss0 坐标减弹坐标求角，即朝 boss0 |

最后一档的减法方向已用 Ghidra Listing 核过，与社区“boss 到弹”的描述相反；未核 boss 不存在时的结果。STEP 的 `c=7` 另走小阈值分支，不能直接查此表。

曲线激光按用户当前范围[暂不转写](transcription-policy.md#曲线激光的明确边界)；普通弹EX或子敌依赖最终创建Curve时，同样暂缓该攻击，不能删掉曲线继续判通过。

## 从 EX 记录写成目标程序

先按“配置、每弹出生、效果进入、持续 tick”四个时点拆开，再选目标操作。配置时共享的量用普通变量存下并按值传入 `xformdef`；每弹出生读数用 `at_spawn(...)`，效果发生时的方向/随机用 `at_effect(...)`。例如原作 `VEL r=999` 是效果进入时从弹位置自机狙，适合 `aim_player(0deg)`；不能把配置时的 `aim_player()` 提前塞入实参。

下面的“直接”只指表中注明的操作子集；“组合”要求保留时点、模式和资源条件；“近似”已经指出会改变的状态。目标仍有每弹 16 物理槽（STEP 占 2 槽）、8 个逻辑缓存及全世界 256 任务槽等约束，原作 24 条记录不能直接复制成 24 条目标槽。

| 原作效果 | 可用状态 | 目标操作或组合 | 边界 |
|---|---|---|---|
| VEL | 直接/组合 | `set_angle`、`set_speed`；自机狙用 `aim_player` | 保留哨兵对应的那一轴不写；先解析方向再重建速度 |
| ANGLE_ACCEL | 组合 | `set_ang_vel` + `set_accel`，到期分别置 0 | 两者同属极坐标模式；与笛卡尔 ACCEL 并发时须逐帧重排 |
| ACCEL | 组合 | 效果进入取固定方向，`set_gravity(r*cos(q), r*sin(q))`；到期清两轴 | 普通非零向量、无冲突子集；零向量时原作保留角/标量的特殊分支另核 |
| WAIT | 组合 | `@a add_speed(0fx)` | `@a` 是后置等待；弹继续运动，已开的持续效果继续 |
| DELAY | 部分/近似 | 出生前可 `wait` 后 `fire`；中途停弹可暂存速度再置 0 | 中途置 0 仍有判定，不能冒充原作 DELAY 的运动/判定门 |
| SETSPRITE | 部分 | `set_sprite(shape,color)` | 目标只换sprite，保留出生时旧radius；源会重读新type默认半径，ANM interrupt亦未复现 |
| SAVE | 组合 | 弹任务局部变量保存位置、角、速 | 必须每弹独立；目标无独立 SAVE xform 操作 |
| STEP | 组合/未全核 | 弹任务按下述递推降速，在段界设角和恢复目标速 | 不能替成 `step_angle` 或 `step_speed`；d 未核，c 各分支分别实现 |
| VELTIME | 部分组合/近似 | 进入保存 `delta=(r-old_speed)/a` 与方向，笛卡尔加速 | 原作标量 speed 独立增加，不从向量模长回填；后续读 speed 时需另存逻辑标量 |
| SIZE / HITBOX | 不支持通用动态几何 | 固定圆形可选择已有近似半径的目标弹型 | 无每弹动态半径/缩放写口；换图与改变致死范围分开记录 |
| HOMING | 组合 | 每弹任务每帧重算目标向量，`v += (target_v-v)*m` | 单人 dt=1、无其他同帧写速度者；不是 `aim_player` 每隔几帧硬转 |
| DELETE | 部分/近似 | xform `set_life(1)` | 目标到清理相位才回收，该帧仍积分、碰撞/擦弹；不等价于源立即进入取消态，cancel script/掉落亦未复现 |
| BOUNCE | 部分组合 | `bounce_arm`，重新编码墙 mask | 原作 U/D/L/R=1/2/4/8，目标 L/R/U/D=1/2/4/8；次数/自定义尺寸另核 |
| GOTO / LOOP | 部分组合 | 简单有限重复展开，或弹任务；底层LOOP不是当前xformdef语法 | 原作同 tick 可续取指；目标 LOOP 每帧跳转护栏与计数语义不同 |
| SHOOT / ENMCREATE / LASER | 组合 | 弹任务 `fire` / `spawn_enemy` / `laser` | 复制原作 EX 需重建目标行为；弹任务出生晚一帧，不能忽略 |
| SPEEDUP / ANIM / BRIGHT / LAYER / PLAYSOUND | 无完整同形映射 | 分别记录出生表现、混合、层与音效差异 | 视觉省略不代表 SIZE/HITBOX 也能省略 |
| OFFSCREEN / WRAP / VELADD / REACT / INVULN | 按机制单列 | 不直接凭名字映射 | VELADD 私有计时和清位异常、保护计数及消费者见原生报告 |

### 先飞、旋转加速、再自机狙

这是完整目标教学程序：出生先以 1px/帧向下飞 30 帧，接着连续转向并加速 20 帧，最后从弹当前位置瞄玩家，并在效果进入时逐弹抽取 ±10°偏角。它示范 WAIT、ANGLE_ACCEL 与 VEL 的组合；没有原作源程序与其逐帧对拍。

```ecl
xformdef TURN_AND_AIM(unused: int) {
    @30 add_speed(0fx);
    set_ang_vel(1deg);
    @20 set_accel(0.05fx);
    set_ang_vel(0deg);
    set_accel(0fx);
    set_angle(at_effect(atan2($player_y - $self_y, $player_x - $self_x)
        + ((rand(3641) - 1820) as angle)));
    set_speed(2fx);
}
sub main() {
    _ = fire(48, 2, 0fx, 96fx, 1fx, 90deg, TURN_AND_AIM(0), none);
    loop { wait(1); }
}
```

`@30 add_speed(0fx)` 先执行零增量再等待 30 帧；若写 `@30 set_speed(0fx)`，弹会从出生就停止。最后两条只表示 VEL 的即时改向改速，±10°随机则示范 TH18 效果时取样入口，不把它说成 VEL 自带百万角哨兵。随机区间离散为 BAM 单位，保留逐弹抽取的时点和范围。

### 固定向量加速与 VELTIME 的差别

这段先飞 20 帧，再向右加速 30 帧，最后继续按所得向量飞行。进入时方向为常量 0°；原作方向是朝玩家时，应在同一个 `at_effect` 表达式内读取当时的玩家坐标。不要把先 `aim_player` 再沿向加速当作等价做法，那会改掉入射速度向量。

```ecl
xformdef VECTOR_ACCEL(unused: int) {
    @20 add_speed(0fx);
    @30 set_gravity(0.025fx, 0fx);
    set_gravity(0fx, 0fx);
}
sub main() {
    _ = fire(48, 4, 0fx, 96fx, 1fx, 90deg, VECTOR_ACCEL(0), none);
    loop { wait(1); }
}
```

ACCEL 的普通向量分支会用新的向量回算 angle/speed，目标笛卡尔加速适合这个子集。VELTIME 保存的斜坡则是 `(target_scalar_speed-current_scalar_speed)/a`，同时给标量 speed 加 delta、给速度向量加 `delta*direction`；方向不平行时，标量与向量长度会分离。目标 `$self_speed` 始终跟向量同步，所以后续有 SAVE、VEL 的保留 speed、STEP 或再一次 VELTIME 时，必须在弹任务中保存原作逻辑标量；仅用 `step_speed(r,a)` 会改变轨迹。

### SAVE 与 STEP 需要保存什么

SAVE 在执行时保存当时的 xyz、angle、speed，后续 STEP c2/c3 才读取；不是出生角缓存，也不是发射器共享缓存。目标弹任务可在对应位置写：

```text
// 目标任务片段；saved_* 是这颗弹自己的 locals。
var saved_x: fx = $self_x;
var saved_y: fx = $self_y;
var saved_angle: angle = $self_angle;
var saved_speed: fx = $self_speed;
```

STEP 的已核降速分支在第 t 次更新（0≤t<a）使用**当时的标量 speed**：`v_draw = speed - t*speed/a`，再用当前角构造本帧速度；这个计算读取原作当前逻辑标量，向量构造 helper `0x429bc0` 本身不回写标量；没有其他效果改它时，该段就是固定逻辑速率乘线性下降系数。段界恢复保存的目标 speed、更新角、计数加一并重置段计时。c0/5 加偏角，c1/6 在段界重新查玩家，c2/c3 依赖 SAVE，c4 固定目标角；c5/6/7 另有随机及进入解析顺序。

对应目标应把“原作逻辑 speed/angle、段计时、目标值、SAVE 快照”保存在弹任务局部变量中，逐帧 `set_vel(0, vx, vy); wait(1)`；首个 t=0 的 tick 与任务出生晚一帧必须在攻击时间轴补齐。若原作后续会读取逻辑 speed，不要用上帧 `$self_speed` 代替它。对 d 或复杂并行未核的样本，不能标成完整精准支持。用单个 `step_speed(0fx,a)` 是明确近似。

下面给一个可运行的固定偏角段界例子：每段 20 帧减速，段界转 45°并恢复到 2px/帧，总共 3 段。`logical_speed` 独立保存原作的标量，绘制/位移速度由它计算，避免目标 `set_vel` 回填 speed 后污染下次计算。这个例子示范 STEP 的普通段循环与 SAVE 式局部快照，不覆盖 c2/c3 的全部回溯策略、未知 d 或其他 handler 并行。

```ecl
async sub stepping() {
    var saved_angle: angle = $self_angle;
    var logical_angle: angle = saved_angle;
    var logical_speed: fx = $self_speed;
    for segment in 0..3 {
        for t in 0..20 {
            var v: fx = logical_speed - (t as fx) * logical_speed / 20fx;
            set_vel(0, v * cos(logical_angle), v * sin(logical_angle));
            wait(1);
        }
        logical_angle = logical_angle + 45deg;
        logical_speed = 2fx;
        set_vel(0, logical_speed * cos(logical_angle), logical_speed * sin(logical_angle));
    }
}
sub main() {
    _ = fire(48, 3, 0fx, 96fx, 2fx, 90deg, none, stepping);
    loop { wait(1); }
}
```

### 持续追踪的最小任务

这个完整程序展示 HOMING 的向量混合；每帧先读当时玩家，再向目标速度向量靠近 1/8。初始向下速度不会被一次性抹掉。只覆盖单人、dt=1、此任务独占速度的子集；原作效果首次 tick 在建弹当帧，目标弹任务下一帧才跑，完整转写还需校准这一帧。

```ecl
async sub homing() {
    for t in 0..120 {
        var a: angle = atan2($player_y - $self_y, $player_x - $self_x) + 5deg;
        var vx: fx = $self_vx + (2fx * cos(a) - $self_vx) * 0.125fx;
        var vy: fx = $self_vy + (2fx * sin(a) - $self_vy) * 0.125fx;
        set_vel(0, vx, vy);
        wait(1);
    }
}
sub main() {
    _ = fire(48, 6, 0fx, 96fx, 1fx, 90deg, none, homing);
    loop { wait(1); }
}
```

### 并行与“停住”不要混为一谈

ANGLE_ACCEL 与 ACCEL 可在原作同时 active，原作 handler 的固定先后顺序会决定最后写入的速度。目标 `set_gravity` 开笛卡尔模式并清极坐标模式，不能把两组 setter 相邻写下就声称保留原作并行；要在一个弹任务中按原作顺序组合本帧更新。

WAIT 只停 EX 游标。DELAY 还有普通运动及碰撞门，已有 handler 仍可能推进。目标可延后调用 `fire`，但这期间连实体和显示都没有；“速度置零再等”仍会杀伤玩家，不能用来替代途中 DELAY。SIZE/HITBOX 缺动态几何写口时如实保留限制，不以换图掩盖判定差异。

## 目标例子验证

四个 `ecl` 围栏均作为独立程序抽出，用 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check <file>` 编译通过，再以 `run <file> --frames 140` 运行；全部报告 `task_faults 0 / contract_viol 0 / pool_full 0`。文件及 stdout 留在忽略目录 `transcribe/work/th18-textbook-20261105/ex-lasers/ex-effects-{1,2,3,4}.*`。

这些检查证明语法与目标运行路径可用，不证明与原作同帧等价。本文已将需要校准的首 tick、逻辑标量/向量分离、动态几何与并行冲突列在相应配方中；没有新增永久测试或启动训练。

## 证据及仍需按样本核查的部分

- [逐 EX 原生比较报告](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md)：30 项完整参数、进入/持续/结束行为、版本差异及各自地址。
- [机器可读清单](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.json)：样本 hash、配置布局、逐项证据路径与未解字段。
- [子弹编号表](bullet-types.md)：SETSPRITE 及发射用到的 type/color。

REACT 的消费者、STEP `d`、TH16 极高角哨兵、复杂插值全模式以及激光完整消费者尚未核完。报告覆盖的是普通弹 EX 的配置/执行路径；相邻激光数据虽已辨认，不能据此宣称各类激光 EX 全部核实。未知项保留原值和依赖，不默认删除。

本轮复用已有社区命名、结构体和 opcode 标签；缺少 Ghidra MCP 时，通过项目只读 driver 核对关键 Listing，未重建或修改数据库。未运行原作或验收转写卡，不将静态比较视为实机等价验证。
