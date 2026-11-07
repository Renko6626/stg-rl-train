# TH18 历史脚本派发记录

> 后续清理：2026-11-07用户要求优先保留现行格式的转写结果，大量旧work目录和日志已删除。本文正文保留当时事实，旧路径不保证存在；当前目录和保留结果见[工作区清理记录](../../docs/investigations/2026-11-07-transcribe-work-cleanup.md)。

> 旧批次证据保留。新派发使用[统一入口](../README.md)，不要重放下列旧命令；本页的out/card和重复validate是当时流程。

2026-11-06，用户已确认使用薄脚本调用 `codex exec`，默认并发2；常规卡Luna medium、复杂卡Terra high、独立审核Terra high。沿用现有卡格式、教材和单卡validate，不接入TH06批量状态机。

最新执行范围：用户随后将总并发提高到6，并停止85张全量批次，改为先跑一、二面。本批20张新转写（Luna5/Terra15）及独立Terra审核已经启动；两面另有4张成品和2张首批已写审单元。见[当前运行记录](../work/th18/production/stages12-status.md)。作者/审核共用6个名额，三至六面暂不启动。下文的初始并发2及首批两卡命令保留为历史。

## 当前范围

普通六关共94候选：已有6张、可继续准备写审87张（Luna21、Terra66）、用户明确暂缓1张 `th18_s6_b10`。暂缓项保留funcSet/REACT研究缺口，不影响其他卡；不重新编号。Extra和曲线激光仍暂不做。

本轮已实际完成首批2张写审，尚未正式收卡；剩85张待逐卡准备/写审（Luna19、Terra66）。[首批运行记录](../work/th18/production/first-batch-run.md)列实际交付、独立锚点及主会话修正，原始6张成品不变。

当前逐卡分配和证据在[分配表](../work/th18/assignments.md)及[JSON](../work/th18/assignments.json)。分配表用于规划；有完整brief/source的单元才进入执行清单。

有效切分：一至四面用 `transcribe/work/th18/stageNN/split-batch/`，五、六面用 `split-review/`，配套 `review-main.md`；[边界复核](../work/th18/independent-boundary-check.md)补充main、中断链和奖励编队来源。旧稿与研究日志保留，不重新作为未决任务派发。

写审双方须读最新[统一口径](transcription-policy.md)、[圆周/椭圆及94取点](circular-motion.md)和对应契约。运动及ins_94的源语义已补齐；用户接受舍入及零点几像素差异，保留参数意义、主要几何和基础时序。出生阶段、奖励波、跨波尾部等已批准简化继续适用，不在审核中补回。

## 首批输入

| 单元 | 源入口 | 作者 | 独立审核 |
|---|---|---|---|
| [th18_s1_w04](../work/th18/stage01/th18_s1_w04/brief.md) | MainSub03，三个GirlD01 | Luna medium | Terra high |
| [th18_s2_w06](../work/th18/stage02/th18_s2_w06/brief.md) | MainSub05，两个GirlD02 | Luna medium | Terra high |

共用[本批约束及工具证据](../work/th18/production/common.md)，作者/审核任务分别放在单元目录和单元下的 `review/`。作者只写自己的out、card验证副本和checks；审核只写自己的verdict和checks。均不得更改正式cards、引擎或全局资料，也不得再派代理、训练、提交或推送。

首批两路Luna作者及两路Terra独立审核均已实际完成，完整validate及主会话复核通过；产物留在对应任务目录。正式cards尚未收录这两张，不把写审完成记为训练验收。

## 执行与交接

首批以下命令已经执行，保留作调用记录；已有输出会被脚本拒绝覆盖，不要直接重跑。后续每批使用新的清单/任务目录，先dry-run再实际执行：

```bash
python transcribe/tools/codex-batch.py transcribe/work/th18/first-author-tasks.json --jobs 2
```

每张作者交付后，主会话先查实际文件、报告和完整 `out/validate.json`：blocked、validate非OK或缺产物先处理，不能因脚本退出0进入收卡。确认后才派该张独立审核，可用 `--ids review-th18_s1_w04` 选一张；另一张作者尚未结束时无需等待。

```bash
python transcribe/tools/codex-batch.py transcribe/work/th18/first-review-tasks.json --ids review-th18_s1_w04 --jobs 1
python transcribe/tools/codex-batch.py transcribe/work/th18/first-review-tasks.json --ids review-th18_s2_w06 --jobs 1
```

后续审核清单在准备阶段仅检查路径/模型/交付位置；作者文件未就绪时不得实际启动。审核从原文按本卡复杂度独立推导1–3条数值期望，不凑数或追小数末位，最多4次 `--at`，报告实际观察。审核者可在自己的checks中重跑完整validate，不修改作者文件。主会话逐条核对verdict及证据，返工另给明确的新目录，保留旧结论。

脚本每任务留 `logs/<UTC时间>/` 的prompt、invocation、events、stderr、final、result。`process_and_outputs_ok`只表示退出0且声明交付非空；不表示语义通过。脚本拒绝覆盖已有声明输出，不自动重试、收卡或修改规划状态。后续每批仍先补单卡材料，再按既定模型分配执行。

准备检查只覆盖资料、清单和工具；整卡编译、各rank运行、完整validate和数值审核在作者/审核实际交付后进行。收卡与训练另按用户当时的指令执行。
