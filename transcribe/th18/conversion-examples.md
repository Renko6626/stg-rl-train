# TH18 完整转换小案例

> **版本**：TH18 v1.00a；目标ENGINE_VER30，2026-11-05核查。

本页接在[入门教材](mapping.md)之后，练习把一份完整原作侧程序转成完整目标程序。三个例子均为自写教学合成程序：依据 TH18 v1.00a 已核机制选择参数，没有摘录游戏 ECL，也不对应某个 stage/sub。原作侧通过 thecl 编译及反编译；目标侧通过当前 release harness 检查与运行。**没有运行原作，没有原作逐帧对拍，也没有验收成训练卡。**

原作 `main` 表示执行这段程序的控制敌入口；目标 `main` 是 STAGE，所以目标另创建位于 `(0,96)` 的敌。比较时以敌程序首次执行为局部时间 `t=0`，不把两个运行环境的启动帧当作同一帧。目标实测敌程序首次执行在全局帧 `B=3`，因而以下目标发射帧为 `B+t`。原作实际关卡的出生/首跑帧仍须另行对齐。

所有围栏均可独立编译，不要把三个 `main` 合并到同一编译单元。源 type6 环玉映射目标行32、色号单独保留；基础判定和原作动画等差异仍见[弹型表](bullet-types.md)。本页侧重事件、取样与矩形，不宣称完整视觉和碰撞等价。

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

这不是 TH06 `jump_dec` 的移植。TH18 的依据是既有原生导出 `EclRunContext__ecl_run 0x48b3a0`：opcode12 写当前脚本时间并跳 PC（Listing `0x48b700`），13/14 条件满足时走相同路径；23 的 wait 则减当前脚本时间（`0x48b727`），下一条指令的时间门决定何时继续。现有[导入原型](../../tools/th18-import-prototype/README.md#时间和栈的转换)用 `clock=$frame-base` 表达这套规则，goto 对应 `base=$frame-newTime`，wait 对应 `base+=n`。不要套 TH06 变量拷贝或自动计数规则。

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
async sub enemy() {
    sh_reset(0); sh_sprite(0, 32, 2); sh_aim(0, 0);
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

### 独立期望和实际核对

先按上表给出目标出生帧：13、23、33、48。向下速度1，出生当帧就积分一次，所以帧48的前三发应位于 y=132、122、112；第4发应在 `(-1,96)`，角180°。

| `--at` | 期望 | 实际 |
|---|---|---|
| 12 | 0弹，尚未到第一轮时间10 | 0弹 |
| 13 | 第1发，`(0,97)`，90° | 1弹，坐标及角相符 |
| 23 | 第2发出生 | 2弹，y=107、97 |
| 33 | 第3发出生并退出循环 | 3弹，y=117、107、97 |
| 47 | 仍只有3弹 | 3弹 |
| 48 | 第4发向左 | 4弹，`(0,132),(0,122),(0,112),(-1,96)`；BAM=16384/32768 |

80帧运行峰值4弹，`task_faults/contract_viol/pool_full` 均为0。这里只实测目标调度和弹位；源时钟根据 TH18 原生分支及编译结果静态推导。

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

首跑相位并非仅凭目标习惯假定：原生 `Enemy__ecl_run 0x48d420` 在运行当前栈前缓存 next；`0x48d850` 把新 async 插在主节点之后。主任务本帧新增的 async 不在已缓存的遍历链上，所以本例 `shoot` 下一 tick 首跑。在已有 async 或后续 async 再生任务等复杂结构中，仍须按链顺序核查，不能推广成所有创建都相同。

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
async sub enemy() {
    var color: int = 2;
    var speed: fx = 1fx;
    sh_reset(0); sh_sprite(0, 32, color); sh_aim(0, 0);
    sh_ring(0, 0); sh_count(0, 1, 1);
    sh_angle(0, 90deg, 0deg); sh_speed(0, speed, 0fx);
    wait(1);
    sh_fire(0);
    color = color + 1;
    wait(1);
    speed = 9fx;
    wait(3);
    color = color + 3; speed = 3fx;
    sh_sprite(0, 32, color); sh_speed(0, speed, 0fx);
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

### 独立期望和实际核对

目标预期在 B+1=4、B+11=14 发弹。帧14的第1发已经积分11次，应在 `(0,107)`，速1、sprite=`32+2=34`；第2发刚出生，应在 `(0,99)`，速3、sprite=`32+6=38`。

| `--at` | 期望 | 实际 |
|---|---|---|
| 3 | 配置完成、尚未发射 | 0弹 |
| 4 | 色2/速1首发 | 1弹，`(0,97)`、speed1、sprite34 |
| 5 | F0=9对应的变量改写不影响第1发 | 1弹，`(0,98)`、speed1 |
| 8 | 配置已改色6/速3，旧弹仍色2/速1 | 1弹，`(0,101)`、speed1、sprite34 |
| 13 | 第二次发射尚未发生 | 1弹 |
| 14 | 第2发色6/速3，旧弹不被重配 | 2弹，`(0,107)` speed1/sprite34；`(0,99)` speed3/sprite38 |

80帧运行峰值2弹，诊断三项均为0。源共享、插链及首跑机制经过既有原生导出静态核查；目标时间线经过实际运行，未做原作实机对拍。

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

### 由原生 switch 推导时序，不能直接抄三段参数

依据 `LaserInfinite__initialize 0x44c870`、`LaserInfinite__on_tick 0x44cae0`、管理循环 `0x448760`：出生状态3，timer=0；每tick先执行状态分支，再由管理循环递增timer。按固定dt=1、无冻结，且以出生后第一次激光tick为 age=0：

| 激光 age | 原生分支及tick后的状态 | 是否判定 |
|---|---|---|
| 0..5 | state3 startup；到期前保持 | 否 |
| 6 | timer=6，state3切state4，timer清0后break；707已保证当前宽16 | 是 |
| 7 | state4的expand=0，切state2、timer清0，当前宽写目标16 | 是 |
| 8..14 | state2；age14检查前timer=7 | 是 |
| 15 | state2检查前timer=8，切state5，timer清0 | 否 |
| 16..18 | state5收缩 | 否 |
| 19 | state5检查前timer=4，返回结束 | 删除 |

所以本子集危险窗长9帧（age6..14），不是701中hold参数8帧。目标填 `warn=6,active=9,fade=4`；先前“expand=0就把hold直接填active”的简写，不能替代这次原生分支分析。目标仅重建危险矩形和无判定退出期，不重建原作警告线宽度、收缩视觉曲线或贴图。

上述原生边界是对既有导出的静态推导；原作游戏回调中相对敌程序的首次激光tick尚未实机校准。因此可以独立核目标 age窗，但尚不能把源程序t与原作实际画面帧作无条件等号。若具体攻击要求原作绝对帧验收，首次tick对齐仍是交付前必须核的项。

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

### 独立期望和实际核对

目标出生帧 B=3，对照上表应有：3..8预警，9..17生效，18..21退出，22回收。目标 `state=0/1/2` 分别表示这三段，不沿用源状态号3/4/2/5。

| `--at` | 期望 | 实际 |
|---|---|---|
| 3 | 出生预警，timer1 | state0/timer1 |
| 8 | 最后一帧预警 | state0/timer6 |
| 9 | 首帧危险窗 | state1/timer1 |
| 10 | 持续危险；源此时已从state4入state2 | state1/timer2 |
| 17 | 最后一帧危险窗 | state1/timer9 |
| 18 | 首帧无判定退出 | state2/timer1 |
| 21 | 最后一帧退出 | state2/timer4 |
| 22 | 已回收 | 0激光 |

以上所有存活锚点均实测 origin=(0,96)、angleBAM=16384、start/end=0/270、width=8、speed/omega=0，warn/act/fade=6/9/4。80帧运行峰值1激光，诊断三项均为0。这里证明目标状态及矩形符合独立推导；没有证明原作实际回调相位或原作玩家碰撞与目标逐帧一致。

曲线 `711 laserCuOn` **暂不转写，状态为 blocked**。本例不能推广到曲线历史轨迹，也不能默认拆成多根短线。700–714其他指令继续按[激光表](lasers.md)分别处理：706是长度增长速率；705不是持续累加漂移；712不是清激光；713/714含未核消费者，不能按编号猜测。

## 本页验证材料与复跑

2026-11-05实际执行的原作侧3次编译、3次反编译、目标侧3次check和20次80帧run均退出0。目标只取样，不启动浏览器、不进行交互测试。可复跑命令如下，文件名前缀替换为上述01/02/03：

```bash
THECL=/data/sunyunbo/www/renkolab/local/vendor/thtk/build/thecl/thecl
ECLMAP=/data/sunyunbo/www/renkolab/local/vendor/eclmap/eclmap/th18.eclm
HARNESS=/data/sunyunbo/www/stg-engine/target/release/stg-harness
CASE=transcribe/work/th18-supplement-20261105/cases/01-clock
"$THECL" -c 18 -m "$ECLMAP" "$CASE.tecl" "$CASE.bin.ecl"
"$THECL" -d 18 -m "$ECLMAP" "$CASE.bin.ecl" "$CASE.roundtrip.tecl"
"$HARNESS" check "$CASE.ecl"
"$HARNESS" run "$CASE.ecl" --frames 80 --seed 1 --rank 2 --at 48
```

临时证据均在忽略目录 `transcribe/work/th18-supplement-20261105/cases/`：`01-clock/02-shared/03-infinite.tecl`、各自 `.bin.ecl/.roundtrip.tecl/.ecl`、`.compile.txt/.roundtrip.txt/.check.txt` 与 `.atN.txt`。目录还保存本次从既有 `renkolab/local/th18.v1.00a/state/data/functions.jsonl` 抽取的原生函数，以地址命名；未新开Ghidra库、未自行反汇编。临时证据不作为版本化依赖；本页保留完整程序、期望、实际锚点与来源地址，可从正文重新构建。
