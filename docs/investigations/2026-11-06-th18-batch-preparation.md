# TH18 普通六关批量切分与派发准备

2026-11-06，用户确认以薄脚本调用Luna/Terra，默认2并发。本轮完成切分和作者分配，未开始新增卡转写。

使用 [codex-batch.py](../../transcribe/tools/codex-batch.py) 调用本机 `codex exec`，沿用ChatGPT登录，显式指定模型和推理强度；未使用Codex原生子代理工具，未修改全局配置或TH06 pipeline。任务及原文资料留在忽略目录 `transcribe/work/th18/`。

| 关 | 道中 | 中Boss | 关底Boss | 合计 | 已有成品 | 可交接新卡 | 待补源证据 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 7 | 1 | 4 | 12 | 2 | 10 | 0 |
| 2 | 8 | 1 | 5 | 14 | 2 | 10 | 2 |
| 3 | 8 | 1 | 6 | 15 | 1 | 12 | 2 |
| 4 | 10 | 1 | 6 | 17 | 0 | 11 | 6 |
| 5 | 9 | 1 | 7 | 17 | 1 | 12 | 4 |
| 6 | 8 | 1 | 10 | 19 | 0 | 12 | 7 |
| 合计 | 50 | 6 | 38 | 94 | 6 | 67 | 21 |

67张新卡分配Luna medium 21张、Terra high 46张，独立审核统一Terra high，主会话逐条复核。可交接仅表示源边界和交接资料已定位，仍需每卡准备源闭包、入口状态、目标时限和工具说明，再运行作者及独立审核；不等于目标可运行、源语义已审核或可自动收卡。

具体分配与证据：

- [分配总表](../../transcribe/work/th18/assignments.md)与[机器可读分配](../../transcribe/work/th18/assignments.json)。后者不是执行清单。
- 一至四面使用各 `stageNN/split-batch/`；五、六面使用 `stageNN/split-review/` 补齐版，旧稿保留。每关附主会话复核。
- [独立边界核对](../../transcribe/work/th18/independent-boundary-check.md)：正常main、Boss中断链、只作过渡的BossN、F条件编队的具体来源。
- [首个Luna任务单](../../transcribe/work/th18/stage01/th18_s1_w04/brief.md)：一面三只GirlD01，已备带原行号的CP932解码摘录及执行清单，已dry-run，尚未派发；派发前按brief核当前harness。未写目标ECL。

21张待补分为：13个道中的相对椭圆/ABS合成；s5_b4、s6_b8的圆运动消费者；s6_b1/b3/b5/b7/b9的ins_94输出坐标；s6_b10的funcSet(1)与REACT消费者。它们是具体源证据缺口，不代表必须扩展引擎。普通六关已核闭包未命中Curve；Extra缺道中st07原文且rank映射未确定，未纳入。

二、三、五、六面的F编队已沿主流程及中Boss HP/超时解除boss0的路径确认同类奖励用途，训练固定为Boss后完整独立波，保留各自计划创建、变量、镜像和内部时序，不移植一面参数。四面MainSub02的enmAlive补怪保留真实存活驱动，不套奖励规则。已批准出生和交接简化未重新变为阻塞。

实际运行与检查：

- `python transcribe/tools/codex-batch.py transcribe/work/th18/split-tasks.json --ids split-s1 --jobs 1`：首关真实试跑通过后，剩余五关以`--jobs 2`完成。
- `python transcribe/tools/codex-batch.py transcribe/work/th18/split-review-tasks.json --jobs 2`：五、六面初稿的笼统闭包缺口经两路Terra high补齐到具体源引用。
- Luna medium独立静态审阅脚本，无critical/major；六次切分、两次补齐、一次脚本审阅共9次真实模型调用均退出0且交付齐全。进程成功和语义通过分别记录。
- AST语法检查、六关与首作者清单`--dry-run`通过；真实缺失可执行文件的检查得到批次退出1、任务结果127及缺失交付，非法ID在启动前被拒绝。未新增永久测试项目。
- 每任务日志含prompt、invocation、events、stderr、final和result；失败人工处理，不自动重试、不自动收卡。已有输出拒绝覆盖，返工使用明确的新任务目录。

本轮没有目标编译/validate、原作动态对拍、训练、收卡、commit或push。现场wheel `build_info()`为0.4.7/ENGINE_VER35；引擎源码为35，首作者派发前仍需完成任务单的harness核验。

后续更新：同日完成[圆周/椭圆源语义调查](../../transcribe/th18/circular-motion.md)，并取得用户明确的舍入/零点几像素精度取舍。上表为初次切分时统计；当前解除15项移动资料阻塞，可交接新卡82（Luna21/Terra61）、剩余源待补6，详见最新分配总表。作者仍未启动，未将资料补齐当作整卡验收。

## 正式写审准备更新（2026-11-06）

ins_94已通过renkolab现有社区标签、只读Ghidra Listing及四点目标探针补核，解除六面五张非符的该项资料阻塞。用户随后明确暂缓最后一符th18_s6_b10，不继续追查funcSet/REACT。当前94候选为6已有、87可准备写审（Luna21/Terra66）、1暂缓；分配JSON将该项标为deferred，保留原研究缺口和编号。

新增[正式派发入口](../../transcribe/th18/dispatch.md)，集中说明有效切分、最新运动/精度与出生等简化口径、模型分工和交接次序。旧研究稿保留历史，入口与分配表说明已解决项，不再把它们作为当前阻塞。TH18 skill和README也标明本轮用户已确认的Codex脚本路线，避免回退到历史默认后端或反复确认。

首批准备th18_s1_w04（三只GirlD01）及th18_s2_w06（两只GirlD02）：两份CP932解码带原行号源摘录、各自brief/prompt、共同工具说明、作者执行清单，以及各自只写review目录的Terra独立审核brief/prompt和依赖作者交付的审核清单。两卡均支持连续四档；预定完整练习窗1200/1400帧，允许按本波实际尾部延长并解释，不把跨波wait截成攻击时限。s1任务单补明etSpeed栈的首速；s2注明611追加、ANIM退位移与出生阶段省略、十轮随机相位环及90帧VELTIME。

现场工具：引擎源码35；release harness无版本命令，复用其replay读取器，故意输入版本0，得到“文件0，本引擎35”的预期拒绝（退出1），证据留production/preflight/harness-version.txt。已安装wheel build_info为0.4.7/35，JSON留同目录。此探针只核工具版本，不是整卡验收，也不新增产物签名要求。

作者与审核均尚未启动；其余85张尚未逐卡打包。准备检查包括两份清单dry-run、计数/路径/源摘录核对，实际结果见production/preflight/preparation-check.txt。本次未做新卡编译/运行/validate、原作动态对拍、收卡、训练、commit或push。

## 首批实际写审结果（2026-11-06）

用户“开干”后，首批两路Luna medium作者及两路Terra high独立审核通过薄脚本实际执行，4次调用退出0、交付齐全；审核各从原文推导并实测4条锚点，复跑四档完整validate。具体命令、日志和主会话结论见[实跑记录](../../transcribe/work/th18/production/first-batch-run.md)。

| 单元 | 四档弹峰值 | 段结束帧 | 最终结论 |
|---|---|---|---|
| th18_s1_w04 | 57/122/277/422 | 1203 | Terra原攻击审核pass；主会话关闭额外控制敌体碰，真实VecEnv观测与完整validate确认 |
| th18_s2_w06 | 60/91/116/197 | 920 | Terra审核pass；末发490、结束前尾弹已清空；主会话将无源声明的局部时间估计由540修正为800，完整validate复验 |

所有最终四档诊断及开场死亡率均0。主会话检查out/card ECL与meta同步、源参数及审核日志；一面的额外控制敌体碰是审核后发现并修正，未将原Terra结论冒充对该修正的实测。二面借实际敌承载phase，出界会让阶段早于1400预算结束；保留本波完整发射、运动和尾弹后按已接受收尾口径通过，没有加保活机制。

首批暴露的流程问题已记录：一面作者4次点位采样发生在最终轮数修正前，二面作者超过4次上限且旧锚点有旧外壳帧号；均如实保留，最终数值依据来自独立审核。后续先固定外壳再采样，uv使用任务内缓存，额外控制敌必须关闭体碰；不扩展成新状态机、自动恢复或重复签名流程。

分配记录更新为6已有成品、2本轮已写审待正式收卡、85待准备/写审（Luna19/Terra66）、1用户暂缓。首批产物仍在work任务目录，未正式收卡、原作动态对拍、训练、提交或推送。
