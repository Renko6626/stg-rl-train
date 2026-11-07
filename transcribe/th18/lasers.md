# TH18 激光：从发射器配置到目标几何

适用TH18 v1.00a；使用结论限本页注明的子集。

读原作激光时，先分清三个实体：`702 laserOn` 创建飞行直线 LaserLine，`703 laserStOn` 创建带编号的 LaserInfinite，`711 laserCuOn` 创建带历史轨迹的 LaserCurve。目标 `laser()` 只提供一条射线上的直线段。它能组合出静止射线、扫射与飞棒，不能表示弯曲轨迹。

**当前范围：曲线激光暂时不做。** 2026-11-05用户明确要求：实际依赖Curve的攻击写 `status: blocked`、注明源位置并暂缓；不删除曲线或用多根短线替代。Line/Infinite仍按本页已核子集转写，详见[统一口径](transcription-policy.md)。

## 700–714：本作名称、参数与落点

700–714的原作顺序参数、类型和直接作用统一查[指令表](instructions.md#激光)。下表只列目标转换路径，具体成立条件见后文。

| 原作入口 | 目标路径与限制 |
|---|---|
| 700 laserNew | `laser` + `lz_start/lz_speed`，先换算实际判定段 |
| 701 laserTiming | 静态宽度子集转三段时长；扩宽期另见下文 |
| 702 laserOn | 飞棒/增长线组合；无通用 EX 复制入口 |
| 703 laserStOn | 保存 `laser()` 返回句柄 |
| 704 laserOffset | `lz_origin`；若依附敌人则明确使用 `lz_anchor` |
| 705 laserTrajectory | 按本作每 tick 原点公式组合；不能直接当持续匀速平移 |
| 706 laserStLength | 有限增长路径可评估 `lz_speed`，注意它会重设 end |
| 707 laserStWidth | 目标无当前宽度写口，不能直接还原动态改宽 |
| 708 laserStAngle | 用当前 `lz_angle` 算差后 `lz_rotate` |
| 709 laserStRotation | `lz_omega`，弧度/帧转 BAM/帧 |
| 710 laserStEnd | `lz_cancel`；原作同编号多条须保存全部句柄 |
| 711 laserCuOn | 暂不转写；命中曲线依赖则blocked |
| 712 etCancelRect | 不能当作“清所有激光”；目标清弹形状另核 |
| 713 unknown713 | kind=3 后续实体消费者未核，不能宣称可用 beam |
| 714 unknown714 | 未核该调用具体行为；无确定目标映射 |

700 的 `lengthLimit` 是按 Line tick 的 `travel+length` 裁剪用途命名。其默认值、负值和特殊 flags 的完整组合没有逐项动态验证；不要把它当成固定“近端留空”。Curve 的长度参数来自 701 而非 700 的前两个长度。

705 尤其容易误读：Infinite每帧先从保存基点恢复当前原点（特定 flags 下改用 boss0 位置），然后加一次附加向量乘 dt，再加沿当前角的距离偏移。仅凭社区“每帧移动”的描述，把 `(x,y)` 连续累加到世界原点，会产生本作没有的漂移。这里已核公式顺序，但这些 flags 的完整用途及所有来源指令仍未全解。

## 把画面长度换成判定段

目标激光由 `(origin,angle,start,end,width)` 决定。`start/end` 都是沿射线离原点的距离，长度是 `end-start`；width 是完整判定宽，半高为 width/2。原作的显示长度和宽度不能直接代入。

本作已核的直线判定路径：

| 原作实体与条件 | 原作判定段 | 目标静态段填法 |
|---|---|---|
| Line，flags的0x2位未设 | 原点沿角前移 L/10，判定长度 0.8L | 原点保留，`start=0.1L,end=0.9L` |
| Line，该位非零 | 从原点开始，长度 L | `start=0,end=L` |
| Infinite | 从当前原点开始，长度 0.9L | `start=0,end=0.9L` |

Line还要求L>16且w>3；Infinite要求L>16且处于原作状态2或4。目标没有这些数值门，短小激光需按本卡参数安排生效时点，不能无条件设active。

原作宽度 w 对应下列半高 h，目标应填 `width=2h`：

| 条件 | Line 半高 h | Infinite 半高 h |
|---|---|---|
| w < 32 | w/4 | w/4 |
| w ≥ 32 | `(w-(w+16)/2)/2 = (w-16)/4` | `(w-(w+16)/3)/2 = (w-8)/3` |

因此 w=16 时目标 width=8；w=40 时 Line width=12，Infinite width≈21.3333。不能统一沿用 TH06“宽度除二”。宽度处于 phase 扩张中时，应对当帧宽度使用相应分支；尤其跨 32 的路径不能只缩放一个最终数值。

## 四段 Infinite 与目标三段时间

原作 Infinite 初始化为状态 3：startup 预警；到时切 4：expand 扩宽；再切 2：hold 全宽；最后状态 5：shrink 收缩。**状态 4 已参与碰撞，状态 5 不参与。** 因此不能把 startup+expand 全部塞入目标 warn，否则会少掉扩张期间的危险区。

目标 `laser(color,x,y,angle,len,width,warn,active,fade)` 创建静止线，初始 start=0、end=len、speed=0。目标状态 0=预警、1=生效、2=收缩；仅 1 判定。预警没有原作 Infinite 的四段宽度插值；fade 表示无判定的退出期。目标没有 `lz_width`。即便expand=0也要经过状态4；初始化当前宽为2，切换状态的下一tick才进入全宽路径，可能产生薄一帧的判定。因此不能把startup/hold/shrink参数不经推导就照抄为warn/active/fade。按给定ECL确定当前宽设置点，使用已核状态时序组合目标三段；本书未覆盖的组合交主会话补规则；[转换案例](conversion-examples.md)给出用707显式设当前宽的静态子集及完整帧边界。expand>0 使用恒宽 active 是几何近似，必须写明提前扩满了多少帧，不能称精确复现。

Line 没有这套预警四态。它先增长到目标长度，再平移，并可按 `lengthLimit` 裁短直至结束。目标 `lz_speed(h,speed,rodLength)` 的规则是每帧 end+=speed，start=max(start,end-rodLength,0)，能表达从零长出再飞走的棒子；它**调用时把 end 重设为 start**。原作有非零初长、不同首尾增长速率、动态裁边、EX 改速时，应逐段检查，不能把 700 的两个长度都当 rodLength。

## 完整目标例子

下面三个程序分别教目标的常用组合。它们是可编译的目标几何例子，不是三份原作攻击的等价验收；数值已按目标单位给出，不能反推 TH18 700 的原始配置。

### 预警后生效扫射

长度 400、完整判定宽 8；30 帧预警后生效 60 帧，最后 12 帧退出。只在预警结束时设置角速度，避免预警线先扫走。`lz_omega` 每帧在目标相位 5 生效，三态都会转；负值表示反向。

```ecl
async sub sweep() {
    var h: int = laser(4, $self_x, $self_y, 90deg, 400fx, 8fx, 30, 60, 12);
    wait(30);
    lz_omega(h, 1deg);
    wait(90);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 300, 1, 1000, 1, sweep);
    loop { wait(1); }
}
```

### 从偏移原点自机狙

原点在 owner 右方 48px；先创建再 `lz_aim`，基点才是该激光原点。`aim_player()` 从 owner 算，直接填它会瞄偏。这个例子只出生时瞄一次；持续跟踪要每帧重算，不能与自机狙混称。

```ecl
async sub aimed() {
    var h: int = laser(6, $self_x + 48fx, $self_y, 0deg, 360fx, 8fx, 24, 90, 12);
    lz_aim(h, 10deg);
    wait(140);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 300, 1, 1000, 1, aimed);
    loop { wait(1); }
}
```

### 从零长出、再飞走的棒子

每帧远端前进 4px，达到 192px 后近端也前进，保持棒长 192。出生即 active，长度为 0 时只有空段；目标没有原作 `L>16` 门。若保真样本要求前几帧无判定，应按实际首次危险帧设置 warn，并说明近端裁剪和宽度规则。

```ecl
async sub spear() {
    var h: int = laser(2, $self_x, $self_y, 90deg, 0fx, 6fx, 0, 240, 0);
    lz_speed(h, 4fx, 192fx);
    wait(240);
}
sub main() {
    _ = spawn_enemy(0fx, 96fx, 300, 1, 1000, 1, spear);
    loop { wait(1); }
}
```

## 控制、取消与从父弹派生

- `lz_start(h,s)` 设近端；s>end 会把 end 抬到 s。`lz_origin(h,x,y)` 设世界原点并解除挂靠。敌人移动时要跟随，用 `lz_anchor(h,$self_enemy,ox,oy)`；原作 boss0 特定 flags 不自动等同 owner 挂靠。
- `lz_rotate(h,a)` 是加角，708 是设置绝对角；用 `lz_rotate(h,target-lz_angle(h))` 才对应一次改角。709 则是持续角速度，不是单次旋转。
- `lz_cancel` 切退出期，不保证立即删除；fade=0 的回收仍由目标相位推进处理。原作 710 同编号可能遍历多条，单句柄写法仅覆盖单条。
- 清普通弹、清激光与敌人死亡取消是不同调用。712 已核是普通弹矩形取消；不要因为位于 700 组就补上全场激光清除。
- 原作 EX_LASER 消费相邻参数记录、复制父弹 EX 并可能删除父弹；目标在弹任务创建 `laser()` 后仍须重建子激光后续控制，不能把 `fire` 的 xform 原样附上去。Line/Infinite/Curve 各有自己的 `run_ex`，不能把普通弹全部 30 种效果都判为激光支持。
- 曲线激光缺的是实体几何及历史采样，不只是名字。当前用户已明确暂不做；拆成短线会改变接头、判定、擦弹和容量，不作为本轮替代方案。

## 验证与证据

目标脚本在相位 2 发出写口；激光在相位 5 更新挂靠、角度、近远端与状态，再由相位 6 碰撞。`run --at F` 查看推进完对应帧的表；读取 `lz_x/y/angle/near/far` 时则得到脚本调用当刻的状态。不要把脚本看到的上一帧末态与 dump 的本帧末态混在一起。
