# 证据位置

先找已有资料，再做必要核验。进度、实验数值和具体调查放在原报告，记忆只保留入口。

## 原作行为与 Ghidra

renkolab 根目录为 `/data/sunyunbo/www/renkolab`。处理原生行为前读其适用的 `AGENTS.md`／`METHOD.md`；生态约定另见 `/data/sunyunbo/.codex/memories/renkolab.md`。

| 资料 | 相对 renkolab 的路径 |
| --- | --- |
| TH16 样本、版本与研究入口 | `games/th16.v1.00a/INDEX.md` |
| TH18 样本、版本与研究入口 | `games/th18.v1.00a/INDEX.md` |
| 已有 TH16 Ghidra 工程 | `local/th16.v1.00a/ghidra_projects/th16.exe.gpr`（同目录 `.rep`） |
| 已有 TH18 Ghidra 工程 | `local/th18.v1.00a/ghidra_projects/th18.exe.gpr`（同目录 `.rep`） |
| 已导出的函数／反编译资料 | `local/<版本>/state/data/functions.jsonl`、`state/index.html`、`state/f/<地址>.html` |
| 现成 Ghidra 工具与读取方式 | `tooling/ghidra/README.md`、`tooling/ghidra/_driver.py`、`tooling/ghidra/scripts/decompile_funcs.py` |

**复用现有已命名、已套类型的工程及导出。** 优先查导出；需要补读时使用现有工具或可用的 Ghidra MCP。不要因未找到 MCP 就自行搭 Capstone／objdump 替代流程，也不要重新 bootstrap、导入或重建数据库。旧索引里的“先建库”命令不代表本次授权。读取工程保持只读（适用入口为 `open_program(tx=None)`），遵守现有锁；原生地址须附作品／样本版本，不能跨作套用。

社区资料用于导航与辅助对照：Priw8 的指令／变量表实际在 `js/ecl/ins.js`、`vars.js`，由 `main.js` 处理继承；没有 TH06 行为表。opcode 名称与 eclmap 本身不证明行为，结论优先依据本作原文／原生实现。路径与资料分工见[基础设施调查](../investigations/2026-11-02-ecl-capability-audit/infrastructure.md)。

## 引擎与转写

- 当前引擎能力：相邻 `stg-engine/docs/ecl-lang.md`、`docs/ecl-lang/`、`docs/xform-ops.md`、`docs/easing-reference.md`、`docs/stateful-interpolation-reference.md`；改引擎先读其规范。训练端实际消费的 wheel 另查[版本与来源](../magnus-migration.md#项目自有-wheel)。
- 本作语义、已批准简化与验收范围：[TH06](../../transcribe/th06/README.md)、[TH16](../../transcribe/th16/README.md)、[TH18](../../transcribe/th18/README.md)；生产流程见[转写总览](../../transcribe/README.md)。原作摘录、工作包和运行日志留在忽略目录 `transcribe/work/`，不复制进记忆。
- 历史能力分类与动态 xform 调查：[能力调查入口](../investigations/2026-11-02-ecl-capability-audit/README.md)、[缺口复核](../investigations/2026-11-02-ecl-capability-audit/gap-recheck-2026-11-03.md)。其中旧版本限制、统计与提案按记录日期理解，当前用法以手册和实现为准。

## 经常需要回查的报告

- 原生抽取错误：[TH18 子弹链首节点](../practice-cards/2026-10-22-th18-bullet-head-fix.md)、[TH06NC Boss 标志与三作追敌](../practice-cards/2026-10-22-enemy-follow.md)、[TH18 几何深审](../practice-cards/2026-10-22-th18-geometry-audit.md)、[2048 容量与 graph7 接入](../practice-cards/2026-10-22-capacity2048.md)。
- 模型与部署：[激光 token／联合注意力设计](../superpowers/specs/2026-10-01-laser-token-joint-attention-design.md)、[TH06NC 精简包](../practice-cards/2026-10-28-th06nc-clean-package.md)、[TH18 打包工具](../../tools/th18-portable/README.md)。
- 实验统一入口：[实验记录](../experiments.md)、[练习卡研究索引](../practice-cards/README.md)、[性能记录](../perf-baseline.md)。TH16 本轮证据见[全量 CPU 试测](../practice-cards/2026-11-08-th16-cpu-eval.md)与[难度假设对照](../practice-cards/2026-11-08-th16-difficulty-hypotheses.md)。
