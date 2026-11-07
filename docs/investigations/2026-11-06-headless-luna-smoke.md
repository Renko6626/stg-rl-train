# 新headless入口的Luna实跑

2026-11-06。用户要求实际派发Luna，检查任务接收、TH06/TH18资料读取与交付。使用两份已有原文摘录，各跑一个作者和一个独立审核会话，共四次模型调用；没有重开旧批次或收卡。

## 输入与调用

- TH06：`th06_s1_w03`，timeline 1554–1762和Sub0，四档难度。
- TH18：`th18_s1_w04`，MainSub03与GirlD01/GirlD01_at，四档难度。
- [任务清单](../../transcribe/work/headless-smoke/20261106-luna/tasks.json)；输入、参考副本、日志与产物均在该批次目录，原文不入库。
- 作者、审核均使用官方 `codex exec --sandbox workspace-write --model gpt-6-luna -c 'model_reasoning_effort="medium"' --json -`，stdin接收新入口组装的提示词。每次独立会话，没有native subagent或MCP派发，也没有dsh-flash。

实际命令：

```bash
UV_CACHE_DIR=/tmp/stg-transcribe-uv uv run --frozen python transcribe/run.py \
  transcribe/work/headless-smoke/20261106-luna/tasks.json --jobs 2 --timeout 900
```

退出码1：TH18审核拒绝，非进程/编译故障。四个CLI均正常退出。详细[验收记录](../../transcribe/work/headless-smoke/20261106-luna/acceptance.json)保留调用、thread、实际读取命令、用量、文件修改、机器报告与审核结果。

## 验证结果

| 检查 | TH06 | TH18 |
|---|---|---|
| 正确收到任务id、入口和范围 | 是 | 是 |
| 实际读取本批作品资料 | 成功读取mapping、契约及引擎参考 | 成功读取mapping、policy、发射模式、弹型、插值等 |
| 约定位置交付main.ecl/meta/report | 是 | 是 |
| 完整validate | 四档通过，峰值0/0/0/36 | 四档通过，峰值72/72/72/701 |
| 独立Luna审核 | pass，存在漏检 | fail，拦住两项major |
| 主会话接受为可收卡成品 | 否 | 否 |

“读到资料”有CLI实际命令和成功输出支持，不只依据作者报告。完整机器验收只由外层执行器运行一次；独立审核运行数值锚点，没有重复整套validate。

## 语义问题

TH06作者把原文累计切换时刻40/120/220误写成40/80/100：两个转向循环分别只有40和20帧，应为80和100帧。这是明显改变轨迹的错误。Luna审核重复同一误读并给pass；有三条锚点和运行命令仍不能保证其期望独立且正确。审核还将末批坐标期望与实测的较大差异解释成首帧误差，证据不足。

TH18作者把`etAim(2)`自机狙环写成扇形，Luna审核通过角间隔实测抓到该错误；也抓到后段速度插值应为二次而代码为线性、作者报告却声称正确映射的矛盾。主会话另外发现Normal/Hard参数分支缺失、单层速度取错，以及真实敌被设置ENEMY_NO_BODY等问题；审核的两项发现不足以覆盖所有返工事项。

两张卡的机器通过证明可编译运行和外壳检查通过，不证明忠实转写。TH06的原始result保持`reviewed`以保留流水线实际结果，但本次主验收明确拒收；不得据此自动收卡。

## 结论与边界

新入口能派发真实Luna，输入、参考资料、产物和审核交接均贯通。此次样本不支持把“Luna作者＋Luna审核”当作可靠的自动验收组合。低成本作者仍可用于产草稿，正式生产需要能独立核清源语义的审核；不能通过加更多JSON字段或重复编译掩盖这个问题。

本轮仅报告测试结果，未替作者修卡、未重新派发、未扩大样本、未改引擎/训练、未提交推送。CLI启动时继承了本机全局MCP配置并出现连接警告，但没有阻塞这四次执行；流水线自身没有依赖MCP。这是启动环境噪声，未因此引入新配置框架。
