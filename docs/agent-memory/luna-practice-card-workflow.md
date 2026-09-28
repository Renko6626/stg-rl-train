---
name: luna-practice-card-workflow
description: Luna 合成练习卡写作、严格机器验收、独立 Luna 审查与哈希冻结约定
metadata:
  type: feedback
---

2026-09-27 用户提出后续练习卡生产计划：dispatch 大量 Luna 子代理写弹幕脚本，采用「编写 → 自动校验（语法和参数）及另一个 Luna 模型审查 → 返工」循环。

- 编写前读取 `/data/sunyunbo/www/stg-engine/.claude/skills/writing-danmaku-ecl/SKILL.md`，检查并按需补充激光内容。
- 编写与模型审查由不同 Luna 子代理承担；自动校验与模型审查结合，不互相替代。
- 初次提出时只是后续意向；同日后续用户明确授权10张合成激光变异试产。该授权不等于以后自动启动任意大批次/训练/提交。
- 此计划针对新增练习卡；没有提出更换现有原作转写后端，或取消原作转写已有的 Opus 抽检要求。

相关：[Astra 委派代码执行工作](astra-delegates-code-work.md)、[原作转写 worker 与抽检约定](transcribe-claude-worker-fallback.md)。

## 2026-09-27 试产后确认

- 新合成卡独立cards-synthetic/，显式配置才合并；原cards/和历史T0/T1池保持。source='th06'加载为original，synthetic显式标记并保留base_card/provenance；未知来源不冒充原作，标签不喂策略。
- 底子排除留出及同源source_ref区间（含共享helper）；不改变原作历史划分。随机overlay消费共享RNG，代码保留不意味着同seed逐帧原弹相同。
- 采用main根伴生overlay，避免新增敌人改变enemy token/跟点目标。main只有一条标记入口，删除后逐字还原底子。
- 每卡/每批最小上下文，fork_turns='none'并显式model/reasoning_effort；只传冻结契约、规格、路径和验收命令，复用底子hash/摘要但review仍查真实overlay与组合。
- 作者先compile/规格自检后READY/FROZEN，机器和另一Luna审查绑定当前文件SHA；文修也使旧pass失效。机器不能只看退出码，要明确判断诊断计数与字段存在性。
- 疑似语义问题先查手册/小探针，再要求作者修改。int as fx是×65536数值换算；只有angle cast位穿透，不能传播本轮曾撤回的误报。
- 当前10卡字段完整、JSON无重复、tl前回收及来源字段由独立review逐卡保证；通用validator的4项强门尚待下一批前硬化。不得把机械合格当作可躲/训练收益证明。
- 本session4槽含root是2026-09-27运行观察，不是普遍硬上限；CLI/Responses并发入口和CSV Agent Jobs的已知/待确认边界见复盘，不按残留字符串假定可用。

详细证据与后续任务队列设计：[试产复盘](../practice-cards/2026-09-27-pilot-retrospective.md)、[契约](../practice-cards/laser-pilot-contract.md)、[验收清单](../practice-cards/README.md)。

## 2026-09-28 第二批反馈与结果

- 用户明确判断：扩充激光卡的成本低于跑弹幕训练实验，要求先沿已试产流程派出大量 Luna 子代理开卡。该授权覆盖本次第二批制作与验收，不等于以后自动启动训练、提交或推送。
- 本批 10 个 Luna 作者各拥有一个底子上的 v2/v3 两张新卡，新增 20 张；另一个 Luna 硬化验收器，非作者 Luna 交叉审查。最终 20/20 新卡双门通过，连同旧 10 张机器门 30/30 通过。批次证据见[第二批计划和完成记录](../practice-cards/2026-09-28-batch2-plan.md)及[验收汇总](../practice-cards/reports/batch2-acceptance-summary.json)。
- 审查确实抓到机器采样未覆盖的角度 `int as angle` BAM 量级、相位、轮数、完整随机范围及 TASK 文案错误；按作者返修、机器重跑、原审查者复审闭环。后续扩量继续保留独立审查，不把机器 PASS 当作最终通过。
