# 原作ECL能力分类与调研入口

> **版本**：跨版本，涉及 TH06/NC、TH16 与 TH18；原生地址按各段作品归属，独立地址引用带作品前缀。

2026-11-02，用户要求先研究 Priw8 网站与 renkolab TH16逆向/Ghidra命名脚本和内容资料，再派发子代理梳理原作ECL与我方引擎能力。

长期分类口径：1直接精准；2现有组合精准；3组合近似；4经过取舍可不做；5缺少且对目标数据扩充关键。**浮点/定点数值差异不据此降级**。状态归属、时序、碰撞门、容量/池序、主动粗量化等另判断。证据不足或重要性待定可保留空类别，但应写明原因。

必须分开：当前引擎源码能力、导入器覆盖、旧训练卡是否采用。不能因旧卡无敌就把当前生命读口判为不支持；不能因原型拒绝某opcode就推断引擎缺能力。“组合精准”要有可操作配方和有效域/相位/预算条件，不能只说理论可写。新省略建议与既有取舍分开，5类候选不构成架构或实施授权。

成果入口：[2026-11-02调研](../investigations/2026-11-02-ecl-capability-audit/README.md)。TH06/NC 151个候选键、TH16 300个候选编号均有记录；另表覆盖变量、特殊回调、发射模式和EX。其余现代版本有资料目录，尚未逐作品原生核完；不要把TH16分类自动外推TH18。具体未定类项看JSON，不把索引覆盖当作行为全验收。

资料入口已核：Priw8实际为 `js/ecl/ins.js`、`vars.js`，按 `main.js` 继承；没有TH06行为表。TH16已有 `renkolab/local/th16.v1.00a/state/data/functions.jsonl` 只读反编译导出，可按地址/名字查，不必先开或改Ghidra工程；导出生成关系本轮未全面审计。原作字节/大段反编译仍留忽略目录。

重要纠偏：TH16 626覆盖603相对偏移，628使用独立绝对基点；line/infinite激光有EX复制与效果执行路径；TH16清弹mode1不产实体、TH18产type9。TH06 CC0自动射击不受shootingDisabled门控，旧mapping有冲突，NC该细节待核。原生/本作证据优先，命名表或社区速查不能单独裁定。

TH06 ex12/14已有组合；ex7局部网格不是全场扫描，但48创建及几何的同帧预算尚未证明，不能直接解禁收卡或判需新引擎。NC17–19、201动态等保留待核。完整动态rank、炸弹伤害、一般HP/多段中断不是当前固定rank单段无敌躲弹卡的默认前置。

调研时我方源码ENGINE_VER27、训练wheel仍stg-rl0.4.2；来源HEAD/实际文件哈希见报告sources.json。未改引擎/导入器/卡池/训练，未原作动态对拍或训练，未提交/推送。

## 2026-11-03 按整段LLM转写收窄缺口

用户指出普通转换及共享发射器可以让LLM按完整攻击重组代码，要求找“没了就让不少弹幕不能跑”的真实缺口。后续不能将逐指令一对一转换器不支持或缺少同名接口直接认作引擎必改。有限共享发射、async取消与脚本时钟均有整段重写路径；预算/精确顺序仍逐样本判断。

当前缺口优先级入口改为[11月3日复核](../investigations/2026-11-02-ecl-capability-audit/gap-recheck-2026-11-03.md)。动态xform参数是值得优先研究的ECL源码暴露限制：底层开火已从当前locals复制参数，不能据此要求重建EX VM；每弹任务有256总槽限制，但尚未测出真实不可消除的超限攻击。新扫22文件/798sub，EX8有65处/34sub带动态参数引用，其中加速/角速参数61处/33sub；统计不是独立卡数或必然不能运行数。

曲线激光是确定的几何缺口；本轮重新解码确认711实际两处为st07bs::BossCard3_at、BossCard7_at，旧报告写at2有误。EX2出生262处/240sub很普遍，但近似原型省略时已能运行，应称保真差异；动态宽度/半径、世界变速、敌非圆框等缺少足量当前扩样阻塞证据。现有TH06弹型命名/编号映射和已接受半径近似继续适用，不自动重开为引擎修复。

## 2026-11-03 动态xform代码与TH06NC实卡进一步核查

用户明确认为只接受常量是重要引擎问题，要求查代码及TH06NC是否有同类需求。事实与候选路线见[专项核查](../investigations/2026-11-03-parameterized-xform-investigation.md)，尚未批准实现。

常量限制位于compiler的const_eval和语法/类型路径；VM建弹已经从当前locals复制wait/op/args。sh_xform当前只保存locals的off/cnt，不是独立配置快照；helper返回后兄弟locals复用、同模板多实例可能造成引用别名，已静态指出但未运行复现。不能仅删常量检查就承诺完整支持，也不能无条件承诺core/World布局不改。

TH06与NC本作均确认“bullet_effects配置点求值→发弹复制到每弹→效果后期读每弹字段”。不能到开火时重读已改写F寄存器。166卡中结合实际攻击路径，12卡使用动态bullet_effects值，主要10弹任务/2固定或粗化；任务绕法不保证其他时序/分布精准。实卡s4_b16四档随机角，s7_b12固定加速度（历史报告记263峰与256任务池），s6_mb1同批共享角改逐弹独立角；s4_b17元数据“随机合并”已过时，当前源码保留独立随机。未发现当前八张全局传参卡相邻帧覆盖的正例。

候选A为有类型形参模板、配置时实例化并给发射器保存快照；若固定4×16槽/256任务配置，主体约192KiB/World、4096环境约768MiB，须存档/校验/版本评审。候选B只在发射处即时实例化，减少配置状态但需明确API限制与源码缓存快照。两条均未获用户选择，未改引擎/卡池/训练、未提交或推送。

## 2026-11-03 引擎动态xform已交付（取代上节候选状态）

用户告知stg-engine已更新，本轮只读核实：main提交`85c042e`（完整身份以该仓Git为准）已实现按值形参、绑定/`at_spawn`/`at_effect`三阶段表达式，ENGINE_VER28；引擎工作区只有原有dist产物，未改引擎代码。设计和实施记录在相邻引擎 `docs/superpowers/{specs,plans}/2026-11-03-xform-runtime-expressions*.md`，作者入口为`docs/ecl-lang/4-bullets.md`“带参变换与求值时点”。上面的“仅常量、尚未批准实现”是历史调查，不再描述当前源码。

实参在fire/sh_xform时只算一次并按值传入；未标记动态参数在绑定时求值；at_spawn在每弹最终出生状态确定后求值；at_effect在每次进入操作时求值，STEP运行及WAIT_SIGNAL停驻期间不重复，LOOP重入重采样。新绑定独立保存36B捕获数据，不留helper locals引用；原公式放镜像共享，每段增加4B元数据，必要原值放段尾。已出生弹不受重绑/reset影响。

rand不可在模板体内使用，可在普通sub先赋变量或在实参位置调用rand，再按值传入。支持三型纯表达式及global/sin/cos/atan2/dist/aim_player等有限读口；不开放任意sub/写操作/每帧持续绑定。@N仍为u16字面量与后置等待，最多8个逻辑缓存，操作+STEP scratch+持久原值数据槽合计仍≤16；动态数值问题解决不等于容量、反弹、出生ANM或曲线激光问题全解决。

实际尺寸净增45056B=44KiB/World（4096环境176MiB，不含共享表达式镜像）。引擎基线记录2048弹每帧触发SET_SPEED的p50常量42.762us、直接101.222us、组合122.818us；STEP稳态55.345/55.683/55.644us。仅是该机微基准，不是训练吞吐。本轮阅读已有验证记录及实现，未重跑测试或性能；原实施记录列core/compiler/harness/RL、golden等通过，未Godot/wheel/真实训练/跨平台验证。

训练仓`pyproject.toml`及`magnus/wheels/SHA256SUMS`目前仍锁`stg-rl0.4.2`，本轮没有升级依赖、改卡、训练、提交或推送。后续先按既定四处同步要求接入新wheel，再考虑以s4_b16/s7_b12/s6_mb1为首批还原动态参数；新能力并未自动修复旧卡或现代导入器。

## 2026-11-03 转写指引核查与训练wheel接入

用户要求检查派发原作ECL转写的skill及文档，并另行授权更新训练wheel。当前引擎main为`07058f3086811a8326307cad2e9423024adc531d`、ENGINE_VER29，除动态xform外还包括六种单值STEP扩展。训练接入`stg-rl0.4.3`，四处依赖与哈希同步；构建来自该提交的导出快照，只在快照内调整Python包装版本，未修改引擎工作区。出处与验证记录见[接入记录](../practice-cards/reports/stg-rl-043-adoption.json)。上段wheel仍为0.4.2描述接入前状态。

本次检查定位到的转写指引问题（检查时尚未修改，后续修订见下节）：

- `transcribe/th06/mapping.md` §5仍写“参数必须是编译期常量”，推荐离散模板、逐弹任务或随机量化；这是写审worker实际读取的语义依据，会继续引导新卡沿用旧绕法。
- §2.4、转写契约和`.claude/skills/th06-transcribe/SKILL.md`仍把所有xform都按每物理槽3字占locals处理，并要求sh_xform/sh_fire同sub。应区分旧零形参全常量路径和新的带参/动态按值绑定，不能全删旧路径警告。
- §5对动态bullet_effects只讲建弹复制，缺少配置点求值。正确转写要先在原bullet_effects位置保存值，再绑定/传参；同一轮共享随机值不能改成每弹重摇。模板体不允许rand，at_spawn/at_effect也不能据此当逐弹随机入口。审核契约还缺少求值时点与共享范围核查。
- 内建速查只抽取7-reference的签名列表，不会带出其xform求值标记说明；新语法应在mapping摘录或契约提供短例子。本机2026-11-03查到176份单元摘录，其中74份仍含旧常量限制；现场重新生成的builtins也没有at_spawn/at_effect。已处理单元的mapping-excerpt/builtins由extract跳过，review又复制旧单元文件；改总表后须刷新目标单元输入，不能以重跑extract代替。
- 旧卡s4_b16四档随机角、s7_b12常量中值加速度、s6_mb1逐弹独立随机仍未迁移。动态参数能力不解除@N字面量、8逻辑缓存、16物理槽或256任务池等独立限制；随机效果回调也不能一概删掉弹任务。

本次未启动转写worker、迁移卡池、启动训练、提交或推送；转写后端仍按现有dsh-flash/备用Sonnet及Opus抽检约定。

## 2026-11-03 转写文档修订完成

用户随后授权修改和优化文档。已同步`.claude/skills/th06-transcribe/SKILL.md`、转写README、写审契约、mapping §2.4/§5及历史设计文档入口。新规则使用带参模板，在原bullet_effects配置点保存参数，保留随机取样位置和共享范围；区分绑定、at_spawn与at_effect，并保留旧静态路径的locals/同sub限制。旧量化示例替换为一个按值绑定、同步helper返回后开火的完整程序；显式说明@N字面量、STEP非阻塞、缓存/槽预算以及效果时随机回调仍需另处理。

skill新增仅刷新派生资料的操作步骤；本机已用现有mapping.excerpt与builtins_cheatsheet刷新176份单元的mapping-excerpt/builtins，其中174份带新版§5。未修改旧review目录、out卡文件、state.jsonl或verdict，后续review会复制新输入；未改流水线代码、启动worker或迁移旧卡。Opus抽检、Sonnet并发4及提交/推送分别授权的约定保留，历史设计中的旧版本/抽检暂停已标明日期与当前入口。

验证：`.venv/bin/python -m pytest -q tests/transcribe/test_mapping.py tests/transcribe/test_split_extract.py`为35 passed；新mapping示例使用release harness运行185帧，无task fault/contract violation/pool full，首轮仍在场的29颗弹速度均为1.4、相对初始环角的转角均为7243 BAM，说明配置后局部变量改为0未改写已绑定值。临时检查产物在`/tmp/sunyunbo/stg-rl-docs-20261103/`，不入库；本次无新增永久测试、训练或原作动态对拍，未提交/推送。

## 2026-11-04 原作EX执行时随机取样已确认

用户询问原作是否确有在子弹额外效果内部抽rand的实际需求。本轮静态解码TH16 v1.00a的22文件/788sub、TH18 v1.00a的22文件/798sub，并对照已有原生反编译导出和TH18 PE反汇编；没有运行原作。源码身份、选中配置与原生地址见[证据摘要](../investigations/2026-11-04-ex-runtime-random.json)，原作摘录仅放已忽略的`transcribe/work/ecl-rand-review-20261104/`。

TH18存在三个明确脚本正例，均为`st05bs.ecl`的`EX_VELTIME / 0x200000`，持续参数120帧：

| sub | EX槽 | 方向模式参数 | 执行时的方向 |
|---|---:|---:|---|
| `Boss1_at` | 15 | 3000000，幅度0.17453292 | 从当前弹位置瞄准当时玩家，再加约±10°的逐弹随机偏角 |
| `Boss2_at` | 14 | 4000000，幅度6.2831855 | 当前弹角加有符号随机偏角，幅度参数为2π |
| `BossCard1_at` | 2 | 3000000，幅度0.17453292 | 同第一项，效果进入时瞄准并随机偏转 |

这些配置的方向模式是字面量，随机发生在原生效果内部，不是配置指令读取RAND伪变量。`Boss1/Boss2`同步调用对应at子程序，`BossCard1_Et`异步调用`BossCard1_at`；配置后有对应etOn。前两项配置含从12槽启动的子弹发射及后续60帧WAIT，第一项另有30帧变速排在随机效果之前，不能把整条路径当普通出生随机。

TH18原生链为`Bullet__run_ex 0x425c60`的VELTIME分支，经`th18:0x426eec`调用方向解析`th18:0x425b40`；300万/400万区间分别在`0x425bab/0x425be0`调用`Rng__randf_neg_1_to_1 0x402810`，使用共享回放RNG `th18:0x4cf288`。PE读出的区间阈值为2999990/3999990/4999990，反汇编确认随机量乘幅度后加当前自机角/弹角；结果存弹的`+0xda4`，供后续效果使用。这里是进入操作时取样，未将其说成每帧重新抽样。

TH16原生`bullet_vm_exec 0x413860`也确有EX_ANGLE c=5/6随机角、c=7随机速度分支，但这次扫描22份本作ECL未见字面c=5/6/7配置；TH18也未见这三个字面子模式。不得用这些支持分支代替真实使用证据，也不能把TH18高位随机角哨兵外推为TH16支持。

结论：效果时逐弹随机存在实际攻击需求，可支持研究xform的效果时rand；尚未授权实现。仅要求随机边际分布时可评估逐弹提前抽样并保存，不能因此宣称保留了原作的取样时点或共享RNG消耗顺序；不同RNG/seed本身仍不自动降低既定能力分类。三处是静态配置位置，不是三个已验收训练卡，也不是本作全部随机效果使用量。

## 2026-11-04 xform三阶段rand已实现并接入训练

用户随后明确确认三阶段统一支持rand并授权实施，取代上节“尚未授权”状态。引擎在main基线`07058f3`上完成改动，随后提交为`2f24d8628231126b01f3025b065117c9013a4934`，ENGINE_VER30：未标记rand绑定抽一次、同配置共享；at_spawn每弹出生抽一次；at_effect每次进入操作抽一次。复用World RNG及普通rand参数规则，n<=0返回0且不消耗；保留源码顺序/短路，不合并或常量折叠随机调用，STEP/WAIT_SIGNAL停驻不重抽、LOOP重入重抽。已执行的抽样不因后续操作参数非法回滚，原P4 no-op+计数不变；World/快照布局及各容量上限未扩展。

训练四处同步到0.4.4，来源为该基线加已审阅的源码补丁（与上述提交的crates改动一致）；出处、补丁/归档/wheel哈希和实际命令见[接入记录](../practice-cards/reports/stg-rl-044-adoption.json)。本机Python3.12与旧CPU venv Python3.11的真实VecEnv三阶段取样值均与普通ECL rand调用对照一致；旧密度场景六组固定动作的全部缓冲/起点索引和0.4.3逐字节一致，本机三场景golden也与改前一致。

core/compiler/harness/RL相关测试、fmt/clippy、表校验及独立只读审阅通过；训练/转写相关158项、引擎Python冒烟15项通过。核心新增3项真实编译执行测试覆盖阶段共享流、顺序/短路及非正界限、STEP/WAIT锁定与保存恢复，并扩展已有LOOP测试；未新增无关测试层。未做跨平台、GPU、原作实机对拍或吞吐评测。

转写mapping、写审契约、skill、README及176份单元派生资料已同步。§10.2的一次冻住再散开示例改用信号+效果时rand，零弹任务；这不解除任意全场弹集合/筛选/相位的其他限制。旧卡、review记录及state未迁移，未启动worker/训练。用户随后授权阶段性提交并推送两个仓库main；交付记录以Git历史为准。

## 2026-11-05 TH18 弹型与EX转写参考

用户准备做TH18 AI转写，要求先核弹型编号与EX效果/参数映射，并明确允许派Sol用既有Ghidra生态对比TH16/TH18。当前入口为[TH18转写参考](../../transcribe/th18/README.md)，原作侧两表已整理；我方appearance/半径取舍与完整转写配方仍未指定，未接入批量派发。

弹型：使用renkolab既有`tooling/pe_read.py`读常量表，结合已有Ghidra与标准thtk导出。共有type0–43的每条前0x110字节、44个主ANM脚本及5张共享贴图RGBA全部一致；TH18另核44–47阴阳玉。表记录48种type/别名/ANM/基础半径/已配置色槽，详见[弹型表](../../transcribe/th18/bullet-types.md)与[来源清单](../investigations/2026-11-05-th16-th18-bullet-types.json)。社区TH16目录下的ECL-info混列44–49，不能把目录名当本作编号支持证明；TH18的48/49未建立映射。

EX：Sol/medium复用两作已命名、已导入社区类型的Ghidra工程/JSONL/HTML，以项目driver只读核关键Listing，未重新导入、改名、保存或重建。覆盖TH16原29种位值与TH18新增追踪0x40000000；609–612布局基本一致，但容量18→24、百万角哨兵/随机、INVULN递减和SHOOT/LASER高角上界有差异。WAIT仍为0x80000000（signed=-2147483648），不能用社区序号替代或任意OR组合type。短式配置不清c/d/m/n，换型重读默认半径。主代理核读关键handler/Listing并收准INVULN消费者与ANGLE_ACCEL参数措辞。详见[EX表](../../transcribe/th18/ex-effects.md)及[原生比较](../investigations/2026-11-05-th16-th18-ex-comparison.md)。

保留未知：REACT消费者、STEP的d与TH16极高角哨兵、复杂插值全模式、激光完整消费者。未运行原作、训练或转写worker，未改引擎和卡池；文档/枚举/来源哈希及证据指针检查通过不代表实机等价。当前为未提交文档工作，上一轮阶段提交推送不构成本轮自动提交授权。

用户随后要求更新skill与对应文档。新增[TH18专用skill](../../.claude/skills/th18-transcribe/SKILL.md)及 `transcribe/th18/contracts/` 写审契约；TH06 skill、三份旧契约、转写README与AGENTS已加入分流入口。任务单须显式提供原作来源/依赖、目标弹型与判定方案、已接受差异及当前工具路径；映射和xform说明须实际传给worker，旧审核结果不因刷新资料而改写。

工具边界已直接核源码：`config.py`/`pipeline.py`/`mapping.py`/`extract.py`仍固定TH06；`validate.py`的lint限定TH06 id/source。TH18可用通用harness编译/运行/数值核对并独立原文审核，但不能伪装成TH06元数据过旧验收，也不能据此称已收卡。此次仅更新文档，没有新CLI、状态机、验收实现或worker派发；dsh-flash/备用Sonnet并发4与Opus抽检约定保留。

用户进一步澄清：需要的是“东方ECL通用知识＋我方ECL通用知识＋语法检查＋弹型/瞄准/插值/EX实际映射”，TH18仅有派发skill与原作语义表不足以指导转写。后续以TH06 mapping落实到目标代码的程度为内容标准，主文件写两边语法的入门教材；所有较大的“编号→游戏功能”表独立为Markdown，不继续在主文堆流程约束，也不让每次brief重新发明常见目标映射。

本轮已收集Priw8教程15页、动态指令/变量及EX页面，核GitHub与本地eclmap/thecl、ExpHP th-re-data/thpages/truth、MERLIN的定位；公开原文仅存忽略目录。教程以TH17为主要示例，EX旧页面18槽须补正为TH18已核24槽；thpages主要是ANM，truth不能作为现成TH18 ECL编译器。来源、hash与建议八单元目录见[教材准备草案](../investigations/2026-11-05-th18-textbook-preparation.md)及其来源JSON。当前仅资料与结构草案，未写正式mapping、改引擎/流水线或启动转写；skill后续应成为教材/表的读取入口，而非替代教材。


### 2026-11-05 TH18教材正文与激光已撰写

用户批准后完成[主线mapping](../../transcribe/th18/mapping.md)，含两边语法、源时钟/目标wait、owner/共享变量与发射器、移动、发射、三阶段xform/rand、激光、完整攻击和排错。大表独立为bullet-types、aim-modes、interpolation-modes、ex-effects、lasers；skill改为先读教材和所需表，再用写审契约。目标12行图集与原作bullet1顶部RGBA完全一致，颜色可据此核；同形不等于同半径/动画/碰撞，候选替代不自动批准。目标set_sprite仅换图不刷新出生radius，原作换型会刷新，已单列缺口。

5个原作合成例thecl18编译、27个目标例harness check/run通过；完整攻击rank0..3各760帧，均PHASE_ENDED@723且无fault/viol/pool_full。关键环形、插值、xform和激光锚点见[验证记录](../investigations/2026-11-05-th18-textbook-verification.md)。本轮未运行原作、未改引擎/流水线、未收卡或训练；mode11/12调速、STEP d、REACT、部分激光/EX及动态几何边界保留。原资料准备条目是此前阶段记录，以本节为当前状态。


### 2026-11-05 对比TH06后的补充范围

用户批准迅速修正301助记名enmCreateA及一圈角度字面量（65536bam非法，360deg/65536 as angle合法），补普通指令索引、敌人状态/段入口、完整双语法案例与统一转写口径。主文继续作教材，大表外置；不因此改引擎、批量流水线或永久测试。

**曲线激光暂时不做是用户明确决定。** 所选攻击实际依赖711 laserCuOn/Curve几何就写status: blocked并暂缓该攻击；不删曲线、不默认用多根短线替代。其他独立攻击正常继续，非目标rank或确证不可达分支按控制流依据排除；普通弹的曲线运动/Hermite移动不因此停掉。规则集中见[统一转写口径](../../transcribe/th18/transcription-policy.md)，skill/作者/审核入口同步。

补充已交付：普通指令227组opcode/精确名核对；敌状态含父镜像创建顺序、原生默认框与未核体碰换算、同敌8float槽、移动覆盖/恢复及段入口清单。新增3套完整源/目标案例，源编译反编译及目标check通过，20次80帧run诊断为0；累计教材8个源完整例与30个目标完整例。Infinite恒宽子集明确707设置前提与四态危险窗，不能直接照抄hold。增量只读审阅未发现实质问题；命令、锚点和仍未动态对拍的边界见[验证记录](../investigations/2026-11-05-th18-textbook-verification.md)。


### 2026-11-05 高版本切分指南

用户指出Boss有专门符卡标记，并明确要求仿TH06写高版本切分指南。新增[指南](../../transcribe/th18/splitting.md)及[split契约](../../transcribe/th18/contracts/split.md)，TH18为已核实例，其他作品需核本作编号/机制。Boss从声明定位，沿HP/超时中断链找入口/非符/结束；同卡难度声明及练习入口不重复计卡，stars不作边界依据。道中从main/call/async创建编排切，覆盖对象是事件实例而非sub；保留重叠、尾部、跨文件依赖和前置状态。

使用split.md人工/AI记录模板，尚未冻结机器schema或接入旧TH06 pipeline/split_check；本轮只写指南，不实施切分器或运行整关。源事实参考TH18一面：MainLatter中的编队先于bossWait，不能假定中Boss和后半道中互不重叠；Boss1→BossCard1→Boss2→BossCard2是普通链，练习入口不再重复计卡。曲线真实依赖继续列出并暂缓，不能漏单元/默认短线替代。


### 2026-11-05 用户批准击破速度奖励波独立切分

Sol试切Stage01后，用户说明MainSub05的enmCreateF编队用于奖励提前击破道中Boss，并明确训练可作为Boss后的独立一波。已确认这一用途的奖励编队可固定完整排程，不因实际击破时刻/F门部分出生继续阻塞切分；保留编队内部时序/位置/参数快照/rank及敌行为，报告写清训练固定场景。Stage01 W05入口MainSub05，保留wait100，两轮40个计划创建实例；不带入上游MBoss创建后wait160。普通波重叠、未知opcode、物理差异等不因此获得普遍简化授权。

指南/契约/skill/统一口径及本次split/troubles末尾均记用户后续决定；原始Sol静态观察仍保留，不改写原作F门语义。详见[已批准规则](../../transcribe/th18/splitting.md#已批准击破速度奖励编队独立成波)。


### 2026-11-05 独立波次与交接取舍、非攻击内容省略

用户进一步确认波次尾部重叠可先分开训练，交接的精确位置/清场/死亡回调暂不用管，作为允许的训练牺牲；不因此堵住整关切分。仍保留当前攻击本体的移动、首发等待、共享et与波内发弹。指南/skill/契约与试切记录已同步，原Sol观察保留为历史。

系统性省略说明集中到transcription-policy“系统性省略与外壳接管”：普通掉落/奖励、计分统计、纯表现与段外UI/对话，不是删所有特效或unknown指令。已有renkolab item-drops已核573/574限时奖励掉落；补核569/570为章内计数权重登记/结算。另核401零帧只清插值，不把坐标改成0；525清敌会运行登记的死亡sub，571清回调的路径不同。源事实仍记录，训练交接按用户允许范围简化，不扩展成全引擎新机制。临时证据在transcribe/work/th18-stage01-blockers-20261105，未运行原作。


### 2026-11-05 弹型/半径对齐是独立要求

用户指出训练转写需核原作与目标的弹种/半径至少一致，不能将已准波次交接简化外推为物理半径近似。现场按已固定exe hash从TH18表逐项重读48个f32半径，并读引擎tables_v0.bin实际192个appearance，内容hash37a7ff12fe40e24e；与源builder12行一致。现有映射为4同形同基础半径、11同形半径差、33缺直接弹形，详细结果见[报告](../investigations/2026-11-05-th18-radius-alignment.md)及JSON。

当前fire/sh_fire从appearance取出生半径，无公开逐弹半径写口；set_sprite不刷新半径；原HITBOX/SIZE等动态几何未一般支持。TH18原生circle为d²<br²+pr²，目标为d²<=(br+pr)²，基础半径相等仍不等于危险区相等。修改全局12行不能覆盖同形多半径（Rice2.4/SpinRice3.2），且影响旧卡；具体引擎接口/内容表/碰撞规则方案需按用户约定先确认，未实施、未升级wheel。

### 2026-11-05 出生近似授权与TH06/NC版本纠正

用户明确同意为性能省略出生减速和出生无判定，避免所有普通弹仅为出生阶段挂变换链；写入[统一口径](../../transcribe/th18/transcription-policy.md#已批准省略出生减速和无判定窗口)。不外推为基础半径、出生退位移、后续攻击变速/冻结/DELAY或激光预警的省略许可。用户接着要求先查偏差是否一直存在，本轮仅核查/文档修正，不实施引擎方案。

旧TH06映射从2026-09-16提交8e4e22d起已接受半径/弹型及出生特效近似。重要版本区分：经典TH06是盒对盒；流水线实际来源TH06NC为圆对圆半径相加，玩家默认1.25。已直接复读既有NC Ghidra JSONL的14006a980消费者、140010870普通弹传模式1调用与140068160初始化；目标默认玩家2.5、目标弹半径由图集行决定，尺寸偏差早已存在。TH18另有平方和公式差异。已纠正TH06 mapping将经典方框说明直接套NC的缺漏；未重核NC十型模板尺寸或改旧卡。详细依据见[跨版本复核](../investigations/2026-11-05-th18-radius-alignment.md#th06与th06nc的历史差异复核)。

### 2026-11-05 已确认弹型按作品区分，碰撞算法选择后置

用户确认外观共用、弹型/物理半径按作品区分，例如TH06米弹与TH18米弹分别保留。当前转写沿用引擎现有半径相加公式，不以未来碰撞算法选择作为切分/转写/审核的前置条件；不再因这个已接受差异单独判blocked。具体选择接口留待后续引擎修改，本次不改引擎或wheel。按作品保留原作半径、当前目标实际值与后续对接项，不能将预定半径接口称为已有API。规则集中于[统一口径](../../transcribe/th18/transcription-policy.md#已批准按作品区分弹型碰撞算法选择后置)，skill和写审契约已同步。

### 2026-11-05 弹型大表已完整接入引擎与训练

用户先选择只准备数据/生成器，随后明确扩大到完整大表运行时接入，并允许人工合成TH06/TH18分作品裁切图源。ENGINE_VER31、WorldTables格式v6/World布局不变，训练wheel0.4.5、内容hash7091aec34290ffd7。旧192项不改，追加TH06十型（base192+type*16）、TH18四十八型（base352+type*16），总1120逻辑项/635物理图格，919有效/201缺色。

清单/两份合成图源在引擎godot/assets/bullet；slice_bullet_sheet.gd离线生成64px图集、layout、Rust整数append和ECL词表。池sprite保留字段但存logical appearance，表现端查物理格，RL TYPE保持逻辑id；出生半径直接取表，无需xform。新词表直接保留源color，不沿旧8色换色。经典TH06/NC十型基础半径已分别核实相同；NC高清美术未复刻。新卡可明确使用TH06_* / TH18_*，旧TH06批量config和176份旧单元不自动迁移。

实际验证：727新有效槽真实wheel出生半径/id全匹配，缺色硬币3编译拒绝；旧192格像素不变，重复烘焙逐字节一致；Rust相关包/fmt/clippy/表校验、15项wheel冒烟、20项Python预览/回放通过，六组旧卡观测回放与0.4.4逐字节一致。golden因tables_hash入校验从帧0变化，不能报告不变。独立只读审阅无重要待修项。ANM动画、静态anchor/blend简化保留；动态HITBOX/SIZE与换图刷新半径仍未扩展。未原作/Windows/GPU/跨平台/训练/提交/推送。详见[接入记录](../investigations/2026-11-05-touhou-bullet-catalog.md)及[wheel来源](../practice-cards/reports/stg-rl-045-adoption.json)。

### 2026-11-05 清理日期命名的过程目录

用户指出transcribe/work又堆积日期命名过程文件夹，要求清理。已删除15个完成调研/验证目录、601个过程文件，释放40.01 MiB；正式报告、证据JSON、引擎图源/生成器和当前wheel保留。Stage01五份切分资料完整移到work/th18/stage01，弹型总览移到work/preview/bullet-catalog.png，移动前后哈希一致；units/review/split/logs、th18-prototype、Opus抽检目录与state.jsonl均未改动。

以后任务结束及时清理一次性下载、解包、构建副本和核查日志，避免根目录长期堆积日期目录；仍需使用的资料按稳定用途目录保存。历史报告中的临时命令/路径作为当时执行记录，不当成持续存在的工具入口；正式生成器和检查仍以仓库代码为准。
