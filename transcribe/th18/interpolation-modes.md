# TH18 插值编号到目标写法

> **版本**：TH18 v1.00a；2026-11-05整理。裸地址均属本作。
> **证据**：已核的原生归一化函数 `0x402fb0`、分派 `0x4035d8`，以及标量 `0x41f640`、运动 `0x439a00` 消费者；复用引擎既有核查，未重新逆向。

## 普通曲线与三个状态型模式

原作mode参数是语义选择，不是目标EASE编号。比如源mode4是二次减速，必须输出
`EASE_QUAD_OUT`；目标内部数字4对应的曲线不同。源mode7/8/17由消费者特殊处理，
必须用状态接口，不能送进 `move_to(...,7)` 或猜一个相近曲线。

普通曲线使用 `value=start+(end-start)*f(t)`，`t` 是已完成时间比例。
`IN`加速起步，`OUT`减速结束；`IN_OUT`先加速再减速，`OUT_IN`相反。
下表的组合定义为：

```text
IN_OUT(n,t) = 0.5*(2t)^n                    t<0.5
              1-0.5*(2-2t)^n               t>=0.5
OUT_IN(n,t) = 0.5*(1-(1-2t)^n)              t<0.5
              0.5+0.5*(2t-1)^n             t>=0.5
BACK(a,t)   = (t*t-2*a*t)/(1-2*a)
```

BACK的P25/P30等表示反向极值出现在总时长的25%/30%等时刻；不是源mode，也不是超调幅度。
OUT镜像极值在1-a。BACK允许越出端点区间，不能自行把结果钳在起终点之间。

## 0–31完整转换表

| 源 mode | 功能 | 我方语义名称／处理方式 |
|---:|---|---|
| 0 | 匀速，`t` | `EASE_LINEAR` |
| 1 | 二次加速，`t²` | `EASE_QUAD_IN` |
| 2 | 三次加速，`t³` | `EASE_CUBIC_IN` |
| 3 | 四次加速，`t⁴` | `EASE_QUART_IN` |
| 4 | 二次减速，`1−(1−t)²` | `EASE_QUAD_OUT` |
| 5 | 三次减速，`1−(1−t)³` | `EASE_CUBIC_OUT` |
| 6 | 四次减速，`1−(1−t)⁴` | `EASE_QUART_OUT` |
| 7 | 每帧 `value += rate` | `accum_start` / `accum_value` |
| 8 | 三次Hermite插值，使用两个端点和两个切线参数 | `hermite_start` / `hermite_value` |
| 9 | 二次先加速后减速，`IN_OUT(2,t)` | `EASE_QUAD_IN_OUT` |
| 10 | 三次先加速后减速，`IN_OUT(3,t)` | `EASE_CUBIC_IN_OUT` |
| 11 | 四次先加速后减速，`IN_OUT(4,t)` | `EASE_QUART_IN_OUT` |
| 12 | 二次先减速后加速，`OUT_IN(2,t)` | `EASE_QUAD_OUT_IN` |
| 13 | 三次先减速后加速，`OUT_IN(3,t)` | `EASE_CUBIC_OUT_IN` |
| 14 | 四次先减速后加速，`OUT_IN(4,t)` | `EASE_QUART_OUT_IN` |
| 15 | 归一化函数返回0，保持起点，到时写终点 | `EASE_HOLD` |
| 16 | 归一化函数返回1，首次推进即取终点 | `EASE_STEP_START` |
| 17 | 每帧先 `value += velocity`，再 `velocity += acceleration` | `accel_start` / `accel_value` |
| 18 | `sin(πt/2)`，正弦减速 | `EASE_SINE_OUT` |
| 19 | `1−cos(πt/2)`，正弦加速 | `EASE_SINE_IN` |
| 20 | 正弦先减速后加速 | `EASE_SINE_OUT_IN` |
| 21 | 正弦先加速后减速 | `EASE_SINE_IN_OUT` |
| 22 | `BACK(0.25,t)` | `EASE_BACK_IN_P25` |
| 23 | `BACK(0.30,t)` | `EASE_BACK_IN_P30` |
| 24 | `BACK(0.35,t)` | `EASE_BACK_IN_P35` |
| 25 | `BACK(0.38,t)` | `EASE_BACK_IN_P38` |
| 26 | `BACK(0.40,t)` | `EASE_BACK_IN_P40` |
| 27 | `1−BACK(0.25,1−t)` | `EASE_BACK_OUT_P25` |
| 28 | `1−BACK(0.30,1−t)` | `EASE_BACK_OUT_P30` |
| 29 | `1−BACK(0.35,1−t)` | `EASE_BACK_OUT_P35` |
| 30 | `1−BACK(0.38,1−t)` | `EASE_BACK_OUT_P38` |
| 31 | `1−BACK(0.40,1−t)` | `EASE_BACK_OUT_P40` |


18/19和20/21的OUT/IN顺序尤其容易反写。表覆盖引擎能力，不表示32种均已找到素材使用或实机验证。
曲线数学形状可以对应；原生f32与目标Q16.16/查表有量化差异。

## 普通移动：只转换语义名

原作 `movePosTime(frames,4,target_x,target_y)` 选择二次减速；目标完整例子如下。
60帧把敌人从(0,96)移到(120,160)，中途约半程时已完成约75%的距离；终点为精确目标。
这是自写的运动演示，不含原作攻击或体碰行为的等价承诺。

```ecl
async sub move_demo() {
    move_to(60, 120fx, 160fx, EASE_QUAD_OUT);
    wait(60);
    wait(30);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 1000, 1, 0, 0, move_demo);
    wait(91);
}
```

`EASE_HOLD`在插值期间保持起点，到时由消费者写终点；`EASE_STEP_START`在第一次推进时
到终点，不是配置调用那一行立即跳。敌人运动与弹STEP的启动相位不同：后者出生当帧初始化，
下一帧才推进。重新发运动指令会覆盖对应运动状态，不应机械地每帧重启整段。

## mode7：每次加一个增量

源标量插值中goal字段改作delta，每次有效更新 `value+=delta`。初值10、delta2，三次更新
得到12、14、16；到时保留累计值，不把delta当终点。目标写为 `accum_start(slot,initial,delta,frames)`，
在原作变量被读取的位置显式 `accum_value(slot)`。完整例子：

```ecl
sub main() {
    accum_start(0, 10fx, 2fx, 3);
    var current: fx = accum_value(0); // 10
    wait(1);
    current = accum_value(0); // 12
    wait(2);
    current = accum_value(0); // 16，此后保持
}
```

应用在角度上是固定角增量，应用在速度上是固定速度增量，不因mode7本身就称作“匀速移动”。
源 `moveVelTime` mode7还涉及角度缺省哨兵和镜像分支；先恢复具体角增量/速增量，再选目标运动写法。
目标槽返回fx；若值表示BAM角，写接口前用 `(value as int) as angle`，不要把度和BAM混用。

## mode17：先加旧速度，再更新速度

源字段goal是加速度a，extra2是初速v0。有效更新顺序：

```text
value += velocity
velocity += acceleration
```

目标 `accel_start(slot,initial,velocity,acceleration,frames)`；初值0、v0=2、a=1时结果为2、5、9。
第k次结果数学上是 `initial+k*v0+k*(k-1)*a/2`，不是先改速度后加得到的3、7、12。

```ecl
sub main() {
    accel_start(0, 0fx, 2fx, 1fx, 3);
    wait(1);
    var current: fx = accel_value(0); // 2
    wait(1);
    current = accel_value(0); // 5
    wait(1);
    current = accel_value(0); // 9
}
```

源91号变量插值把extra清零，因此用它启动mode17时初速是0；92号额外参数版才可传入v0。
变量插值的目标变量自动回写属于原作上下文语义；目标值槽不会自动改原局部或全局变量，
须在同一读写位置取值并赋值。只启动槽而不读出，画面不会因此运动。

## mode8：Hermite端点与切线

mode8是三次Hermite，四参数为 `p0,p1,m0,m1`：

```text
value = (2t^3-3t^2+1)*p0 + (-2t^3+3t^2)*p1
      + (t^3-2t^2+t)*m0 + (t^3-t^2)*m1
```

切线m0/m1针对归一化时间t。若给的是物理速度v0/v1，持续T帧，则切线为T*v0/T*v1。
原作425 `moveBezier` 和426相对版虽然名字含Bezier，原生setter直接保存切线，
不把两个额外向量当控制点。若要与Bezier点换算，B1=p0+m0/3，B2=p1-m1/3。

以下完整例子从0到10、两端切线0、4帧，中点是5；到期固定为10。

```ecl
sub main() {
    hermite_start(0, 0fx, 10fx, 0fx, 0fx, 4);
    wait(2);
    var current: fx = hermite_value(0); // 5
    wait(2);
    current = hermite_value(0); // 10
}
```

向量运动可把x/y分量分别放两个Hermite槽，再按帧显式取值写回位置；相对运动必须先处理其基点，
不能把绝对位置与相对位移混在同一p0/p1中。目标没有自动绑定运动向量的Hermite写口。

## 槽位、时间和替换的边界

三类槽各自有 `INTERP_SLOTS_PER_KIND` 个（当前每任务每类4个），不同种类的同号槽不冲突。
同步sub共享当前任务槽，spawn任务的槽独立清零；退出后不再推进。启动语句求参一次并覆盖同类同号槽，
读取不会推进；下一有效任务帧开始先推进再执行脚本，wait期间仍推进，场景冻结则停止。

累加/加速恰好推进N次；0帧保持initial，Hermite0帧立即取end。合法帧数0..65535。
状态型原生计时器的初始化、旧槽先推进再替换、终帧读取相位须按调用场景核，不能仅复制frames
就保证逐帧相同。普通曲线、状态型操作及弹STEP也不能互换启动时机。

源91/92有8个上下文变量槽；目标每种4个任务槽。只按实际同时活跃项重编号，超出或涉及跨任务
共享时保留具体缺口，不擅自扩池或构造新的调度机制。目标状态值不会自动回写变量，这是使用方式差异。

## 来源和验证范围

- 引擎 `docs/easing-reference.md` 保存原作mode与目标具名曲线的三方表；`crates/stg-core/src/math/easing.rs` 与 `consts.rs` 是当前目标注册依据。
- 引擎 `docs/stateful-interpolation-reference.md` 保存原生状态布局、91/92、405、425/426注入与目标槽的运行时约定。其历史ENGINE_VER不是当前训练依赖版本声明。
- 本页目标完整例子已用release harness的check检查。编译证明语法和接口可用，未运行原作对拍；原生浮点舍入、替换/终帧相位按具体攻击另核。

### 本页例子的实际检查

2026-11-05：将本页每个 `ecl` 围栏单独抽为完整文件后，分别执行
`stg-harness check <file>` 和 `stg-harness run <file> --frames 8 --at 3`，均退出0，
`task_faults/contract_viol/pool_full` 均为0。各文件不能合在同一目录一次check，因为各自定义main。
材料和逐例日志保存在忽略目录 `transcribe/work/th18-textbook-20261105/tables/`；只验证前8帧目标运行，
未做原作实机或完整攻击验收。
