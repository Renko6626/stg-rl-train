# TH18 规则书整理：维护依据与历史检查

> 后续清理：2026-11-07用户要求优先保留现行格式的转写结果，大量旧work目录和日志已删除。本文正文保留当时事实，旧路径不保证存在；当前目录和保留结果见[工作区清理记录](2026-11-07-transcribe-work-cleanup.md)。

2026-11-07从规则书移出的调查说明与旧验证记录。供维护者追溯，不进入单卡worker默认阅读。当前使用结论见[规则书](../../transcribe/th18/README.md)。记录中的命令、旧弹型、版本与时序检查均保留其历史含义，不作为新任务指令。

## mapping.md：### 1.1 编译一个最小原作程序

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

## mapping.md：旧外壳和元数据教学

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

开段前要沿同一只敌的上游调用/中断链恢复位置、变量、移动、发射器、活动任务及判定配置；具体步骤见[段入口重建](../../transcribe/th18/enemy-state.md)。训练外壳、数值实现差异、物理近似和暂缓项分别按[统一转写口径](../../transcribe/th18/transcription-policy.md)记录，不能把TH06已接受的差异直接搬来。

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

这里不把教学例收进卡池。TH18 单卡已接入 `stgtranscribe.validate`，目录使用 `th18_s…`，source 如实写 `th18`；编号、时限和完整命令见[单元编号与验收](../../transcribe/th18/validation.md)。`stgtranscribe.pipeline`、摘录器与切分检查仍限定 TH06，批量接入另行推进。

## mapping.md：### 9.3 本教材的验证与来源边界

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

### 9.3 本教材的验证与来源边界

本轮完整原作合成例使用指定thecl18+eclmap编译，完整目标例使用当前release harness检查；关键波形、效果和激光另有运行锚点，实际命令和结果见[验证记录](2026-11-05-th18-textbook-verification.md)。代码片段不宣称可独立编译。

原作运行语义优先取自TH18自身已导入命名/类型的Ghidra资料。复核方法与结论见[TH16/TH18 EX比较](2026-11-05-th16-th18-ex-comparison.md)、[弹型来源](2026-11-05-th16-th18-bullet-types.json)。教学组织借鉴[TH06 mapping](../../transcribe/th06/mapping.md)，具体编号、色序、坐标和激光规则逐项按本作核。

学习thecl文本可继续读 [Priw8教程](https://priw8.github.io/#b=ecl-tutorial/&p=1)、[指令表](https://priw8.github.io/#b=modding/&p=ins&table=18)、[EX说明](https://priw8.github.io/#s=modding/transforms)。教程主要以TH17举例，EX旧文的18条容量不能套TH18的24条；TH18继承页面描述也不能替代本作执行证据。助记符来自 [Priw8/eclmap TH18文件](https://github.com/Priw8/eclmap/blob/f146162e330c27d1b0a8880c3a41884615147a11/eclmap/th18.eclm)，文本语法/编译格式参考 [thtk/thecl](https://github.com/thpatch/thtk/tree/917a3d3858850f01276b7fb5b9327e2c24d27d5b/thecl)。

[ExpHP th-re-data](https://github.com/exphp-share/th-re-data)提供逆向命名与结构入口；[thpages](https://exphp.github.io/thpages/)主要讲ANM，[truth](https://github.com/ExpHP/truth)的所查版本不能直接替代本教材的thecl ECL工具。所有读取版本、URL和hash见[资料清单](2026-11-05-th18-textbook-sources.json)与[准备记录](2026-11-05-th18-textbook-preparation.md)。这些来源各司其职，不把ANM语法或其他工具方言混入ECL。

目标更完整的作者手册在邻仓 stg-engine `docs/ecl-lang.md`，xform见 `docs/xform-ops.md`，状态型插值见 `docs/stateful-interpolation-reference.md`。转写worker除本教材与所需表外，还应拿到任务单给出的当前内建签名和工具路径。本文只验证合成例与已核映射，不声称完成原作动态对拍、全卡验收、训练接入或未知机制逆向。

## transcription-policy.md：原政策形成经过

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

# TH18 单攻击转写的统一口径

2026-11-05。本文将已确定写法、任务单须明确的差异和暂缓范围集中起来。用于主会话准备、作者与审核者共用；不增加新的引擎机制、批量命令或验收状态。先读[主线教材](../../transcribe/th18/mapping.md)，普通opcode按[指令索引](../../transcribe/th18/instructions.md)定位。

## 当前范围与处理方式

| 类别 | 统一做法 | 报告要求 |
|---|---|---|
| 已核且可等价表达 | 按本作语义重组目标程序，保留时点、共享范围和顺序 | 给源位置→目标位置、独立期望和实际检查 |
| 训练外壳 | 按任务单使用无敌、开场缓冲、单段结束事件 | 分开记录源攻击时轴和目标全局帧，不改原攻击内部周期 |
| 已知目标差异 | 使用已核单位/数值实现；影响另行说明 | 记录Q16.16/BAM取整、原作浮点、RNG等实际边界 |
| 物理或机制近似 | 仅采用任务单中明确接受的方案 | 列原行为、目标行为、改变的几何/时序/分布及依据 |
| 实际命中未解机制 | 保留原值和依赖，写 `status: blocked` | 指出最小缺口和受影响攻击；不把整关自动停掉 |
| 实际使用曲线激光 | **暂时不转写该攻击** | `status: blocked`，原因注明“曲线激光暂不做”及源位置 |

`blocked` 沿用现有单攻击report字段，不是在旧TH06流水线里新增TH18状态。主会话可把该攻击登记为暂缓；独立、无需该机制的其他攻击继续。某个rank/分支是否实际使用，按任务范围与可验证控制流判断，不能仅在文件中搜到一个opcode就跳过整份ECL。

## 曲线激光的明确边界

用户本轮明确要求曲线激光暂时不做。以下规则同时适用于作者、审核者与主会话：

- 所选攻击实际执行 `711 laserCuOn`、依赖曲线的历史节点/局部切线，或依赖仍存活曲线产生的危险区，就暂缓该攻击。
- 不删除曲线后提交一个缺少危险区的版本；不默认换成直线、多个短直段或普通弹。
- 不为这项任务扩展引擎曲线实体，也不为绕过限制另建近似机制。
- Line与Infinite直线仍按[激光表](../../transcribe/th18/lasers.md)及[换算案例](../../transcribe/th18/conversion-examples.md)处理。未知713不是已经支持的直线替代品。
- 若曲线只在未选rank或确实不可达分支出现，可以给出控制流依据后继续当前范围；不能靠删掉分支制造“不可达”。

这里暂缓的是曲线激光。普通子弹的曲线运动、贝塞尔/Hermite敌移动、持续转向的直线激光分别查对应机制，不因名称含“曲线”就一并停掉。

## 已确定的转换规则

1. **两套语法分开。** 原作侧使用指定thecl18和eclmap，301名为 `enmCreateA`。目标使用int/fx/angle；一圈可写 `360deg` 或 `65536 as angle`，不能写非法的 `65536bam`。
2. **时间按实际执行推导。** 原作跳转可重设脚本时钟，wait也改时钟；目标wait是任务让出。循环退出后的等待、async下一帧首跑及源/卡帧平移分别核。完整配方见[转换案例](../../transcribe/th18/conversion-examples.md)。
3. **发射器按读取者归属重组。** 原作同敌跨async共享，目标每任务私有。主任务改配置时，发弹任务必须在对应帧读到正确值；只传一次快照不能复现后续共享改写。
4. **动态值直接表达。** 按值xform保存配置值，出生值用at_spawn，效果进入值用at_effect；rand沿原取样阶段和共享范围。不能因为参数动态就量化、取中值或一批共用逐弹随机。
5. **编号按语义映射。** 弹型/颜色查本作表；普通层速端点换步长用M−1，M=1单独处理；插值用EASE名称，7/8/17用状态槽；方向哨兵先解码再转BAM。
6. **保留实际状态影响。** 换图不等于换半径，DELAY不等于停速，VELTIME不等于持续追踪。并行EX按原作更新顺序分析，不能把所有持续效果都串成wait。

这些是实现方法，不是新增的物理近似授权。

## 弹型与半径的一致性要求

2026-11-05初查旧12形映射存在半径和缺型差异，见[半径对齐报告](2026-11-05-th18-radius-alignment.md)。随后引擎ENGINE_VER31追加按作品区分的TH06十型和TH18四十八型，新转写使用生成词表中的本作弹型和原作色号，基础半径按原生值转Q16.16。旧192项保持，不能继续把旧候选的半径偏差当作新卡默认取舍。

分别核源type→目标形/色/基础半径、出生及EX中的半径/缩放/换型变化、玩家判定参数与碰撞公式；出生动画附带的减速和无判定窗口按已批准的例外处理。Q16.16正常量化允许在原数值最近可表示值层面比较；它与2.4被改成2或2.8被改成5的差异不同。新表解决出生基础尺寸；通用动态半径/缩放写口仍未增加，现有换图操作仍保留出生半径。

## 已批准：按作品区分弹型，碰撞算法选择后置

2026-11-05用户确认，同一种外观可共用贴图，弹型身份与物理半径按来源作品区分，例如TH06米弹与TH18米弹分别记录，不能因都叫RICE就强制合并。任务资料使用“作品/版本＋原type＋color”标识，分别列目标外观、原作半径和当前目标实际半径。随后已授权并接入生成的 `TH06_*` / `TH18_*` 词表；它们是普通内容常量，须加入卡片编译目录，不是新的全局关键字。

当前转写继续使用引擎现有 `距离² <= (弹半径+玩家半径)²`，如实记录与原作的公式差异。以后是否提供碰撞算法选择，留到后续引擎修改；**不作为切分、转写或审核的前置条件**，不因这项已接受的差异单独判blocked，也不通过修改弹半径来补偿公式。

转写继续恢复控制流、移动、发射和EX。新表在出生时直接设置物理半径，普通弹不为静态半径挂xform；引擎和训练wheel须使用同批新表。既有卡不自动迁移。完整目录、生成入口和接入证据见[本轮记录](2026-11-05-touhou-bullet-catalog.md)。

## 已批准：省略出生减速和无判定窗口

2026-11-05用户明确同意，为性能省略普通弹出生动画附带的短暂减速与无判定窗口；首张符卡试产后进一步澄清：**出生阶段整体省略，包括仅由该动画造成的后续效果等待。** 普通弹直接使用配置初速并参与判定，后续ACCEL等效果从目标出生后的首次效果更新开始，不补等原作动画时长。报告注明这一已接受的时序简化即可，不必逐卡重新请求。

**写审双方都不要补回已经省略的出生等待，也不要因未知ANM恢复帧将攻击标为blocked、要求额外逆向或再次审批。** 已批准简化自然带来的时序变化按该口径实现；不要以“保真”或“稳妥”为由把它重新变成前置条件。首张试产th18_s1_b2的ANIM→ACCEL卡点据此解除。

独立显式WAIT/DELAY、后续加速的持续时间和其他攻击变换仍照常转写。本卡已核的12px出生退位移单独保留，不妨碍ACCEL立即开始；基础半径、动态几何和激光预警仍按各自规则处理。原作出生状态的事实保留在原生报告中，报告分清原作机制与训练侧已接受的简化。

## 系统性省略与外壳接管

现有躲弹转写省略不参与攻击行为的普通道具掉落、掉落奖励配置、计分/章节统计、纯音效、装饰粒子/动画、立绘、背景演出和UI；对话/调试/练习入口不作为实战攻击内容。TH06已在其mapping §8/9/11明确采用这类口径；TH18按本节区分纯表现与攻击副作用，并非存在一个自动删除所有同名opcode的预处理器。

| 内容 | 当前做法 | 保留的边界 |
|---|---|---|
| 普通掉落与奖励 | 不重现P、钱/点、命/炸弹资源、主/额外掉落和限时奖励；敌掉落表/分数置为无奖励配置 | 若某个“掉落”入口还会发弹、清弹、换状态，只省奖励部分 |
| 纯表现 | 省音效、震屏、装饰ANM/粒子、立绘、背景与显示信息 | 弹型/颜色映射仍保留；名称含ANM或特效不自动证明无物理作用 |
| 计分/章节统计 | 训练卡不模拟原作评分和章节奖励累计 | 攻击实际读取的难度/变量不能顺手删掉 |
| 原作击破与段落推进 | 无敌躲弹外壳，不依赖玩家DPS/掉落；单段开始/结束由训练外壳组织 | 本段内的移动、发射、变换、必要任务切换仍保留 |
| 波次/阶段交接 | 用户已接受独立训练时不复现上一段完整位置/尾弹/清场回调和逐帧交接 | 当前攻击自己的开场移动、首发等待和内部危险行为不能作为“交接”删除 |

原作出生特效可能伴随半速、位移或无碰撞窗，SIZE/HITBOX也会改几何；这些有物理影响。出生减速和出生无判定按上述明确许可省略，其余副作用不能归入“纯表现”删除。TH06的其他历史近似不自动成为TH18通用许可。曲线激光仍是暂缓整个实际依赖攻击，不是只删掉曲线。

Stage01这次所列573/574已核为限时奖励掉落配置，可归普通掉落省略；569/570已核到章节计数权重的登记/结算，不写本调用点的运动/发射状态，不再因助记名unknown就阻塞切分。具体静态证据见[状态表补充](../../transcribe/th18/enemy-state.md#6-stage01试切后补核的非阻塞项)。更上层统计用途未完整追踪，不据此给其他作品或实际读取统计值的特殊攻击作普遍删指令承诺。

## 已批准：圆周/椭圆保留语义与基础时序，容许细小数值差异

2026-11-06，用户在圆周/椭圆调查期间明确表示：舍入问题和零点几像素的细节可以不那么精确，重点是搞明白椭圆语义和基础时序；这是有意识的取舍。

这类转写优先使用现有ECL脚本表达运动方程。原生逐层百分位floor、f32三角尾差与目标Q16.16/BAM舍入差异作为已知差异记录，**不要求逐项复刻，不作为blocked或审核失败理由，也不为此增加仿f32、逐层舍入或误差补偿机制**。写审任务单直接引用本许可，不逐卡重新询问。

仍须保留圆心、相位/轴角/比例的真实含义，ABS/REL组合，入口参数快照，Time实际插值的量，设置当帧的主要位置变化，以及首发、等待和运动/发射周期。许可不扩大为任意改轨迹、删运动、取随机中值或改变关键时序。目标与原生执行相位的既有差异继续按具体卡说明，不声称完整逐帧等价。

当前15个移动待补单元的原生方程与脚本表达路线见[圆周/椭圆配方](../../transcribe/th18/circular-motion.md)。详细调查报告保留原生舍入事实；其中早于本许可写出的“精度仍需确认”等表述，以本节为准。

## 已批准：道中波次暂按独立场景训练

2026-11-05用户确认，波次尾部重叠问题暂不阻碍分开训练。按已划定的编队单独制卡，不必复制上一波残留敌/弹，不强制合并相邻波次；记录原作重叠与训练隔离的差异。仍保留本波自己的完整攻击过程和共享状态；波内主动发弹/内部回调保留，纯服务于跨波交接的残留和收尾不追逐帧复现，尾部/时限在转写时安排。

切分缺口与转写缺口分开：阶段/波次边界、源位置和依赖已明确时，不因还没完成目标实现、逐帧对拍或每个计分/掉落说明而把整关切分判失败。实际会改变本攻击危险区、又没有已核做法或已接受方案的内容，才作为对应单元的具体待补。

## 已批准：击破速度奖励波单独训练

2026-11-05用户确认，已识别的道中Boss击破速度奖励编队可以切成Boss后的独立一波。Stage01 MainSub05/W05按Boss已结束、完整奖励编队处理，不继续用原作击破时刻或F门导致的部分出生作为切分阻塞；保留编队内部排程、参数与敌人行为。具体入口和40个计划创建实例见[切分指南](../../transcribe/th18/splitting.md#独立波次与奖励编队)。

报告分别写原作条件与训练固定场景，不把此规则外推到任意条件创建、未知指令、普通波次重叠或其他物理近似。规则已经由用户确认，后续worker可直接引用，不必逐卡重复请求。

## enemy-state.md：## 5. 证据与本轮检查

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 5. 证据与本轮检查

原作固定来源：`/data/sunyunbo/www/renkolab/local/th18.v1.00a/state/data/functions.jsonl`。关键记录：748 `0x42e100` 构造；749 `0x42e5a0` 双层推进/出界；751 `0x42ed40` 受击、flags与体碰门；754 `0x42ff80` tick顺序/计时器；760 `0x430d30` handler；761 `0x4369e0` 创建和12槽快照；1459 `0x48b3a0` VM；1460 `0x48d420` 主/async结束。地址为TH18 v1.00a；JSONL行号随重新导出可能变化，优先用地址。

目标签名和默认值见 stg-engine `docs/ecl-lang/3-enemy.md`、`7-reference.md`；中断本作证据见 renkolab `engine/ecl/th18/01-boss-interrupts-and-spellcard.md`。较早[modern-vm调查](2026-11-02-ecl-capability-audit/modern-vm.md)主要核TH16，只有明确注明TH18的部分可直接复用；本文未把它整表升级为TH18已支持。

只读提取的原作全文与本轮检查记录留在忽略目录 `transcribe/work/th18-supplement-20261105/instructions-state/`，不入库。本文没有完整目标程序，仅提供状态配方，不以语法编译证明原作行为等价。原作体碰寄存器半径、复杂移动组合、完整flag域和通用中断/回调仍需按实际样本补证据。

## aim-modes.md：## 证据与复核入口

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 证据与复核入口

- TH18既有导出：renkolab `local/th18.v1.00a/state/data/functions.jsonl`，键 `addr=00424fe0/00427810`，保留已导入的社区类型和函数名；本轮未开库或改名。
- 逐弹抽取：忽略目录 `transcribe/work/th16-th18-ex-20261105/th18-00424fe0.c`。包装确认整波一次A、同点90°、层外路内。
- [Priw8第四课](https://priw8.github.io/#b=ecl-tutorial/&p=4)提供0..8的图示及参数解释；其TH17示例只作交叉参照，不替代本作分支核查。已下载正文见[来源清单](2026-11-05-th18-textbook-sources.json)。
- 我方行为来自 stg-engine `crates/stg-core/src/ecl/syscall/shooter.rs` 与 `docs/ecl-lang/4-bullets.md`。编译示例只验证目标语法；本轮未运行原作或做原作逐帧对拍。

### 本页例子的实际检查

2026-11-05：将本页每个 `ecl` 围栏单独抽为完整文件后，分别执行
`stg-harness check <file>` 和 `stg-harness run <file> --frames 8 --at 3`，均退出0，
`task_faults/contract_viol/pool_full` 均为0。各文件不能合在同一目录一次check，因为各自定义main。
材料和逐例日志保存在忽略目录 `transcribe/work/th18-textbook-20261105/tables/`；只验证前8帧目标运行，
未做原作实机或完整攻击验收。

四个例子的峰值弹数依次为36、9、8、16，与路数×层数相符。

## interpolation-modes.md：## 来源和验证范围

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

## movement.md：## 检查范围与复核入口

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 检查范围与复核入口

上面的helper正文可直接复制；自写运行小例保存在忽略目录`transcribe/work/th18/stage01/th18_s1_b2/native-move-rand/sample/`。`stg-harness check`退出0；80帧运行在32、63两个选定点检查，fault/viol/pool_full均0。水平自由例前30次x=22.25、停止后x=29.50；从x49出发的限位例始终不超过50。静止标记弹也记录了原发射点0/22.25/29.50，验证helper没有提前移动出弹口。

原生证据保存在该任务`evidence/`，由`read_native.py --renkolab <renkolab根>`经既有_driver的`open_program(tx=None)`读取；无事务、无save，isChanged前后均False。主要文件：move-rand、ctor、velocity-handler、interp-step/interp-tail、ease-linear、move-tick、compose-limit、enemy-tick和rand-angle/rand-signed的Listing。没有启动原作，没有新建逆向工程；随机分支依据Listing静态核查，未穷举原作RNG轨迹。

圆周与椭圆使用另一组源方程和设置时序，见[圆周/椭圆配方](../../transcribe/th18/circular-motion.md)。其setter可当场改变出弹点，不直接套用本页moveRand“设置当帧仍从旧位置发射”的安排。

## circular-motion.md：## 已知范围与证据

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 已知范围与证据

421/423 `EllipseTime`还会配置轴角/比例插值槽，但普通原生tick不消费这些槽，不能凭名字补成理想旋转椭圆。当前15项未使用这两个指令，暂不扩展其目标配方；详细原生事实保留在调查报告。

两路Sol报告：[TH18](../../transcribe/work/th18/movement-research/th18/report.md)、[TH16对照](../../transcribe/work/th18/movement-research/th16/report.md)。worker曾因用户偏好目录只读而无法启动JVM；随后主会话把启动器配置/缓存放到本任务目录，经原有`open_program(tx=None)`成功读取现有工程。两次均无事务、无save，`isChanged`前后False；可见已有社区符号。日志：[TH18](../../transcribe/work/th18/movement-research/parent-native/th18/read.log)、[TH16](../../transcribe/work/th18/movement-research/parent-native/th16/read.log)。没有重建或重新导入。

数学检查覆盖设置当帧、首两次更新、Time端点/缩圈、反向重设与轴角快照；结果是从原生代码推导后的计算，**不称原作动态对拍**。目标示例编译、实际预算及完整卡写审仍在后续实施阶段；此次不改引擎、不训练、不收卡。

## ex-effects.md：## 目标例子验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 目标例子验证

四个 `ecl` 围栏均作为独立程序抽出，用 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check <file>` 编译通过，再以 `run <file> --frames 140` 运行；全部报告 `task_faults 0 / contract_viol 0 / pool_full 0`。文件及 stdout 留在忽略目录 `transcribe/work/th18-textbook-20261105/ex-lasers/ex-effects-{1,2,3,4}.*`。

这些检查证明语法与目标运行路径可用，不证明与原作同帧等价。本文已将需要校准的首 tick、逻辑标量/向量分离、动态几何与并行冲突列在相应配方中；没有新增永久测试或启动训练。

## 证据及仍需按样本核查的部分

- [逐 EX 原生比较报告](2026-11-05-th16-th18-ex-comparison.md)：30 项完整参数、进入/持续/结束行为、版本差异及各自地址。
- [机器可读清单](2026-11-05-th16-th18-ex-comparison.json)：样本 hash、配置布局、逐项证据路径与未解字段。
- [子弹编号表](../../transcribe/th18/bullet-types.md)：SETSPRITE 及发射用到的 type/color。

REACT 的消费者、STEP `d`、TH16 极高角哨兵、复杂插值全模式以及激光完整消费者尚未核完。报告覆盖的是普通弹 EX 的配置/执行路径；相邻激光数据虽已辨认，不能据此宣称各类激光 EX 全部核实。未知项保留原值和依赖，不默认删除。

本轮复用已有社区命名、结构体和 opcode 标签；缺少 Ghidra MCP 时，通过项目只读 driver 核对关键 Listing，未重建或修改数据库。未运行原作或验收转写卡，不将静态比较视为实机等价验证。

## movement.md：## 插值为什么是线性

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 插值为什么是线性

以EnemyData为基址，角槽在+0x3c8，速度槽在+0x3f8；槽+0x28为duration，+0x2c为mode。setter分别是`0x41f600`和`0x41f630`。

`moveRand`把角槽start/end都设为α、duration=60、mode=4；角本来就不变，mode4不影响这条恒值轨迹。速度槽start=1/end=0、duration=60，但`0x4336da`–`0x4336e1`设置mode时ECX仍指向**角槽**，未写速度槽mode。这个观测在Listing中成立，不能按合理猜想“修正”为给速度槽mode4。

本卡速度槽mode实际为0，依据是完整的短路径：

1. Enemy构造`0x42e1cc`–`0x42e1ee`清零Enemy+0x122c开始的0x5600字节，覆盖速度槽mode（Enemy+0x1650，即EnemyData+0x424）。
2. Boss公共入口与Boss1进入本卡前没有正时长moveVelTime/moveSpeedTime；Boss1只使用同一moveRand，仍不写该mode。
3. BossCard1的`moveVelTime(0,0,0,0)`只取消两槽duration：`0x4321f7`–`0x43220c`调用`0x41b790`，后者仅清槽+0x28；不能据第二实参0声称它重置了mode。

mode0在`0x402fb0`的普通曲线函数走默认`elapsed/duration`。`0x41f640`先递增elapsed，再计算值；第60次明确返回终值并清duration。于是后续运动tick k=1..60：

```text
speed(k) = 1 − k/60
α(k) = α
Δ(k) = speed(k) × (cos α, sin α)
```

未限位总位移为29.5像素；前30次为22.25。第60次速度0，此后停止，直到下一次moveRand重建槽。本卡在源t90首次配置，每165帧重复，所以下次配置前已停105帧。

## movement.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

> **版本**：TH18 v1.00a。裸地址均属本作；2026-11-05 使用现有 PyGhidra 工程只读 Listing 补核。
> **范围**：`st01bs.ecl.txt::BossCard1` 的 `moveRand(60,4,1.0)`，普通 dt=1、REL恒零、无镜像。不是全部现代ECL移动指令的通用实现。

## bullet-types.md：## 编号表

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

## 编号表

色槽列记录原生调色记录中已配置的索引；“固定/脚本”表示由具体脚本控制，不能强套 16 色或 8 色。未核越界色号的处理，不据此添加取模或钳制。

| type | 弹种别名 | ANM script | 基础半径 | 已配置色槽 |
|---:|---|---:|---:|---|
| 0 | Pellet | 35 | 2.4 | 0–15 |
| 1 | Pellet2 | 36 | 2.4 | 0–15 |
| 2 | InvertPopcorn | 37 | 2.4 | 0–15 |
| 3 | Popcorn | 38 | 2 | 0–15 |
| 4 | Ball | 39 | 4 | 0–15 |
| 5 | Ball2 | 40 | 4 | 0–15 |
| 6 | RingBall | 41 | 4 | 0–15 |
| 7 | RingBall2 | 42 | 4 | 0–15 |
| 8 | Rice | 43 | 2.4 | 0–15 |
| 9 | Kunai | 44 | 2.4 | 0–15 |
| 10 | Shard | 45 | 2.4 | 0–15 |
| 11 | Talisman | 46 | 2.8 | 0–15 |
| 12 | Arrowhead | 47 | 2.4 | 0–15 |
| 13 | Bullet | 48 | 2.4 | 0–15 |
| 14 | LumpyBall | 49 | 2.4 | 0–15 |
| 15 | InvertRice | 50 | 2.4 | 0–15 |
| 16 | StarR | 51 | 4 | 0–15 |
| 17 | Coin | 52 | 4 | 0–2 |
| 18 | BigBall | 72 | 8.5 | 0–7 |
| 19 | BigBall2 | 73 | 8.5 | 0–7 |
| 20 | Oval | 74 | 7 | 0–7 |
| 21 | Dagger | 75 | 6 | 0–7 |
| 22 | Butterfly | 76 | 7 | 0–7 |
| 23 | BigStarR | 77 | 7 | 0–7 |
| 24 | BigStarL | 78 | 7 | 0–7 |
| 25 | FireballRed | 108 | 6 | 固定/脚本 |
| 26 | FireballPurple | 109 | 6 | 固定/脚本 |
| 27 | FireballBlue | 110 | 4 | 固定/脚本 |
| 28 | FireballYellow | 111 | 4 | 固定/脚本 |
| 29 | Heart | 81 | 10 | 0–7 |
| 30 | PulseBall | 79 | 7 | 0–7 |
| 31 | Arrow | 82 | 4 | 0–7 |
| 32 | Bubble | 80 | 14 | 0–3 |
| 33 | GlowBall | 315 | 12 | 0–7 |
| 34 | Droplet | 107 | 2.4 | 0–15 |
| 35 | SpinRice | 53 | 3.2 | 0–15 |
| 36 | SpinShard | 54 | 3.2 | 0–15 |
| 37 | StarL | 55 | 4 | 0–15 |
| 38 | LaserChunk | 158 | 4 | 0–15 |
| 39 | NoteRed | 317 | 4 | 固定/脚本 |
| 40 | NoteBlue | 318 | 4 | 固定/脚本 |
| 41 | NoteYellow | 319 | 4 | 固定/脚本 |
| 42 | NotePurple | 320 | 4 | 固定/脚本 |
| 43 | Rest | 321 | 5 | 0–7 |
| 44 | YinYangR | 324 | 10 | 0–7 |
| 45 | YinYangL | 325 | 10 | 0–7 |
| 46 | BigYinYangR | 326 | 28 | 0–3 |
| 47 | BigYinYangL | 327 | 28 | 0–3 |

## TH16 可以复用的范围

- **type 0–43**：两作每条原生描述记录的前 `0x110` 字节全部一致；包含主 ANM script、16 组颜色记录、基础半径及相关元数据。对应 44 个主 ANM 脚本正文也全部一致，共用的 `bullet1.png` 至 `bullet5.png` 解码 RGBA 像素完全一致。因此这些弹型的编号、名称识别及已配置颜色记录可以复用。
- **type 44–47**：本机 TH18 表新增的阴阳玉，主脚本 324–327，使用 `bullet6.png`。44/45 为较小的正/负角速度版本；46/47 为大阴阳玉，脚本同时设 X/Z 角速度。这里的旋转指视觉动画，不代表运动轨迹带角速度。
- 本机 TH16 表只核出 0–43 的连续有效记录；社区 `ECL-info.md` 虽放在 th16 目录，却还列出 44–49，不能将目录名当作逐作支持证明。TH18 本表确认到 47，48/49（Diamond/Tear）未建立对应，不得直接派给 worker。

记录 stride 分别为 TH16 `0x114`、TH18 `0x118`；TH18 从 `+0x110` 起的新增/差异字段没有在本轮解释。两作基础数据相同也不等于碰撞公式、出生计时和 EX 行为完全相同。

## 证据与边界

- [结构化核查记录](2026-11-05-th16-th18-bullet-types.json)：两作 exe、ANM、Ghidra 导出 SHA256、逐型数据及对照结果。
- TH16 已命名 Ghidra 导出：`bullet_pool_spawn`（`th16:0x412cb0`）读取 `g_bullet_render_desc + type*0x114`；主脚本在 `+0x0`，基础半径在 `+0x104`。符号落盘脚本为 renkolab `tooling/ghidra/scripts/apply_th16_bullet_names.py`。
- TH18 表基址 `th18:0x4c5f90`，stride `0x118`；初始化在 `th18:0x425992` 附近读半径，换型在 `th18:0x42640a` 附近重读。本机 `docs/investigations/2026-10-22-th18-geometry/` 的既有 48 项几何核查与本轮全部数值一致。旧报告及 CSV 仍是本机未入库资料，主要数字与出处已保存在上述本轮 JSON。
- 本轮使用项目已有 `tooling/pe_read.py` 读常量数据，复用 Ghidra 与标准 thtk 的既有导出；没有自行反汇编、重建数据库、复制原作资产入库或运行游戏。

下表给出内建图集可直接表达的映射和缺口；当前 TH18 原型统一使用 appearance 0 的行为不能当作正式映射。

## bullet-types.md：### 目标表与验证证据

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

### 目标表与验证证据

- 唯一维护输入：stg-engine `godot/assets/bullet/catalog.json` 与 `source_th06.png` / `source_th18.png`。
- 生成物：`atlas-layout.json`、`godot/assets/bullets.png`、`crates/stg-core/src/tables/touhou_appearances.rs`、`godot/ecl/game/touhou-bullets.ecl`；再经harness bake-tables生成运行时表。
- 当前1120逻辑项、635物理图格，旧192前缀不变；普通弹出生直接带半径，不需要额外xform。
- 本轮验证与训练wheel来源见[接入记录](2026-11-05-touhou-bullet-catalog.md)。历史教材检查保留在[原验证记录](2026-11-05-th18-textbook-verification.md)。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

2026-11-06，TH18 v1.00a。两路 Sol 分别调查 TH18 原生实现和 TH16 社区/原生资料，主会话再用现有只读 Ghidra driver 核对关键 Listing。以下地址默认属于 TH18，TH16 只作交叉参照，不直接移植其地址或字段。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

原生依据：setter `0x432899` / `0x4329b3` / `0x432cdd`；状态推进 `0x402bf0`；坐标消费者 `0x402cc0`，椭圆分支 `0x402d64–0x402e0e`；角差helper `0x404c70`；FINAL合成 `0x42ec00`。参数读取索引、字段写入和消费者已交叉核对。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

证据：中心判据 `0x43a270`，setter的即时消费和合成调用 `0x432999–0x4329a9`、`0x432e45–0x432e5c`；tick `0x42e5a0`，敌更新 `0x42ff80`；限位 `0x42ec77–0x42ed2e`。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

完整ID均加`th18_`前缀。源调用及行号见[调用清单](../../transcribe/work/th18/movement-research/actual-motion-calls.json)，原文为CP932，摘录不入库。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

文档线索来自[THBWiki ECL对照表](https://thbwiki.cc/%E8%84%9A%E6%9C%AC%E5%AF%B9%E7%85%A7%E8%A1%A8/ECL)的94条目。核查的[Priw8网站源码](https://github.com/Priw8/priw8.github.io/blob/1c0276927ec203f7adfafca01ec157dba52c35a7/js/ecl/ins.js)中TH18系统组上界为93、INS_18为空；其94条目属于TH08，不能混用。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

原生核验使用renkolab已有TH18 Ghidra工程：社区`labels.json`定位94到`0x48d0c8`；分派取opcode后经`0x48d3b8`/`0x48d2a8`跳转。Listing在`0x48d0c8–0x48d16c`读取phi/axis并算角差、极坐标，`0x48d171–0x48d1d8`缩放局部x并旋转，`0x48d1e8–0x48d206`写两输出。输入实际读取顺序为phi、axis、radius、ratio；本批local输入无随机副作用。极坐标helper为`0x48d900`，sin/cos包装为`0x404e10`/`0x404df0`。当前指令分支没有PosVel消费者的百分位floor。

## circular-motion.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

通过既有只读driver取出的[Listing及日志](../../transcribe/work/th18/ins94/evidence/read.log)确认工程已有社区命名/类型，isChanged前后False。小型[目标表达例](../../transcribe/work/th18/ins94/target-probe/main.ecl)以四组独立几何期望验证，实际check/run通过，得到(5,0)、(0,10)、(0,5)、(-2.5,7.5)，诊断全0；只证明此方程可用现有ECL表达，不代表五张整卡已验收或原作动态对拍。

## conversion-examples.md：## 本页验证材料与复跑

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

## conversion-examples.md：历史目标取样

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

## conversion-examples.md：历史目标取样

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

## conversion-examples.md：历史目标取样

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

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

曲线 `711 laserCuOn` **暂不转写，状态为 blocked**。本例不能推广到曲线历史轨迹，也不能默认拆成多根短线。700–714其他指令继续按[激光表](../../transcribe/th18/lasers.md)分别处理：706是长度增长速率；705不是持续累加漂移；712不是清激光；713/714含未核消费者，不能按编号猜测。

## lasers.md：三个完整程序的实际编译及取样记录

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

三个完整程序的实际编译及取样记录留在忽略目录 `transcribe/work/th18-textbook-20261105/ex-lasers/`。用 release harness `check <file>`，再 `run <file> --frames 110 --at F` 核 state、width、start/end、speed、三段时长；具体结果由教材验证记录汇总。没有原作动态对拍，也没有验收成训练卡。

本次实测，三个程序的激光都出生于全局帧 3（关卡主任务先创建敌人，敌任务随后启动）：

| 程序 / `--at` | 已观察的几何与状态 |
|---|---|
| sweep / 32 | angle=90°，start/end=0/400，width=8，state=0，timer=30 |
| sweep / 33 | angleBAM=16566（约91°），omega=182，state=1，timer=1 |
| sweep / 92 | angleBAM=27304（约150°），state=1，timer=60 |
| sweep / 93 | state=2，timer=1；进入无判定退出期，omega 仍在推进 |
| aimed / 3 | origin=(48,96)，angle≈109.46°，start/end=0/360，width=8，state=0 |
| spear / 3 | start/end=0/4，width=6，speed=4，state=1 |
| spear / 50 | start/end=0/192，达到棒长 |
| spear / 60 | start/end=40/232，保持棒长192 |

上述 110 帧运行均报告 `task_faults 0 / contract_viol 0 / pool_full 0`。例如命令为 `stg-harness run transcribe/work/th18-textbook-20261105/ex-lasers/lasers-1.ecl --frames 110 --at 33`；检查命令为 `stg-harness check <抽出的 .ecl 文件>`。完整 stdout 在该忽略目录的 `*.check.txt` 与 `*-at*.txt`。

原作依据为 renkolab 现有 `local/th18.v1.00a/state/data/functions.jsonl`：分派 `0x430d30`，Line initialize `0x4490d0` / tick `0x44a4f0`，Infinite initialize `0x44c870` / tick `0x44cae0`，Curve initialize `0x44ed70` / tick `0x44f450`。目标依据为 stg-engine `docs/ecl-lang/9-lasers.md`、`crates/stg-core/src/world/laser.rs`、`integrate.rs` 与 `collide.rs`；手册末尾以 TH06 为背景的统一宽度换算不得覆盖本表的 TH18 分段规则。EX 复制参数见[EX 表](../../transcribe/th18/ex-effects.md)与[原生比较报告](2026-11-05-th16-th18-ex-comparison.md)。

## lasers.md：原生依据/历史验证

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

宽度分段依据已有[TH18 几何调查](2026-10-22-th18-geometry/encoding-lasers.md)记录的原生 Listing：Line `0x44aa25..43`、Infinite `0x44ced4..f5` 与几何消费者 `0x45cea0`。原作玩家使用局部矩形，与目标玩家圆形相交仍有独立判定差异；匹配激光矩形不等于完整碰撞等价。

## instructions.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 0 `nop` | 无副作用占位；保留其时间门 | `drop` 只删操作，不删等待 |
| 1 `delete` | 结束当前上下文；敌主上下文结束使敌静默退场 | `translate`：目标结束当前任务；额外async结束不等于敌死，不能统一换 `die()`；见教材 §3.2 |
| 10 `ret`；11 `call` | 同步返回/调用，源保存调用时钟与栈帧 | `translate`：静态非递归call图改普通sub，参数/时间先恢复；根ret为结束。目标禁递归，不能直接保留无限尾调用链 |
| 12 `jmp`；13 `jmpEq`；14 `jmpNeq` | 分支/跳转还写源脚本时间；13判零、14判非零 | `translate`：按执行轨迹写if/while/goto+wait；不能仅保留PC跳转。教材 §3.1；本作VM `0x48b3a0` |
| 15 `callAsync` | 同敌新增上下文、拷实参 | `translate`：`spawn helper(...)`，目标次帧首跑；同敌共享I/F不变成任务局部快照。教材 §3.2–3.3 |
| 16 `callAsyncId`；17 `killAsync`；21 `killAllAsync` | 同敌async带用户ID创建、查ID取消、全async取消 | `需上下文`：有限已知集合可显式保留目标任务标识；源ID不是目标池索引，`KILL_CHILDREN`只及直系，不能覆盖同敌孙任务。一般动态ID取消 `blocked`；见[状态表 §4](../../transcribe/th18/enemy-state.md#4-同一敌人的段入口恢复状态而非重置模板) |
| 23 `wait` | 推迟源脚本时间门 | `translate`：正常dt=1且整数等待可恢复为目标wait；与时间标签不可双算。教材 §3.1 |
| 24 `waitf`；547 `gameSpeed` | 浮点等待/游戏速度影响源时钟 | `需上下文`；确有子帧或变速要求时无一般等价目标内建，`blocked`，不能默默取整 |
| 40 `stackAlloc`；42 `pushi`；43 `seti`；44 `pushf`；45 `setf` | 原生局部/表达式栈读写 | `translate`：先恢复高层变量与求值顺序再写var/赋值；`[-1]`并非每次独立pop。教材 §2.1、§3.4 |
| 50 `addi`、51 `addf`、52 `subi`、53 `subf`、54 `muli`、55 `mulf`、56 `divi`、57 `divf`、58 `modi` | 标量算术 | `translate`：int/fx/angle按物理量拆分，整数除法与float表达式不能混写；教材 §2.2 |
| 59 `eqi`、60 `eqf`、61 `neqi`、62 `neqf`、63 `lessi`、64 `lessf`、65 `leqi`、66 `leqf`、67 `greateri`、68 `greaterf`、69 `geqi`、70 `geqf` | 比较 | `translate`：比较前保留源类型、角规范化与表达式副作用 |
| 71 `noti`；72 `notf`；73 `or`；74 `and`；78 `deci` | 逻辑操作与自减 | `需上下文`：恢复原操作数求值后再写条件；目标&&/\|\|短路可能少消耗RAND，自减要保留旧值用途 |
| 75 `xor`；76 `bit_or`；77 `bit_and` | 整数逐位操作 | `需上下文`：不能把一般掩码改成逻辑布尔；常量可在转写时算出，动态完整位运算的目标配方未在本表证明 |
| 79 `stackSin`；80 `stackCos`；81 `circlePos`；82 `validRad`；83 `negi`；84 `negf`；85 `squareSum`；86 `squareSumRoot`；87 `getAngle`；88 `stackSqrt` | 数学/插值定位组 | `需上下文`：普通三角/向量可用sin/cos/atan2/dist；弧度先转BAM。89名字不能当“线性乘法”的证据；91/92任意变量写回、93随机分布及88一般sqrt尚无本表完整TH18配方，实际需要且本书未定义时交主会话补齐，插值见[模式表](../../transcribe/th18/interpolation-modes.md) |
| 89 `linearFunc`；90 `pointRotate`；91 `floatTime`；92 `math92`；93 `math93` | 数学/插值定位组 | `需上下文`：普通三角/向量可用sin/cos/atan2/dist；弧度先转BAM。89名字不能当“线性乘法”的证据；91/92任意变量写回、93随机分布及88一般sqrt尚无本表完整TH18配方，实际需要且本书未定义时交主会话补齐，插值见[模式表](../../transcribe/th18/interpolation-modes.md) |

## instructions.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

| opcode / 精确助记名 | 功能与路径 | 处理及边界 |
|---|---|---|
| 600 `etNew` | 初始化指定et配置及辅助偏移/游标状态 | `translate`：在负责发射的目标任务里sh_reset，再显式写实际需要的字段；源16份配置、目标每任务4槽，不能直接全保留默认值 |
| 601 `etOn` | 读取当前配置建弹 | `translate`：sh_fire或按原序显式fire；出生角/速度/顺序/随机范围见教材 §5与[瞄准表](../../transcribe/th18/aim-modes.md) |
| 602 `etSprite` | 弹型与色 | `translate`按[弹型表](../../transcribe/th18/bullet-types.md)，源type不是目标appearance |
| 603 `etOffset`；626 `etOffsetRad`；627 `etDist`；628 `etOffsetAbs` | 出弹位置/距离配置定位 | `需上下文`：先恢复实际出生点与坐标层；603常见偏移用sh_offset，628/626/627不能都当同一个offset。自机狙从实际口算 |
| 604 `etAngle`；605 `etSpeed`；606 `etCount`；607 `etAim` | 方向、首末速度、颗数/层数与模式 | `translate`：sh_angle、sh_speed、sh_count、sh_aim/sh_ring；源首末速度须转层步长，见教材 §5与瞄准表 |
| 608 `etSound` | 发射声音配置 | `drop`限不参与所选攻击逻辑的音效 |
| 609 `etExSet`；610 `etExSet2`；611 `etEx`；612 `etEx2` | 指定槽/追加短长EX记录 | `translate`/`blocked`逐EX判断；短式不清未写字段，24条EX与追加游标要保存，见[EX表](../../transcribe/th18/ex-effects.md)、教材 §6 |
| 614 `etCopy` | 复制源et描述符及辅助偏移到目标et | `需上下文`：TH18本作0x430d30 case0x7f复制0x488字节及两组偏移；不写单独EX追加游标。目标无sh_copy；有限静态字段可缓存重放，不能以sh_reset(dst)代替拷贝，更不能顺手清游标 |
| 613 `etClearAll` | 全场普通弹及激光取消 | `需上下文`：本作handler调BulletManager与LaserManager取消，**不是清空et配置**。目标clear_bullets是field，执行相位/激光/转星规则有差别 |
| 615 `etCancel`；616 `etClear` | 敌位置圆域取消，原handler传不同mode | `需上下文`：候选clear_bullets_at；半径、道具、激光部分取消和相位要对齐，本表未补全TH18取消消费者，不能直接套TH16转星规则 |
| 635 `etCancel2`；636 `etClear2`；712 `etCancelRect` | 其他圆域/矩形取消入口 | `需上下文`：712已核只处理普通弹矩形域，不是改弹判定；635/636逐样本核过滤，目标field不能自动覆盖源保护规则 |
| 617 `etSpeedR3`；618 `etSpeedR5`；619 `etSpeedR2`；620 `etCountR3`；621 `etCountR5`；622 `etCountR2`；624 `etSpeedD`；625 `etCountD` | 按rank/难度选值的配置入口 | `需上下文`：固定难度可先消解已核分支；原动态RANK不等于目标GVAR_RANK。教材 §3.3 |
| 623 `angleToPlayer`；640 `etExSub`；641 `etExSubtract` | 角度查询及EX相关定位 | `需上下文`：623从实际取样位置/时点核方向；640/641不得仅凭名当已支持EX重排 |

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

| 原位 | 已核消费者/行为 | 转写边界 |
|---|---|---|
| `0x2` | `0x42ed40` 体碰入口检查 `flags & 0x22 == 0`；受击入口检查的是 `flags & 0x21` | 仅这一位的禁体碰用途可表达为 `ENEMY_NO_BODY`，清位反向映射；同时存在其他禁体碰原因时不能盲目清目标位 |
| `0x4` / `0x8` | `0x42e5a0`分别跳过横/纵屏外回收；五面首符flag303实际同时使用 | 目标敌仍有出界回收。无交互、无其他实体查询的发射体可按值任务保存独立世界坐标，见[五面首符](../../cards/th18/th18_s5_b2/notes.md) |
| `0x10` | 同函数伤害扣血路径要求该位为0且无敌计时器到期 | 只核到阻止扣血；`set_invuln` 有期限且目标事件行为不同，不等于复制整位 |
| `0x20` | 同时进入受击门 `0x21` 与体碰门 `0x22`；502/503还遍历ANM做状态操作 | 同时影响交互及动画，不能只解释成禁体碰或纯外观；按样本拆出必要行为 |
| `0x1000` | 伤害路径选择圆/宽高分支；体碰也切到另一几何路径 | 不能作为目标公开 flag 写入；形状/朝向按实际消费者核 |
| `0x20000` | 移动限位开关，504写入四边界并置位，505清位 | 目标无常驻限位写口，见 §3 |
| `0x80000` | 镜像开关；424按参数置清，创建helper也读取 | 保存在脚本状态；按具体移动指令与创建顺序处理，见 §2–3 |

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

目标公开可写另有 `ENEMY_KILLALL_EXEMPT`，但本文未确认一个能覆盖 TH18 所有清场入口的单一源位。原生清场 `0x430710/0x430910/0x430b20` 检查复合掩码 `0xc004a0`，并有 `0x100` 例外；不能从 TH16 表拷一个位号就声称等价。

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

`0x4369e0` 中，若父 `0x80000` 置位，**在上表加父坐标之后**再把最终出生x取负，并翻转子镜像初始位；y保持前一步结果。于是普通相对创建在父镜像下的x是 `-(parent_final_x + input_x)`，不能改成 `parent_final_x - input_x`。这是创建helper的静态事实，不应外推为所有移动或发弹指令的统一镜像规则。F族检查在 `0x430d30` 的共享分派分支中，找到boss0则不执行普通创建路径；不要凭F名字解释为“继承全部flags”。

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

旧 `renkolab/engine/ecl/th18/05-stage1-midstage-spawns.md` 的创建变体表存在错位与“A=async”的旧说明；本表以当前eclmap及本作 `0x4369e0` 为依据，不沿用该解释。

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

TH18有ABS与REL两套PosVel状态，并由 `0x42ec00` 合成最终位置。`402 movePosRel` 是写REL层，不能泛化为“给当前世界位置加一段偏移”。两层都在运动、插值未结束或读回ABS/REL变量时，单次 `move_to` 无法保留这些状态。

## enemy-state.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

- **573 unknown573、574（thecl显示ins_574，eclmap未命名）**：handler分别为 `0x433a4a`、`0x433a70`，调用 `0x42d020/0x42d040` 写限时额外掉落及窗口/计时。已有renkolab `engine/ecl/th18/02-item-drops.md` §5.1–5.2也已说明；这些属于击破速度奖励掉落，不是等待/发弹配置，按普通道具省略。
- **569 unknown569、570 unknown570**：handler `0x4338ab/0x433904`。569写敌 `+0x6828` 的章内计数权重，调用 `0x439ec0` 增加统计；570在自身chapter匹配当前chapter时，经 `0x439eb0` 结算并清零该权重。对应写口只累加章节统计字段，未写运动/发射配置。更上层评分用途未完整追踪，但不因其unknown名字阻塞Stage01独立攻击切分。
- **401 movePosTime在frames≤0时**：分派走 `0x431bbf`，调用 `0x439900` 只清该位置插值的持续字段；本支不把参数x/y写成当前坐标。因此Boss换段的 `movePosTime(0,0,0,0)` 不能改成目标 `move_to(0,0fx,0fx,...)` 瞬移。后续正时长移动仍从当时位置起步。
- **525 enmKillAll与死亡回调**：分派经 `0x434e1b` 调 `0x430710`，对通过源flag过滤的敌调用 `0x430240`；该函数执行非空setDeath程序。不能把原作清敌都解释成无回调静默删除。571的另一清场路径 `0x430b20` 则先清回调字符串。源事实已能区分；训练交接是否保留这些尾部按[用户已批准口径](../../transcribe/th18/transcription-policy.md#系统性省略与外壳接管)，不再要求逐帧复现跨波过程。

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

412的参数依次是持续帧数、角插值mode、起始速度。`0x433375`选择ABS角槽与速度槽；`0x4335ff`起读取mode、speed和duration。每次调用使用当时FINAL位置和玩家x，得到一个固定方向α。

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

设`R = π×U`，U为有符号单位随机量。`0x405b90`调用`0x402810`后在`0x405b99`再乘π；不能把R直接当U。横向分支如下，条件为严格小于/大于：

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

随后按y处理：y<112取`α=abs(α)`；y>144取`α=−abs(α)`；112≤y≤144不动。**中央加π后没有先wrap**，必须保留这个顺序；例如α=200°时顶部的abs仍为200°，不能提前转成−160°再取abs。左右外侧分支只有右侧显式wrap。证据：`0x4333c9`–`0x433563`。

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

最后，若`abs(α+π/2)<0.05`，按原来位于−π/2的哪一侧推至`−π/2±0.05`；否则若`abs(α−π/2)<0.05`，同理推至`π/2±0.05`。恰等中心时选加0.05一侧。没有额外随机。按上述方向区间，本卡实际不会接近±90°，因此该护栏保留在配方中但本样本不可达。证据：`0x43356b`–`0x4335f7`；常量分别读到±1.520796…、±1.620796…。

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

`0x42e5a0`先推进角/速插值，转换当前极坐标速度并积分ABS、REL，再调用`0x42ec00`组合FINAL。`0x42ec77`–`0x42ecf9`对FINAL夹界，`0x42ed03`–`0x42ed2e`将ABS写回`FINAL−REL`。不改速度、方向或插值进度；被挡住的位移不会积在墙外，也不会反射。本卡REL恒零，故可直接递推：

## movement.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

`0x42ff80`依次执行运动/限位、Enemy__ecl_run、EnemyData__step_game_logic（含体碰）：即**源为移动→ECL→体碰**。因此配置moveRand的那一次发射仍从旧位置P(0)出弹，后续源t+1读到P(1)，源t+5读到P(5)。本卡t0先清速度/旧插值，60帧移至(0,128)，t90才开始moveRand；独立训练已选择(0,128)初始化时，初次回中是零位移。

## aim-modes.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

> **版本**：TH18 v1.00a。裸地址属于本作；2026-11-05复用既有Ghidra导出核查。
> **方法**：`FUN_00424fe0` `0x424fe0` 的逐弹分支，加包装 `FUN_00427810` `0x427810`；Priw8教程作交叉参照。

## aim-modes.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

TH18 `0x424fe0` 的case11/12确实使用表列环角；然后调用 `FUN_004a9ea0`，
再以绝对值参与速度调制。现有Ghidra反编译未正确表达该调用的SSE参数/返回，
不能将残留的 `(1-abs(angle)*s1)*v(q)` 当作已核公式，也不能因社区称“peanut”就自行补sin。
未解点只在这两行的方向调速函数及其s1有效域；0..10不因此整体待定。

## interpolation-modes.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

> **版本**：TH18 v1.00a；2026-11-05整理。裸地址均属本作。
> **证据**：已核的原生归一化函数 `0x402fb0`、分派 `0x4035d8`，以及标量 `0x41f640`、运动 `0x439a00` 消费者；复用引擎既有核查，未重新逆向。

## interpolation-modes.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

普通`407 moveVelTime`的角度插值取最短弧：当前与目标差的绝对值≥π时，给较小端点加2π后插值。父变量分别`validRad`不会使其改走长弧。TH18指令`0x432388–0x4323d8`及π/2π常量已于2026-11-06只读核实；五面首符的160°/−170°转向使用此规则，不外推mode7/8等特殊分支。

## ex-effects.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

| type 十六进制 / 十进制 int | 效果 | 参数语义 | 与 TH16 对照 |
|---|---|---|---|
| `0x1` / 1 | [SPEEDUP](2026-11-05-th16-th18-ex-comparison.md#ex-1) | 已核主路径无参数 | 相同（已核子集） |
| `0x2` / 2 | [ANIM](2026-11-05-th16-th18-ex-comparison.md#ex-2) | a=ANM interrupt=7+low16(a) | 相同（已核子集） |
| `0x4` / 4 | [ACCEL](2026-11-05-th16-th18-ex-comparison.md#ex-3) | a=持续时间；r=加速度标量；s=角参数；各版本解析不同；m=TH18瞄准偏移/随机幅度；TH16瞄准偏移见既有一手记录 | 不同 |
| `0x8` / 8 | [ANGLE_ACCEL](2026-11-05-th16-th18-ex-comparison.md#ex-4) | a=持续时间；r=速度增量/帧；s=角速度；每步 angle += s*dt | 相同（已核子集） |
| `0x10` / 16 | [STEP / ANGLE](2026-11-05-th16-th18-ex-comparison.md#ex-5) | a=每段持续时间；b=段数上限；c=角/速子模式0..7；d=保存进私有状态；本轮未确定用途；r=角参数；c=5/6为随机幅度；s=目标速；<=-999990保留；c=7为当前速随机幅度；m=TH18角helper偏移/幅度 | 不同 |
| `0x40` / 64 | [BOUNCE](2026-11-05-th16-th18-ex-comparison.md#ex-6) | a=反弹事件次数上限；b=墙mask U/D/L/R=1/2/4/8；0x10抑制反射；0x20自定义尺寸；r=> -990时设置反弹处理后的speed，否则保留；s=b&0x20时宽；否则384；m=b&0x20时高；否则448 | 相同（已核子集） |
| `0x80` / 128 | [INVULN](2026-11-05-th16-th18-ex-comparison.md#ex-7) | a=写入bullet+0x24计数 | 不同 |
| `0x100` / 256 | [OFFSCREEN](2026-11-05-th16-th18-ex-comparison.md#ex-8) | a=最长保活倒计时；b=非0额外做视锥可见性检查 | 相同（已核子集） |
| `0x200` / 512 | [SETSPRITE](2026-11-05-th16-th18-ex-comparison.md#ex-9) | a=弹型索引；b=低15位颜色；0x8000触发ANM interrupt2 | 相同（已核子集） |
| `0x400` / 1024 | [DELETE](2026-11-05-th16-th18-ex-comparison.md#ex-10) | a=等于1时先把cancel script设-1 | 相同（已核子集） |
| `0x800` / 2048 | [PLAYSOUND](2026-11-05-th16-th18-ex-comparison.md#ex-11) | a=声音id | 相同（已核子集） |
| `0x1000` / 4096 | [WRAP](2026-11-05-th16-th18-ex-comparison.md#ex-12) | a=传送次数上限；b=墙mask U/D/L/R=1/2/4/8 | 相同（已核子集） |
| `0x2000` / 8192 | [SHOOTPREP / SHOOT](2026-11-05-th16-th18-ex-comparison.md#ex-13) | a=aim模式；b=子弹起始effect_index；c=路数；d=层数；r=发射角/当前角/玩家角哨兵；s=第二角；m=首速；<=-999990保留父speed；n=末速 | 不同 |
| `0x4000` / 16384 | [SHOOT_DATA](2026-11-05-th16-th18-ex-comparison.md#ex-14) | a=配对记录：sprite；b=配对记录：color；c=配对记录：非0删除父弹 | 相同（已核子集） |
| `0x8000` / 32768 | [REACT](2026-11-05-th16-th18-ex-comparison.md#ex-15) | a=写入反应编号字段 | 未核（消费者） |
| `0x10000` / 65536 | [GOTO / LOOP](2026-11-05-th16-th18-ex-comparison.md#ex-16) | a=目标EX记录index；b=<=0无条件跳；>0使用逐弹共享循环计数 | 相同（已核子集） |
| `0x20000` / 131072 | [MOVE](2026-11-05-th16-th18-ex-comparison.md#ex-17) | a=持续时间；b=低8位插值模式；0x100相对坐标；r=目标x；s=目标y | 相同（已核子集） |
| `0x40000` / 262144 | [VEL](2026-11-05-th16-th18-ex-comparison.md#ex-18) | r=<-990保留角；[-990,990)字面；>=990朝玩家+r-999；s=<-990保留speed，否则直接赋speed | 相同（已核子集） |
| `0x80000` / 524288 | [VELADD](2026-11-05-th16-th18-ex-comparison.md#ex-19) | a=写私有时限；r=附加位移方向；s=附加位移速度 | 相同（已核子集） |
| `0x100000` / 1048576 | [BRIGHT](2026-11-05-th16-th18-ex-comparison.md#ex-20) | a=1/2选择混合标志，其余清相应模式位 | 相同（已核子集） |
| `0x200000` / 2097152 | [VELTIME / ACCELWEIRD](2026-11-05-th16-th18-ex-comparison.md#ex-21) | a=持续时间/计算斜坡的分母；r=目标标量速；s=角参数；各版本解析不同；m=TH18瞄准偏移或随机幅度 | 不同 |
| `0x400000` / 4194304 | [SIZE](2026-11-05-th16-th18-ex-comparison.md#ex-22) | a=插值结束时间；b=插值模式；r=初始尺寸；s=最终尺寸 | 相同（已核子集） |
| `0x800000` / 8388608 | [SAVE / SAVEANGLE](2026-11-05-th16-th18-ex-comparison.md#ex-23) | 已核主路径无参数 | 相同（已核子集） |
| `0x1000000` / 16777216 | [ENMCREATE / ENEMY](2026-11-05-th16-th18-ex-comparison.md#ex-24) | a=子敌I0；b=子敌I1；c=子敌I2；d=子敌I3；r=子敌F0；s=子敌F1；m=子敌F2；n=子敌F3 | 相同（已核子集） |
| `0x2000000` / 33554432 | [LAYER](2026-11-05-th16-th18-ex-comparison.md#ex-25) | a=渲染桶/层索引 | 相同（已核子集） |
| `0x4000000` / 67108864 | [DELAY](2026-11-05-th16-th18-ex-comparison.md#ex-26) | a=等待时间；<1直接前进 | 相同（已核子集） |
| `0x8000000` / 134217728 | [LASER](2026-11-05-th16-th18-ex-comparison.md#ex-27) | a=0线激光；1无限激光；其他值不创建；b=sprite；c=color；d=a0:非0删除父；a1:flags及起始effect_index/删父打包；r=角/哨兵；s=speed/保留哨兵；m=线:长度；无限:附加浮点字段（未核命名）；n=线:长度相关字段；无限:长度 | 不同 |
| `0x20000000` / 536870912 | [HITBOX](2026-11-05-th16-th18-ex-comparison.md#ex-28) | r=>=0为动态半径；<0恢复当前弹型默认半径 | 相同（已核子集） |
| `0x80000000` / -2147483648 | [WAIT](2026-11-05-th16-th18-ex-comparison.md#ex-29) | a=等待时间；<1直接前进 | 相同（已核子集） |
| `0x40000000` / 1073741824 | [HOMING（行为别名）](2026-11-05-th16-th18-ex-comparison.md#ex-30) | a=持续时间；r=目标速度；s=瞄准角偏移；m=每步速度向量混合系数 | TH18新增 |

## ex-effects.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

原生`0x423e10`在任一handler返回结束后，会同帧重新执行整列active效果，最后只积分一次位置；`0x428970`的OFFSCREEN每次调用都减1。因此保活参数不能总按世界帧原样复制。二面第二符两个效果结束各多减一次，300对应目标298帧；三面首符五次边界让200在零起age194清位，该帧还会让正在运行的VELTIME多更新一次。按具体效果链折算，配方见成品[二面第二符](../../cards/th18/th18_s2_b4/notes.md)和[三面首符](../../cards/th18/th18_s3_b2/notes.md)；此前二面首符的同长ANGLE_ACCEL200/OFFSCREEN200仍用200。

## ex-effects.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

STEP 的已核降速分支在第 t 次更新（0≤t<a）使用**当时的标量 speed**：`v_draw = speed - t*speed/a`，再用当前角构造本帧速度；这个计算读取原作当前逻辑标量，向量构造 helper `0x429bc0` 本身不回写标量；没有其他效果改它时，该段就是固定逻辑速率乘线性下降系数。段界恢复保存的目标 speed、更新角、计数加一并重置段计时。c0/5 加偏角，c1/6 在段界重新查玩家，c2/c3 依赖 SAVE，c4 固定目标角；c5/6/7 另有随机及进入解析顺序。

## lasers.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

| 编号 / 名称 | 原作签名与参数 | 本作关键含义 | 目标路径 |
|---|---|---|---|
| 700 laserNew | `Sffff (etId, initialLength, targetLength, lengthLimit, width)` | 配发射器激光几何；第三浮点在线激光限制末端路程 | `laser` + `lz_start/lz_speed`，先换算实际判定段 |
| 701 laserTiming | `SSSSSS (etId,startup,expand,hold,shrink,flags)` | Infinite 四段；Curve 把 startup 槽用作轨迹长度 | 静态宽度子集转三段时长；扩宽期另见下文 |
| 702 laserOn | `S (etId)` | 创建 Line，复制发射器 EX | 飞棒/增长线组合；无通用 EX 复制入口 |
| 703 laserStOn | `SS (etId,laserId)` | 创建 Infinite 并给实例编号 | 保存 `laser()` 返回句柄 |
| 704 laserOffset | `Sff (laserId,x,y)` | 写当前原点及保存的基点；本作函数 `0x42d700` | `lz_origin`；若依附敌人则明确使用 `lz_anchor` |
| 705 laserTrajectory | `Sff (laserId,x,y)` | 写 Infinite 的附加向量 `+0x794/+0x798` | 按本作每 tick 原点公式组合；不能直接当持续匀速平移 |
| 706 laserStLength | `Sf (laserId,value)` | 写 `+0x78`：长度增长速率，不是立即设总长度 | 有限增长路径可评估 `lz_speed`，注意它会重设 end |
| 707 laserStWidth | `Sf (laserId,width)` | 写当前宽 `+0x74`；phase 随后可能再次覆盖 | 目标无当前宽度写口，不能直接还原动态改宽 |
| 708 laserStAngle | `Sf (laserId,angle)` | 写当前角 `+0x6c`，单位弧度 | 用当前 `lz_angle` 算差后 `lz_rotate` |
| 709 laserStRotation | `Sf (laserId,omega)` | 写角速度 `+0x7a4`，tick 持续积分 | `lz_omega`，弧度/帧转 BAM/帧 |
| 710 laserStEnd | `S (laserId)` | 找到该编号实体，调用取消并解除编号，循环至无匹配 | `lz_cancel`；原作同编号多条须保存全部句柄 |
| 711 laserCuOn | `S (etId)` | 创建 Curve，保存逐段运动历史 | 暂不转写；命中曲线依赖则blocked |
| 712 etCancelRect | `ff (w,h)` | 以当前敌位置取消矩形内普通弹 | 不能当作“清所有激光”；目标清弹形状另核 |
| 713 unknown713 | `SS (etId,laserId)` | 分派调用激光 kind=3 的分配路径 | kind=3 后续实体消费者未核，不能宣称可用 beam |
| 714 unknown714 | `SS (laserId,value)` | 找实体后调用 vtable+8，传第二参数 | 未核该调用具体行为；无确定目标映射 |

## lasers.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

705 尤其容易误读：Infinite tick `0x44cae0` 每帧先从保存基点恢复当前原点（特定 flags 下改用 boss0 位置），然后加一次该向量乘 dt，再加沿当前角的距离偏移。仅凭社区“每帧移动”的描述，把 `(x,y)` 连续累加到世界原点，会产生本作没有的漂移。这里已核公式顺序，但这些 flags 的完整用途及所有来源指令仍未全解。

## lasers.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

这是本作 `LaserLine__check_graze_or_kill 0x44a950`、`LaserInfinite__check_graze_or_kill 0x44ce80` 的几何。Line 另有 `L>16` 与 `w>3` 门；Infinite 要 `L>16` 且处于原生状态 2 或 4。目标没有这些原作数值门，短小激光不得不经判断就设成 active。

## conversion-examples.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

这不是 TH06 `jump_dec` 的移植。TH18 的依据是既有原生导出 `EclRunContext__ecl_run 0x48b3a0`：opcode12 写当前脚本时间并跳 PC（Listing `0x48b700`），13/14 条件满足时走相同路径；23 的 wait 则减当前脚本时间（`0x48b727`），下一条指令的时间门决定何时继续。现有[导入原型](../../tools/th18-import-prototype/README.md#时间和栈的转换)用 `clock=$frame-base` 表达这套规则，goto 对应 `base=$frame-newTime`，wait 对应 `base+=n`。不要套 TH06 变量拷贝或自动计数规则。

## conversion-examples.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

首跑相位并非仅凭目标习惯假定：原生 `Enemy__ecl_run 0x48d420` 在运行当前栈前缓存 next；`0x48d850` 把新 async 插在主节点之后。主任务本帧新增的 async 不在已缓存的遍历链上，所以本例 `shoot` 下一 tick 首跑。在已有 async 或后续 async 再生任务等复杂结构中，仍须按链顺序核查，不能推广成所有创建都相同。

## conversion-examples.md：带地址的原始说明

以下保留整理前的记录；其中“本轮/当前”指原记录时点，不是新任务要求。

依据 `LaserInfinite__initialize 0x44c870`、`LaserInfinite__on_tick 0x44cae0`、管理循环 `0x448760`：出生状态3，timer=0；每tick先执行状态分支，再由管理循环递增timer。按固定dt=1、无冻结，且以出生后第一次激光tick为 age=0：

## 试用后同步：普通圆体碰半径

Sol试用指出enemy-state仍保留早期“体碰换算未核”。[首卡试产记录](2026-11-05-th18-first-card-trial.md)的“首次worker阻塞后主会话补核”已记录：TH18普通圆分支从EnemyData+0x118取体碰宽度、乘0.5后传给碰撞函数；body48×48对应r=24。原地址/常量及Listing定位保留在该记录第98行附近。2026-11-07将这一已核普通分支同步到规则书，明确24×24对应r=12；不外推矩形、旋转或自定义判定，没有重新逆向或新增近似。

## 405与407的编号纠正

2026-11-07，用户要求核清插值章节的“407 moveVelTime”。本机TH18 eclmap明确为405 moveVelTime（ABS）、407 moveVelRelTime（REL）。五面首符原文st05bs:638/640/642/644使用moveVelTime，故实际为405；旧试产记录、审核说明及教材将其记成407，历史记录中的这一编号应按此纠正。

主会话只读既有renkolab `local/th18.v1.00a/state/data/functions.jsonl` 中addr=00430d30的导出：case 0x19是压缩跳表的内部case号，不是ECL opcode；该处理按原opcode 0x195（405）选择ABS状态，REL分支使用另一组状态，镜像条件同时识别0x195/0x197（407），之后共用角差处理。旧 `transcribe/work/th18/stage05/th18_s5_b2/review-main/short-arc.listing.txt` 的0x432388–0x4323d8及short-arc-read.log确认绝对角差与π比较、给较小端点加2π。两者普通分支的最短弧结论成立，纠正的是编号/名称和样本归属；不新增对mode7/8、全部镜像或其他特殊组合的承诺。

本次未新开逆向工程或修改引擎、卡代码，也未重跑训练/卡验收。规则正文只保留名称、层归属及可用结论。


## 三层参考结构与参数来源核对

2026-11-07，用户确认一份指令表、一份总体纲要、各子系统专题。`instructions.md`改为原作参数字典，`README.md`管总体模型和查询顺序；旧索引中的转换限制归入基础语义、敌状态、移动、发射器及EX专题。专题的可编译教学程序保持不变，EX／激光的重复签名表改为链接唯一指令表。

参数名称对照本机eclmap（f146162e330c27d1b0a8880c3a41884615147a11）与当日读取的Priw8 `js/ecl/ins.js`；参数类型另核本机thtk（892114a0fcaa0bbdaaecf3cb4ad56f758683fb40）的TH18格式回退链。社区继承条目单独标注，不提升为TH18原生全验证。本轮没有新逆向、模型调用或原作动态对拍。

- 91/92变量插值参数和上下文归属来自既有引擎公开参考 `docs/stateful-interpolation-reference.md`；91配置写start及帧尾推进来自二面首符已核记录，已回填插值专题。
- 92语义为八参，但本机thecl格式只有 `SfSSff`；713已有本作／社区两参记录，但本机thecl格式为 `S`。指令表保留冲突，不更改工具或推断缺失值。普通六面保留文本没有math92调用；未知输入是否受此影响需准备时判断。
- 完整性检查以本机eclmap的315个名字加94/574两条未命名指令为范围，共317条；这表示可查条目数量，不表示全部语义或目标支持已核。
- 已批准的掉落省略和STEP单段特例已同步到摘要，避免旧限制覆盖新结论。原作参数定义、目标配方和历史调查继续分工维护。
