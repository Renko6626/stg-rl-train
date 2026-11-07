# TH16 敌人移动与 moveRand 配方

普通移动签名见[指令表](instructions.md#移动)，ABS/REL与镜像见[敌人状态](enemy-state.md#3-绝对相对镜像与限位如何组合)，圆周／椭圆见[运动方程](circular-motion.md)，插值见[模式表](interpolation-modes.md)。下文保留已验证的moveRand样本，不将其当作所有入口的通用实现。

## moveRand的已核样本

范围：TH18 v1.00a，BossCard1的moveRand(60,4,1.0)，普通dt=1、REL恒零、无镜像；不是所有moveRand入口的通用实现。

本样本可以用现有目标ECL表达。关键是：**速度从1线性降到0，不能按参数4选二次降速。** 限位每帧夹位置，不做反弹。下列源结论有TH18指令证据；目标配方经过自写小例及完整单卡检查，BossCard2复用范围见文末；尚未做原作动态对拍。

## 原生参数与方向选择

412的参数依次是持续帧数、角插值mode、起始速度，作用于ABS角/速槽。每次调用使用当时FINAL位置和玩家x，得到一个固定方向α。

设`R = π×U`，U为有符号单位随机量；R是弧度角。横向分支如下，条件为严格小于/大于：

| 当时位置 | α | 随机读取 |
|---|---|---|
| x < −25 | R/3，即±60° | 一次signed float |
| x > 25 | wrap(R/3+π) | 一次signed float |
| −25 ≤ x ≤ 25 | 先R/4，即±45°；按下述条件加π | signed float后再一次WORD |

中央分支另抽`w∈[0,65535]`，保留`w%3`。玩家x>敌x时仅余数0加π；玩家x≤敌x时仅余数非0加π。因此有约2/3概率朝玩家所在横向一侧，等x归左侧偏向。WORD取模有极小偏差，目标不要直接换成理想的三等分概率。源signed float由rand_dword生成，底层消耗两个WORD；中央另多一个WORD。目标World RNG算法与源不同，不承诺原作seed序列。

随后按y处理：y<112取`α=abs(α)`；y>144取`α=−abs(α)`；112≤y≤144不动。**中央加π后没有先wrap**，必须保留这个顺序；例如α=200°时顶部的abs仍为200°，不能提前转成−160°再取abs。左右外侧分支只有右侧显式wrap。

最后，若`abs(α+π/2)<0.05`，按原来位于−π/2的哪一侧推至`−π/2±0.05`；否则若`abs(α−π/2)<0.05`，同理推至`π/2±0.05`。恰等中心时选加0.05一侧。没有额外随机。按上述方向区间，本卡实际不会接近±90°，因此该护栏保留在配方中但本样本不可达。

## 速度与更新

本样本速度插值继承mode0（线性），moveRand的mode参数不覆盖速度槽。每次调用固定方向α，随后k=1..60的运动更新为：

```text
speed(k) = 1 − k/60
Δ(k) = speed(k) × (cos α, sin α)
```

第60次到0并停止；配置当帧仍从旧位置发弹。此结论限本页给出的入口，不要求作者重查构造/寄存器；其他入口若缺速度mode信息，交准备者补齐。

## 限位与执行顺序

`moveLimit(0,128,100,64)`的后两参是完整宽高：实际x∈[−50,50]、y∈[96,160]；方向选择使用的内区却是中心±宽高的1/4，即x±25、y112..144，不要混为同一组边界。

每个运动tick先推进角/速插值，将极坐标速度积分到ABS/REL，再组合FINAL并夹界，将ABS写回`FINAL−REL`。不改速度、方向或插值进度；被挡住的位移不积在墙外，也不反射。本卡REL恒零：

```text
P(k) = clamp(P(k−1) + Δ(k), (−50,96), (50,160))
```

源顺序为移动/限位→ECL→体碰。配置moveRand的那一次发射仍从旧位置P(0)出弹，后续源t+1读P(1)，源t+5读P(5)。本卡t0先清速度/旧插值，60帧移至(0,128)，t90才开始moveRand；独立训练以(0,128)初始化时，初次回中为零位移。

## 目标表达

使用同一个敌owner任务，保留逻辑方向与步计数，不新增引擎接口。随机部分按上表计算未wrap的整数BAM，再执行fabs/竖直方向修正，最后才cast为angle。0.05rad约521.52BAM，最近整数边界为±π/2±522BAM；这属于目标正常角度量化。每次调用只采样一次方向，不能每帧重抽。

下面是本卡使用的完整随机方向与60帧移动helper，与已运行小例一致。敌共享int槽0保存步计数、fx槽0/1保存cos/sin，本卡未使用这些源槽；接卡时声明所有权。目标阶段5在ECL之后积分，所以helper预先安排下一次源运动tick的**实际限位位移**：

```ecl
// TH18 v1.00a BossCard1 only. int slot0=next-step count; fx0/1=logical unit vector.
// All source wait(n) inside this attack must use card_wait(n), in the same owner task.
// No new task: emit uses the current position, phase5 then performs the next source movement tick.
sub card_arm_next_step() {
    var k: int = self_int(0)+1;
    set_self_int(0, k);
    var speed: fx = 0fx;
    if k < 60 { speed = (60-k) as fx / 60; }
    var nx: fx = $self_x+self_fx(0)*speed;
    var ny: fx = $self_y+self_fx(1)*speed;
    if nx < -50fx { nx = -50fx; }
    if nx > 50fx { nx = 50fx; }
    if ny < 96fx { ny = 96fx; }
    if ny > 160fx { ny = 160fx; }
    move_vel_xy(0, nx-$self_x, ny-$self_y, EASE_LINEAR);
}
sub card_begin_angle(a: angle) {
    set_self_fx(0, cos(a));
    set_self_fx(1, sin(a));
    set_self_int(0, 0);
    card_arm_next_step();
}
sub card_move_rand() {
    // Source 405b90 = signed unit random * pi. Values below are unwrapped BAM ints.
    var r: int = rand(65536)-32768;
    var a: int = r/3;
    if $self_x < -25fx {
        a = r/3;
    } else if $self_x > 25fx {
        a = r/3+32768;
        if a > 32768 { a = a-65536; } // source explicitly normalizes this branch
    } else {
        a = r/4;
        var choose: int = rand(65536)%3; // source WORD modulo3, including its tiny bias
        if $player_x > $self_x {
            if choose == 0 { a = a+32768; }
        } else {
            if choose != 0 { a = a+32768; }
        }
        // Deliberately do not normalize this branch before the source fabs tests.
    }
    if $self_y < 112fx {
        if a < 0 { a = -a; }
    } else if $self_y > 144fx {
        if a < 0 { a = -a; }
        a = -a;
    }
    // Native +/-pi/2 guard, epsilon0.05rad. Nearest BAM boundaries (normal angle quantization).
    if a > -16906 && a < -15862 {
        if a < -16384 { a = -16906; } else { a = -15862; }
    } else if a > 15862 && a < 16906 {
        if a < 16384 { a = 15862; } else { a = 16906; }
    }
    card_begin_angle(a as angle);
}
sub card_wait(frames: int) {
    for i in 0..frames {
        wait(1);
        card_arm_next_step();
    }
}
```

调用顺序：在原moveRand点取方向并`card_begin_angle(a)`，随后立即执行原首发；把该攻击内部`wait(5)`及循环尾`wait(60)`换为`card_wait`。不用另起异步移动任务，也不在发弹之前直接把敌位置挪至下一点。这样发射时读取的位置序列为P(0),P(5)…；阶段5把下一点写好，供下一次ECL读取。整步结束的dump已经显示下一运动tick，不能与“源同次ECL之前/之后”混比较。

限位时目标实际vx/vy为夹界后的位移，源极坐标槽则继续保留原始意图；这里用保存的cos/sin及逻辑speed重算，防止下一tick从被夹成0的实际速度倒推方向。它保持本卡的轨迹/发弹位置，不宣称目标`$self_speed`等于源被墙阻挡时的逻辑速率。当前攻击不读回这些源速度字段，也不依赖它们发弹；若新样本读取，需另核。

源为f32、目标为Q16.16/BAM/CORDIC，存在通常数值舍入及不同RNG序列；没有取方向中值、改变周期或仅夹最终终点。**目标为ECL→阶段5移动→后续碰撞**，原生为移动→ECL→体碰：此配方保持wait后发弹读取的位置，但目标帧末敌位置及体碰可能已采样下一移动点，不能据小例宣称它们与源同帧完全一致。这是现有引擎执行相位的差异，不是随机运动公式仍未解；本轮不为此扩大对拍或增加引擎机制。

## 已复用：Stage01 BossCard2

第二符卡使用`moveRand(60,4,0.7)`、`moveLimit(0,128,240,64)`。同一原生算法按当前limit字段取界：方向内区x±60、y112..144，实际位置限位x±120、y96..160。沿Boss公共入口、Boss1、BossCard1与Boss2核对，没有正时长速度插值改写速度mode，因此本卡同样继承mode0；每步速度为`0.7*(1-k/60)`，60步未限位总位移20.65px。

本样本在卡内复用局部helper，仅调整这些参数。主环发完才开始移动；Normal第三组后创建的大玉任务下一帧首跑时，Boss已移动一步，不能把大玉出弹点固定在前一帧位置。Hard/Lunatic此时还在发后续主组，移动尚未开始。源/目标帧末碰撞相位差异仍按上文记录，不引入新的通用移动层。

## 其他移动入口的转换边界

原作签名统一查[指令表](instructions.md)；以下保留组合目标程序时的限制，按本卡实际涉及的指令查阅。

- 400 `movePos`；401 `movePosTime`：单层静止前置可用move_to；源400不保证硬停；源401的frames≤0只清位置插值，不是瞬移，不能改成目标move_to(0)。[位置移动](mapping.md#41-绝对位置上的减速移动)、[移动层](enemy-state.md#3-绝对相对镜像与限位如何组合)
- 404 `moveVel`；405 `moveVelTime`；406 `moveVelRel`；407 `moveVelRelTime`：已核单层可转换；`move_vel`是极坐标插值，不能以move_vel_xy代替全部情况
- 440 `moveAngle`；441 `moveAngleTime`；442 `moveAngleRel`；443 `moveAngleRelTime`；444 `moveSpeed`；445 `moveSpeedTime`；446 `moveSpeedRel`；447 `moveSpeedRelTime`：单层用move_angle/move_speed；最短弧、残余速率、镜像与层归属分别核
- 424 `moveSetMirror`；558 `flagMirror`；428 `moveVelNM`；429 `moveVelNMTime`；430 `moveVelNMRel`；431 `moveVelNMRelTime`：424写镜像位已核；558具体入口不据名字外推。NM不能机械套同一水平反射；创建镜像顺序另见状态表
- 418 `moveAdd`；419 `move419`；427 `moveReset`；436 `moveAddTime`；437 `moveAddRelTime`：本文未给419或reset全部字段的TH16承诺；实际需要而本书缺少定义时交回
- 420 `moveEllipse`；421 `moveEllipseTime`；422 `moveEllipseRel`；423 `moveEllipseRelTime`；425 `moveBezier`；426 `moveBezierRel`：420/422当前样本的方程、轴角快照与ABS/REL合成已核，见[配方](circular-motion.md)；421/423配置的轴角/比例槽不被普通tick消费，不能凭名补全；425/426的Hermite参数已核，见[插值专题](interpolation-modes.md#mode8hermite端点与切线)，完整调用组合仍按本卡处理。普通运动曲线不等于711曲线激光
- 432 `moveEnm`；433 `moveEnmRel`；434 `moveCurve`；435 `moveCurveRel`；438 `moveCurveAdd`；439 `moveCurveAddRel`：查给定源参数和插值表；没有整组通用目标内建，也未全部逆向。移动曲线不等于711曲线激光
