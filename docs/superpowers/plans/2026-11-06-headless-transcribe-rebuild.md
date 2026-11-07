# Headless 转写流水线重做计划

> 执行方式：使用 superpowers:executing-plans 按任务实现；实施不启动付费生产worker。项目的授权、测试范围和禁止自动提交约定优先于技能模板。

**Goal:** 用一个薄命令行入口完成跨作品、大批量作者→校验→独立审核，并保存可重跑的输入与证据。

**Architecture:** Python 标准库执行器加通用argv/stdin进程启动，直接复用 validate/harness。每卡一份目标代码；资料决定作品语义，清单决定批次和模型。

**Tech Stack:** 项目现有 Python 3.12、subprocess、concurrent.futures、JSON/Markdown、pytest；不加依赖。

**Spec:** [已确认方向及设计记录](../specs/2026-11-06-headless-transcribe-design.md)。

## 全局约束

- 在 main 工作；保留现有未提交改动，不创建分支/worktree，不自动 commit/push。
- 不启动新付费批次，不迁移历史生产状态，不触碰已有运行进程或改训练/引擎。
- 不增加 hash、签名、冻结、数据库、插件系统、自动重试/恢复/模型路由。
- 只补关键新增行为或具体故障的测试；不为文档清理新增测试，不以 mock 成功宣称真实模型链通过。
- 保留已接受简化和必要独立数值审核。现有 DSH 抽检要求不因工具统一而消失。

## 代码与文档盘点（2026-11-06）

| 现有位置 | 发现 | 处理 |
|---|---|---|
| `transcribe/tools/codex-batch.py`（113行） | 已有清单、进程、超时、日志；固定 Codex，已有输出就拒绝重跑 | 复用思路，替换为共用执行路径，不叠加第三层调度 |
| `work/th18/production/run-remaining.py`、`run-stages12.py` | 硬编码85/20、关卡和路径；分别加载作者/审核/配对清单 | 新入口支持一份清单后退出使用；保留历史代码/日志供追查 |
| `src/stgtranscribe/pipeline.py`（529行） | TH06 源解析、模型调用、用量、状态、重试、审核、抽检、收卡混在一起 | 新执行器不继承状态机；迁移调用入口后撤掉重复写审路径 |
| 同上 `transcribe_one/review_one` | worker 返回值未用于停止后续处理，已有产物可继续被消费 | 新链以退出成功和本次有效结果为前提，覆盖回归场景 |
| `src/stgtranscribe/validate.py`（256行） | 编译、各rank运行、开场安全可复用；contract_viol只警告；来源/预算有限制 | 定点修正，保留其职责，不重写验证框架 |
| TH18写审契约及批次调度 | 作者完整validate、外层完整validate、审核侧validate；out/card副本逐字比较 | 作者直接写card，执行器负责一次完整验收，审核做源语义/数值 |
| `thecl/structure/split_check/extract/mapping/units` | TH06 方言、摘录注释和闭包已实现 | 保留源准备能力，不伪装成现代ECL解析器 |
| `config.py` | 共用引擎路径仍取TH06配置 | 在新入口显式传/设置现有引擎路径，后续按需要收敛默认配置 |
| `transcribe/th18/` 教材与机制表 | 已有真实转写经验，流程文字散在多个入口 | 保留技术内容，共用流程移到一处，作品页只留特有规则 |
| 根/TH06 README | 仍称wheel0.4.5，pyproject已为0.4.7；总览还说无TH18批量调度 | 区分历史与当前，不在多个入口复制易过期版本和运行状态 |
| `.claude/skills/*-transcribe`、`AGENTS.md` | 同时含旧默认后端、Opus规则、本轮Luna/Terra例外 | 作为入口指向共用流程，历史质量约定明确保留，不冒名完成抽检 |

盘点基于当前文件；工作区有大量既有未提交代码、文档、卡和wheel改动，本轮不整理它们。当前工具沙箱的进程视图不足以确认宿主机旧批次是否仍运行，因此不据此宣称已停止或已完成。

## 验证重点

1. worker 非零退出且目录有旧代码：必须失败，不能进入审核（任务1）。
2. 机器验收失败：不启动审核；审核pass却带major或缺数值证据：不记通过（任务2）。
3. 返工或分步执行：保留旧证据，旧pass不沿用；每次完整链仅做一次完整验收（任务2）。
4. 多卡并发：一张失败不影响另一张成功，活动worker不超过jobs（任务1）。
5. 清单切换TH06/TH18：共用执行逻辑，实际来源/预算按已有validate处理（任务2）。

## 任务1：共用启动器与单清单

文件：新增 `transcribe/run.py`（薄CLI）、`src/stgtranscribe/runner.py`（清单及顺序编排）、`src/stgtranscribe/worker.py`（两种CLI启动）；新增 `tests/transcribe/test_runner.py`，保持简短。

接口建议：`worker.run_worker(cwd, prompt, command, log_dir, timeout) -> int` 返回退出码；`runner.main(argv=None) -> int` 供命令行调用。command为官方CLI的字符串参数数组，不引入后端参数转换、类层级或插件协议。

- [x] 读取本地 Codex/DSH CLI帮助及官方文档；确认dsh-flash为本机包装器，按用户后续要求完全退出新流程，直接调用官方headless，不使用MCP或DSH派发skill。
- [x] 实现一个清单：顶部writer/reviewer配置、任务列表 `{id, dir}`、必要单卡覆盖；路径相对清单，保留id唯一和目标路径有效等直接检查。
- [x] 提供 `--ids`、`--jobs`、`--timeout`、`--dry-run`；没有卡数/关卡硬编码，不自动套旧Luna/Terra复杂度分配。
- [x] 复用现有进程超时与日志办法；每个worker是独立会话，记录实际参数和提示词，不读取/打印密钥。不把不受支持的沙箱权限当作已实现。
- [x] 用临时本地可执行脚本调用真实进程启动逻辑，覆盖非零退出、超时退出和有限并发/单卡失败；不调用付费模型，不新建模拟平台。

## 任务2：单份产物、验收和独立审核

文件：修改 `runner.py`、`validate.py`、`tests/transcribe/test_validate_pipeline.py`；在 `test_runner.py` 补关键链路。新增 `transcribe/contracts/transcribe.md`、`review.md` 通用约定。

- [x] 作者直接写 `card/<id>/`，说明写任务根report；审核工作目录为review，输入只读。组装两份提示词，不把作者会话继续当审核。
- [x] 按“作者→validate.validate(card)→审核”执行，保存完整机器报告；blocked/进程失败/交付缺失均停止本卡，不能读旧verdict充数。
- [x] 保留 verdict/findings/volleys 字段，检查pass无critical/major且至少三条完整数值证据。检查仅证明格式和声明，不宣称证明语义正确。
- [x] 加 write/check/review 分步选择；显式返工前保留旧代码及报告到旧日志，新调用不沿用旧结论。review单独执行时先做本次完整验收；同一全链内不重复做。
- [x] 将contract_viol升级为错误，使用已有诊断测试夹具增加直接行为断言，不为所有诊断另写一套框架。
- [x] 复用已有真实TH06范例及TH18验收用例；在runner测试中覆盖验收失败不审核、无效pass不通过、旧结果不沿用。真实模型审核留待实际试产，不能由替身测试冒充。

## 任务3：输入准备、操作文档及旧入口退出

文件：更新 `transcribe/README.md`、`th06/README.md`、`th18/README.md`、`th18/validation.md`、两作写审契约、根README/AGENTS相关段落；按需将 `.claude/skills/*-transcribe` 收敛成入口。处理旧 `pipeline.py` / `codex-batch.py` 及其直接测试和调用方。

- [x] 提供一份可直接改的清单示例及task模板。任务材料从已有切分/摘录产物准备，不再手写三份执行清单，不要求主会话预解每张卡。
- [x] 批次保存实际使用的参考副本、版本说明和源摘录，重放命令写清环境及本地路径。资料副本每批共享，不生成签名、清单hash或镜像系统。
- [x] 只保留一处通用启动/重跑/失败查看说明；作品文档保留语义、限制、切分和预算差异，删除重复完整验收及out/card同步要求。
- [x] 将旧TH06 split/extract所需调用从旧编排中保留下来，作为输入准备入口；写审只保留新入口。preview/play及已有卡消费端不改。
- [x] 旧收卡/抽检/统计仍有用的操作明确留作旧记录管理，退出新流水线，不把状态JSONL转换为新成功结果。旧batch脚本标为历史，不删除原文和生产证据。
- [x] 删除已退役编排对应的测试时不删除有效验收断言；保留源解析/摘录测试，不扩大到训练测试或GPU。

## 验证与交付

- 局部实现期间运行受影响的已有测试；完整改动集中运行 `uv run --frozen pytest -q tests/transcribe`，失败定位后只补相关检查。
- 用不调用模型的dry-run展示同一入口接受两作任务及两种后端；真实CLI只核帮助/参数可用性，不将dry-run报告成真实写审成功。
- 检查本轮文档链接和 `git diff --check`；报告实际结果和未验证项。真实低成本小批次及随后扩大派发使用明确任务清单，不从历史授权自动重开旧批次。

## 实施记录（2026-11-06）

- 已实现通用argv/stdin执行器，单清单和单份card，旧结论不沿用；返工保留旧代码/报告/机器反馈。旧TH06写审与模型参数转换删除，源准备改用官方dsh，旧Codex包装器退出当前入口。
- 用户纠正后的决定：所有coding agent直接使用其官方headless命令，模型参数由原CLI处理。通用启动器不依赖dsh-flash、MCP或DSH skill；此决定替代早期“两种后端适配”建议。
- 未按技能模板创建worktree、commit或建立复杂工作账本；依项目约定在main保留既有改动，验证集中执行。这份实施记录保存进度。
- `UV_CACHE_DIR=/tmp/stg-transcribe-uv uv run --frozen pytest -q tests/transcribe`：130 passed，4.53s；含真实TH06/TH18 harness与开场检查。新增runner的模型进程用本地可执行替身，只证明调度、文件交接和校验，不代表真实模型写审。
- 无新增依赖、引擎修改、训练、付费生产调用或提交推送。官方CLI已核帮助/版本，真实服务登录、额度、模型质量及生产权限仍需实际试产验证。

- 一次只读独立审阅发现中断遗留worker和旧density缺导入，均已修正。SIGINT/SIGTERM回归先复现失败再通过；旧density用一张真实TH06卡运行，rank0峰值16、均值3.5。未再追加复审轮次。
- 官方argv清单dry-run接受TH06/TH18两卡，无模型调用、无运行文件。227个本地文档链接检查通过，git diff --check通过。
