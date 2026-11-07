# TH18 Codex 批量切分执行计划

用户已于2026-11-06确认薄脚本方案并要求开始。沿用现有TH18切分与写审契约，在main工作，不提交或推送。

目标：用脚本调用Luna/Terra，先完成普通六关的切分与后续任务分配。输入见 `transcribe/work/th18/batch-preparation.md`；该目录中的原文引用与过程材料不入库。

实现：`transcribe/tools/codex-batch.py` 使用Python标准库读取JSON任务列表，以显式model/effort、cwd和prompt启动 `codex exec`。默认2并发；每次调用分别留下事件、stderr、最终答复和进程结果。失败人工处理，不加自动重试、恢复系统或自动收卡；不改TH06 pipeline或全局Codex配置。已有ChatGPT登录沿用，不新建API凭证。

任务字段为 `id/cwd/prompt/model/effort/outputs`；prompt及outputs相对任务cwd，cwd相对清单位置或为绝对路径。outputs只检查交付存在，不代表源语义通过。日志放任务目录logs下的独立运行目录。

- [x] 实现薄脚本与六关切分清单；检查语法、dry-run、输入路径和模型参数。
- [x] 先运行Stage01（Terra medium），确认真实调用、产物与退出结果。
- [x] 以2并发运行其余五关，检查完成和提前退出；不以外层shell存活宣称模型在工作。
- [x] 主会话按原文复核切分及已收卡排除；整理Luna常规卡、Terra复杂卡、暂缓项，保留未决证据。
- [x] 汇总实际切分结果、运行证据和后续分配。全卡转写完成、收卡和训练不由切分成功推定。

约束：每worker只写指定任务目录；不派嵌套代理；保持已有6张成品编号；曲线按实际可达攻击暂缓；已批准出生/交接/奖励编队简化不重新阻塞。CP932解码原文，行号对应原文件；不新增hash流程。

验证聚焦：任务选择和路径、模型/强度显式传递、真实子进程和交付、失败退出结果。脚本不修改训练逻辑，不启动全量训练检查；切分采用静态源审核，不运行TH06 split_check。后续每卡仍须完整validate和独立数值审核。

执行结果见 [批量准备记录](../../investigations/2026-11-06-th18-batch-preparation.md)。本轮只完成切分与分配，新增卡作者未启动。
