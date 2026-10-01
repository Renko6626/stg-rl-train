# 激光变异试产

2026-09-27 试产 10 张、2026-09-28 第二批新增 20 张，合计 30 张合成激光变异。原作 `cards/` 与默认配置不变；显式选 `configs/exp-t2-laser-pilot.toml` 会合并当前整个 `cards-synthetic/`（现为 30 张）。两批制作阶段只做验收；随后已用于 T2/T3/T4 训练。机械/独立规格审查合格不代表已证明训练收益或可躲性。

当前事实与纠错见 [2026-09-29 事实和未决问题](2026-09-29-facts-and-open-questions.md)，包括生成约束来源、激光真实机制及 T4 的实验混杂。

2026-09-30 用户认可增加以激光为绝对主体的专项加强练习，见 [激光专项设计方向](2026-09-30-laser-specialist-design.md)。该文记录持续压力、候选机制家族、观测预算及验证构思；尚未生产专项卡，具体卡数、参数与下一轮训练配置未定。下文的底子/overlay 规则描述既有两批混合卡，不直接作为专项卡契约。

2026-10-01 专项批次已完成：20张原创纯激光卡，20/20机器门通过，17张有限样本候选（12 train、5 held-out），3张NOT_PROVEN隔离。见[结果与限制](2026-10-01-batch3-results.md)及[逐卡最终汇总](reports/batch3/batch3-acceptance-summary.json)。从零卡的加载兼容、独立机器/真实玩家工具已实现并审查；[派发模板](laser-specialist-dispatch-prompts.md)包含执行后经验。制作阶段未启动训练或提交；用户随后授权启动[T5专项混合训练](2026-10-01-t5-experiment.md)。候选目录独立于前两批，旧配置不自动扩池。

## 来源标签

原作source='th06'兼容加载为Card.data_kind='original'；未知/example来源保持unknown。前两批变异卡显式source='synthetic'、data_kind='synthetic'、base_card、mutation_id及provenance原文件SHA。标签不进入策略输入；新训练run env.json.cards提供card_id→来源/底子映射，starts旧格式保持。

前两批变异卡复制底子，main仅新增标记spawn行，overlay.ecl包含新逻辑；删除入口行可逐字恢复底子。根伴生任务不新增敌人，不抢boss_or_free目标。变异卡的底子source_ref不能与激光留出任意源区间重叠；原作历史划分保持153个rank2训练起点（166卡减13留出）。

第三批从零卡使用 `synthetic_kind='laser_specialist'`、`generation_mode='standalone'`，按[专项契约](laser-specialist-contract.md)校验，无原作底子或伪造血缘字段；来源标签仍不进入策略输入。`cards-laser-specialist/`只含有限样本候选，`cards-laser-specialist-quarantine/`另存未找到真实完成轨迹的三个版本。

## 第一批试产清单（2026-09-27）

| 合成ID（synth_laser_前缀） | 底子 | 新机制 | 随机化/难度 |
|---|---|---|---|
| s1_b1 | th06_s1_b1 | 静止预警竖线，左右轮换 | 固定pilot，各rank相同 |
| s2_b1 | th06_s2_b1 | 沿射线推进短棒 | 固定pilot，各rank相同 |
| s2_b3 | th06_s2_b3 | 随机斜向omega扫射 | 随机原点/角度/转向；rank调角速 |
| s3_b1 | th06_s3_b1 | 原点平移的双线通道 | 随机中心/初始间距；rank调平移速 |
| s4_b1 | th06_s4_b1 | 在已有激光底子加单条预警狙 | 随机原点，lz_aim；rank调宽度 |
| s4_w10 | th06_s4_w10 | 双飞行短棒 | 随机原点/开角；rank调棒速 |
| s5_b1 | th06_s5_b1 | 向下平移的水平激光 | 随机初始y；rank调移动速 |
| s5_w05 | th06_s5_w05 | 近端留空的旋转短段 | 随机初角/转向；rank调角速 |
| s6_b1 | th06_s6_b1 | V形双射线 | 随机中心/开角；rank调宽度 |
| s7_b1 | th06_s7_b1 | 随机方向的短棒列 | 随机原点/方向；仅继承源卡Extra特殊值rank4 |

常规难度映射仍是0=Easy、1=Normal、2=Hard、3=Lunatic；s7源卡metadata的ranks=[4,4]是既有Extra特殊值，沿用training_ranks兼容，不改变常规映射。

前两张固定pilot用于验证流水线；其余八张须有实际像素/角度量级的随机变化。随机overlay消费共享引擎RNG，底子原发弹代码不改，但后续随机序列可能变化。ranks/time_limit沿用底子；所有速度/宽度范围仅为试产保守选择，不是原作实测保证。

## 复跑

```bash
.venv/bin/python -m stgtrain.practice_validate cards-synthetic --all --json docs/practice-cards/reports
.venv/bin/pytest -q tests/test_cards.py tests/test_practice_validate.py tests/test_config.py
```

每卡机器报告保存实际卡文件SHA、验证器和harness SHA、安装stg_rl版本、各rank×seeds1/7全时长诊断、任务spec驱动的关键帧几何、首/末出生帧与段末回收。字段缺失/重复/非零即失败；reqs_dropped本试产严格要求0。数量上限和时序通过声明关键帧检查与独立源码审查，不宣称逐帧穷举；随机卡两种子需出现可观测几何差异。机器没有策略推理，不证明可解。

不同Luna审查者读取TASK+完整脚本+机器报告；审查报告绑定文件SHA。文件变更使旧pass失效，必须重跑并重新审查。report为机器候选依据，独立review为第二门；两者均通过才可称验收候选。详见[契约](laser-pilot-contract.md)、[计划](../superpowers/plans/2026-09-27-laser-pilot.md)、reports/。

本流程只处理新增合成卡，现有TH06转写后端和Opus抽检/逐条复核不变。

复盘与后续批量化设计见[2026-09-27试产复盘](2026-09-27-pilot-retrospective.md)。

## 第二批扩量（2026-09-28）

第二批在上述十个已核过来源的底子上，各新增 `v2`、`v3` 两种不同形态，目录和任务见[第二批计划](2026-09-28-batch2-plan.md)。20 张卡均保留独立底子血缘、随机几何、完整机器报告和非作者 Luna 审查；最终状态与当前哈希见[第二批验收汇总](reports/batch2-acceptance-summary.json)。通用验收器已补关键帧必填字段、重复 JSON/帧拒绝、时限处实际回收检查及 metadata 继承检查。修订过的卡均以最终文件重新验收、复审。

本目录下旧[第一批验收汇总](reports/acceptance-summary.json)仍只描述当时的 10 张卡，不应当作当前整个合成卡池的数量。
