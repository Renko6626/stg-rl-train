# TH18 转写教材与参考

从 [TH18 → stg-engine ECL 转写入门](mapping.md) 开始。主文按两边语法、时间/任务、移动、发弹、EX、激光、完整攻击和验证的顺序教学，代码为自写合成例；大编号表独立保存。

2026-11-05已接入ENGINE_VER31 / wheel0.4.5的新弹型大表，TH18全部48型有独立名字、原作基础半径和普通态静态贴图；新卡查[本作词表](bullet-types.md#48种弹型的新词表)，直接使用原作color。旧卡不自动迁移，碰撞算法选择不阻塞转写；[接入记录](../../docs/investigations/2026-11-05-touhou-bullet-catalog.md)列实际验证与视觉/动态几何边界。

| 按需查阅 | 内容 |
|---|---|
| [高版本切分指南](splitting.md) / [切分契约](contracts/split.md) | 从main恢复编排，按符卡声明和中断链划分攻击，交接依赖与入口状态 |
| [普通指令索引](instructions.md) | 常用opcode、处理方式及具体配方位置 |
| [敌人状态与段入口](enemy-state.md) | 判定/flags、移动组合、子敌与攻击前置状态重建 |
| [完整转换案例](conversion-examples.md) | 时钟循环、共享发射器与原作激光配置的双语法转换 |
| [统一转写口径](transcription-policy.md) | 已确定规则、需明确的物理差异和曲线激光暂缓范围 |
| [单元编号与验收](validation.md) | 卡目录、元数据、validate 命令与 TH18 预算规则 |
| [弹型表](bullet-types.md) | 48种原生type、颜色、目标appearance及半径/外观差异 |
| [瞄准与发射模式](aim-modes.md) | mode0–12的几何、速度、抽样/创建顺序与实际配方 |
| [插值模式](interpolation-modes.md) | mode0–31到EASE名称或accum/accel/Hermite状态槽 |
| [EX效果](ex-effects.md) | 30项原始type、参数语义、方向哨兵与目标组合 |
| [激光](lasers.md) | 700–714、Line/Infinite/Curve、碰撞几何及生命周期 |
| [主会话skill](../../.claude/skills/th18-transcribe/SKILL.md) | 阅读和派发入口，工具边界与交付规则 |
| [转写契约](contracts/transcribe.md) / [审核契约](contracts/review.md) | 单攻击作者与独立审核者的输入、权限、产出及检查 |

2026-11-05：[验证记录](../../docs/investigations/2026-11-05-th18-textbook-verification.md)列本轮编译与运行结果；[资料与结构准备](../../docs/investigations/2026-11-05-th18-textbook-preparation.md)保留来源筛选经过。原作功能有证据、目标语法可用、完整攻击等价分别判断。表中候选替代和判定差异不自动成为已接受近似；mode11/12调速、部分EX字段及曲线等缺口见各页。

**曲线激光暂时不做。** 实际依赖Curve的攻击报告blocked并暂缓，不删掉曲线或替换为多根短线；只影响对应攻击。直线激光按已核范围继续。

读原作时先区分ECL opcode、发射器id、弹型type、EX程序槽index、EX type。不要套TH06的x减192、色号、自动发射或统一激光宽度换算；旧TH18原型全部用appearance0的行为也不是正式映射。

## 从整关切分到单攻击写审

尚未划定攻击时，先按[切分指南](splitting.md)及[split worker契约](contracts/split.md)准备一关的原文/摘要，产出人工或AI审阅用的 `split.md`。Boss以符卡声明和中断链定位，道中按创建事件编排；恢复入口状态并记录重叠/暂缓。当前没有对应自动切分或TH18机器覆盖检查。

用户已确认：道中Boss击破速度奖励编队可作为Boss后的完整独立波。Stage01 W05采用该训练切分，不按原作击破时刻筛掉部分出怪；内部时序/参数与其余行为照原文保留，详见[已批准口径](splitting.md#已批准击破速度奖励编队独立成波)。

## 单攻击准备与写审

主会话先在 `transcribe/work/` 下为本次攻击准备独立目录，用 `brief.md` 说明原作版本与源路径、入口与依赖、rank、时间窗、源帧/卡帧对应、目标弹型/判定方案、已接受差异和实际工具路径。原文放 `source.txt`；弹型表、EX 条目、内建速查与 xform 语法片段须以可读路径或副本交给 worker。

作者按转写契约产出 `out/main.ecl`、`meta.toml`、`report.md`，审核者在自己的任务目录按审核契约读原文、实测锚点并写 `verdict.json`。更新映射后，刷新本次待派发/复审的参考副本；旧审核输入与结论保留，不因文档更新改状态。默认后端与独立审核、Opus 抽检及逐条复核要求沿用项目约定。

只核本单元实际用到的未解机制。出现尚未指定的目标弹型近似、缺失依赖或关键语义不明时，由主会话补方案或证据，不让 worker 用旧 TH06 规则填空。

## 当前验证范围

`stgtranscribe.validate` 已支持 TH18 单卡：使用 `th18_s<关>_<w|mb|b><序号>`、`source="th18"`，运行编译、各档 harness、元数据/外壳检查与开场安全，详见[编号与验收](validation.md)。TH06 规则保持；TH18 不套旧 3000 帧/1024 弹预算，实体池耗尽仍报错。

自动验收通过后仍须使用 harness `--at` 做独立原文数值审核，不代表已完成原作动态对拍。`stgtranscribe.pipeline`、摘录器和 `split_check` 仍是 TH06 专用；TH18 批量切分、自动收卡、训练接入及尚缺的动态几何支持另行推进。
