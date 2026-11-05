---
name: th18-transcribe
description: Use when splitting TH18 stages into attacks, preparing or reviewing ECL AI transcriptions, or maintaining their mappings in stg-rl-train. TH06/NC batch transcription uses th06-transcribe.
---

# TH18 原作 ECL 转写

整关尚未划分攻击时，先读[高版本切分指南](../../../transcribe/th18/splitting.md)与[切分契约](../../../transcribe/th18/contracts/split.md)。以本作符卡声明定位Boss卡，再沿中断链补齐非符；道中从main编排切波次。输出人工/AI审阅用的split.md，保留依赖、入口状态与重叠；不调用TH06 split_check。

已确认用于道中Boss击破速度奖励的编队，用户已批准作为Boss后的完整独立波；保留内部时序/参数，原作F门条件不再阻塞该波切分。Stage01 MainSub05/W05及适用边界见[切分指南](../../../transcribe/th18/splitting.md#已批准击破速度奖励编队独立成波)。

用户已确认道中波次尾部重叠可暂分开训练，不必携带前波残留或强制合并；保留本波内部完整行为，记录训练隔离差异。切分身份/依赖已明确与目标实现仍待补要分开报告。

波次/阶段交接的精确位置与收尾暂不作为切分阻塞；纯表现、普通掉落/奖励、计分统计按[省略口径](../../../transcribe/th18/transcription-policy.md#系统性省略与外壳接管)处理。当前攻击内部的运动/判定/发弹保留，不按ANM或unknown名字直接删机制。

单攻击转写按下文阅读和派发。

先读 [TH18转写教材](../../../transcribe/th18/mapping.md)，学习两边语法、时间/任务、移动、发弹、EX、激光与检查方法。再按当前攻击查表，不能用派发流程代替语义知识：

- [弹型/颜色/判定](../../../transcribe/th18/bullet-types.md)
- [瞄准与发射模式](../../../transcribe/th18/aim-modes.md)
- [插值模式与状态槽](../../../transcribe/th18/interpolation-modes.md)
- [EX参数与目标配方](../../../transcribe/th18/ex-effects.md)
- [激光几何与生命周期](../../../transcribe/th18/lasers.md)
- [普通指令索引](../../../transcribe/th18/instructions.md)、[敌人状态/段入口](../../../transcribe/th18/enemy-state.md)
- [完整转换案例](../../../transcribe/th18/conversion-examples.md)、[统一转写口径](../../../transcribe/th18/transcription-policy.md)

写、审分别使用 [转写契约](../../../transcribe/th18/contracts/transcribe.md) / [审核契约](../../../transcribe/th18/contracts/review.md)。原作摘录和临时验证留在 `transcribe/work/`，不入库。

派发前按[单元编号与验收](../../../transcribe/th18/validation.md)固定 `th18_s<关>_<w|mb|b><序号>`，任务单给最终 `unit_id` 和可写 `card/<unit_id>/`。作者保留 `out/` 交付，同步验证副本后跑共用 validate，附 `out/validate.json`；不能用 `out` 目录名直接验收。

## 当前工具边界

目前可按指南准备人工/AI整关切分记录，并委派单个攻击写审；共用 `stgtranscribe.validate` 已支持 TH18 编号和 `source="th18"`。TH18 时限允许到引擎 65535 帧上限，不套旧 3000 帧/1024 弹预算；池耗尽仍报错，完整验收包含开场安全。自动通过后仍须独立数值审核。`stgtranscribe.pipeline`、摘录器和切分检查仍是 TH06 专用，没有 TH18 批量命令。

**曲线激光暂时不做。** 所选攻击实际依赖 `711 laserCuOn` / Curve几何时写 `status: blocked`、注明位置并暂缓；不删曲线、不用短线替代。其余独立攻击继续。

新卡使用ENGINE_VER31及以后表中的`TH18_*`词表和原作色号；弹型/碰撞处理及出生阶段省略分别遵循[已批准口径](../../../transcribe/th18/transcription-policy.md#已批准按作品区分弹型碰撞算法选择后置)和[出生口径](../../../transcribe/th18/transcription-policy.md#已批准省略出生减速和无判定窗口)。静态基础表不代表动态半径/缩放写口已支持，派发时按实际使用的机制交代范围。

## 派发前

主会话为本次攻击准备独立的 `transcribe/work/` 子目录和只读输入，任务单写入 `brief.md`：

- TH18 版本、原始文件路径、入口 sub/起点、原作摘录及依赖闭包（call、async、ecli、EX 创建的子敌）。明确本次 rank、时间窗、源帧到卡帧的对应，缺失依赖先补。
- 按 [弹型表](../../../transcribe/th18/bullet-types.md) 列出实际使用的 type/color和 `TH18_*` 常量；附生成词表文件或所需定义，核对同批表的半径与有效色槽。不要用旧12形别名代替新本作弹型，也不套旧8色换16色规则。原作48/49等本作未核编号仍先查，不能全部替成appearance0。
- 附 [EX 表](../../../transcribe/th18/ex-effects.md) 及本次涉及的详细条目，保留原始 type、槽 index、async、参数和配对记录。只核本单元命中的未知项，不要求先解完所有 EX。
- 给出已核版本的 harness、内建签名速查和 xform 语法片段。新弹型表要求ENGINE_VER31及同批wheel；此前0.4.4/30只有旧192项。执行前分别核实源码、harness、已安装wheel，不能用历史版本号代替现场核验。
- 交代训练外壳、段结束、开场缓冲、产出及验证目录的可写范围；反馈和已接受近似一并传入。沿用现有卡格式，`meta.toml` 的 source 如实写 `th18`，完整验收不使用 `--skip-rl`。

原作摘录永不入库。可以复制本次用到的参考到任务目录，也可以给出 worker 可读的完整路径；两种方式都须让 worker 实际拿到资料，不能只在主会话读过。复制资料时记录源路径与版本，复审用更新后的输入，保留旧审核结论。

## 转写和审核要点

将本攻击涉及的语义参考交给写审双方：作者按[转写契约](../../../transcribe/th18/contracts/transcribe.md#转写)恢复行为，审核者按[审核契约](../../../transcribe/th18/contracts/review.md#核对)独立核对。弹型、发射器、EX参数和取样规则由上面的主题资料维护。

未知语义、未支持机制或超出已接受范围的近似须写清具体影响，交主会话分诊；不擅改引擎，也不凭“编译通过”删掉出生位移、碰撞门、缩放或曲线几何。

## 写审与交付

写、审分开，worker 只写任务单指定目录。默认后端沿用 dsh-flash；按既有约定用 Sonnet 时并发 4。通过 DeepSeek Harness 委派须先读 dsh-subagent；不要因本次文档准备自行换后端或启动一批任务。

作者先做目标程序编译/运行自检；审核者从原文独立推导数值锚点，并核效果进入前后和随机共享，不能抄卡内注释当期望。原作侧映射相同、目标运行通过、语义审核通过分别报告。dsh 审核后的 Opus 抽检和逐条复核要求保留；无 Opus 时如实保留待办，不能用别的模型冒名完成。

发现映射缺口先回查 [原生比较报告](../../../docs/investigations/2026-11-05-th16-th18-ex-comparison.md)。确需进一步逆向时复用 renkolab 的 Ghidra 命名、类型、HTML/JSONL 与只读 driver；不要自行反汇编或重复建库。不要为每个写审 worker 另起逆向流程。

收卡、批量接入、旧卡迁移、训练、提交和推送均按用户当前任务范围执行；本 skill 不代表已授权这些动作。
