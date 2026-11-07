# QoderCN DeepSeek-Flash 两卡实跑

2026-11-06。用户要求用qodercn试同样任务，随后明确禁止Auto选模，指定deepseek-flash。使用qodercn-dispatch技能核对本地用法，实际经项目共用runner派发官方CLI，没有新增后端或包装器。

## 选模核验

本机QoderCN 1.1.84。官方CLI支持`-p`、stdin及`stream-json`，见[官方用法](https://docs.qoder.cn/en/cli/run-in-scripts)。

最初两路Auto作者在用户纠正后已终止，协调进程退出130，两个worker均已退出。之后显式传显示名`DeepSeek-Flash`的两路也因实际启动事件仍为Auto而终止；单独小写`deepseek-flash`探测同样退回Auto。这些中止结果不作为Flash测试结果。

本机CLI内部日志明确记录“model不在列表、退回auto”，但`--list-models`又列出DeepSeek-Flash。通过官方TUI的只读会话核对，内部标识`dfmodel`对应界面上的 **DeepSeek-Flash / High / 1M context**，未提交模型任务或修改全局选模。随后四个正式headless会话的init事件均明确报告`model: DeepSeek-Flash`；用量归到`dfmodel`。

已验证的命令数组：

```json
["qodercn", "-p", "--model", "dfmodel", "--permission-mode", "auto", "--output-format", "stream-json", "--no-session-persistence"]
```

permission-mode的auto只负责工具审批，不负责选模型。此内部key是本机该版本的实测结论，升级后应核对实际会话模型；不能仅凭argv或模型列表认定选模成功。

## 任务与执行

沿用[Luna实跑](2026-11-06-headless-luna-smoke.md)的TH06 s1_w03、TH18 s1_w04，复制相同task/source/unit输入到空目录，不提供Luna或中止Auto批次的卡作为答案。两路并发；每卡依次执行作者、完整validate、新会话独立审核。CLI自身上下文和推理配置不同，这是工作流程的小样本对照，不是控制变量的模型基准。

```bash
UV_CACHE_DIR=/tmp/stg-transcribe-uv uv run --frozen python transcribe/run.py \
  transcribe/work/headless-smoke/20261106-qodercn-dfmodel/tasks.json --jobs 2 --timeout 900
```

[清单](../../transcribe/work/headless-smoke/20261106-qodercn-dfmodel/tasks.json)、[汇总证据](../../transcribe/work/headless-smoke/20261106-qodercn-dfmodel/acceptance.json)包含实际命令、模型、进程退出码、文档读取、用量与审核。原文和过程资料仍留忽略的work目录。

## 结果

| 项目 | TH06 s1_w03 | TH18 s1_w04 |
|---|---|---|
| 作者/审核模型 | 两次均确认DeepSeek-Flash | 两次均确认DeepSeek-Flash |
| 任务、参考读取、约定交付 | 成功 | 成功 |
| 四档机器验收 | 通过；峰值0/0/0/38 | 通过；峰值57/122/277/528 |
| 独立审核 | pass，无findings | fail，一项major、一项minor |
| 主会话复核 | 本次范围未发现阻塞问题 | 确认拒收，应返工 |

TH06正确保留出生后40/120/220帧的转向切换，两个持续段为80和100帧，没有重犯Luna的40/80/100错误。作者还按原文数出6对镜像、8对正向共28只，指出旧unit.note的7+7概述有误。独立审核从源参数计算位置，再用四次--at核对出怪、运动、Lunatic自机狙与出界退场；主复核确认关键转换。正文注释“E/L两档”是概述不准确，meta与代码实际覆盖0–3四档；不影响本次行为结论。

TH18正确实现环形发射、四档轮次/间隔、单层速度1.6/2.6、二次插值、出生退位移，真实敌保留体碰。但作者把Lunatic路数写成15；源`!LO`分支是12。审核在rank3/frame186测到三敌45颗、24°间距，而源应为36颗、30°间距，明确判major并fail。它还指出卡注释的出生帧122应为实测124（minor）。主会话同意拒收，没有用机器通过覆盖语义错误。

流水线最终退出1，原因是TH18审核拒绝；四个agent进程均退出0。TH06写/审约307/367秒，TH18写/审约503/430秒。CLI报告这四次合计 **39.064614 credits**，不包含此前中止的调用；`total_cost_usd=0`不能解释为免费。每卡仅由执行器跑一次完整validate，两位审核各使用四次--at。

## 结论

共用runner无需改代码，只换命令数组即可使用QoderCN。此次两张样本上，DeepSeek-Flash作者及审核的表现好于Luna组合：TH06通过，TH18作者仍犯错但审核有效拦截。只能支持继续小批使用的判断，不能据此推断整批准确率或取消独立审核。

未修卡重跑、未收卡、未训练、未改引擎或提交推送。额外操作仅为查询帮助/模型列表、核对选模并停止误选进程。后续使用本仓QoderCN时遵循用户选择：固定DeepSeek-Flash，不自行切Auto。
