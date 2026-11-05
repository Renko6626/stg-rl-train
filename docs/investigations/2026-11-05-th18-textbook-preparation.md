# TH18 双语法转写教材：资料与结构草案

2026-11-05。本文保留开始撰写前的资料收集与结构建议。用户随后批准并补充激光，正文已落为[转写教材](../../transcribe/th18/mapping.md)，实际结果见[验证记录](2026-11-05-th18-textbook-verification.md)；以下“拟新增”“尚未编写”等表述属于准备时的状态。

## 写作目标

读者会基本编程，但不需要事先熟悉东方 ECL 或 stg-engine。主文让人和转写 AI 能顺序读懂：原作文本在表达什么、我们用什么语法表达同一行为、怎样编译和检查结果。保留 TH06 mapping 的具体公式、完整例子和明确差异，按教材顺序组织。

采用用户提出的“主文教材 + 独立大表”：主文同时教两边必要语法，不再要求读者从多个入口自行拼教程。完整编号枚举移到单独 Markdown；主文需要某个编号时演示查表和使用，只保留解释当前例子所需的少量行。

## 已收集的公开资料

GitHub 连接器和联网搜索接口本轮连接失败，已通过直接 HTTPS 获取公开原始文件及仓库元数据，再与现有本地副本核对。[来源清单](2026-11-05-th18-textbook-sources.json)记录 URL、抓取 hash、仓库版本和本地输入 hash。原始第三方页面与 JS 仅存已忽略的 `transcribe/work/th18-doc-sources-20261105/`。

| 资料 | 已查内容 | 用途 | 版本与适用边界 |
|---|---|---|---|
| [Priw8 ECL 教程](https://priw8.github.io/#b=ecl-tutorial/&p=1) | 下载简介、正文及位运算旁篇共15页；重点读 sub、发射器、表达式/栈及多文件部分 | 教学顺序、thecl 文本的概念和习惯 | 作者以TH17为主要例子；不能据此认定TH18全部行为 |
| [教程源码](https://github.com/Priw8/priw8.github.io/tree/1c0276927ec203f7adfafca01ec157dba52c35a7/content/ecl-tutorial) | 数值、变量、条件、循环、敌移动、include/ecli 等章节均已取得 | 按章节定位来源，避免抓到网页外壳就当读过教程 | 博客页码与原始文件名不同，引用保留实际路径 |
| [Priw8 指令表](https://priw8.github.io/#b=modding/&p=ins&table=18)与[变量表源码](https://github.com/Priw8/priw8.github.io/blob/1c0276927ec203f7adfafca01ec157dba52c35a7/js/ecl/vars.js) | 页面、ins.js、vars.js、版本继承代码 | 原作编号、参数描述及特殊变量 | INS_18为空但继承旧表；没有覆盖项不表示行为相同 |
| [Priw8 EX 说明](https://priw8.github.io/#s=modding/transforms) | 配置指令、EX副本、async与配对机制 | EX章节的概念解释 | 正文限定TH13–17并写18条；TH18已核24条，须补正 |
| [Priw8/eclmap 的 TH18 文件](https://github.com/Priw8/eclmap/blob/f146162e330c27d1b0a8880c3a41884615147a11/eclmap/th18.eclm) | 与本地文件逐字节一致 | opcode与变量助记符 | 本文件没有ins_signatures节，助记符不等于完整签名或功能证明 |
| [thtk/thecl](https://github.com/thpatch/thtk/tree/917a3d3858850f01276b7fb5b9327e2c24d27d5b/thecl) | 命令手册；本地thecl10.c、ecsparse.y、ecsscan.l | 原作编译/反编译参数、语法、默认参数格式 | 格式按版本继承；本地工具版本单独记录，不静默升级 |
| [ExpHP th-re-data](https://github.com/exphp-share/th-re-data) | README与本机TH18已有符号/类型入口 | 函数、结构体、opcode标签及逆向定位 | 名称和类型是地图，执行语义仍回到TH18自身代码 |
| [ExpHP thpages](https://exphp.github.io/thpages/)与[truth](https://github.com/ExpHP/truth/tree/61ea9895a42a1ccedca36dd9db091a6af63d509f) | thpages首页、truth README/语法及与thtk的比较 | ANM补充背景、工具与文本方言区分 | thpages主要是ANM；所查truth版本没有可直接替代thecl的ECL工具 |
| [Priw8 MERLIN](https://github.com/Priw8/merlin) | README、仓库文件目录、教程相关章 | 社区弹型/模式命名的辅助入口 | README列TH16/17；不自动作为TH18库依赖 |

本机 `thtk` 与 `th-re-data` 的 HEAD 比本次观察到的远端旧；已分别记录版本，未更新仓库或重新导入 Ghidra。eclmap、truth、thpages 的本地 HEAD 与本次远端一致。Priw8 网站源码当前观察到的提交为 `1c0276927ec203f7adfafca01ec157dba52c35a7`。

## 本项目已有可复用内容

- [TH06 mapping](../../transcribe/th06/mapping.md)：借鉴从源语义落实到我方代码的写法，不搬用本作特有坐标、发弹池或已接受近似。
- stg-engine 的 `docs/ecl-lang/1-hello-danmaku.md` 至 `9-lasers.md`：目标语法的教学基础，重点使用任务/时间、三型、敌人、发射器、xform、诊断章节。签名核当前 `builtins.rs` 与生成速查，历史概述不能压过当前实现。
- stg-engine 的 `docs/easing-reference.md`：已列 TH18 mode0–31 到曲线语义/名称的对应。`docs/stateful-interpolation-reference.md`：7/8/17 的累加、Hermite和二阶累加，以及我方显式值槽；两者必须接入教材。
- [TH18弹型表](../../transcribe/th18/bullet-types.md)与[弹型核查清单](2026-11-05-th16-th18-bullet-types.json)：原作48种type、ANM、基础半径和色槽已核；还需补我方appearance及明确的颜色/判定对应。
- [TH18 EX表](../../transcribe/th18/ex-effects.md)与[两作原生比较](2026-11-05-th16-th18-ex-comparison.md)：已有30项原始效果的参数与执行路径，接下来补到我方操作/组合程序及支持边界。
- [发射模式调研](2026-11-02-ecl-capability-audit/modern-hazards.md)：已有TH16模式0–12的配方或未解标记；TH18条目须回查本作发射函数，不能直接给整张表贴TH18标签。
- [现代导入原型](../../tools/th18-import-prototype/README.md)：栈、跳转、脚本时钟和源码对拍有已有证据；原型覆盖及已声明近似不当作正式转写上限或默认策略。

资料按问题使用：解释thecl语法看教程/语法实现；确认TH18运行时看本作Ghidra证据；确认目标写法看当前我方编译器/运行时。社区常用别名与已验证运行行为分别注明。

## 主文件建议目录

拟用现有路径 `transcribe/th18/mapping.md`，标题为“TH18 → stg-engine ECL 转写入门”。主文按一段弹幕从无到有的顺序展开，预计八个教学单元：

| 单元 | 核心问题 | 读完能做什么 |
|---|---|---|
| 1. 两种ECL与最短验证环 | 原作二进制.ecl、thecl文本和我方文本.ecl怎样区分？两套编译器各检查什么？ | 编译最小原作合成例和最小目标程序，理解输出与报错 |
| 2. 看懂并写出基本语法 | sub、声明、字面量、表达式、参数和返回约定怎样对应？ | 将原作int/float/角参数改写为我方int/fx/angle，处理cast与弃值 |
| 3. 时间、控制流与任务 | 时间标签、wait、跳转重设时钟、栈引用、call/async各意味着什么？ | 恢复原作行为，再写if/循环/spawn；必要时保留goto和显式时钟 |
| 4. 一只会动的敌人 | owner、位置、相对/绝对运动和插值怎样表达？ | 生成/保留/结束敌人，查插值表选择正确曲线或状态型操作 |
| 5. 从一颗弹到一波弹 | 发射器配置、etOn、路/层、瞄准和随机有什么联系？ | 查弹型及瞄准表，写sh_*或显式逐颗fire，保留速度层与创建序 |
| 6. 发射之后的变化 | EX程序副本、并行门、等待、插值和分裂怎样转？ | 写带参xform，区分配置/出生/效果进入取样，识别必须保留的状态 |
| 7. 合成一个完整攻击 | 如何把调用依赖、rank、移动和EX连起来？ | 沿一个自写贯穿例完成源码、训练外壳和元数据，另列原作改动 |
| 8. 验证与排错 | 编译通过、运行正常、行为一致各靠什么证明？ | 使用check/run/--at，从源程序推导颗数、速度、方向、周期和效果前后锚点 |

第1单元就给出可运行的检查命令，此后每章沿用。栈既要讲明白，也不把所有人都拖进字节码细节：先解释读反编译必须识别的栈引用和统一收栈，再给深入来源。多文件的 `#include` / `ecli` 区别放在依赖与调用的上下文中。

## 独立编号表

沿用当前平铺目录，不先搬文件或建立新框架：

```text
transcribe/th18/
  mapping.md                 主线教材，拟新增
  bullet-types.md            已有；补原作→我方弹型/色号/判定对应
  aim-modes.md               拟新增；原作发射模式→几何公式→我方实现
  interpolation-modes.md     拟新增；原作mode→语义→EASE_*或状态型操作
  ex-effects.md              已有；补原作EX→我方操作/组合/未支持边界
```

全量opcode、特殊变量或flags若需形成较大编号表，分别放 `instructions.md`、`variables.md`、`flags.md`；不把数百行指令目录塞回主文，也不为凑目录先建空文件。原生结构体偏移和逆向过程留在资料/调查文档中，主文只引用必要结论。

每张表提供“原作编号与上下文、语义名称、功能、我方写法或详细配方链接、限制/证据”。较复杂的 EX 用短索引表链接到本文件的分节；参数和代码不挤进超长单元格。原作编号、我方内部编码、弹型与EX命名空间始终分开。

## 每节如何写

同一概念用同一小场景讲四件事：

1. 一段自写原作合成例，逐句解释在什么时候改了哪份状态。
2. 对应的我方完整小程序；关键转换旁给原因，读者不必先翻完整目标手册。
3. 一个有意义的变化，例如改变路数、移动敌人或把一次瞄准改为持续追踪，让读者知道结果为何改变。
4. 实际检查命令、可观察的期望及常见报错。细节查对应独立表；不在每章重复整张表。

例如讲环形发射，先介绍etNew/etSprite/etCount/etAngle/etSpeed/etAim/etOn构成的配置，再对照sh_reset/sh_sprite/sh_count/sh_angle/sh_speed/sh_aim/sh_ring/sh_fire。速度端点与步长、瞄准基点、层间角偏移和创建顺序须讲实际差异，不能只给同名函数替换。完整aim模式枚举另查表。

讲插值时，主文用一个mode4减速移动解释“按语义选择EASE_QUAD_OUT”；完整0–31表外置，7/8/17明确走状态型路径。讲EX时，先做等待后改速，再讲持续角速、效果时随机和并行效果；复杂追踪/分裂按需要深入。

源码示例自行编写，不把原作摘录放进可入库教材。每个代码块注明原作thecl文本、目标完整程序或不可独立编译的片段，避免同为`.ecl`却交错编译。完整例子分别用thecl18+指定eclmap、我方harness真编译；关键行为做有明确期望的运行核对，不为文档启动训练或大范围回归。

## 写作前仍需补齐的材料

1. 将TH18弹型原生表接到现有我方图集：常见对应直接整理；没有同形/同判定的条目明确记录差异，不能把整张映射留给每次brief重做。
2. TH18发射模式逐项核本作参数与几何，优先补常用0–8；9–12若仍有未解公式，明确在表中标出，不能沿用TH16调查冒充已核。
3. 将已有插值语义表和状态型接口整理成转写者可直接使用的配方；核对参数和更新时点，不只给编号或名称。
4. 给常用EX补目标实现与完整例子，已知不支持的机制写清影响。只因动态参数就量化/开逐弹任务的旧绕法不再作为默认。

正文集中教常见、已核路径；未解项放对应表和具体例子旁，避免主文又被流程约束和逆向待办淹没。最后才精简skill：指导读取主文和所需表，写审契约负责任务权限、产出及验收，三者分工明确。
