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

## 2026-10-01 从零专项批次

- 用户授权大量Luna制作；将全局并发设为16并重启后，运行时实际17总槽（含root）验证；这是本次观察，未来需重新核对。15作者任务生成20卡、独立写审及返工，17张有限样本候选/3 NOT_PROVEN隔离，详见[本批结果](../practice-cards/2026-10-01-batch3-results.md)。不据本次授权自动启动训练/提交/推送。
- 新 standalone schema 必须明确 `synthetic_kind=laser_specialist` 和 `generation_mode=standalone`，有family/layout/split/contract版本，不能伪造base_card/source_ref/provenance。旧overlay契约/机器门继续保留，不挪用“最多新增4条”。新候选目录需显式接入；held-out元数据无条件排除train_starts。
- 发卡前提供已实测骨架：spawn_enemy没有flags参数，第4是drop_table、第6是sprite；boss任务用 `set_enemy_flag(ENEMY_NO_BODY,1)` 禁体碰，hitbox0不能代替。phase从开局开始，90帧开场延迟放在发射编排中；不因main延迟推后整局time_limit。
- 作者READY前必须单卡新版validator真正0errors，不凭退出0/复制其他卡事件填写PHASE_ENDED。不能对父目录--all扫描兄弟卡。关键帧需覆盖state0/1/2、首中末出生、精确自然回收零场与1800零场。
- 真实玩家边界x±192/y0..448。通道自机中心净空=中心线间距−完整激光宽−2×实际半径；本批保守R4.5、高速4.5/低速2、motor约束明确。只堵四角不够，量化槽位也可能留下源码保证的窄整带；检查完整随机参数支持，并将警告/实际生效/有限线段正向范围分开。
- 全部偏角非零的出生狙可能永远打不到静止自机，本批每组加入出生直狙off0，旧线冻结。有限点站桩幸存不等于普遍漏洞；不得为了让80个样本全死做坐标特化。源码范围证明与真实轨迹结合，启发式失败只记NOT_PROVEN。
- 新Rust工具用原始World逐帧稳定index/generation避免VecEnv死亡reset/同计数换线漏测，依赖源码/编译锁/可执行SHA绑定，未改引擎。真实玩家工具保留实际motor、半径、按键与first-done截止；不同控制器/预测窗口须独立标记，不伪装成同一策略或学习成绩。
- 本批候选只表示有限完成轨迹+机器/独立审查；corridor02证据只在rank0/1，sweep01只在rank3，其他未知档位逐卡列出。隔离不代表无解。持久完整轨迹放忽略的runs，不依赖历史tmp路径；历史报告不能替当前SHA验收。
