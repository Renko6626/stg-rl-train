# 官方DSH headless两卡实跑

2026-11-06。用户要求记录QoderCN试跑并测试DSH，随后聚焦输入文本中的难度分叉和栈参数说明。本轮使用同两张卡、原task/source输入和旧版参考副本，未把前两轮产物交给作者，也未在运行中补答案。

## 启动方式

本机官方DSH 0.2.1-rc.3，直接调用`dsh --profile headless --patch <批次配置> --json -`，通过stdin接任务。没有调用自制dsh-flash、MCP或DSH派发skill，共用runner代码未改。

[本次配置](../../transcribe/work/headless-smoke/20261106-dsh-flash/headless.patch.yml)明确设置deepseek-official / deepseek-flash / high。已用官方dump-config仅检查选模字段，确认合成配置一致。本机没有启动环境API key或用户.env，但存在托管凭据，因此按[官方headless说明](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/bundle/headless/README.md#credentials)在本次overlay启用credentials/authorization/deepseek-account；没有读取、复制或输出凭据内容，没有手工改全局选模配置。权限沿用官方workspace-write默认值。

```bash
UV_CACHE_DIR=/tmp/stg-transcribe-uv uv run --frozen python transcribe/run.py \
  transcribe/work/headless-smoke/20261106-dsh-flash/tasks.json --jobs 2 --timeout 900
```

[清单](../../transcribe/work/headless-smoke/20261106-dsh-flash/tasks.json)、[证据汇总](../../transcribe/work/headless-smoke/20261106-dsh-flash/acceptance.json)保留session、命令、读取工具调用、产物、机器结果和审核。本机版本final事件只含type/text，未返回用量，不能据此计算费用或与Qoder credits直接比较。

## 结果

| 项目 | TH06 s1_w03 | TH18 s1_w04 |
|---|---|---|
| 任务/文档读取与约定交付 | 成功 | 成功 |
| 四档机器验收 | 通过；弹峰值0/0/0/38 | 通过；弹峰值60/132/364/567 |
| 独立DSH审核 | pass，两项资料minor | fail，一项语义major |
| 主会话复核 | 本次范围未发现卡行为阻塞问题 | 同意拒收，需返工 |
| 作者耗时 | 808.40秒 | 488.63秒 |
| 审核耗时 | 435.28秒 | 476.11秒 |

四个agent进程均正常退出0；批次退出1是因为TH18审核拒绝。没有超时或自动重试。

TH06正确实现6对镜像＋8对正向、40/120/220帧的转向切换及Lunatic独有的自动自机狙。审核使用源数据推导后核对运行结果。两项minor是：旧unit.note写7+7而source实际6+8；旧契约仍提mapping-excerpt.md/builtins.md，本次提供的是完整mapping和语言参考。两者均未导致本卡语义错误，旧资料未在试跑期间改写。

TH18作者正确处理四档路数12/12/15/12、轮次、环形发射和插值，但把两组压栈值的参数顺序读反，交付速度1.4/1.9，正确首端点应为1.6/2.6。独立审核最终恢复正确栈顺序，结合rank0/rank3的速度及出生退位移实测判major。主会话确认拒收；机器可运行不抵消该错误。

## 用户反馈与说明修订

用户指出：这种已知转换应尽量照表搬运，不应让worker每卡反复调查。实际记录也显示，TH06作者用了较长时间检查细小帧差和补充报告；TH18审核在已有栈规则之外继续追查实现证据。

原TH06教材已有详细难度前缀说明；TH18教材只用一段介绍栈顶，缺少完整难度压栈示例，source.txt头部没有相应提示。现已补[教材§3.4](../../transcribe/th18/mapping.md#34-读反编译时要识别栈和依赖)及[源头阅读提示](../../transcribe/th18/source-header.txt)，两侧契约直接链接；新任务准备时放在原文前，原始指令和行号保持不变。[带提示的source示例](../../transcribe/work/headless-smoke/source-reading-example/th18_s1_w04/source.txt)可直接查看。

修订仅涉及阅读说明，没有新增中间格式、解析器、审核层或自动恢复。旧试跑输入和参考副本保留原样，**新说明尚未进行模型复测**。

## 范围

DSH能完成官方CLI派发、读取、转写、机器验收与独立审核交接；本次仍出现作者取值错误，但审核最终拦住。不能据两张样本推断批量准确率。既有DSH后的Opus抽检没有执行，本轮没有收卡、修卡重跑、训练、引擎改动或提交推送。
