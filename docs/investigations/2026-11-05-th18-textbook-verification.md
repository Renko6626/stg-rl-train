# TH18 教材验证记录

> 临时材料维护：下文日期目录及其中命令是当时执行记录，现已按用户要求清理。正式结论、来源哈希和正文示例保留；不将这些临时路径作为长期工具入口。

2026-11-05。对应[教材正文](../../transcribe/th18/mapping.md)、[弹型](../../transcribe/th18/bullet-types.md)、[发射模式](../../transcribe/th18/aim-modes.md)、[插值](../../transcribe/th18/interpolation-modes.md)、[EX](../../transcribe/th18/ex-effects.md)及[激光](../../transcribe/th18/lasers.md)。所有例子为自写合成程序；本轮只写文档，不改引擎、训练或批量流水线。

## 工具与输入

- 引擎源码 HEAD `2f24d86`；使用 `/data/sunyunbo/www/stg-engine/target/release/stg-harness`。
- 原作编译器 `/data/sunyunbo/www/renkolab/local/vendor/thtk/build/thecl/thecl`；本地thtk HEAD `892114a0fcaa0bbdaaecf3cb4ad56f758683fb40`。
- 映射 `/data/sunyunbo/www/renkolab/local/vendor/eclmap/eclmap/th18.eclm`；HEAD `f146162e330c27d1b0a8880c3a41884615147a11`。
- `.venv/bin/python -c 'import stg_rl; print(stg_rl.build_info())'` 返回version=0.4.4、engine_ver=30、tables_hash=37a7ff12fe40e24e、git_sha=unknown；不把wheel未知sha写成源码HEAD。
- 三种代码围栏：`tecl`=完整原作侧合成程序，`ecl`=完整目标程序，`text`=片段。每个完整程序单独抽取；不能将多个带main的例子合成一个编译单元。

原始第三方页面、原作资产、Ghidra函数导出及运行日志留在忽略目录。相关版本/来源另见[资料清单](2026-11-05-th18-textbook-sources.json)，本轮未重新建库或使用自建反汇编。

## 编译与目标运行

实际运行的命令形式如下，路径指向对应围栏抽出的独立文件：

```bash
"$THECL" -c 18 -m "$ECLMAP" example.tecl example.bin.ecl
"$HARNESS" check example.ecl
"$HARNESS" run example.ecl --frames 200 --seed 1 --rank 2
"$HARNESS" run example.ecl --frames 34 --seed 1 --rank 2 --at 33
```

| 文档 | 完整原作例 | 完整目标例 | 实际目标运行范围 | 结果 |
|---|---:|---:|---|---|
| mapping | 5 | 11 | 每例200帧；完整攻击另四个rank各760帧 | 全部退出0 |
| bullet-types | 0 | 1 | 8帧，取第3帧 | 全部退出0 |
| aim-modes | 0 | 4 | 8帧，取第3帧；峰值36/9/8/16弹 | 全部退出0 |
| interpolation-modes | 0 | 4 | 8帧，取第3帧 | 全部退出0 |
| ex-effects | 0 | 4 | 140帧 | 全部退出0 |
| lasers | 0 | 3 | 110帧；另取预警/生效/退出及飞棒锚点 | 全部退出0 |

首轮共5个原作合成例编译、27个目标例编译并运行。目标运行诊断的task_faults、contract_viol、pool_full均为0。正文临时脚本 `main/verify.py` 的首轮运行每例均为200帧；完整攻击的760帧复核在 `main/anchors.py` 单独执行。

材料位于 `transcribe/work/th18-textbook-20261105/`：`main/validation.json`、`main/anchors.json`、`tables/validation.json`、`ex-lasers/*.check.txt` 及对应运行stdout。它们不是新的永久测试项目。

## 独立期望与运行锚点

下表帧号均为执行第N次step后的全局帧。独立期望由例子中的数学参数推导，再对照转储；临时断言已检查颗数、角速网格、状态和段事件。

| 正文例子 / 帧 | 推导依据 | 实际观察 |
|---|---|---|
| 移动 / 32、62 | 二次减速中点完成75%，终点120 | x=90、120，y=96 |
| accum / 6 | 初值1，每帧加0.25，共4次 | 新弹speed=2 |
| 8路3层环 / 3 | 8×3=24；每45°一组，速度1/1.5/2 | 24颗，角BAM=8192×i，各三速；appearance34 |
| SLOW_AFTER / 2、31、32 | E=2，E+30=32 | 前两锚点speed=2，第32帧speed=1 |
| LATE_AIM / 33 | 每弹出生速2保存后加0.5 | 8弹均speed=2.5；方向随效果时各弹位置不同 |
| 扫射激光 / 32 | 出生帧3起计满30次预警 | state=0，timer=30，angle=16384 BAM |
| 扫射激光 / 33 | 进入生效并每帧转64 BAM | state=1，timer=1，angle=16448 BAM |
| 扫射激光 / 93 | 生效60次后退出 | state=2，timer=1；near/far=0/320，width=12 |
| 80长飞棒 / 22、25 | 每帧推进4，达到棒长后near也推进 | near/far=0/80、12/92 |
| 完整攻击 / 124 | 120帧外壳后新pattern首发，低难8路/高难12路 | rank0/1=8颗，rank2/3=12颗，初速2 |
| 完整攻击 / 723 | 开段后600帧触发超时结束 | 四rank均PHASE_ENDED@723 |

完整攻击在rank0/1峰值122弹，rank2/3峰值182弹；760帧均无fault/viol/pool_full。峰值受弹出界影响，不等于累计发射数，未拿峰值反推源周期。

激光参考页另有192长飞棒：帧50为near/far=0/192，帧60为40/232；预警扫射例帧32仍预警、33生效、92仍生效、93退出。详见该页实测表。

表内逐颗通用扇形曾在扩大到15弹时超出单任务同帧预算；定稿示例缩为9弹并复核运行。文档明确应先静态化分支/使用合适发射器，不能加wait拆波后仍声称同帧等价。未因此改引擎预算或原作参数。

## 内容、链接与边界

最终检查覆盖本轮正文、五表、TH18 README/skill/写审契约、准备/验证记录及相关入口。对本作原始EX type使用常量豁免后，按现有文档检查器检查相对链接、地址记法/版本和表格单元格；技能frontmatter检查及 `git diff --check` 另执行。实际命令 `python transcribe/work/th18-textbook-20261105/doccheck.py` 检查13份文档与5份入口链接，全部0错误；`python /data/sunyunbo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .claude/skills/th18-transcribe` 返回 `Skill is valid!`。范围内 `git diff --check` 无输出、退出0。首轮32个完整代码围栏与已编译/运行的抽取文件逐字核对一致。

审阅特别核对了目标扇形的相邻路间距、整周环的层偏角、源速度端点、同敌/同任务共享范围和激光边界。目标 `set_sprite` 仅换sprite、不刷新出生radius，已在表和正文明确；原生SETSPRITE重读默认半径不等于目标行为。独立只读审阅提出的三项事实已修正：换型保留旧半径、move_to期间位置接管及结束后速度恢复、set_life(1)清理前仍有末帧积分/判定。

本轮没有运行原作游戏、做原作动态对拍、验收正式训练卡、接入TH18批量工具或启动训练。发射mode11/12的调速、STEP d、REACT消费者、部分激光参数/EX、动态几何及曲线实体的缺口继续明确保留。编译或短时运行通过不覆盖这些边界。


## 对比TH06后的补充验证

用户随后确认修正小问题并补齐普通指令索引、敌人/移动/段入口状态、完整转换案例和统一口径，同时明确曲线激光暂时不做。新增[指令索引](../../transcribe/th18/instructions.md)、[敌人状态](../../transcribe/th18/enemy-state.md)、[转换案例](../../transcribe/th18/conversion-examples.md)、[统一口径](../../transcribe/th18/transcription-policy.md)，正文/README/skill/写审契约同步。原作前置状态、未知消费者和未接受的物理差异仍按实际攻击处理。

- `python transcribe/work/th18-supplement-20261105/instructions-state/check-docs.py`：227组opcode/精确助记名与本机TH18 eclmap相符，errors=[]；只证明命名，不代表227种功能全部已支持。
- 新增3个完整原作合成程序按本记录thecl18命令编译、反编译，3个目标完整程序harness check通过。6个围栏与已检查文件逐字核对一致；共计正文/参考8个原作完整例、30个目标完整例。
- 新案例20次80帧目标run均退出0，task_faults/contract_viol/pool_full均为0。时钟例首发13/23/33、末发48；共享配置例帧4色2速1、帧14新弹色6速3，旧弹不变；Infinite在帧9生效、18退出、22回收，near/far=0/270、width8，时长6/9/4。期望和实际表写在案例页，源时序为原生导出静态推导，未原作动态对拍。
- 一圈字面量另做最小编译：360deg和65536 as angle退出0，非法65536bam按预期退出1并报超u16范围。证据在 `transcribe/work/th18-supplement-20261105/main/literal-checks.json` 及对应日志。
- `python transcribe/work/th18-textbook-20261105/doccheck.py`：17份文档的链接/地址/版本/表格检查与5份入口链接均0错误；skill quick_validate通过；范围内 `git diff --check` 通过。
- 一次增量只读审阅未发现确定的实质问题，核了循环退出等待、共享配置取样、Infinite额外状态4的危险帧及曲线blocked规则一致性。

本次新增材料在忽略目录 `transcribe/work/th18-supplement-20261105/`，所有第三方/原作全文和反编译仍不入库。未新增永久测试、改引擎/批量工具或训练；曲线实际依赖明确blocked，不默认短线替代。


## 高版本切分指南检查

用户要求仿TH06写高版本切分指南后，新增splitting.md与contracts/split.md，约定当前人工/AI记录为split.md，不冻结机器格式或假称已有TH18 split_check。现场读TH18一面源，核普通流程调用顺序、MainLatter先编队再bossWait的重叠、Boss1→BossCard1→Boss2→BossCard2→BossDead四个中断后继；核537/523/540/514/521/711精确名。临时结果存 `transcribe/work/th18-splitting-guide-20261105/checks.txt`。

文档检查器现覆盖19份文档和5份入口链接，links/addr/version/tables全部0错误；skill quick_validate通过，范围内git diff --check通过，新文档无行尾空白。没有新增可执行ECL例子，因此未重跑编译/训练；也未实际完成整关切分、机器覆盖检查或原作动态验证。
