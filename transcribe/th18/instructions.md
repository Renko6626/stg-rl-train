# TH18 常用指令：定位与处理路径

> **版本**：TH18 v1.00a；目标 ENGINE_VER30，2026-11-05 静态核对。

这是单攻击转写的查表入口，不是全指令逆向或支持清单。名称精确采用 TH18 `th18.eclm`；功能以[教材](mapping.md)、各专表及本作原生证据为准。`unknown*` 保留原名，名字本身不证明语义。

处理状态按**当前调用点**判定：`translate` 表示在所列条件下有转写路径，仍要验证时序/数值；`drop` 仅适用于已证明不影响攻击的语句；`需上下文` 表示要找前置状态、参数或消费者；`blocked` 表示当前目标不能保真表达所需行为，或用户明确暂不做。不存在“整组opcode都可删/都支持”的默认裁定。曲线激光暂不转写，不能默认拆短线替代。

## 1. 控制流、时间与任务

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 0 `nop` | 无副作用占位；保留其时间门 | `drop` 只删操作，不删等待 |
| 1 `delete` | 结束当前上下文；敌主上下文结束使敌静默退场 | `translate`：目标结束当前任务；额外async结束不等于敌死，不能统一换 `die()`；见教材 §3.2 |
| 10 `ret`；11 `call` | 同步返回/调用，源保存调用时钟与栈帧 | `translate`：静态非递归call图改普通sub，参数/时间先恢复；根ret为结束。目标禁递归，不能直接保留无限尾调用链 |
| 12 `jmp`；13 `jmpEq`；14 `jmpNeq` | 分支/跳转还写源脚本时间；13判零、14判非零 | `translate`：按执行轨迹写if/while/goto+wait；不能仅保留PC跳转。教材 §3.1；本作VM `0x48b3a0` |
| 15 `callAsync` | 同敌新增上下文、拷实参 | `translate`：`spawn helper(...)`，目标次帧首跑；同敌共享I/F不变成任务局部快照。教材 §3.2–3.3 |
| 16 `callAsyncId`；17 `killAsync`；21 `killAllAsync` | 同敌async带用户ID创建、查ID取消、全async取消 | `需上下文`：有限已知集合可显式保留目标任务标识；源ID不是目标池索引，`KILL_CHILDREN`只及直系，不能覆盖同敌孙任务。一般动态ID取消 `blocked`；见[状态表 §4](enemy-state.md#4-同一敌人的段入口恢复状态而非重置模板) |
| 23 `wait` | 推迟源脚本时间门 | `translate`：正常dt=1且整数等待可恢复为目标wait；与时间标签不可双算。教材 §3.1 |
| 24 `waitf`；547 `gameSpeed` | 浮点等待/游戏速度影响源时钟 | `需上下文`；确有子帧或变速要求时无一般等价目标内建，`blocked`，不能默默取整 |
| 40 `stackAlloc`；42 `pushi`；43 `seti`；44 `pushf`；45 `setf` | 原生局部/表达式栈读写 | `translate`：先恢复高层变量与求值顺序再写var/赋值；`[-1]`并非每次独立pop。教材 §2.1、§3.4 |
| 50 `addi`、51 `addf`、52 `subi`、53 `subf`、54 `muli`、55 `mulf`、56 `divi`、57 `divf`、58 `modi` | 标量算术 | `translate`：int/fx/angle按物理量拆分，整数除法与float表达式不能混写；教材 §2.2 |
| 59 `eqi`、60 `eqf`、61 `neqi`、62 `neqf`、63 `lessi`、64 `lessf`、65 `leqi`、66 `leqf`、67 `greateri`、68 `greaterf`、69 `geqi`、70 `geqf` | 比较 | `translate`：比较前保留源类型、角规范化与表达式副作用 |
| 71 `noti`；72 `notf`；73 `or`；74 `and`；78 `deci` | 逻辑操作与自减 | `需上下文`：恢复原操作数求值后再写条件；目标&&/\|\|短路可能少消耗RAND，自减要保留旧值用途 |
| 75 `xor`；76 `bit_or`；77 `bit_and` | 整数逐位操作 | `需上下文`：不能把一般掩码改成逻辑布尔；常量可在转写时算出，动态完整位运算的目标配方未在本表证明 |
| 79 `stackSin`；80 `stackCos`；81 `circlePos`；82 `validRad`；83 `negi`；84 `negf`；85 `squareSum`；86 `squareSumRoot`；87 `getAngle`；88 `stackSqrt` | 数学/插值定位组 | `需上下文`：普通三角/向量可用sin/cos/atan2/dist；弧度先转BAM。89名字不能当“线性乘法”的证据；91/92任意变量写回、93随机分布及88一般sqrt尚无本表完整TH18配方，按样本读handler，插值见[模式表](interpolation-modes.md) |
| 89 `linearFunc`；90 `pointRotate`；91 `floatTime`；92 `math92`；93 `math93` | 数学/插值定位组 | `需上下文`：普通三角/向量可用sin/cos/atan2/dist；弧度先转BAM。89名字不能当“线性乘法”的证据；91/92任意变量写回、93随机分布及88一般sqrt尚无本表完整TH18配方，按样本读handler，插值见[模式表](interpolation-modes.md) |

## 2. 敌创建、退场与查询

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 300 `enmCreate`；301 `enmCreateA`；304 `enmCreateM`；305 `enmCreateAM`；309 `enmCreateF`；310 `enmCreateAF`；311 `enmCreateMF`；312 `enmCreateAMF` | 创建变体：相对/绝对、镜像、F条件；12敌变量快照 | `translate`/`需上下文`：完整变体表、父镜像处理顺序和初始化清单见[状态表 §2](enemy-state.md#2-创建子敌名字与继承顺序)。301不是`enmCreateAbs`，A不表示async |
| 321 `enmMapleEnemy` | 特殊创建入口定位 | `需上下文`：不以名字将其当普通创建；本文未核专用消费者 |
| 340 `enmDelete` | 按源ID指定目标敌退场的定位入口 | `需上下文`：先核该样本ID与本作handler；目标无通用按任意敌句柄静默删除写口，不能用全场kill代替 |
| 525 `enmKillAll` | 敌人清场 | `需上下文`：已核525对通过过滤的敌执行setDeath回调；目标清场的豁免/模式仍不同，训练交接可按已准取舍处理。状态表 §6 |
| 555 `enmAlive`；801 `enmPos`；324 `enmPos2` | 源敌ID存活/位置查询定位 | `需上下文`：要维护来源ID到目标不透明句柄的对应，并核查找失败规则；不照抄ID整数 |
| 561 `die`；556 `setDeath` | 死亡相关入口 | `需上下文`：精确名字不保证561执行完整死亡逻辑；不得把它、1、340和目标die一概等同；556涉及回调不能按纯外观丢弃 |

## 3. 常见移动与判定

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 400 `movePos`；401 `movePosTime` | ABS位置立即写/定时移动 | `translate`：单层静止前置可用move_to；源400不保证硬停；源401的frames≤0只清位置插值，不是瞬移，不能改成目标move_to(0)。教材 §4.1、状态表 §3 |
| 402 `movePosRel`；403 `movePosRelTime` | REL位置层写入/插值 | `需上下文`：REL是独立层，不是无条件加当前世界位置；保存ABS/REL后合成 |
| 404 `moveVel`；405 `moveVelTime`；406 `moveVelRel`；407 `moveVelRelTime` | 各层速度设置/插值 | `translate`限已核单层；`move_vel`是极坐标插值，不能以move_vel_xy代替全部情况 |
| 440 `moveAngle`；441 `moveAngleTime`；442 `moveAngleRel`；443 `moveAngleRelTime`；444 `moveSpeed`；445 `moveSpeedTime`；446 `moveSpeedRel`；447 `moveSpeedRelTime` | 角/速率独立更新 | `需上下文`：单层用move_angle/move_speed；最短弧、残余速率、镜像与层归属分别核 |
| 424 `moveSetMirror`；558 `flagMirror`；428 `moveVelNM`；429 `moveVelNMTime`；430 `moveVelNMRel`；431 `moveVelNMRelTime` | 镜像与非镜像路径定位 | `需上下文`：424写镜像位已核；558具体入口不据名字外推。NM不能机械套同一水平反射；创建镜像顺序另见状态表 |
| 418 `moveAdd`；419 `move419`；427 `moveReset`；436 `moveAddTime`；437 `moveAddRelTime` | 增量/重置相关定位 | `需上下文`：本文未给419或reset全部字段的TH18承诺；按实际handler恢复写入和在飞插值 |
| 408 `moveCircle`；409 `moveCircleTime`；410 `moveCircleRel`；411 `moveCircleRelTime`；412 `moveRand`；413 `moveRandRel`；414 `moveBoss`；415 `moveBossRel` | 复杂轨迹定位组 | `需上下文`：查源参数/消费者并结合插值表；没有整组通用目标内建，也未全部逆向。移动曲线不等于711曲线激光 |
| 420 `moveEllipse`；421 `moveEllipseTime`；422 `moveEllipseRel`；423 `moveEllipseRelTime`；425 `moveBezier`；426 `moveBezierRel` | 复杂轨迹定位组 | `需上下文`：查源参数/消费者并结合插值表；没有整组通用目标内建，也未全部逆向。移动曲线不等于711曲线激光 |
| 432 `moveEnm`；433 `moveEnmRel`；434 `moveCurve`；435 `moveCurveRel`；438 `moveCurveAdd`；439 `moveCurveAddRel` | 复杂轨迹定位组 | `需上下文`：查源参数/消费者并结合插值表；没有整组通用目标内建，也未全部逆向。移动曲线不等于711曲线激光 |
| 504 `moveLimit`；505 `moveLimitReset` | 设置/取消位置约束 | `需上下文`：每帧限位与只夹目标点不同；目标无常驻约束内建，触边速度/合成相位须核。状态表 §3 |
| 500 `setHurtbox`；501 `setHitbox` | 受击框/体碰框 | `需上下文`：源宽高与目标半径不同，默认及已核普通受击半径见状态表 §1；非圆框有几何缺口 |
| 502 `flagSet`；503 `flagClear` | 敌flag按掩码置/清 | `translate`仅已核子位；不能整掩码直传。源0x2禁体碰、0x10阻止扣血、0x20多门控等见状态表 §1 |
| 515 `setInvuln`；541 `noHitboxDur`；563 `unknown563`；564 `hitboxRotate`；634 `setHitboxFunc` | 无敌、临时禁体碰及特殊几何定位 | `需上下文`：无敌与禁体碰分开；563保持未知名，不能因旧TH16调查就宣称本作完整形状切换支持；自定义碰撞/旋转框不能全删 |

## 4. 段、中断、表现与掉落

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 511 `lifeSet`；512 `setBoss`；513 `timerReset`；514 `setInterrupt`；521 `setTimeout`；800 `enmCall`；802 `broadcastInterrupt` | 段状态、计时/HP中断、跨敌切换定位 | `需上下文`：同敌换段保留对象状态；八槽中断不等于目标spell_begin。只有任务单明确裁剪段外流程且证明不影响攻击才 `drop`。状态表 §4 |
| 522 `spellEx`；523 `spellEnd`；537 `spell`；538 `spell2`；539 `spell3`；540 `stars`；542 `spellTimeout` | 符卡声明/结束/UI与耐久标记 | `需上下文`：目标用phase/spell外壳组织；名字/星数不能当攻击终止证据，也不能把段末清弹/子敌处理一起删。教材完整攻击章 |
| 518 `dialogRead`；519 `dialogWait`；520 `bossWait`；548 `diffWait` | 对话、等待及难度等待定位 | `需上下文`：独立段外壳可裁剪对话，但要保留首发延迟；不得看到wait字样就丢弃 |
| 302 `anmSelect`；303 `anmSetSprite`；306 `anmSetMain`；307 `anmPlay`；308 `anmPlayAbs`；317 `anmSwitch`；323 `deathAnm`；516 `playSound`；517 `setScreenShake` | 常见表现入口 | `drop`仅限已证明纯表现；ANM尺寸、状态读取、回调/位置或碰撞依赖须恢复，不能整300组丢弃 |
| 506 `dropClear`；507 `dropExtra`；508 `dropArea`；509 `dropItems`；510 `dropMain`；562 `dropItemsSp` | 掉落入口定位 | `需上下文`：单段无敌练习可按外壳约定裁剪；掉落可能消耗RNG、影响条件/实体，未获准就不统一drop |
| 569 `unknown569`；570 `unknown570` | 已补核章内计数权重登记/结算，原名保留 | 独立躲弹卡按非攻击统计省略；不凭unknown名称阻塞切分，见[补核证据](enemy-state.md#6-stage01试切后补核的非阻塞项) |
| 573 `unknown573`；574（未命名，thecl显示ins_574） | 限时击破奖励的掉落配置及窗口/计时 | `drop`：普通道具奖励省略；不是发弹/脚本wait，见[统一口径](transcription-policy.md#系统性省略与外壳接管) |
| 632 `funcSet`；637 `funcCall`；639 `funcSet2` | 原生特殊函数/回调入口 | `需上下文`：按实际函数号恢复行为；未核则 `blocked`。不能当普通无害call删除 |

## 5. 发射器配置、复制与取消

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 600 `etNew` | 初始化指定et配置及辅助偏移/游标状态 | `translate`：在负责发射的目标任务里sh_reset，再显式写实际需要的字段；源16份配置、目标每任务4槽，不能直接全保留默认值 |
| 601 `etOn` | 读取当前配置建弹 | `translate`：sh_fire或按原序显式fire；出生角/速度/顺序/随机范围见教材 §5与[瞄准表](aim-modes.md) |
| 602 `etSprite` | 弹型与色 | `translate`按[弹型表](bullet-types.md)，源type不是目标appearance |
| 603 `etOffset`；626 `etOffsetRad`；627 `etDist`；628 `etOffsetAbs` | 出弹位置/距离配置定位 | `需上下文`：先恢复实际出生点与坐标层；603常见偏移用sh_offset，628/626/627不能都当同一个offset。自机狙从实际口算 |
| 604 `etAngle`；605 `etSpeed`；606 `etCount`；607 `etAim` | 方向、首末速度、颗数/层数与模式 | `translate`：sh_angle、sh_speed、sh_count、sh_aim/sh_ring；源首末速度须转层步长，见教材 §5与瞄准表 |
| 608 `etSound` | 发射声音配置 | `drop`限不参与所选攻击逻辑的音效 |
| 609 `etExSet`；610 `etExSet2`；611 `etEx`；612 `etEx2` | 指定槽/追加短长EX记录 | `translate`/`blocked`逐EX判断；短式不清未写字段，24条EX与追加游标要保存，见[EX表](ex-effects.md)、教材 §6 |
| 614 `etCopy` | 复制源et描述符及辅助偏移到目标et | `需上下文`：TH18本作0x430d30 case0x7f复制0x488字节及两组偏移；不写单独EX追加游标。目标无sh_copy；有限静态字段可缓存重放，不能以sh_reset(dst)代替拷贝，更不能顺手清游标 |
| 613 `etClearAll` | 全场普通弹及激光取消 | `需上下文`：本作handler调BulletManager与LaserManager取消，**不是清空et配置**。目标clear_bullets是field，执行相位/激光/转星规则有差别 |
| 615 `etCancel`；616 `etClear` | 敌位置圆域取消，原handler传不同mode | `需上下文`：候选clear_bullets_at；半径、道具、激光部分取消和相位要对齐，本表未补全TH18取消消费者，不能直接套TH16转星规则 |
| 635 `etCancel2`；636 `etClear2`；712 `etCancelRect` | 其他圆域/矩形取消入口 | `需上下文`：712已核只处理普通弹矩形域，不是改弹判定；635/636逐样本核过滤，目标field不能自动覆盖源保护规则 |
| 617 `etSpeedR3`；618 `etSpeedR5`；619 `etSpeedR2`；620 `etCountR3`；621 `etCountR5`；622 `etCountR2`；624 `etSpeedD`；625 `etCountD` | 按rank/难度选值的配置入口 | `需上下文`：固定难度可先消解已核分支；原动态RANK不等于目标GVAR_RANK。教材 §3.3 |
| 623 `angleToPlayer`；640 `etExSub`；641 `etExSubtract` | 角度查询及EX相关定位 | `需上下文`：623从实际取样位置/时点核方向；640/641不得仅凭名当已支持EX重排 |

## 6. 直线激光与明确阻塞项

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 700 `laserNew`；701 `laserTiming` | 配置几何与时长 | `translate`限[激光表](lasers.md)列出的子集；源四段到目标三段，扩宽期已危险，不能全部算warn |
| 702 `laserOn` | 发飞行直线Line | `translate`/`需上下文`：laser+lz_speed/lz_start；近远端裁剪、width分段、EX复制与初长须分别核 |
| 703 `laserStOn` | 发带编号Infinite | `translate`限静态几何等已列子集；保存目标句柄，原编号可能对应多条 |
| 704 `laserOffset`；705 `laserTrajectory`；706 `laserStLength`；707 `laserStWidth` | 原点/附加向量/增长率/宽度写入 | `需上下文`：705不是连续漂移，706不是立即改总长；707动态宽度无目标写口，所需行为 `blocked` |
| 708 `laserStAngle`；709 `laserStRotation`；710 `laserStEnd` | 绝对角、角速度与按编号取消 | `translate`限已知实例：差角lz_rotate、lz_omega、lz_cancel；fade和同编号多实例边界见激光表 |
| 711 `laserCuOn` | 发带历史轨迹的Curve | **`blocked`：用户明确暂不转写曲线激光**。真实依赖曲线的攻击先隔离，不默认分段短线或其他形状替代 |
| 713 `unknown713`；714 `unknown714` | kind=3分配及实体虚函数控制定位 | `blocked`：消费者未核，不能因在700组就映射成已有直线激光 |

## 7. 使用与证据范围

先用opcode与精确名定位，再读对应节恢复参数/前置状态；在单卡报告中逐项写实际 `translate/drop/blocked/需上下文` 结论、已接受差异及证据。表中仅“定位”的条目不算已支持，也不要求为了补表把整套VM重做。

本轮复用 `/data/sunyunbo/www/renkolab/local/vendor/eclmap/eclmap/th18.eclm` 与本作既有 `state/data/functions.jsonl`：VM `0x48b3a0`，高位分派 `0x430d30`，创建 `0x4369e0`，敌逻辑 `0x42ed40`。详细行号/地址见[状态表证据](enemy-state.md#5-证据与本轮检查)与激光/EX专表；[2026-11-02能力调查](../../docs/investigations/2026-11-02-ecl-capability-audit/modern-vm.md)的主体版本为TH16，不能把其类别原封外推成TH18验证结果。

本文没有完整目标程序；不新增永久测试、不启动训练、不重建原作导出。临时原文与检查在已忽略的 `transcribe/work/th18-supplement-20261105/instructions-state/`。文档检查只证明名字/链接与范围说明一致，不能代替实际攻击的独立harness check、短run、数值锚点和原文审核。
