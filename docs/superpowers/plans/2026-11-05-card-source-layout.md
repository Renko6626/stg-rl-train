# 按来源统一卡库与生产目录实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 将 cards 与 transcribe 都按 th06、th18、synthetic 组织，接通已有消费入口并保持既有实验卡集合。

**Architecture:** 成品统一放 cards/<source>/<id>，细分依赖 metadata；生产资料放 transcribe/<source>。复用现有加载器、配置与验收入口。本次先完成已确认的目录和消费端迁移，不将迁移扩大为整套TH18批量编排实现。

**Tech Stack:** 现有 Python、TOML、JSON、shell；无新依赖。

**Spec:** docs/superpowers/specs/2026-11-05-transcribe-modular-design.md，尤其“产物、synthetic 与消费端”及精简验证反馈。

## Global Constraints

- 在main，保留已有修改，不commit/push；不改引擎、PPO、模型、卡ECL行为，不启动训练或付费生成。
- 不新增hash、冻结、审批、恢复机制；沿用已有测试，关键新行为补简短测试。
- 三张暂停卡使用enabled=false；五张专项held-out仍不进入训练；卡ID与旧评测清单不变。
- 旧任务、审核结果和历史实验报告保留原内容；更新现行入口与执行脚本。

## Review Focus

- 递归发现与metadata筛选不能把暂停卡或其他来源卡意外加入旧训练。
- 统一synthetic目录后，早期只含30张变体的配置仍排除17张专项。
- checkpoint内旧目录配置仍能通过已知目录名转换选择到相同卡集合，不使用软链。
- 收卡必须落到本作品目录；预览标题与试玩清单使用同一个卡发现入口。
- 新TH18来源识别、一般standalone合成卡与固定held-out不依赖卡ID前缀。

## Task 1: 成品加载与选择

Files: src/stgtrain/cards.py、config.py，训练/评测/录像/bench/gpucheck的现有调用，tests/test_cards.py、test_config.py。

Interfaces: `discover(cards_dir, *, include_disabled=False)`递归发现；`configured_cards(env: dict)`用env.card_filter筛选sources/tags/ids/exclude_synthetic_kinds。默认仍为TH06；旧配置的已知目录名在from_dict中转换，显式card_filter表示新配置。

- [x] 在已有测试中覆盖嵌套来源、暂停卡、metadata筛选、TH18与standalone，以及旧配置转换。
- [x] 实现上述逻辑并替换使用训练配置的discover调用；保留原有专项卡字段要求，不推广它们到一般合成卡。

## Task 2: 迁移卡目录与消费入口

Files: cards*/、configs/*.toml、src/stgtranscribe/pipeline.py与preview.py、transcribe/play.sh、现行tools/scripts及相关测试。

- [x] 先记录当前各配置的卡ID与训练起点集合（本地一次性记录，无hash）。
- [x] 166张原作移入cards/th06，50张合成移入cards/synthetic；3张暂停卡加enabled=false，保留既有其他字段与源码。
- [x] 训练配置统一cards根＋metadata筛选；初期变体配置排除laser_specialist，其余保持原来源集合。
- [x] 收卡写cards/th06，密度统计仍TH06；预览递归发现，试玩列出启用成品。现行诊断脚本同步路径，历史报告不批量改写。

## Task 3: 生产入口、说明与集中验证

Files: cards/README.md、cards/th06/README.md、cards/th18/README.md、cards/synthetic/README.md、transcribe/synthetic/README.md与contracts/、transcribe/README.md、设计与记忆。

- [x] 补synthetic独立入口与作者/审核契约：允许设计brief或底子卡；不伪造source原文，不增加hash或普遍可躲证明。
- [x] 说明结果流向及配置用法；TH18批量工具尚未接通的边界如实保留。
- [x] 集中运行卡加载/配置/相关消费端与transcribe测试；比较旧配置卡ID和训练起点集合，编译全部迁移卡一次；shell语法检查，不启动浏览器或训练。
- [x] 一次只读范围审查；处理实际问题，完成后记录验证和未验证项。

## 执行记录

- 用户已确认布局；按已授权方案直接执行，不再请求执行方式确认。遵循项目约束，使用本计划记录进度，不另建重复任务日志或逐任务审核流程。

- 完成：cards/th06 166张，cards/synthetic 50张（3张enabled=false），cards/th18暂空；transcribe同名三入口齐备。卡ID与ECL行为未修改，旧根cards-*目录移除。
- `uv run --frozen pytest -q tests/test_cards.py tests/test_config.py tests/test_eval_ckpt.py tests/test_replay_gif.py tests/test_card_intent.py tests/test_intent_follow.py tests/test_practice_validate.py tests/test_specialist_validate.py tests/transcribe`：213 passed、1 skipped，67.89s。
- 只读审阅指出两个专用验收器--all混入其他合成类型；已使用共用metadata选择器修复，并同步专项可行性工具的批量选择。另保留configured_cards的原作→变体→专项顺序，防止旧课程日志起点列序改变。
- 修正后运行 `uv run --frozen pytest -q -rs tests/test_cards.py tests/test_config.py tests/test_practice_validate.py tests/test_specialist_validate.py tests/test_specialist_feasibility.py tests/test_card_intent.py tests/transcribe/test_preview.py`：110 passed、1 skipped，13.72s。跳过项仅针对pre-0.4.1引擎，当前版本不适用；未重复整套检查。
- 一次性迁移检查：45份配置的卡ID、训练起点集合与旧目录分组顺序保持；216张卡全部编译成功；批量选择器分别得到30张overlay和17张专项。未添加hash记录。
- `bash -n transcribe/play.sh`通过；只列试玩清单，列出213张启用卡，未启动viewer或浏览器。文档目标链接与diff空白检查通过。
- 未运行实际训练、原作游戏、付费模型生成或TH18真实卡生产；TH18/synthetic共用批量调度未在此次目录迁移中实现。未commit/push。

## 阶段性提交准备（2026-11-05）

用户随后授权提交并推送main。本次纳入卡库迁移、TH18资料/单卡验收及其0.4.5新弹型依赖；Perceiver实验与游戏部署改动留在工作区，混合文件按代码块暂存。

对暂存索引导出的独立文件副本执行相关测试（用本项目Python，PYTHONPATH指向副本src）：228通过、1项旧引擎用例跳过，2项Rust工具测试因临时目录缺少相邻stg-engine失败；补齐临时环境后仅重跑这2项，均通过（21.92s）。未修改测试预期或生产逻辑。副本所用源码不包含未提交的Perceiver/部署改动；Git空白检查、已纳入文档目标链接和既有wheel校验清单通过。
