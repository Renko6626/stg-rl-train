# TH18 → stg-engine ECL 转写入门

这份教材面向会基本编程、尚不熟悉东方 ECL 的读者和转写 AI。按顺序读完，可以把一段 TH18 v1.00a 攻击从原作文本改写成我方脚本，并用编译器和运行转储检查结果。示例全部为自写教学程序，不是原作关卡摘录。

主文讲语法、执行模型和转换方法；需要查编号时使用下列参考。原作功能、目标写法与差异在表内分别列出。

| 要查的内容 | 参考 |
|---|---|
| `etSprite` 的弹型、颜色、目标 appearance 与判定差异 | [弹型表](bullet-types.md) |
| `etAim` 的扇形、环形、随机模式及创建顺序 | [瞄准与发射模式](aim-modes.md) |
| 移动/EX 的 mode、`EASE_*` 与状态型插值 | [插值模式](interpolation-modes.md) |
| EX 原始 type、参数、方向哨兵及目标配方 | [EX 效果](ex-effects.md) |
| 700–714 相关指令、直线/无限/曲线激光与几何 | [激光](lasers.md) |
| 从main编排、符卡声明和中断链确定转写单元 | [高版本切分指南](splitting.md) |
| 常用普通 opcode 的含义、处理方式与阅读位置 | [指令索引](instructions.md) |
| 敌人判定、移动组合、同敌段入口与前置状态 | [敌人状态与段入口](enemy-state.md) |
| 时钟循环、共享发射器、原作激光配置的完整转换 | [转换案例](conversion-examples.md) |
| 已确定写法、需任务单确认的差异与暂缓范围 | [统一转写口径](transcription-policy.md) |

本文基于 2026-11-05 检查的引擎源码 `2f24d86`、release harness 和训练 wheel 0.4.4 / ENGINE_VER30。版本更新后重新核实可用内建与行为；文末说明证据范围。写单个攻击时，另读[转写契约](contracts/transcribe.md)；它负责权限、产出与交接，不能替代本教程。

## 1. 先分清两个语言、三种文件

原作游戏执行二进制 `.ecl`。社区工具 **thecl** 将它反编译成文本，也能把文本编回游戏使用的二进制。`eclmap` 把 opcode 命名成 `etOn`、`movePosTime` 等；这些名字是社区助记符。

我方 **stg-engine ECL** 是另一种文本语言，也常用 `.ecl` 后缀，由 `stg-harness` 检查和执行。它没有原作 VM 的全部指令；转写需要理解行为并重新表达。

为了避免交错编译，本教材用 `tecl` 代码块表示完整原作侧合成程序，用 `ecl` 表示完整目标程序，用 `text` 表示不能单独编译的片段。把代码保存为文件时，原作文本暂用 `.tecl`，编译输出另用 `.bin.ecl`。

### 1.1 编译一个最小原作程序

```tecl
void main() {
    wait(60);
}
```

这里的 `main` 是原作控制敌的入口；子程序执行完，所属敌的主调用栈结束。它不包含任何渲染资源，也没有创建敌人或发弹。

以下为本机已用过的工具路径，换机器时替换变量值：

```bash
THECL=/data/sunyunbo/www/renkolab/local/vendor/thtk/build/thecl/thecl
ECLMAP=/data/sunyunbo/www/renkolab/local/vendor/eclmap/eclmap/th18.eclm
"$THECL" -c 18 -m "$ECLMAP" lesson.tecl lesson.bin.ecl
"$THECL" -d 18 -m "$ECLMAP" lesson.bin.ecl lesson.roundtrip.tecl
```

`-c 18` 选择 TH18 编译，`-d 18` 选择反编译；`-m` 指定同一份映射。要读较原始的栈指令，可在反编译时加 `-r`。不要用其他社区工具的参数或语法替换这套命令。

编译成功证明文本和本版本指令格式可接受；它不证明资源齐全，也不证明程序在游戏内达到预期。

### 1.2 编译并运行最小目标程序

```ecl
sub main() {
    loop { wait(1); }
}
```

我方必须有且只有一个零参、非 `async` 的 `sub main()`。它是关卡任务，owner 是 STAGE，不是一只隐形敌人。`loop { wait(1); }` 让这条任务每帧恢复一次，保持关卡流程存在。

```bash
HARNESS=/data/sunyunbo/www/stg-engine/target/release/stg-harness
"$HARNESS" check lesson.ecl
"$HARNESS" run lesson.ecl --frames 120 --seed 1 --rank 2
"$HARNESS" run lesson.ecl --frames 120 --seed 1 --rank 2 --at 60
```

`check` 查语法、类型、引用和容量；`run` 真正推进世界，报告实体/任务峰值及 fault；`--at F` 输出第 F 帧实体数值。普通难度为 `0=Easy, 1=Normal, 2=Hard, 3=Lunatic`，所以这里检查 Hard。后续各章沿用这组命令。

## 2. 把原作语句读成行为，再写成三种目标类型

### 2.1 sub、变量和表达式

thecl 高层语法接近 C：类型在变量名前，普通调用进入同一调用栈，`async` 后缀建立额外调用栈。这个合成例先设置同一只敌的整数变量，再调用发弹辅助 sub：

```tecl
void emit(int count, float speed) {
    etNew(0);
    etSprite(0, 6, 2);
    etAim(0, 3);
    etCount(0, count, 1);
    etAngle(0, rad(90), 0.0f);
    etSpeed(0, speed, speed);
    etOn(0);
}

void main() {
    int n = 8;
    float speed = 2.0f;
    emit(n, speed);
    wait(180);
}
```

`etNew` 初始化 0 号发射器，后续语句修改这份配置，`etOn` 才实际发射。原作 `float` 同时装速度、坐标和弧度角；`rad(90)` 是 thecl 的字面量写法，结果为 π/2 弧度。它只接受字面量，不是可对变量调用的运行时函数。

目标把不同物理量分成 `int`、`fx`、`angle`，不能隐式混用。下面是对应的完整程序：

```ecl
const OUTLINE: int = 32;
const RED: int = 2;

sub emit(count: int, speed: fx) {
    sh_reset(0);
    sh_sprite(0, OUTLINE, RED);
    sh_ring(0, 1);
    sh_aim(0, 0);
    sh_count(0, count, 1);
    sh_angle(0, 90deg, 0deg);
    sh_speed(0, speed, 0fx);
    sh_fire(0);
}

async sub enemy() {
    var n: int = 8;
    var speed: fx = 2fx;
    emit(n, speed);
    wait(180);
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

源 type6 是环玉；本例使用目标行基值32，同形色序与基础半径4对应，原作动画及碰撞公式仍有差异，详见[弹型表](bullet-types.md)。`OUTLINE`、`RED` 是本程序自己声明的常量，名称不由引擎自动注入。不要把源 type6 直接填进 `fire` 的 appearance 参数。

检查出生时应有 8 颗等速 2px/frame 的整周弹。目标 `emit` 是同步 sub，发射器属于调用它的任务；敌人的主任务 180 帧后结束，敌静默退场，已经发出的弹继续存在。

### 2.2 字面量和 cast

| 用途 | 原作文本 | 目标文本 |
|---|---|---|
| 颗数、帧数、编号 | `8` | `8`（`int`） |
| 坐标、速度 | `96.0f`、`2.0f` | `96fx`、`2fx`（16.16 定点） |
| 朝右、朝下 | `0.0f`、`rad(90)` | `0deg`、`90deg`（BAM） |
| 一整圈 | 约 `6.2831853f` | `360deg` 或 `65536 as angle`；消费时低16位回绕 |

目标 `fx` 计算采用定点，转写不能承诺逐位复现原作浮点。原作普通弧度 `a` 转目标 BAM 的数学关系是 `a × 65536 / (2π)`；先识别方向哨兵，再换单位。几百万的“角度”往往是 EX 特殊编码，不能直接乘这个系数。

目标 `as` 是显式 cast：`int as fx` 转数值，`fx as int` 向零截断；`int as angle` 保留整数位模式，**不会把度数转成 BAM**。例：`90 as angle` 仅为90 BAM，写九十度应当用 `90deg`。需要等分角度时写 `(i * 65536 / n) as angle`，不要对 `angle` 直接做乘除。

一圈在数学上等于65536 BAM单位，但 `65536bam` 超出BAM字面量的u16范围，会编译失败。角度变量可保存未回绕的int32值，与字面量的取值限制分开理解。

目标常见控制语句有 `if 条件 { ... } else { ... }`、`while 条件 { ... }`、`loop { ... }` 和 `for i in 0..n { ... }`。后者包含0、不包含n，对应原作明确执行n次的循环；原作 `times(n)` 之外还可能在循环内修改计数，须先核实际次数。条件表达式返回int的0/1，`&&`、`||` 短路求值，不能为了简化条件增加RAND读取。

普通 sub 无返回值、禁止递归；原作 thecl 的高层返回值常通过 I3/F3 约定传递，不能理解成目标支持 `return expr`。简单计算放回调用者；确有同敌共享语义时用共享槽。目标有返回值的内建必须消费结果，例如 `_ = fire(...);`；`sh_fire(...)` 等 void 内建直接调用，不能加 `_ =`。

## 3. 时间、调用栈和并行任务

### 3.1 `wait` 和时间标签有不同职责

原作反编译常见下面的片段：

```text
0:
    etOn(0);
30:
    etOn(0);
```

这些数字是**脚本时间条件**，不是普通跳转标签。单调时间、没有其他改时钟行为时，两次发射相差30帧，可以改写为 `sh_fire(0); wait(30); sh_fire(0);`。

但原作 `wait` 会改脚本时间，`goto` 除了跳 PC 还可重设时间。若文本同时有时间标签、`wait`、带时间的跳转，就先推导运行轨迹：在哪个世界帧、脚本时钟是多少、下一条是否满足时间条件。不要既按标签补30帧，又保留原有 `wait(30)`，也不要抹掉跳转造成的时钟变化。

目标 `wait(n)` 的直接规则是：在世界帧 F 执行，F+n 帧继续。`wait(0)` 不让出；参数最终按16位时长处理，不会自动把负值修成合理等待。普通 `label:` / `goto label;` 只改目标控制流，不会附带原作脚本时钟。需要保留复杂原作时间时，可在任务内维护显式时钟；有限、清楚的攻击也可先展开其事件序列，再重写循环。

带跳转重设时钟、循环退出后等待的完整转换见[转换案例](conversion-examples.md)的案例一。

### 3.2 同步调用和异步调用

原作 `helper();` 对应目标普通 sub 调用；原作 `helper() async;` 通常对应目标 `spawn helper();`，并将定义改成 `async sub helper()`。新任务在下一帧首跑，原任务继续执行。

```ecl
async sub shoot() {
    loop {
        _ = fire(32, 2, $self_x, $self_y, 2fx, aim_player(), none, none);
        wait(30);
    }
}

async sub enemy() {
    spawn shoot();
    loop {
        move_to(60, -80fx, 96fx, EASE_LINEAR);
        wait(60);
        move_to(60, 80fx, 96fx, EASE_LINEAR);
        wait(60);
    }
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

`shoot` 和 `enemy` 的 owner 都是新敌。敌移动时，发弹任务每30帧从当时的敌坐标读位置；它不会因为移动任务正在 `wait` 而停射。`main` 没有敌 owner，不能把上述移动或同敌共享变量读写直接搬进 `main`。

原作主调用栈结束会导致敌消失；目标敌主任务结束也会退场，目标为静默退场，不等于扣光HP后的死亡/掉落/计分。只让额外发弹任务结束不会结束敌。要常驻，就让敌主任务继续等待。

### 3.3 局部变量不等于原作敌变量

原作局部栈参数、同敌 I0–I3/F0–F7、跨敌全局分别是不同的存储。目标任务局部变量在 `spawn` 后各自独立，不能把原作共享 I0 随手改成两个任务里同名的 `var i`。

例如原作主任务和额外任务都要访问同一 I0，可在目标敌上选一个槽：`set_self_int(0, value)` 写，`self_int(0)` 读。目标每敌有4个 int、8个 fx 槽，初始化时写清用途；它们要求敌 owner。只需要出生快照时，直接用 `spawn helper(value)` 或 `spawn_enemy(..., behavior(value))` 按值传参。不要无意把共享改成快照，或把快照改成全局。

原作特殊变量名也要按物理含义读：`FINAL_X/Y` 是最终位置，`ABS_X/Y`、`REL_X/Y` 分属位置层；`ANGLE_PLAYER` 是读取时的自机方向；`DIFF` 是难度，`RANK` 是原作动态 rank。目标 `global(GVAR_RANK)` 是0起的难度，不是动态 rank。先消解原作难度前缀/分支，再为目标各 rank 明确选值。

### 3.4 读反编译时要识别栈和依赖

thecl 高层表达式背后是 VM 栈。反编译中的 `[-1]` / `[-1.0f]` 是栈顶引用；一条指令的多个参数可能读同一个栈顶，统一收栈由指令头控制。不能“每读到一个 `[-1]` 就 pop 一次”。遇到低层表达式先恢复它的值和求值顺序，再写目标表达式。

原作 `#include` 是编译期包含文本，`ecli` 是运行时加载其他 ECL 的依赖声明。摘录一个入口时，沿 call、async、创建子敌和 ecli 找齐依赖；单独一个漂亮的弹幕 sub 不保证能独立解释。我方 harness 可把目录里的 `.ecl` 组成一个编译单元；其中只能有一个 `main`，也不能直接使用原作 `ecli`。

目标中单任务每帧有指令预算，locals和表达式栈也有编译容量限制。大颗数同帧循环应使用发射器或合理拆解；不能靠 `wait(0)` 解决超预算，因为它仍在同帧执行。

## 4. 先有一只会动的敌人

TH18 现代场地常用 x=0 为中轴、y向下，与我方 `x∈[-192,192], y∈[0,448]` 约定相近。**不要套 TH06 的 x减192**。仍需核原作具体位置层、offset、父子依赖，不能仅凭画面看起来在中间就省略平移。

原作 `enmCreate` 的坐标相对调用者；`enmCreateA` 使用绝对坐标（本教材指定eclmap的301号助记名）。目标 `spawn_enemy(x,y,hp,drop_table,score,sprite,task)` 的出生坐标是世界坐标；无镜像等特殊flags时，相对创建要显式加父敌最终坐标；父镜像的额外变换按[敌人状态](enemy-state.md)处理。两个函数尾部的 score/item 与目标 drop_table/score/sprite 不是同一顺序，不能整串参数直抄。

敌人体碰与受击框、flags、镜像/限位、子敌初始化，以及从一段攻击中途开始时要恢复的状态，见[敌人状态与段入口](enemy-state.md)。不要按目标默认值补齐原文缺失的前置配置。

### 4.1 绝对位置上的减速移动

```tecl
void main() {
    movePos(0.0f, 96.0f);
    movePosTime(60, 4, 120.0f, 96.0f);
    wait(60);
    wait(180);
}
```

这里 mode4 表示二次减速，目标选择语义名称 `EASE_QUAD_OUT`：

```ecl
async sub enemy() {
    move_to(60, 120fx, 96fx, EASE_QUAD_OUT);
    wait(60);
    wait(180);
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

假设进入时没有残余速度，两边都从(0,96)在60帧内到(120,96)，早段快、末段慢。归一化 `u=t/60` 时，理想连续式为 `x=120×(2u−u²)`，中点为90。实际目标起动/积分帧与浮点→定点误差，用运行锚点单独核对。

`move_to` 立即返回，不自动等待；少写 `wait(60)`，后续移动会在同帧覆盖它。原作绝对/相对位置层、极坐标速度可以共存，目标发起 `move_to` 时会清掉此前速度意图、停止旧速度补间；在位置补间活跃时直接写位置，不叠加vx/vy位移。在 `move_to` 之后重新发起的速度操作仍可推进，位置补间结束后才恢复对位移的影响；要到点继续飘，速度操作必须写在 `move_to` 之后。不能把原作多位置层直接当成相同的目标叠加；先画清每层贡献、覆盖及恢复时点。

### 4.2 普通曲线与状态型插值

完整0–31见[插值表](interpolation-modes.md)。目标 `EASE_*` 内部编号与原作mode不同，用名称表达所需曲线。原作mode7、8、17分别涉及累加、Hermite、二阶累加，必须使用有状态的值槽或等价显式状态；不能硬挑一条“看起来差不多”的 ease。

例如每帧把标量增加0.25，不是从起点到终点的一条普通缓动。目标可这样保存并读取状态：

```ecl
sub main() {
    accum_start(0, 1fx, 0.25fx, 4);
    wait(4);
    var result: fx = accum_value(0);
    _ = fire(32, 2, 0fx, 96fx, result, 90deg, none, none);
    loop { wait(1); }
}
```

启动时值为1，随后4次更新为1.25、1.5、1.75、2，读值不推进；最终发出的弹速为2。这些槽是任务私有的，普通同步调用共用该任务的槽，`spawn` 后分开。Hermite切线的单位和二阶累加的更新顺序见表内配方。

## 5. 从单发到一波：配置、弹型和发射模式

### 5.1 读懂发射器的状态

原作同一只敌持有多份 `et` 配置。`etNew(id)` 初始化，`etSprite/Angle/Speed/Count/Aim/Offset` 修改，`etOn(id)` 读取配置生成子弹。同敌的额外调用栈也能改同一份配置，所以必须沿时间跟踪最后写入者。

目标每任务有4个 `sh_*` 发射器槽。同步 sub 可复用调用者槽；`spawn` 的新任务有自己的槽。原作主任务配置0、异步任务仅 `etOn(0)` 的结构不能机械改成主任务 `sh_*`、异步任务 `sh_fire(0)`；可以让一条目标任务独自拥有配置和发射，或把明确快照作为参数传给发弹任务，在其中初始化。

主任务在异步射击期间改配置的完整重组见[转换案例](conversion-examples.md)的案例二；要保留每次读取的是新状态还是旧快照。

源弹型/色号应先查[弹型表](bullet-types.md)。目标 `fire(base,color,...)` 的 base 是我方形轴起点，颜色单独为0–15；源端有些弹型不是16色，不能统一认为 color值天然相同。对已核共享图集行可直接保留色号，其余查表；半径不相同须记录，默认不视为用户已接受近似。

### 5.2 双端点速度转层步长

假设原作要8路、3层、不瞄准的整周环：

```tecl
void main() {
    etNew(0);
    etSprite(0, 6, 2);
    etAim(0, 3);
    etCount(0, 8, 3);
    etAngle(0, 0.0f, 0.0f);
    etSpeed(0, 1.0f, 2.0f);
    etOn(0);
    wait(180);
}
```

常规模式下，源 `etSpeed(s1,s2)` 定义首末速度。层数 M>1 时，层 j 的速度为 `s1+j×(s2−s1)/(M−1)`；M=1时只取s1。这里是1、1.5、2，总共24颗。目标 `sh_speed(id,start,step)` 第二个速度是**每层增量**，因此写0.5：

```ecl
async sub enemy() {
    sh_reset(0);
    sh_sprite(0, 32, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 8, 3);
    sh_angle(0, 0deg, 0deg);
    sh_speed(0, 1fx, 0.5fx);
    sh_fire(0);
    wait(180);
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

这个配置应产生角度0、45、90、135、180、225、270、315度，各有3种速度。目标整周环自动分摊BAM余数；路数不能整除65536时，也不应先截断步长再累加出一个缺口。

### 5.3 扇形、自机狙和层旋转

源 mode0/1 是自机狙/固定方向扇形；mode2/3是自机狙/固定方向整周环；mode4/5将环偏半个路间隔。完整公式与mode6–12见[发射模式表](aim-modes.md)。

在目标，`sh_aim(id,1)` 开启发射时自机狙，`sh_ring(id,0/1)` 选择扇形/整周。`sh_angle` 在扇形时使用中心角和**相邻路间隔**，与源扇形ang2对应，N路总张角为 `(N−1)×ang2`。整周模式中，源ang2与目标 `sh_angle` 第二个角参数都表示**相邻速度层的旋转量**，可直接保留；同一波的每层因此可以有不同基角。

自机狙还涉及基点：原作从带发射偏移的实际位置瞄准，目标 `aim_player()` 从当前 owner 位置算。目标 `sh_aim` 也从配置后的出弹口算。手工 `fire` 且出生点带offset时，应从出生坐标调用 `atan2($player_y-y,$player_x-x)`；不要沿用未偏移的owner角。整波只取一次自机角时，先存变量再进层/路循环，不要在每颗弹处重读目标。

原作通常层在外、路在内，目标 `sh_fire` 角度在外、速度在内；固定弹阵的几何可一致，但创建顺序不同。逐弹随机、EX派生或容量截断依赖顺序时，用显式双循环 `fire` 按原序生成。随机mode也先查它抽角还是抽速、端点还是幅度，以及每波/每层/每弹的抽样次数；不能给所有“随机”都套同一公式。

## 6. 发出之后：EX 转 xform

### 6.1 先恢复一段原作 EX 程序

原作 `etExSet(id,index,async,type,a,b,r,s)` 指定槽，`etEx` 追加；带2的长式另有c/d/m/n。TH18每份配置24条记录，发射时复制给每颗弹。已发弹不会因为敌后来改发射器而自动换程序。

`id` 是发射器号，`index` 是程序槽，`async` 是效果并行/等待约定，`type` 是原始效果位值；这四者不能混成“EX编号”。社区效果目录的顺序号也不是原始type。短式只写一部分字段，未清c/d/m/n；覆盖同槽时须保留未写字段。

例如：

```tecl
void main() {
    etNew(0);
    etSprite(0, 6, 2);
    etAim(0, 1);
    etCount(0, 1, 1);
    etAngle(0, rad(90), 0.0f);
    etSpeed(0, 2.0f, 2.0f);
    etExSet(0, 0, 0, -2147483648, 30, 0, 0.0f, 0.0f);
    etExSet(0, 1, 0, 262144, 0, 0, rad(90), 1.0f);
    etOn(0);
    wait(180);
}
```

第一条是 WAIT 原始 `0x80000000` 的signed写法，第二条VEL为 `0x40000`，按参数指定方向和速率。它表达“先等，再改变速度”；原作WAIT进入/退出的同tick续跑规则须按[EX详细条目](ex-effects.md)核，不能只看参数30就断言目标绝对帧一致。

### 6.2 `@N` 是执行之后等 N 帧

目标 xform 是每颗弹自己的变换序列，不额外占一条弹任务。先写一个独立的目标示例，检查它的自身时序：

```ecl
xformdef SLOW_AFTER {
    @30 add_speed(0fx);
    set_speed(1fx);
}

sub main() {
    _ = fire(32, 2, 0fx, 96fx, 2fx, 90deg, SLOW_AFTER, none);
    loop { wait(1); }
}
```

第一条先把速度加0，再等待30帧，才执行第二条。若写 `@30 set_speed(1fx)`，减速会立即发生，等待只约束下一条。设第一条实际执行帧为E，则第二条在E+30；目标本例E=2，第31帧速度仍为2，第32帧变为1；完整检查见第9章。原作出生/首次EX更新与目标首执行相位要各自对齐，不能无条件宣称上面的原作WAIT例与它逐帧完全相同。

STEP同样不自动等待结束。例如启动60帧改速后要再转向，片段应为：

```text
@60 step_speed(3fx, 60 + 65536 * EASE_QUAD_OUT);
turn(90deg);
```

第二参数把时长和曲线编码在一起；使用名称。启动帧保存起值，后续帧推进，到终帧写精确目标。每条STEP占2个物理槽；等待前缀与时长分别表达“何时继续程序”和“补间多久”。

### 6.3 配置、出生、效果进入，三个取样时点

现在引擎已支持按值参数和表达式，不需要因为原作参数是动态的就量化成许多静态模板。

```ecl
xformdef LATE_AIM(extra: fx, offset: angle) {
    @30 add_speed(0fx);
    set_speed(at_spawn($self_speed + extra));
    set_angle(at_effect(aim_player() + offset));
}

async sub enemy() {
    sh_reset(0);
    sh_sprite(0, 32, 2);
    sh_ring(0, 1);
    sh_count(0, 8, 1);
    sh_speed(0, 2fx, 0fx);
    sh_xform(0, LATE_AIM(0.5fx, 10deg));
    sh_fire(0);
    wait(180);
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

`extra/offset` 在 `sh_xform` 绑定时保存。`at_spawn` 每弹出生时记住初速加0.5，稍后设速为2.5；`at_effect` 到该操作时才从当前弹位置瞄准自机。模板不能偷读调用者局部变量，需要把它作为形参传入。标记要包整个参数，不能写成 `at_effect(aim_player()) + offset`。

三阶段都可用 `rand(n)`，ENGINE_VER30沿用同一World随机流：

```text
set_angle(rand(65536) as angle);              // 绑定时一次，同配置共享
set_angle(at_spawn(rand(65536) as angle));    // 每弹出生一次
set_angle(at_effect(rand(65536) as angle));   // 每次进入该操作一次
```

这三个表达式每次调用都消耗随机流，不能交换位置或擅自合并。原作先把RAND读到变量再复用，应在相同位置抽一次并传值；原作方向哨兵在效果开始时逐弹抽样，则使用效果阶段表达式。STEP运行中、WAIT_SIGNAL等待中不会每帧重抽；再次进入操作才会重新求值。不同引擎的RNG算法不自动相同，保留分布、调用时点和共享范围与证明原作seed逐位对拍是不同任务。

### 6.4 选操作要看作用机制

常用的定速、改角、角速度、标量加速、固定方向矢量加速、补间、反弹、延寿等，先查[EX目标配方](ex-effects.md)。特别注意：

- ANGLE_ACCEL的s是角速度，不是角加速度；ACCEL的固定方向矢量与沿当前弹向的标量加速不同。
- VELTIME在进入时选定方向；HOMING每tick重新追踪并混合速度向量，不能改成一次自机狙。
- 源SETSPRITE会重读新弹型默认半径，而目标xform `set_sprite` 只换图、保留出生半径；新旧弹型半径不同会额外失配，不能仅替换appearance。
- 原作 async不是“多开一个目标spawn”就全部等价；须保留效果持续状态、游标是否停驻、同tick后续记录能否执行。
- SHOOT/LASER读配对记录；分裂、曲线、碰撞门、缩放、消弹免疫等若无等价写口，记录具体缺口，不能删掉后称完成。

目标脚本里的 `set_speed(handle,speed)` 等子弹setter有当前owner限制，首参不是任意目标弹的选择器。敌任务不能靠保存 `fire` 的返回值远程改那颗弹；用xform，确需复杂分支时才挂子弹 `async sub`。动态xform有8个逻辑缓存值、总16物理槽等容量限制；不要为绕容量默默删效果。

## 7. 激光：先认形态，再算几何和生命周期

TH18把飞行直线、无限直线、曲线激光分开，建线还会读取发射器和EX配置。不能把所有激光都看成“很长的一颗弹”。本节教目标的直线实体；[激光参考](lasers.md)列原作指令与逐项支持边界。

### 7.1 一条预警后扫动的线

目标 `laser(color,x,y,angle,len,width,warn,active,fade)` 返回激光句柄。几何是从原点沿angle方向的区间 `[near,far]`；初始near=0、far=len。`width` 是全宽，半宽为width/2。原作width字段、宽度动画、碰撞截宽需分别换算，**不能套TH06统一除二规则**。

```ecl
async sub enemy() {
    var beam: int = laser(2, $self_x, $self_y, 90deg,
                          320fx, 12fx, 30, 60, 10);
    wait(30);
    lz_omega(beam, 64bam);
    wait(80);
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

它先预警30帧（无碰撞），生效60帧，再消退10帧（无碰撞）。等待预警后才设置每帧64 BAM的角速度，因此预警线固定，随后扫动。本例在全局第32帧末仍为预警，第33帧生效；设置角速度与碰撞切换的边界不能只按等待字面量猜测。若建线后立刻调用 `lz_omega`，预警阶段也转；不要把“预警”理解成暂停所有运动。状态切换的实际帧锚点同样要检查。

一次自机狙可在建线时给角度；原点偏离owner时，建线后用 `lz_aim(beam,offset)` 从激光原点瞄。持续追踪则要明确每帧/每几帧重算，不可把一次瞄准当成追踪。

### 7.2 飞出去的有限线段

```ecl
async sub enemy() {
    var beam: int = laser(6, $self_x, $self_y, 90deg,
                          0fx, 6fx, 0, 180, 0);
    lz_speed(beam, 4fx, 80fx);
    wait(190);
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

`lz_speed(beam,4fx,80fx)` 每帧推进far，near保持 `max(旧near,far−80,0)`：先从原点长出，达到80长后整段向前。`lz_start` 可改近端，`lz_origin` 改原点并解除锚定，`lz_anchor` 把原点绑到指定敌及offset。选择哪一个取决于原作是在增长、平移射线原点，还是让近远端沿射线前进。

TH18直线/无限激光各有碰撞截头尾和宽度阶段，曲线又有节点与局部切线；上面的完整目标例只展示可用写口。转具体原作时，按参考推导碰撞段并核时间，不能把原生length/width原值填进去就算完成。源配置到判定矩形的完整换算见[转换案例](conversion-examples.md)的案例三。

**曲线激光暂时不做。** 2026-11-05用户明确划定本轮范围：实际执行到 `711 laserCuOn` 或依赖曲线激光几何的攻击，按[统一口径](transcription-policy.md)报告 `status: blocked` 并暂缓该攻击；不删掉曲线，也不用多根短直线替代。其余独立攻击照常转写。

## 8. 组合成一个可验证的攻击

把前面知识连起来：敌在固定位置，每30帧发一个环；弹在延迟后减速并朝下。下面是教学目标程序，带训练所需的段结束信号，**不是某张原作卡的正式转写**。

```ecl
xformdef FALL_AFTER(delay_speed: fx) {
    @30 add_speed(0fx);
    set_speed(delay_speed);
    set_angle(90deg);
}

async sub pattern() {
    var n: int = 8;
    if global(GVAR_RANK) >= 2 { n = 12; }
    sh_reset(0);
    sh_sprite(0, 32, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    sh_speed(0, 2fx, 0fx);
    sh_xform(0, FALL_AFTER(1fx));
    loop {
        sh_fire(0);
        wait(30);
    }
}

async sub boss() {
    set_invuln(65535);
    wait(120);
    phase_begin(0, pattern, 600, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0fx, 96fx, 10000, 0, 0, 0, boss);
    loop { wait(1); }
}
```

`main` 创建boss；boss等120帧开场缓冲，再由 `phase_begin` 开600帧非符段；新pattern下一帧首跑。Easy/Normal为8路，Hard/Lunatic为12路。每30帧发一波，每颗初速2，第一效果后30帧改为速1、朝下。段结束会结束绑定pattern及其任务后代；已发弹的owner不同，不能假定pattern结束就自动终止它们所有行为。

开场缓冲、无敌、段事件是躲弹训练外壳。正式转写的 `report.md` 必须注明源攻击起点怎样平移到目标首发帧；不得将缓冲算进原作攻击周期。`phase_begin` 是非符段；真正符卡可按任务要求使用 `spell_begin` 并保留原作时限/结束条件。改变HP以维持无敌练习的做法也应写在外壳差异里。

开段前要沿同一只敌的上游调用/中断链恢复位置、变量、移动、发射器、活动任务及判定配置；具体步骤见[段入口重建](enemy-state.md)。训练外壳、数值实现差异、物理近似和暂缓项分别按[统一转写口径](transcription-policy.md)记录，不能把TH06已接受的差异直接搬来。

元数据的基本形状如下，仅为填写说明，值须按真实任务来源替换：

```toml
title = "TH18教材合成例"
source = "th18"
origin = ""
source_ref = "自写教材合成例；无原作摘录"
ranks = [0, 3]
marks = [0]
time_limit = 600
original_time_limit = 600
tags = ["ring"]
laser_approx = false
lower_half_blocked = false
```

这里不把教学例收进卡池。TH18 单卡已接入 `stgtranscribe.validate`，目录使用 `th18_s…`，source 如实写 `th18`；编号、时限和完整命令见[单元编号与验收](validation.md)。`stgtranscribe.pipeline`、摘录器与切分检查仍限定 TH06，批量接入另行推进。

## 9. 如何证明写对了

### 9.1 先从源程序写预期，再看转储

语法检查、正常运行、原作行为一致是三件事。对一个真实任务，先在 `report.md` 写源位置与目标位置对应，并独立推导：

1. 第一波何时发生，路数×层数是多少，后续周期是多少。
2. 出生坐标、角网格和速度层，瞄准从哪里算、抽样几次。
3. 效果进入前后一帧的速度/方向，补间终点和等待是否重叠。
4. 激光预警结束、碰撞段、宽度和近远端，段结束何时发出。

然后选少量锚点：例如第5章应在第一波刚出生时看见24颗、8个方向、每方向1/1.5/2三速；第6章SLOW_AFTER应在改变前仍为2，改变后为1；激光例应在预警内无碰撞态，在转换后生效。不要先看转储，再把它抄成“原作预期”。

`--at` 的角度/BAM、速度和实体状态用于核数学结果；相邻帧的积分相位仍需考虑。玩家按固定种子运行时的位置也要记录，因为自机狙/追踪会受其影响。同seed重复运行只能证明我方确定性，不代表已复现原作RNG。

### 9.2 常见错误如何定位

| 现象 | 先查什么 |
|---|---|
| 编译类型不匹配 | 坐标/速度是否写fx，角是否写deg/bam，有返回值内建是否消费 |
| 同帧只剩最后一个移动 | 非阻塞move后是否缺wait，是否覆盖前段移动或弄反位置/速度操作顺序 |
| 发出的层速特别大 | 把源末速当成sh_speed步长；M=1是否仍做了除零换算 |
| 异步任务发了默认弹 | 源同敌发射器共享被改成目标每任务槽，未在发弹任务初始化 |
| 说好等30帧却立即减速 | `@30` 写在减速操作上，误当成前置等待 |
| 整波转向完全一样 | 应逐弹取样，却把rand/瞄准放在绑定时或共享局部值中 |
| 目标编译通过但敌瞬间消失 | 敌主任务自然结束，spawn后未保留主任务 |
| 激光有画面但路径/碰撞不同 | near/far、原点、全宽/半宽、状态门和原作截头尾混淆 |
| run出现fault或峰值异常 | 超预算、owner错误、实体/段/任务池压力；先看诊断再改发射行为 |

遇到未知参数或无对应写口，说明具体影响和证据缺口；不要默认取中值、漏掉记录或改判定以凑出可运行程序。未用到的未知机制不阻止本攻击继续转写。

### 9.3 本教材的验证与来源边界

本轮完整原作合成例使用指定thecl18+eclmap编译，完整目标例使用当前release harness检查；关键波形、效果和激光另有运行锚点，实际命令和结果见[验证记录](../../docs/investigations/2026-11-05-th18-textbook-verification.md)。代码片段不宣称可独立编译。

原作运行语义优先取自TH18自身已导入命名/类型的Ghidra资料。复核方法与结论见[TH16/TH18 EX比较](../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md)、[弹型来源](../../docs/investigations/2026-11-05-th16-th18-bullet-types.json)。教学组织借鉴[TH06 mapping](../th06/mapping.md)，具体编号、色序、坐标和激光规则逐项按本作核。

学习thecl文本可继续读 [Priw8教程](https://priw8.github.io/#b=ecl-tutorial/&p=1)、[指令表](https://priw8.github.io/#b=modding/&p=ins&table=18)、[EX说明](https://priw8.github.io/#s=modding/transforms)。教程主要以TH17举例，EX旧文的18条容量不能套TH18的24条；TH18继承页面描述也不能替代本作执行证据。助记符来自 [Priw8/eclmap TH18文件](https://github.com/Priw8/eclmap/blob/f146162e330c27d1b0a8880c3a41884615147a11/eclmap/th18.eclm)，文本语法/编译格式参考 [thtk/thecl](https://github.com/thpatch/thtk/tree/917a3d3858850f01276b7fb5b9327e2c24d27d5b/thecl)。

[ExpHP th-re-data](https://github.com/exphp-share/th-re-data)提供逆向命名与结构入口；[thpages](https://exphp.github.io/thpages/)主要讲ANM，[truth](https://github.com/ExpHP/truth)的所查版本不能直接替代本教材的thecl ECL工具。所有读取版本、URL和hash见[资料清单](../../docs/investigations/2026-11-05-th18-textbook-sources.json)与[准备记录](../../docs/investigations/2026-11-05-th18-textbook-preparation.md)。这些来源各司其职，不把ANM语法或其他工具方言混入ECL。

目标更完整的作者手册在邻仓 stg-engine `docs/ecl-lang.md`，xform见 `docs/xform-ops.md`，状态型插值见 `docs/stateful-interpolation-reference.md`。转写worker除本教材与所需表外，还应拿到任务单给出的当前内建签名和工具路径。本文只验证合成例与已核映射，不声称完成原作动态对拍、全卡验收、训练接入或未知机制逆向。
