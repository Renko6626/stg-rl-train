# 合成卡作者契约

先读任务目录的brief.md与提供的目标ECL参考；只写任务单指定的out/和临时验证目录，不修改引擎、训练代码、其他卡或任务状态，不启动训练或另派worker。

实现任务指定的弹幕设计。有底子时保留其来源和明确要求保持的行为；从零创作不伪造原作引用。未指定的重要行为或需要引擎新增机制时报告具体缺口，不自行扩大功能。

交付main.ecl、必要辅助ECL、meta.toml及简短report.md。meta填title、source="synthetic"、ranks、marks、time_limit、tags；从零生成加generation_mode="standalone"，底子变体给base_card。report记录实现要点、实际运行结果和未完成项。

执行当前harness的check与覆盖设计所需rank/时长的run，检查运行错误和段结束。若需数值锚点，先由设计要求写预期，再看少量--at输出。修改后仅补受影响的检查，不新增hash/冻结流程。把代码与实际日志交给独立审核者，作者自检不能替代审核。
