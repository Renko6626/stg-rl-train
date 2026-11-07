# 转写工作区清理

2026-11-07，用户明确要求多删除、少归档，优先保留现行干净格式的转写结果。此次直接删除旧产物，没有搬到另一份archive或隐藏备份；仅在替换目录期间暂存将要保留的文件，完成后临时目录已消失。

## 保留结果

- 正式卡池不变：TH06 166张、TH18 6张。
- [work/th18](../../transcribe/work/th18/README.md)按每卡task.md、source.txt、card/<id>/、report.md、checks/及已有review/组织，只有一份工作代码。
- 87项待处理任务：74 written、10 reviewed、3 failed。另保留用户明确暂缓的s6_b10输入，并排除出运行清单。总计88个任务目录，86份main.ecl。
- written仅代表作者交付；reviewed为旧独立审核pass，仍待正式收卡/必要主复核。迁移没有重新验收或升级状态。
- s4_w08选用较新的Sol试用产物；旧DSH同卡重复结果删除。s3_mb1和s6_w08保留未通过/未完成草稿，s5_b4只有输入；后两项没有恢复授权。
- 旧布局中独有的10份TH18已写审结果已迁出保留。六张正式TH18成品的工作副本删除，正式目录未改。
- 保留各关解码原文source-context/和最终切分splits/；源边界中的旧待补标识加历史说明，不作为当前作者的新任务。保留preview/bullet-catalog.png。

## 删除范围

旧TH06 units/review/logs/split/state及sample文件；旧预览GIF；th18-prototype（含Rust target、重复轨迹和旧原生摘录）；headless-smoke各模型试跑；wheel-upgrade回放中间件；dsh-cli-research、旧archive、play状态文件；TH18旧stage目录、production脚本、研究目录、重复out/card、模型原始会话日志及参考副本。

TH06旧工作区未收卡的10个单元没有.ecl转写代码；不存在被删除的唯一TH06目标成果。TH18保留卡代码在删除前与选定来源逐文件比较：188个.ecl/meta文件内容完全相同，未通过重写代码改变行为。清理不触碰renkolab原始资料或DSH自身会话库。

旧研究/交接文档仍记录当时发现，但其中已删除work路径不再可复跑；这属于本次用户授权的取舍，不伪称已保留全套历史证据。

## 体量与检查

清理前10,735个文件，1658.61 MiB；清理后约1,067个文件，6.72 MiB，减少约1.61 GiB。

- 新清单 `uv run --frozen python transcribe/run.py transcribe/work/th18/tasks.json --step check --dry-run` 成功，解析87项。仅dry-run，没有运行卡验收或启动模型。
- 检查了保留卡的原文/任务/报告、代码字节一致性、正式卡数量、参考与原文路径。
- 删除前未发现使用work目录的活跃任务；旧协调器和两个暂停PID已不存在。
- 未启动训练、独立审核、正式收卡、提交或推送；没有扩展执行器、数据库或归档框架。
