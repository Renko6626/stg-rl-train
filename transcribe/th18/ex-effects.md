# TH18 EX 编号与参数

适用TH18 v1.00a。前半给参数，后半给目标组合；原作EX名称不等于目标xform操作。

## 配置指令

609–612 的完整顺序参数与类型统一见[指令表](instructions.md#发射器与效果配置)。609/610指定槽，611/612按游标追加；609/611为短式，610/612为长式。本节解释记录与执行规则。

`id` 是发射器编号，`index` 是 EX 记录编号，`type` 是下面的原始效果值。TH18 每颗弹复制 24 条记录，TH16 为 18 条；每条记录仍是 `0x2c` 字节。指定槽写入后，追加游标变为 `index+1`；追加写入后游标前进。

**短式 609/611 不清零 `c/d/m/n`。** 覆盖旧槽时，这四个字段仍可能来自之前的配置；未找到重置证据时，不能按未传参自动补零。长式也不自动覆盖由其他指令配置的 sub 字符串。

`type` 按单个效果标识分派；active 状态虽是位场，不代表可以在配置的 type 中任意 OR 多个效果。社区的 0–33 效果序号不直接作为 type：例如 ANGLE_ACCEL 的原始值是 8，WAIT 是 `0x80000000`，按有符号 int 显示为 `-2147483648`。

`async=0` 遇到其他持续效果通常停住，OFFSCREEN 有例外；非零允许不同效果并行。相同效果已经 active 时仍有停门。因此不能把 async 当线程，也不能把并行 EX 全部串成 wait 序列。

## 原始 type 对照

参数名按上表签名定位。下表未列出的参数，仅表示已核普通弹主路径未见读取；复杂配对记录和子模式见下文；未解字段实际影响本卡时交回。名称是便于识别的别名，不是我方 xform 名称。

| type 十六进制 / 十进制 int | 效果 | 参数语义 |
|---|---|---|
| `0x1` / 1 | SPEEDUP | 已核主路径无参数 |
| `0x2` / 2 | ANIM | a=ANM interrupt=7+low16(a) |
| `0x4` / 4 | ACCEL | a=持续时间；r=加速度标量；s=角参数；各版本解析不同；m=TH18瞄准偏移/随机幅度 |
| `0x8` / 8 | ANGLE_ACCEL | a=持续时间；r=速度增量/帧；s=角速度；每步 angle += s*dt |
| `0x10` / 16 | STEP / ANGLE | a=每段持续时间；b=段数上限；c=角/速子模式0..7；d=保存进私有状态；本轮未确定用途；r=角参数；c=5/6为随机幅度；s=目标速；<=-999990保留；c=7为当前速随机幅度；m=TH18角helper偏移/幅度 |
| `0x40` / 64 | BOUNCE | a=反弹事件次数上限；b=墙mask U/D/L/R=1/2/4/8；0x10抑制反射；0x20自定义尺寸；r=> -990时设置反弹处理后的speed，否则保留；s=b&0x20时宽；否则384；m=b&0x20时高；否则448 |
| `0x80` / 128 | INVULN | a=取消免疫/弹自身存活计数 |
| `0x100` / 256 | OFFSCREEN | a=最长保活倒计时；b=非0额外做视锥可见性检查 |
| `0x200` / 512 | SETSPRITE | a=弹型索引；b=低15位颜色；0x8000触发ANM interrupt2 |
| `0x400` / 1024 | DELETE | a=等于1时先把cancel script设-1 |
| `0x800` / 2048 | PLAYSOUND | a=声音id |
| `0x1000` / 4096 | WRAP | a=传送次数上限；b=墙mask U/D/L/R=1/2/4/8 |
| `0x2000` / 8192 | SHOOTPREP / SHOOT | a=aim模式；b=子弹起始effect_index；c=路数；d=层数；r=发射角/当前角/玩家角哨兵；s=第二角；m=首速；<=-999990保留父speed；n=末速 |
| `0x4000` / 16384 | SHOOT_DATA | a=配对记录：sprite；b=配对记录：color；c=配对记录：非0删除父弹 |
| `0x8000` / 32768 | REACT | a=写入反应编号字段 |
| `0x10000` / 65536 | GOTO / LOOP | a=目标EX记录index；b=<=0无条件跳；>0使用逐弹共享循环计数 |
| `0x20000` / 131072 | MOVE | a=持续时间；b=低8位插值模式；0x100相对坐标；r=目标x；s=目标y；生命周期见下文 |
| `0x40000` / 262144 | VEL | r=<-990保留角；[-990,990)字面；>=990朝玩家+r-999；s=<-990保留speed，否则直接赋speed |
| `0x80000` / 524288 | VELADD | a=写私有时限；r=附加位移方向；s=附加位移速度 |
| `0x100000` / 1048576 | BRIGHT | a=1/2选择混合标志，其余清相应模式位 |
| `0x200000` / 2097152 | VELTIME / ACCELWEIRD | a=持续时间/计算斜坡的分母；r=目标标量速；s=角参数；各版本解析不同；m=TH18瞄准偏移或随机幅度 |
| `0x400000` / 4194304 | SIZE | a=插值结束时间；b=插值模式；r=初始尺寸；s=最终尺寸 |
| `0x800000` / 8388608 | SAVE / SAVEANGLE | 已核主路径无参数 |
| `0x1000000` / 16777216 | ENMCREATE / ENEMY | a=子敌I0；b=子敌I1；c=子敌I2；d=子敌I3；r=子敌F0；s=子敌F1；m=子敌F2；n=子敌F3 |
| `0x2000000` / 33554432 | LAYER | a=渲染桶/层索引 |
| `0x4000000` / 67108864 | DELAY | a=等待时间；<1直接前进 |
| `0x8000000` / 134217728 | LASER | a=0线激光；1无限激光；其他值不创建；b=sprite；c=color；d=a0:非0删除父；a1:flags及起始effect_index/删父打包；r=角/哨兵；s=speed/保留哨兵；m=线:长度；无限:附加浮点字段（未核命名）；n=线:长度相关字段；无限:长度 |
| `0x20000000` / 536870912 | HITBOX | r=>=0为动态半径；<0恢复当前弹型默认半径 |
| `0x80000000` / -2147483648 | WAIT | a=等待时间；<1直接前进 |
| `0x40000000` / 1073741824 | HOMING（行为别名） | a=持续时间；r=目标速度；s=瞄准角偏移；m=每步速度向量混合系数 |

SHOOT_DATA 随相邻 SHOOTPREP 一起消费。LASER 也会读取下一条参数记录；社区称作 LASER_DATA 的 `0x10000000` 在普通弹上没有独立动作分支。不能将这些记录删除或当成下一次独立发射。`0x20` 未找到普通弹动作；社区 ACCEL_2 / NO_GRAZE_EFFECT 的序号不能直接换算为本作 type。

### 配对记录与已核附加语义

SHOOT读紧随记录的a2/b2作为type/color，c2非0删父，复制父EX并从指定effect_index开始；两条记录一起消费。TH18的高角值只有[999990,1999990)表示瞄准玩家，达到1999990按字面角处理，不套TH16无此上界的规则。

LASER同样消费两条记录并复制父EX。a=0的Line用后记录a2/b2/c2表示发射音/变换音/effect_index，r2/s2/m2表示附加浮点字段/宽度/距离；a=1的Infinite用d低位表示flags、bits8..15表示effect_index、bit16表示删父，后记录a2/b2/c2/d2为start/expand/duration/stop，r2/s2为宽度/距离。其高角1999990上界与SHOOT相同。创建端字段布局已核，附加浮点字段及完整激光EX消费者仍未全解，实际命中未定义行为时交回，不按字段位置猜用途。

INVULN是bomb取消免疫及触碰玩家后保留弹自身的计数，仍可致死；TH18在tick尾部递减，不能把a直接当成a个完整无判定tick。目标尚无通用等价配方。

ANIM进入时保留 `position -= 4 * velocity`；出生阶段的减速、无判定和动画等待按统一口径省略。a用于选择动画路径，不是退位移的开关；本页已核出生a=1/2的退位移都保留。若同时使用etDist，将沿弹角的出生距离与此位移合成，见[出生距离配方](aim-modes.md#出生距离与anim退位移)。

## 转写时必须保留的语义

- **进入时点**：ACCEL、STEP、VELTIME 的当前角、玩家位置和随机量在效果进入时读取；普通 sub 配置点的随机表达式则仍在配置时求值。不要合并同批逐弹随机。
- **TH18 百万角哨兵**：ACCEL/VELTIME 使用下表；STEP 也调用方向解析，但其子模式可能随后覆盖角并继续消耗随机数。VEL 使用另一套 ±990 阈值，SHOOT/LASER 又有自己的高角上界，不能统一套用。
- **STEP**：包含降速、段界改向及重复，不是一次普通角度补间。`d` 的消费尚未核清；遇到实际使用应单列核对。
- **HOMING**：`0x40000000` 每 tick 重读玩家，以 `r` 作为目标速度、`s` 作为瞄准偏角、`m` 作为速度向量混合系数；`v += (target_v-v)*m`。不要把它与 VELTIME 的一次目标采样混淆。
- **INVULN**：写的是逐弹保护计数；TH16 与 TH18 的递减位置不同。不能据名称推断弹失去对玩家的致死判定，未由本页定义的保护行为交主会话补齐。
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

最后一档指弹朝boss0，而非boss朝弹；未核 boss 不存在时的结果。STEP 的 `c=7` 另走小阈值分支，不能直接查此表。

曲线激光按用户当前范围[暂不转写](transcription-policy.md#曲线激光的明确边界)；普通弹EX或子敌依赖最终创建Curve时，同样暂缓该攻击，不能删掉曲线继续判通过。

## 从 EX 记录写成目标程序

先按“配置、每弹出生、效果进入、持续 tick”四个时点拆开，再选目标操作。配置时共享的量用普通变量存下并按值传入 `xformdef`；每弹出生读数用 `at_spawn(...)`，效果发生时的方向/随机用 `at_effect(...)`。例如原作 `VEL r=999` 是效果进入时从弹位置自机狙，适合 `aim_player(0deg)`；不能把配置时的 `aim_player()` 提前塞入实参。

下面的“直接”只指表中注明的操作子集；“组合”要求保留时点、模式和资源条件；“近似”已经指出会改变的状态。目标仍有每弹 16 物理槽（STEP 占 2 槽）、8 个逻辑缓存及全世界 256 任务槽等约束，原作 24 条记录不能直接复制成 24 条目标槽。

| 原作效果 | 可用状态 | 目标操作或组合 | 边界 |
|---|---|---|---|
| VEL | 直接/组合 | `set_angle`、`set_speed`；自机狙用 `aim_player` | 保留哨兵对应的那一轴不写；先解析方向再重建速度 |
| ANGLE_ACCEL | 组合 | `set_ang_vel` + `set_accel`，到期分别置 0 | 两者同属极坐标模式；与笛卡尔 ACCEL 并发时须逐帧重排 |
| ACCEL | 组合 | 效果进入取固定方向，`set_gravity(r*cos(q), r*sin(q))`；到期清两轴 | 普通非零向量、无冲突子集；零向量时原作保留角/标量的特殊分支另核 |
| WAIT | 直接/组合 | ENGINE_VER34的`wait(a)`；旧版可用`@a add_speed(0fx)` | 只停游标，运动及已有持续效果继续 |
| DELAY | 部分/近似 | 出生前可 `wait` 后 `fire`；中途停弹可暂存速度再置 0 | 中途置 0 仍有判定，不能冒充原作 DELAY 的运动/判定门 |
| SETSPRITE | 部分 | `set_sprite(shape,color)` | 目标只换sprite，保留出生时旧radius；源会重读新type默认半径，ANM interrupt亦未复现 |
| SAVE | 组合 | 弹任务局部变量保存位置、角、速 | 必须每弹独立；目标无独立 SAVE xform 操作 |
| MOVE | 源语义已核；通用目标配方待补 | 见下文的进入、持续与结束规则 | 相对基点在效果进入时取值；到期恢复进入时保存的speed，不能只做位置补间 |
| STEP | 组合/未全核 | 弹任务按下述递推降速，在段界设角和恢复目标速 | 通用情况不能直接替成 `step_angle` 或 `step_speed`；已验证单段特例见下文，d 未核，c 各分支分别实现 |
| VELTIME | 部分组合/近似 | 进入保存 `delta=(r-old_speed)/a` 与方向，笛卡尔加速 | 原作标量 speed 独立增加，不从向量模长回填；后续读 speed 时需另存逻辑标量 |
| SIZE / HITBOX | 不支持通用动态几何 | 固定圆形可选择已有近似半径的目标弹型 | 无每弹动态半径/缩放写口；换图与改变致死范围分开记录 |
| HOMING | 组合 | 每弹任务每帧重算目标向量，`v += (target_v-v)*m` | 单人 dt=1、无其他同帧写速度者；不是 `aim_player` 每隔几帧硬转 |
| DELETE | 部分/近似 | xform `set_life(1)` | 目标到清理相位才回收，该帧仍积分、碰撞/擦弹；不等价于源立即进入取消态，cancel script/掉落亦未复现 |
| BOUNCE | 部分组合 | `bounce_arm`，重新编码墙 mask | 原作 U/D/L/R=1/2/4/8，目标 L/R/U/D=1/2/4/8；次数/自定义尺寸另核 |
| GOTO / LOOP | 部分组合 | ENGINE_VER34的标签、`goto label;`、`loop(label,n)` | 同tick续取指；源为逐弹共享GOTO计数，目标每条loop独立计数且n是总执行次数，不能直接照搬b |
| SHOOT / ENMCREATE / LASER | 组合 | 弹任务 `fire` / `spawn_enemy` / `laser` | 复制原作 EX 需重建目标行为；弹任务出生晚一帧，不能忽略 |
| SPEEDUP / ANIM / BRIGHT / LAYER / PLAYSOUND | 无完整同形映射 | 分别记录出生表现、混合、层与音效差异 | 视觉省略不代表 SIZE/HITBOX 也能省略 |
| OFFSCREEN | 组合 | ENGINE_VER35的`offscreen_keep(n)`，b=0时按源handler次数折算n | 目标逐帧减1；源同帧重跑可多减，见下文；寿命/消弹照常；b非0视锥分支未实现 |
| WRAP / VELADD / REACT / INVULN | 按机制单列 | 不直接凭名字映射 | VELADD、保护计数和REACT等未给出通用配方，实际需要时交回 |

上述新控制语法见引擎`docs/ecl-lang/4-bullets.md`，要求ENGINE_VER34编译器和运行时；OFFSCREEN的b=0映射另要求ENGINE_VER35。具体使用的工具版本以工作包为准。

转写普通弹出生ANIM时，按[已批准的出生省略口径](transcription-policy.md#已批准省略出生减速和无判定窗口)跳过整个出生阶段及其附带的效果等待。后续ACCEL等可在目标出生后的首次效果更新开始；无需先逆向ANM恢复帧，也不补等同长时间。独立WAIT/DELAY和效果自身持续时间保留。

### MOVE：取基点、插值与恢复速度

`0x20000 MOVE` 在效果进入时固定目标位置，并保存当时的原speed；`b & 0x100` 非零时，相对目标以**此时的弹当前位置**为基点，不在etEx配置时提前绑定。

持续期间按所选模式推进位置插值，每tick将插值位置之差写为速度。到期将位置设到目标点，恢复进入时保存的原speed，并结束该效果。不能漏掉末端到位和速度恢复，也不能用结束时的插值速度代替保存值。

以上是已有源语义结论。本书尚无覆盖所有插值模式及并发效果的已验证通用目标配方；具体实现仍需保留这些取样和状态变化，不能仅凭目标位置补间名称判断等价。原作使用3D插值，但全部模式的跨作数学及z写入顺序未完整核实，本节不宣称3D等价。实际需要而规则或公开API无法确定的部分交主会话，不要求作者查原生实现。

### 有限效果结束时的同帧重跑

源EX任一handler结束后会同tick重跑active效果，最后只积分一次位置；OFFSCREEN每次调用都减1。因此a不总等于世界帧数。已核例：二面第二符两个效果结束各多减一次，a=300对应目标298；三面首符a=200在零起age194清位，清位tick的VELTIME也多更新一次；二面首符同长ANGLE_ACCEL200/OFFSCREEN200仍用200。按本卡明确的效果链安排更新；缺少具体链的顺序定义时交主会话，不照抄其他卡数值。

### 先飞、旋转加速、再自机狙

这是完整目标教学程序：出生先以 1px/帧向下飞 30 帧，接着连续转向并加速 20 帧，最后从弹当前位置瞄玩家，并在效果进入时逐弹抽取 ±10°偏角。它示范 WAIT、ANGLE_ACCEL 与 VEL 的组合；没有原作源程序与其逐帧对拍。

```ecl
const TH18_BALL: int = 416;
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
    _ = fire(TH18_BALL, 2, 0fx, 96fx, 1fx, 90deg, TURN_AND_AIM(0), none);
    loop { wait(1); }
}
```

`@30 add_speed(0fx)` 先执行零增量再等待 30 帧；若写 `@30 set_speed(0fx)`，弹会从出生就停止。最后两条只表示 VEL 的即时改向改速，±10°随机则示范 TH18 效果时取样入口，不把它说成 VEL 自带百万角哨兵。随机区间离散为 BAM 单位，保留逐弹抽取的时点和范围。

### 固定向量加速与 VELTIME 的差别

这段先飞 20 帧，再向右加速 30 帧，最后继续按所得向量飞行。进入时方向为常量 0°；原作方向是朝玩家时，应在同一个 `at_effect` 表达式内读取当时的玩家坐标。不要把先 `aim_player` 再沿向加速当作等价做法，那会改掉入射速度向量。

```ecl
const TH18_BALL: int = 416;
xformdef VECTOR_ACCEL(unused: int) {
    @20 add_speed(0fx);
    @30 set_gravity(0.025fx, 0fx);
    set_gravity(0fx, 0fx);
}
sub main() {
    _ = fire(TH18_BALL, 4, 0fx, 96fx, 1fx, 90deg, VECTOR_ACCEL(0), none);
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

STEP 的已核降速分支在第 t 次更新（0≤t<a）使用**当时的标量 speed**：`v_draw = speed - t*speed/a`，再用当前角构造本帧速度；这个计算读取原作当前逻辑标量，向量构造本身不回写标量；没有其他效果改它时，该段就是固定逻辑速率乘线性下降系数。段界恢复保存的目标 speed、更新角、计数加一并重置段计时。c0/5 加偏角，c1/6 在段界重新查玩家，c2/c3 依赖 SAVE，c4 固定目标角；c5/6/7 另有随机及进入解析顺序。

对应目标应把“原作逻辑 speed/angle、段计时、目标值、SAVE 快照”保存在弹任务局部变量中，逐帧 `set_vel(0, vx, vy); wait(1)`；首个 t=0 的 tick 与任务出生晚一帧必须在攻击时间轴补齐。若给定原作ECL后续会读取逻辑 speed，不要用上帧 `$self_speed` 代替它。对 d 或复杂并行未核的样本，不能标成完整精准支持。不能把一般的 STEP 直接替换为单个 `step_speed(0fx,a)`；须先核对逻辑速度、段界更新和其他效果的读写。

**已验证的单段特例：Stage01 BossCard2。** 源STEP为a=30、b=1、c=0、d=0、角偏0、目标速0；期间逻辑speed恒为2.5，没有并发改速或后续读取旧逻辑speed。其位移速度为t=0..29的`2.5*(1-t/30)`；t=30归零并同tick进入ANGLE_ACCEL，随后每次加E/100，共100次。目标可用`@30 step_speed(0fx,30); @100 set_accel(gain); set_accel(0fx);`：STEP出生只初始化、下一帧才推进，终帧先写0再执行加速，与本样本对应。不能外推到多段、其他c模式、非零d或并发效果；该配方仅用于上述已核子集，允许正常定点取整。

本页已核ANIM a=1/2均执行`position -= 4*velocity`：主环初速2.5退10px、大玉初速0.6退2.4px。a用于选动画interrupt，不是“是否反退”的开关；出生阶段省略时仍保留此位移。

下面给一个可运行的固定偏角段界例子：每段 20 帧减速，段界转 45°并恢复到 2px/帧，总共 3 段。`logical_speed` 独立保存原作的标量，绘制/位移速度由它计算，避免目标 `set_vel` 回填 speed 后污染下次计算。这个例子示范 STEP 的普通段循环与 SAVE 式局部快照，不覆盖 c2/c3 的全部回溯策略、未知 d 或其他 handler 并行。

```ecl
const TH18_BALL: int = 416;
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
    _ = fire(TH18_BALL, 3, 0fx, 96fx, 2fx, 90deg, none, stepping);
    loop { wait(1); }
}
```

### 持续追踪的最小任务

这个完整程序展示 HOMING 的向量混合；每帧先读当时玩家，再向目标速度向量靠近 1/8。初始向下速度不会被一次性抹掉。只覆盖单人、dt=1、此任务独占速度的子集；原作效果首次 tick 在建弹当帧，目标弹任务下一帧才跑，完整转写还需校准这一帧。

```ecl
const TH18_BALL: int = 416;
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
    _ = fire(TH18_BALL, 6, 0fx, 96fx, 1fx, 90deg, none, homing);
    loop { wait(1); }
}
```

### 并行与“停住”不要混为一谈

ANGLE_ACCEL 与 ACCEL 可在原作同时 active，原作 handler 的固定先后顺序会决定最后写入的速度。目标 `set_gravity` 开笛卡尔模式并清极坐标模式，不能把两组 setter 相邻写下就声称保留原作并行；要在一个弹任务中按原作顺序组合本帧更新。

WAIT 只停 EX 游标。DELAY 还有普通运动及碰撞门，已有 handler 仍可能推进。目标可延后调用 `fire`，但这期间连实体和显示都没有；“速度置零再等”仍会杀伤玩家，不能用来替代途中 DELAY。SIZE/HITBOX 缺动态几何写口时如实保留限制，不以换图掩盖判定差异。

## EX配置的其他入口

640 `etExSub` 的字符串参数与记录索引见[指令表](instructions.md#发射器与效果配置)；641 `etExSubtract` 的社区定义为回退追加游标。二者不等于目标通用 EX 重排接口。需要字符串消费者、动态覆盖或游标回退的攻击，须保留实际配置顺序；本作未定义的消费者交主会话，不能仅凭名称认定已支持。
