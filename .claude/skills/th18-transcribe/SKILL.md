---
name: th18-transcribe
description: Use when preparing TH18 transcription tasks, splitting stages, or maintaining TH18 ECL mappings in stg-rl-train.
---

# TH18 转写入口

本skill供主会话准备和维护使用。已拿到固定单卡任务的worker按注入的角色说明、task/source及两本规则书执行，不重走项目准备流程。

- 准备工作包、选择官方CLI、运行和处理结果：读[统一流程](../../../transcribe/README.md)。
- 尚未划定整关攻击：读[切分指南](../../../transcribe/th18/splitting.md)；派切分worker时使用[切分契约](../../../transcribe/th18/contracts/split.md)。
- 查本作语义或维护映射：从[TH18规则书](../../../transcribe/th18/README.md)定位章节。研究结论由主会话补进规则书后再交作者，不让作者自行逆向。

具体职责只由通用[作者](../../../transcribe/contracts/transcribe.md)和[审核](../../../transcribe/contracts/review.md)说明维护；本页不另定流程、检查或交付要求。
