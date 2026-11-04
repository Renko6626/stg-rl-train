# 原作 ECL 与我方引擎能力调研

日期：2026-11-02。本轮是资料与行为调研，不修改引擎、导入器、训练配置或卡池，不训练，不提交或推送。

## 从这里阅读

- **引擎已更新**：2026-11-03只读核实stg-engine main的`85c042e`已交付ENGINE_VER28动态xform，支持按值参数、绑定/出生/效果求值，World净增44KiB。下文常量限制及候选方案是更新前调查；当前用法看相邻引擎`docs/ecl-lang/4-bullets.md`，接入状态见[项目记忆](../../agent-memory/ecl-capability-audit.md)。2026-11-04已接入ENGINE_VER30及0.4.4 wheel，三阶段rand可用；精确源码身份与验证见[接入记录](../../practice-cards/reports/stg-rl-044-adoption.json)，旧卡未迁移。
- **2026-11-03更新**：[按整段LLM转写复核实际缺口](gap-recheck-2026-11-03.md)。当前优先级以此为准；初版第五类是接口对照候选，不能整批当引擎必做需求。
- **动态xform进一步核查**：[代码路径、TH06NC实卡影响与两条候选路线](../2026-11-03-parameterized-xform-investigation.md)。已找到旧卡因接口限制改为粗化/固定值的历史记录；后续用户确认并实现动态xform及三阶段rand，当前状态见上述项目记忆。
- [首轮结论与后续边界](results.md)：五类代表行为、TH06NC旧卡余量、资料冲突及待取舍项。
- [资料结构与版本边界](infrastructure.md)：Priw8动态表、Ghidra已有导出、版本继承和来源固定方式。
- 分域表：[TH06/NC](th06.md)、[现代VM与敌人](modern-vm.md)、[现代发射器/EX/激光](modern-hazards.md)。
- [逐编号索引](instruction-index.csv)与[可筛选行为矩阵](behavior-matrix.csv)，以及各报告同名JSON。类别留空代表待核实或待确定重要性，原因保留在对应记录中。
- [验证结果](verification.json)、[来源元数据](sources.json)、[版本目录](version-catalog.csv)。验证只覆盖资料结构/枚举/引用，未做原作动态等价验收。

## 目标与口径

用户要求按五类核对原作指令与行为：

| 类别 | 含义 | 必须说明的条件 |
|---|---|---|
| 1 | 原作有，我方直接精准实现 | 对应公开 ECL 接口、实际执行路径、语义边界 |
| 2 | 无直接对应接口，但现有组合代码能精准实现 | 具体组合方法；状态归属、帧相位、动态参数和容量条件 |
| 3 | 现有组合代码只能近似实现 | 哪个行为不同，训练中会看到什么差异 |
| 4 | 经过取舍可以不做 | 已有取舍依据；本轮新建议标“待用户确认”，不冒充已决定 |
| 5 | 我方缺少、且对数据扩充关键 | 具体缺口、受影响样本或机制、为何值得做；不代表实施授权 |

浮点与定点的数值差异按用户要求不影响本轮五类判定，单独记录。不借此忽略状态归属、时序、碰撞门、随机分布等其他语义差异。类别是表达能力判断，不是逐帧原作对拍通过声明。原作行为或组合方法证据不足时，类别留空、标“待核实”；这是证据状态，不是新增第六类。

主表以 TH06/TH06NC 和 TH16 为逐项核对基准；现代版本资料另外逐版本登记，不把 TH16 结论自动外推至 TH18。TH08 为早期架构的辅助资料。Priw8 未提供 TH06 行为表，TH06 需使用本地 CC0 反编译与 NC 逆向记录补齐。

每条记录分开说明：引擎源码是否能表达、转换器是否接入、既有训练卡是否采用。初版调研以相邻引擎 `ENGINE_VER27`、训练依赖 `stg-rl 0.4.2` 为基准；该历史基准不代表当前接入版本，后续交付见本页开头。

## 资料入口

- [Priw8 指令表](https://priw8.github.io/#b=modding/&p=ins)、[变量表](https://priw8.github.io/#b=modding/&p=vars)。网站按版本继承指令描述，并有 `null` 删除标记、未写行为的占位项；不能只读 `INS_16` 或把表内所有槽都当真实指令。
- 实际数据：[ins.js](https://priw8.github.io/js/ecl/ins.js)、[vars.js](https://priw8.github.io/js/ecl/vars.js)、[解析与继承逻辑](https://priw8.github.io/js/ecl/main.js)、[命名映射加载器](https://priw8.github.io/js/ecl/eclmap.js)。旧调查中的 `js/ins.js` URL 已不可用。
- 本地逆向仓：`/data/sunyunbo/www/renkolab`；先读其 `README.md`、`METHOD.md`、`DOCSTYLE.md`。仅读取，不改该仓及 Ghidra 工程。
- TH16 VM：`engine/ecl/th16/01-ecl-context-and-variables.md`、`04-ecl-vm-interpreter.md`、`05-fire-interface.md`、`07-vm-architecture.md`。
- TH16 弹幕：`engine/bullet/th16/01-core-engine.md`、`02-bullet-vm-model.md`、`03-lasers.md`、`04-cancel-to-item.md`。`engine/ecl/th16/ECL-info.md` 是社区速查，其中已有本机逆向指出的跨版本错误，不能当最终裁决。
- Ghidra 可重放命名：`tooling/ghidra/scripts/apply_th16_{ecl,bullet,math}_names.py`。脚本混合社区命名与本地确认注释，名字本身不证明函数行为。
- 已有只读导出：`local/th16.v1.00a/state/data/functions.jsonl`，字段含 `addr/name/sig/comments/decompiled/callers/callees`，可按地址或函数名查行为。原始反编译仅保留在忽略目录，不写入本报告。
- TH06：`local/vendor/th06-decomp/src/{EclManager,EnemyEclInstr,BulletManager}.cpp`、`engine/ecl/th06nc/`、本仓 `transcribe/th06/mapping.md`。
- 我方实现：`/data/sunyunbo/www/stg-engine` 的 `PROGRESS.md`、`crates/stg-ecl-compiler/src/lang/builtins.rs`、`crates/stg-core/src/ecl/{task,vm,syscall,shooter}.rs` 及 `syscall/`、`world/`。文档有旧内容，判定需要回指当前源码。

## 工作拆分

先读取网站的数据结构与本地证据格式，再并行调研三个互不重叠的领域：

1. TH06/NC：普通指令、独立 timeline、特殊回调，核对已收卡与排除单元。
2. 现代 VM 与敌人：TH16 的控制流、变量、任务、移动、敌人属性、表现和交互，附 TH18 已有证据的差异。
3. 现代弹幕与激光：TH16 的发射器、EX 子指令、激光，附 TH18 已有证据的差异。

主代理负责资料清单、分类口径、版本边界、覆盖核对与汇总。各子代理只写分配的报告和分类数据，不改公共索引或生产代码。

## 产物与验证

- 各领域报告保留行为、条件、组合方法、偏差和原作／我方证据指针。
- 结构化分类数据通过 opcode 与 timeline 命名空间关联基础清单；EX 子指令、回调和变量需另表，不能只覆盖顶层 opcode。
- 汇总时检查基准指令是否逐项有记录、是否重复／漏项、是否存在失效证据路径，单列待核实与待用户取舍项。
- 本轮只执行资料提取、覆盖与链接检查，不启动训练、浏览器交互或无关测试。

原始下载、继承解析结果、反编译摘录与临时脚本放 `transcribe/work/ecl-audit-20261102/` 或 `/tmp/sunyunbo/`；公开报告不复制第三方整表描述、游戏原文或大段反编译。
