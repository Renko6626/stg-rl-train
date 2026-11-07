# TH16 发射模式：从 etAim 到目标几何

适用TH16 v1.00a。
公式区分静态几何与创建顺序，按本卡实际依赖选择。

`etAim(id, mode)` 选择整波几何，配合 `etCount(id,N,M)`、`etAngle(id,alpha,delta)`、
`etSpeed(id,s0,s1)`。N是路数，M是层数；下面的 `i=0..N-1`、`q=0..M-1` 都是零起索引。
原作浮点角度单位是弧度；目标 `angle` 使用度字面量或整数BAM，一周65536。

## 参数模型与实际生成序

普通模式的层速度为 `v(q)=s0+(s1-s0)*q/(M-1)`；M=1时只用s0。
源 `etSpeed(0,3f,2f)` 是首末端点，我方 `sh_speed(0,3fx,-0.5fx)` 则是首速与步长，
这里假设最终M=3。若先改speed、后改count，必须在 `etOn` 对应开火处按最终M换算。
M或N不为正时包装循环不发弹，不要自动改成1。

包装只在整波开始求一次自机角A，基点是源发射描述符保存的出弹口；与自机完全同点时A=π/2。
原生循环为**层q在外、路i在内**。扇形还按中轴两侧交替创建。我方 `sh_fire` 是路外层、层内层，
扇形从一侧扫到另一侧，因此“画出同一个点集”与“保留创建序”分开处理。
随机、EX、弹任务或满池截断依赖顺序时，使用下文的逐颗配方。以下配方以单自机、同帧完成整波、
资源足够为适用域；原生出生保护、EX和弹型判定按各自表处理。

## 0–12编号转换表

定义 `R(i)=2π*i/N`，`H(K,k)=floor((k+1)/2)*delta`（K奇数），
K偶数时为 `(floor(k/2)+1/2)*delta`；`F(K,k)=(-1)^k*H(K,k)`。
例如N=5的F为 `0,-delta,+delta,-2delta,+2delta`；N=4为 `+delta/2,-delta/2,+3delta/2,-3delta/2`。

| mode | 意义 | 每弹角度 | 每弹速度 | 目标配方 |
|---:|---|---|---|---|
| 0 | 自机狙扇形 | `A+alpha+F(N,i)` | `v(q)` | `sh_aim=1`的fan；保序用逐颗扇形 |
| 1 | 固定方向扇形 | `alpha+F(N,i)` | `v(q)` | `sh_aim=0`的fan；保序用逐颗扇形 |
| 2 | 自机狙环 | `A+alpha+R(i)+q*delta` | `v(q)` | ring+aim；保序用逐颗环 |
| 3 | 固定方向环 | `alpha+R(i)+q*delta` | `v(q)` | ring，无aim |
| 4 | 自机狙、半路错开环 | `A+alpha+π/N+R(i)+q*delta` | `v(q)` | mode2的base加半个路间距 |
| 5 | 固定、半路错开环 | `alpha+π/N+R(i)+q*delta` | `v(q)` | mode3的base加半个路间距 |
| 6 | 随机角 | `alpha+U_signed*delta` | `v(q)` | 逐弹抽角；不自动加A |
| 7 | 环角、随机速 | `alpha+R(i)+q*delta` | `s0+U*s1` | 逐弹抽速，s1为幅度 |
| 8 | 随机角与速 | `alpha+U_signed*delta` | `s0+U*s1` | 每弹先角随机、后速随机 |
| 9 | 自机狙交替层环 | `A+alpha+(-1)^q*(R(i)+H(M,q))` | 下式成对层速 | 显式逐颗 |
| 10 | 固定交替层环 | `alpha+(-1)^q*(R(i)+H(M,q))` | 下式成对层速 | 显式逐颗 |
| 11 | 环角，方向调速 | `alpha+R(i)` | 调制因子未解 | 角可写；暂不提供完整速度转换 |
| 12 | 半路错开环，方向调速 | `alpha+R(i)+π/N` | 调制因子未解 | 同上 |

mode9/10速度的索引是 `k=(q+(M%2)) & ~1`，M>1时
`speed=s0+(s1-s0)*k/(M-1)`；M=1仍为s0。M=4时速度索引为0,0,2,2；M=5时为0,2,2,4,4。
正负号作用于整个 `R(i)+H(M,q)`，不可只对层偏角取反。mode9在取反后再加A。

## 用 sh_* 表达同一静态点集

以下完整程序对应mode2：12路、3层，速度3、2.5、2，每层角偏5°，以出弹口瞄自机。
如只需要这一静态几何且生成序无消费者，配置后反复 `sh_fire` 即可。下例TH16_RING_BALL复用已核相同的环玉槽，见[弹型表](bullet-types.md)。

```ecl
const TH16_RING_BALL: int = 448;
async sub ring_demo() {
    sh_reset(0);
    sh_sprite(0, TH16_RING_BALL, 2);
    sh_ring(0, 1);
    sh_aim(0, 1);
    sh_count(0, 12, 3);
    sh_speed(0, 3fx, -0.5fx);
    sh_angle(0, 0deg, 5deg);
    sh_fire(0);
    wait(120);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 1000, 1, 0, 0, ring_demo);
    wait(121);
}
```

改成mode3：`sh_aim(0,0)`；改成mode4：base加 `(32768/N) as angle`，保留aim；
mode5再关闭aim。mode0/1用 `sh_ring(0,0)`，angle第二参恢复为路间距；base仍是中轴，
无需先减去半个扇形。此段说明的是目标代码修改，不能作为原作完整程序传给thecl。

## 保留源创建序：逐颗扇形和环

下面完整程序选择mode0..5，由 `mode` 变量决定。它先缓存出弹口和A，之后层外路内；
N=3、M=3，共9弹。mode0/1的路序为中、负1、正1；
环形每颗用 `(i*65536)/N` 求方向，避免先截断一个步长再重复累加。
本例将所有角度换成BAM后计算，允许通常的浮点/定点量化差异。

```ecl
const TH16_RING_BALL: int = 448;
sub main() {
    var mode: int = 0;
    var n: int = 3;
    var m: int = 3;
    var x: fx = 0fx;
    var y: fx = 96fx;
    var alpha: int = 0;
    var delta: int = 1820; // 约10度
    var aim: angle = 90deg;
    if $player_x != x || $player_y != y {
        aim = atan2($player_y-y, $player_x-x);
    }
    for q in 0..m {
        var speed: fx = 3fx;
        if m > 1 { speed = 3fx + (2fx-3fx)*q/(m-1); }
        for i in 0..n {
            var a: int = alpha;
            if mode < 2 {
                var off: int = ((i+1)/2)*delta;
                if n%2 == 0 { off = (i/2)*delta+delta/2; }
                if i%2 != 0 { off = -off; }
                a = a+off;
            } else {
                a = a+(i*65536)/n+q*delta;
                if mode == 4 || mode == 5 { a = a+32768/n; }
            }
            if mode == 0 || mode == 2 || mode == 4 {
                a = a+(aim as int);
            }
            _ = fire(TH16_RING_BALL, 2, x, y, speed, a as angle, none, none);
        }
    }
    wait(120);
}
```

通用分支比专用发射器消耗更多指令：本例刻意只发9弹。同帧扩大N/M前应检查任务预算；
若触发BUDGET，不能加wait拆波而仍宣称保留原作同帧几何。可先将确定的mode分支静态化，
再检查；仍超预算的具体攻击另列缺口。

### 出生距离与ANIM退位移

这段只处理固定出弹口，没有把 etDist 的每弹沿角出生距离藏进瞄准基点：原生A先从描述符出弹口求，
之后逐弹沿实际角偏移出生位置。若源用了etDist，先算A，再对每弹加 `distance*cos(a)`、
`distance*sin(a)`；不要将每弹偏移后的位置再拿来瞄一次。若目标使用sh_dist，按引擎手册的基点/顺序组合。源同时带ANIM退位移时，参见[EX说明](ex-effects.md#配对记录与已核附加语义)：例如etDist=16、初速1.8，沿弹角的净出生距离为16−4×1.8=8.8px；瞄准仍从偏移前的描述符出弹口取一次。

## 6–8：随机值必须在逐弹循环里抽

这里 `U∈[0,1)`，`U_signed=2U-1`。模式7/8的s1是随机幅度，**不是最慢端点**：
`s0=2,s1=1` 给2到3；误用普通层速公式会变成2到1。
下面目标完整程序演示mode8，4路×2层共8弹，角度60°到120°，速度2到3；
每弹先一次角随机、再一次速度随机。mode6删去速度随机并恢复普通v(q)；
mode7删去角随机、改为表中环角，保留一次速度随机。

```ecl
const TH16_RING_BALL: int = 448;
sub main() {
    for q in 0..2 {
        for i in 0..4 {
            var ra: int = rand(65536);
            var signed_u: fx = (ra-32768) as fx / 32768;
            var offset: int = (5461fx*signed_u) as int;
            var a: angle = 90deg + (offset as angle);
            var rv: int = rand(65536);
            var u: fx = (rv-32768) as fx / 65536 + 0.5fx;
            _ = fire(TH16_RING_BALL, 2, 0fx, 96fx, 2fx+u, a, none, none);
        }
    }
    wait(120);
}
```

先减32768再 `as fx` 是为让整数转换处于Q16.16可表示范围，不能直接把0..65535整数转成fx。
这一配方保留区间、边际分布、抽样次数与角先速后的调用顺序；目标PRNG与原生共享流算法不同，
不据此宣称联合随机序列或原作seed的轨迹相同。原生源是否另有配置时RAND、EX出生/效果随机要分别看。

## 9/10的可执行层配方

mode10、N=4、M=4示例会发16弹；q=0/1同速3，q=2/3同速 `3+(1-3)*2/3`。
每层环方向整体反向，非逐颗交替。改mode9时只在最后给a加缓存的A。

```ecl
const TH16_RING_BALL: int = 448;
sub main() {
    var n: int = 4;
    var m: int = 4;
    var delta: int = 1820;
    for q in 0..m {
        var k: int = ((q+m%2)/2)*2;
        var speed: fx = 3fx;
        if m > 1 { speed = 3fx+(1fx-3fx)*k/(m-1); }
        var h: int = ((q+1)/2)*delta;
        if m%2 == 0 { h = (q/2)*delta+delta/2; }
        for i in 0..n {
            var a: int = (i*65536)/n+h;
            if q%2 != 0 { a = -a; }
            _ = fire(TH16_RING_BALL, 2, 0fx, 96fx, speed, a as angle, none, none);
        }
    }
    wait(120);
}
```

## 11/12已核到哪一步

mode11/12的环角已核，方向调速函数和s1有效域尚无可用定义；实际需要时交主会话。不能猜sin或照反编译残式填速度。0–10不受此缺口影响。

## 发射器状态与取消的转换边界

原作签名统一查[指令表](instructions.md)；以下保留组合目标程序时的限制，按本卡实际涉及的指令查阅。

- 600 `etNew`：在负责发射的目标任务里sh_reset，再显式写实际需要的字段；源16份配置、目标每任务4槽，不能直接全保留默认值
- 603 `etOffset`；626 `etOffsetRad`；627 `etDist`；628 `etOffsetAbs`：先恢复实际出生点与坐标层；603常见偏移用sh_offset，628/626/627不能都当同一个offset。自机狙从实际口算
- 614 `etCopy`：TH18研究显示复制整份et配置及两组偏移；TH16按实际调用核相应字段；不写单独EX追加游标。目标无sh_copy；有限静态字段可缓存重放，不能以sh_reset(dst)代替拷贝，更不能顺手清游标
- 613 `etClearAll`：本作handler调BulletManager与LaserManager取消，**不是清空et配置**。目标clear_bullets是field，执行相位/激光/转星规则有差别
- 615 `etCancel`；616 `etClear`：候选clear_bullets_at；半径、道具、激光部分取消和相位要对齐，本章未补全TH18取消消费者，不能直接套其他作品的转星规则
- 635 `etCancel2`；636 `etClear2`；712 `etCancelRect`：712已核只处理普通弹矩形域，不是改弹判定；635/636逐样本核过滤，目标field不能自动覆盖源保护规则
- 617 `etSpeedR3`；618 `etSpeedR5`；619 `etSpeedR2`；620 `etCountR3`；621 `etCountR5`；622 `etCountR2`；624 `etSpeedD`；625 `etCountD`：固定难度可先消解已核分支；原动态RANK不等于目标GVAR_RANK。[共享变量](mapping.md#33-局部变量不等于原作敌变量)
