---
name: th06-transcribe
description: Prepare TH06 source excerpts and run the shared headless transcription workflow.
---

# TH06 转写入口

先读[统一流程](../../../transcribe/README.md)和[TH06说明](../../../transcribe/th06/README.md)，语义查[映射](../../../transcribe/th06/mapping.md)。只处理本任务依赖，不扩大到引擎或训练。

源准备继续使用TH06的structure/split_check/extract；新版写审不读旧state.jsonl。所选单元准备task.md/source.txt，保留unit.json、mapping-excerpt.md、builtins.md作为参考并加入批次资料。对照表修订后，新任务使用最新实际资料，旧摘录和旧审核仅作历史。

清单直接填写官方CLI命令，经transcribe/run.py启动，不调用本机dsh-flash、MCP或DSH派发skill。作者直接写card/<id>/，执行器完整验收一次，新会话独立审核。通用职责见[作者约定](../../../transcribe/contracts/transcribe.md)和[审核约定](../../../transcribe/contracts/review.md)，作品特例见TH06 contracts。

DSH审核后的Opus抽检和逐条复核仍保留，依据见[既有批次抽检要求](../../../transcribe/README.md#既有批次的-opus-抽检)。抽检须由实际Opus读原文并做数值检查，逐条处理发现；无Opus就标明未完成。新模型组合不自动继承三层审核，也不能冒名取消旧批次要求。

旧pipeline的status/sample/collect/usage只用于旧生产记录；sample输出不表示抽检完成，collect不表示训练验收。收卡、训练、commit、push分别按当前授权执行。
