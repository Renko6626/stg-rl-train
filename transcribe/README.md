# ECL 转写与独立审核

一份任务清单，一个命令。执行器按卡依次启动作者、完整机器验收、独立审核；卡之间并发。作者和审核者都是新的headless会话，失败停止该卡，不自动重试或换模型。

## 运行

使用项目锁定环境，准备好官方CLI的登录/模型配置及stg-engine release harness。命令中使用当前账号支持的模型名。

```bash
uv sync --frozen
uv run --frozen python transcribe/run.py transcribe/work/batch/tasks.json --dry-run
uv run --frozen python transcribe/run.py transcribe/work/batch/tasks.json --jobs 6
# 指定卡返工：重新执行完整链，保留旧代码和审核证据
uv run --frozen python transcribe/run.py transcribe/work/batch/tasks.json --ids th18_s1_b2
# 分步：write只写，check只验，review先验再审
uv run --frozen python transcribe/run.py transcribe/work/batch/tasks.json --ids th18_s1_b2 --step review
```

`--timeout`是每个agent进程的秒数，默认3600；`--jobs`默认2，按实际资源调整。`--engine-dir`或`STG_ENGINE_DIR`指定引擎位置。同一任务不要同时启动两条命令，运行期间不要手工修改卡或参考；改过代码后重新check/review。Ctrl+C或SIGTERM停止已启动的worker进程组并跳过未开始的任务；正在执行的本地机器验收结束后退出，不再派审核。脚本不自动收卡、训练或提交。

## 一份清单

`tasks.json`示例；dir和references来源路径相对清单。writer/reviewer直接是官方命令的argv数组，单卡可用同名字段替换整条命令，没有模型别名、复杂度分流或参数翻译。

```json
{
  "writer": ["codex", "exec", "--sandbox", "workspace-write", "--model", "gpt-6-luna", "-c", "model_reasoning_effort=\"medium\"", "--json", "-"],
  "reviewer": ["dsh", "--profile", "headless", "--json", "-"],
  "references": {
    "transcribe/th18": "../../th18",
    "engine/docs/ecl-lang.md": "/path/to/stg-engine/docs/ecl-lang.md",
    "engine/docs/ecl-lang": "/path/to/stg-engine/docs/ecl-lang",
    "engine/docs/xform-ops.md": "/path/to/stg-engine/docs/xform-ops.md"
  },
  "tasks": [
    {"id": "th18_s1_b2", "dir": "th18_s1_b2"},
    {"id": "th18_s1_b4", "dir": "th18_s1_b4"}
  ]
}
```

DSH模型由其官方配置决定；不要把旧包装器的`--model/--reasoning/--cwd`传给官方headless子命令。Codex审核也可直接用另一条`codex exec`命令。参数配置文件使用绝对路径，确保切换worker cwd后仍可读。认证沿用CLI自身设置，不把密钥放清单、argv或参考副本。

CLI登录、模型和权限按官方工具配置，执行器不做参数转换。旧版本的具体命令与试跑证据见[DSH记录](../docs/investigations/2026-11-06-headless-dsh-flash-smoke.md)和[QoderCN记录](../docs/investigations/2026-11-06-headless-qodercn-flash-smoke.md)；其中模型名须以当前CLI实际识别结果为准，不默默回退Auto。

执行器通过stdin发送提示词，以子进程cwd选择任务目录，保存stdout/stderr和退出码。它不解析各厂商事件协议；过程退出成功还必须满足交付、机器校验及审核要求。权限由CLI实际配置决定：Codex示例显式workspace-write，DSH沿用其官方profile策略；提示词的文件职责不是沙箱隔离证明。需要交互批准而无法继续时，该任务按CLI失败处理，不绕过批准。

## 每卡材料

```text
batch/
  tasks.json
  th18_s1_b2/
    task.md                  任务说明
    source.txt               带原文件/行号的实际摘录
    card/th18_s1_b2/          唯一工作代码：main.ecl、meta.toml、辅助.ecl
    report.md                作者说明，首行status: done或blocked
    review/verdict.json      独立审核及review/内的数值日志
    result.json              最近一次执行结果和日志位置
    logs/<运行时间>/          输入、调用、验收和旧代码/报告备份
  logs/<运行时间>/            批次清单、参考副本、环境说明和汇总
```

## 准备工作包

操作者先确定单卡范围，再按[任务模板](templates/task.md)填task.md，source.txt保留原文件、行号及必要闭包。TH06沿用[源准备工具](th06/README.md)，TH18尚未切分时用[切分指南](th18/splitting.md)。切分完成只代表边界已定位；派发前还需整理本卡依赖、必需入口状态、时限依据和真实未决项。

作者常规输入只有四类：执行器注入的角色说明、task/source、本作语义与转写规则书、引擎ECL手册。准备者完成以下工作：

- 给出入口、结束边界、难度、必要初始化的值或明确源位置；不预先替作者计算全卡答案。原文优先给本卡闭包，整文件可作为标明用途的备用上下文。boundary.md仅在有额外事实时使用，不要求作者通读整关split和主审履历。
- 指定源/卡时间关系、开场缓冲、时限依据和一个适用外壳。TH18外壳见[卡格式附录](th18/validation.md#训练外壳)；不再把旧引擎rl-card-pool.md作为TH18默认参考。
- task给出两本书在本批references中的实际路径及相关章节线索。通用角色说明已在stdin内，不再复制一份让worker重读；流程README、skill和研究记录不作为作者必读。
- 同批参考复制一次，保留相对结构。TH18默认提供下例文件；其他公开手册按实际使用附入。必要规则不能只在未随包提供的旧notes/研究链接中，缺口先补到规则书或明确交回。
- 确认harness可运行、wheel及参考对应的能力版本，路径和结果在工作包/批次记录中给出。只做已有工具核验，不让每个作者查源码版本或重建工具。
- 已解决的旧“待补”在新task中明确当前结论，真实缺口列影响；已批准简化引用规则书，本卡特殊取舍单列。原文和参考副本留work，不入库。

TH18清单的references示例（将来源路径替换为本机实际目录，目标键维持下面的布局）：

```json
{
  "transcribe/th18": "/path/to/stg-rl-train/transcribe/th18",
  "engine/docs/ecl-lang.md": "/path/to/stg-engine/docs/ecl-lang.md",
  "engine/docs/ecl-lang": "/path/to/stg-engine/docs/ecl-lang",
  "engine/docs/xform-ops.md": "/path/to/stg-engine/docs/xform-ops.md",
  "engine/docs/easing-reference.md": "/path/to/stg-engine/docs/easing-reference.md",
  "engine/docs/stateful-interpolation-reference.md": "/path/to/stg-engine/docs/stateful-interpolation-reference.md",
  "engine/docs/fixed-point-corners.md": "/path/to/stg-engine/docs/fixed-point-corners.md",
  "engine/docs/bullet-catalog.md": "/path/to/stg-engine/docs/bullet-catalog.md",
  "engine/touhou-bullets.ecl": "/path/to/stg-engine/godot/ecl/game/touhou-bullets.ecl"
}
```

TH18规则书入口为references/transcribe/th18/README.md，引擎手册入口为references/engine/docs/ecl-lang.md。普通内建签名查第7篇；xform操作的参数与行为查同包engine/docs/xform-ops.md，保持它与ecl-lang/的相对位置，供第4篇链接访问。书中的维护者/历史链接不必随包提供，也不属于worker查阅范围；作为使用依据的章节和API必须可达。参考目录是查阅库，不是通读清单。其他作品同样使用任务模板和通用角色说明，不复制调度程序。

## 检查与结果

- 完整机器验收由执行器对最终卡做一次，包含编译、各rank运行、段结束、元数据/外壳、实体池耗尽、contract_viol和开场安全。作者只做必要调试；审核不重复整套验收。
- 作者自检、停止条件和报告格式只由[作者说明](contracts/transcribe.md)维护；独立审核、抽查范围和verdict格式只由[审核说明](contracts/review.md)维护。作品知识分别见[TH06](th06/README.md)、[TH16](th16/README.md)、[TH18](th18/README.md)。
- 作者报告blocked时执行器记failed并停止该卡；这是缺口交回，不等于CLI崩溃，也不要求作者强行完成。
- 结果为written、validated、reviewed、failed或cancelled；前三种分别对应已写、机器通过、独立审核通过。reviewed仍是待收卡，不表示原作动态对拍或训练验收。退出码0表示所选步骤全部完成，1表示有卡失败，2表示参数/清单错误，130表示批次被中断。
- DSH审核后的既有Opus抽检和旧批次主会话复核要求保留，不能冒名完成。新模型组合的额外抽检另行明确，不在执行器里硬编码模型层级。

## 既有批次的 Opus 抽检

历史 DSH 审核曾照抄卡内注释作期望值并漏掉严重问题，因此既有批次收卡前的 Opus 抽检和逐条复核要求继续保留。抽检须由实际 Opus 对照原文、检查必要的数值锚点，并逐条处理发现；没有 Opus 就如实标明该项未完成，不能用生成清单或其他模型冒名完成。新模型组合不自动增加同一套审核层级，其额外抽检按当次约定执行。

## 可复现与历史资料

保留任务/source、实际提示词、命令、参考副本、CLI/引擎信息、产物和日志，便于重新执行与追查。云端模型输出不保证逐字一致；外部CLI配置和认证需自行保持，未知版本如实记未知。每次返工将旧代码及报告留在previous，当前可执行代码只有card一份，不做hash、签名或冻结。

旧`pipeline`只保留TH06源准备入口；`codex-batch.py`已退役。2026-11-07按用户授权删除旧工作副本、批次脚本和过程日志，未另存归档；现存待收卡结果见[work入口](work/README.md)及[TH18任务](work/th18/README.md)。历史调查文档保留结论，原work路径可能已删除。以后运行按现行格式留必要输入、结果和检查，不将旧状态当作新流程通过。原文和运行数据仍留work，不入库。

```bash
uv run --frozen pytest -q tests/transcribe
uv run --frozen python -m stgtranscribe.validate <card目录> --json <报告路径>
```

试玩和出图仍用`transcribe/play.sh`与`python -m stgtranscribe.preview`，成品按[cards约定](../cards/README.md)收录。
