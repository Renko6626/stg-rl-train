# TH16 完整转换小案例

本页保留TH18原教学合成例，供TH16复用目标ECL写法；源侧编译/原参数/TH18弹型仍只属于TH18。TH16具体type须使用[本作弹型表](bullet-types.md)和后续目标映射。

本页接在[入门教材](mapping.md)之后，练习把一份完整原作侧程序转成完整目标程序。三个例子均为自写教学合成程序：依据 TH18 v1.00a 已核机制选择参数，没有摘录游戏 ECL，也不对应某个 stage/sub。原作侧通过 thecl 编译及反编译；目标侧通过当前 release harness 检查与运行。**没有运行原作，没有原作逐帧对拍，也没有验收成训练卡。**

原作 `main` 表示执行这段程序的控制敌入口；目标 `main` 是 STAGE，所以目标另创建位于 `(0,96)` 的敌。比较时以敌程序首次执行为局部时间 `t=0`，不把两个运行环境的启动帧当作同一帧。目标实测敌程序首次执行在全局帧 `B=3`，因而以下目标发射帧为 `B+t`。原作实际关卡的出生/首跑帧仍须另行对齐。

所有围栏均可独立编译，不要把三个 `main` 合并到同一编译单元。源 type6 环玉映射TH16_RING_BALL（448）、色号单独保留；TH16已核0–43复用现有槽，见[弹型表](bullet-types.md)。本页侧重事件、取样与矩形，不宣称完整视觉和碰撞等价。

## 案例一：时钟循环

### 原作侧完整程序

```tecl
void main() {
    int n = 0;
    movePos(0.0f, 96.0f);
    etNew(0); etSprite(0, 6, 2); etAim(0, 1);
    etCount(0, 1, 1); etAngle(0, rad(90), 0.0f);
    etSpeed(0, 1.0f, 1.0f);
10:
again:
    etOn(0);
    n = n + 1;
    if (n < 3) { goto again @ 0; }
25:
    etAngle(0, rad(180), 0.0f);
    etOn(0);
    wait(30);
}
```

### 先推导事件

opcode12跳转同时写脚本时间，13/14条件满足时同样处理；23 wait减脚本时间，下一条指令的时间门决定何时继续。可用 `clock=世界帧-base` 理解：goto把base改为`世界帧-newTime`，wait使base增加n。此处按TH18规则解释，不套TH06计数规则。

本程序 `goto again @ 0` 的目的地址是 `again`，重设后的脚本时间为0；到达该地址后，时间10的 `etOn` 仍要再等10帧。thecl 的反编译已确认编译结果包含 `goto ... @ 0`，if 的未命中分支回到时间10，随后是时间25的指令。

| 敌程序局部时间 t | 指令运行时的脚本时间 | n 与事件 |
|---|---|---|
| 0 | 0 | 初始化 n=0、固定向下的单发配置 |
| 10 | 10，然后跳转设0 | 第1发，n=1 |
| 20 | 10，然后跳转设0 | 第2发，n=2 |
| 30 | 10，条件不命中 | 第3发，n=3，脚本时钟仍为10 |
| 45 | 25 | 再等 `25−10=15`，改为向左并发第4发 |
| 75 | 25 | wait(30)减时钟，等待后返回 |

不能用累计世界时间30去减静态标签25；也不能在循环后再等25帧。该有限循环可以直接降为三次 `wait(10)`，随后 `wait(15)`。遇到非固定跳转时间或不规则前驱，才保留显式 base/门控，不必为本例引入新的时钟状态。

### 目标侧完整程序

```ecl
const TH16_RING_BALL: int = 448;
async sub enemy() {
    sh_reset(0); sh_sprite(0, TH16_RING_BALL, 2); sh_aim(0, 0);
    sh_ring(0, 0); sh_count(0, 1, 1);
    sh_angle(0, 90deg, 0deg); sh_speed(0, 1fx, 0fx);
    for n in 0..3 { wait(10); sh_fire(0); }
    wait(15);
    sh_angle(0, 180deg, 0deg); sh_fire(0);
    wait(30);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```


## 案例二：共享发射器

### 原作侧完整程序

```tecl
void shoot() {
    etOn(0);
    I0 = I0 + 1;
    wait(10);
    etOn(0);
}
void main() {
    movePos(0.0f, 96.0f);
    I0 = 2; F0 = 1.0f;
    etNew(0); etSprite(0, 6, I0); etAim(0, 1);
    etCount(0, 1, 1); etAngle(0, rad(90), 0.0f);
    etSpeed(0, F0, F0);
    shoot() async;
    wait(2);
    F0 = 9.0f;
    wait(3);
    I0 = I0 + 3; F0 = 3.0f;
    etSprite(0, 6, I0); etSpeed(0, F0, F0);
    wait(30);
}
```

### 先推导共享状态、取样时点和首跑相位

TH18 `et` 配置属于敌，`I0/F0` 也属于同敌共享变量，`shoot` 不是它们的独立快照。相反，目标发射器属于任务，跨 `spawn` 直接 `sh_fire(0)` 会读到另一份槽。这个例子选择**一条目标敌任务负责全部配置与调度**，把两条源时间线合并；因此共享 `I0/F0` 可以分别收敛为这条任务的 `color/speed` 局部变量。

本例主任务新建的async下一tick首跑；一条目标敌任务可以合并这些已知时间线。复杂的再生async结构若本书未定义其源首跑顺序，交主会话补规则，不自行查任务链实现。

| t | 原作主任务 | 原作 shoot / 发射器快照 |
|---|---|---|
| 0 | I0=2，F0=1；配置色2/速1，创建 async | 新 async 尚未首跑 |
| 1 | 等待 | 读现有配置发色2/速1；共享 I0 改为3 |
| 2 | F0 改为9，但没有 etSpeed | 已有发射器仍保存速1；已发弹也不变 |
| 5 | I0 从3加3得到6，F0=3；重写色6/速3 | 同敌那份配置被更新 |
| 11 | 等待 | 第二次 etOn 读取更新后的色6/速3 |
| 35 | 主任务结束 | shoot 已结束，已发弹继续飞 |

F0 在 `etSpeed` 的调用点被读入配置；`etOn` 并不自动重读 F0。因此不能将第二发设为9，也不能在 t=0 预先复制整份配置给目标子任务并永久沿用。这里固定方向，没有随机数或自机读取；若增加它们，必须在表中的原取样位置保留读取次数，不能随合并调度提前到 t=0。

### 目标侧完整程序

```ecl
const TH16_RING_BALL: int = 448;
async sub enemy() {
    var color: int = 2;
    var speed: fx = 1fx;
    sh_reset(0); sh_sprite(0, TH16_RING_BALL, color); sh_aim(0, 0);
    sh_ring(0, 0); sh_count(0, 1, 1);
    sh_angle(0, 90deg, 0deg); sh_speed(0, speed, 0fx);
    wait(1);
    sh_fire(0);
    color = color + 1;
    wait(1);
    speed = 9fx;
    wait(3);
    color = color + 3; speed = 3fx;
    sh_sprite(0, TH16_RING_BALL, color); sh_speed(0, speed, 0fx);
    wait(6);
    sh_fire(0);
    wait(24);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```

目标在 t=0 完成初始化，`wait(1)` 保留源 async 的首跑延迟；首次发射后改共享计数，t=2改变量而不改发射器，t=5重配，t=11再发。同步 helper 可以复用该任务的发射器，但这里无需额外抽象。这个合并适用于已知有限时间线；真实攻击若有动态分支，应先列出事件依赖，再选单任务调度或在源实际时点复制参数，不能把“合并”理解成取消并发语义。


## 案例三：源激光配置换算

### 原作侧完整程序

```tecl
void main() {
    movePos(0.0f, 96.0f);
    etNew(0); etSprite(0, 0, 2); etAim(0, 1);
    etCount(0, 1, 1); etAngle(0, rad(90), 0.0f);
    etSpeed(0, 0.0f, 0.0f);
    laserNew(0, 300.0f, 300.0f, 0.0f, 16.0f);
    laserTiming(0, 6, 0, 8, 4, 0);
    laserStOn(0, 7);
    laserStWidth(7, 16.0f);
    wait(40);
}
```

这是有意选择的恒宽子集：700的初长与目标长均为300，速度为0，不用705附加位移、不跟随Boss、不旋转、不带EX。703创建编号7的 Infinite，**不是702 Line**。707在创建后立刻把当前宽设16，701的目标宽也为16。这样 startup→expand 的过渡 tick 不会留下初始化的当前宽2；后续 expand=0 进入hold时也会写回同一个宽16。这句707是本合成例的明确前提，不能替未写707的原作攻击自行补上。

### 从原生参数恢复判定矩形

| 原作配置/字段 | 已核含义 | 本例目标换算 |
|---|---|---|
| 700 `(0,300,300,0,16)` | 初长300、目标长300、Line用的长度限制0、原生宽16 | Infinite恒长 L=300；不把第三浮点当近端空白 |
| etAngle=π/2，etSpeed=0 | 朝下、长度不增长 | angle=16384 BAM，speed=0 |
| 703 `(0,7)` | Infinite并登记实例编号7 | 本例只有一条，无后续编号操作 |
| 707 `(7,16)` | 当前宽立即写16 | 使进入state4那帧也是相同全宽 |
| Infinite判定长度 | 当前 L 的90% | near=0，far=`0.9×300=270` |
| w=16<32 | 原生半高 `w/4=4` | 目标完整判定宽 `2×4=8` |

因此有判定时的独立几何期望是：原点 `(0,96)`，朝下，沿轴 `[0,270]`，横向半宽4，世界矩形 `x∈[−4,4]、y∈[96,366]`。L>16门满足；原作Infinite只在状态2/4判定，状态3/5无判定。原作玩家矩形与目标玩家圆形仍有独立差异，矩形相符不代表完整玩家碰撞相符。w≥32时须用[激光表](lasers.md)的Infinite分段公式，不能把本例 width=w/2 外推。

### 恒宽子集的时序换算

本恒宽子集出生状态为3、timer=0，每tick先处理状态再递增timer。固定dt=1、无冻结，出生后第一次激光tick为age=0；已核换算如下，可直接用于本例：

| 激光 age | 原生分支及tick后的状态 | 是否判定 |
|---|---|---|
| 0..5 | state3 startup；到期前保持 | 否 |
| 6 | timer=6，state3切state4，timer清0后break；707已保证当前宽16 | 是 |
| 7 | state4的expand=0，切state2、timer清0，当前宽写目标16 | 是 |
| 8..14 | state2；age14检查前timer=7 | 是 |
| 15 | state2检查前timer=8，切state5，timer清0 | 否 |
| 16..18 | state5收缩 | 否 |
| 19 | state5检查前timer=4，返回结束 | 删除 |

所以本子集危险窗长9帧（age6..14），不是701中hold参数8帧。目标填 `warn=6,active=9,fade=4`；本子集直接使用该换算，不需再查原生分支。目标仅重建危险矩形和无判定退出期，不重建原作警告线宽度、收缩视觉曲线或贴图。

上述原生边界是对既有导出的静态推导；原作游戏回调中相对敌程序的首次激光tick尚未实机校准。因此可以独立核目标 age窗，但尚不能把源程序t与原作实际画面帧作无条件等号。若任务另行要求原作绝对帧验收，由主会话提供首次tick对齐依据；作者不自行追查。

### 目标侧完整程序

```ecl
async sub enemy() {
    _ = laser(2, $self_x, $self_y, 90deg, 270fx, 8fx, 6, 9, 4);
    wait(40);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 500, 0, 0, 0, enemy);
    loop { wait(1); }
}
```
