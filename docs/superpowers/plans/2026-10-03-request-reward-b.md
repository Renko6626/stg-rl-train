# 请求动作 reward：B 实验实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. 建议本任务采用 Native，由主 agent 顺序实现。

**Goal:** 在 T7 的15维输入和8根激光路线下，准备按原始请求计量动作惩罚的 B 配置。

**Architecture:** 复用 EnvWrapper 的请求入口，在 StepInfo 中提供仅供奖励使用的请求快照；RewardFn 选择请求或实际执行的动作统计。策略、RawObs、ONNX 与 PPO 算法保持现有结构。

**Tech Stack:** 项目现有 Python/PyTorch/tensordict/stg_rl；不升级依赖。

**Spec:** [请求动作 reward 方案](../specs/2026-10-03-request-reward-b-design.md)。

## Global Constraints

- main 上工作，保留既有改动；不 commit/push；2026-10-03用户另已授权直接提交B训练任务。
- player 保持15维，v8/v3，激光 K=8，GRAPH_VERSION=6；无 RNN、请求历史输入或部署接口改动。
- 保留运动层 hold=[2,6]/delay=[0,2]/slow=true、逐帧决策和原 reward 系数。
- 请求仅用于奖励内部记账，不改变实际执行动作、随机流、原动作指标或其他 reward。
- request 模式拒绝 frame_skip!=1；旧配置默认 executed。
- 项目测试约束优先：只补关键新增行为的真实生产链路覆盖，不为配置和文档另造测试。

## Review Focus

- 被运动层挡住／撤回的请求必须纳入奖励，不能误用执行按钮。
- 终止帧使用旧局请求快照，下一局首段不算跨局回抽。
- 请求段长度与原 quick_frames 阈值同口径，首次请求不罚 quick_change。
- 左右镜像与实际执行保持一致；增加记账不改变物理轨迹或随机流。
- CUDA 图打包的 None／张量结构固定；request 字段缺失时报错，默认旧模式兼容。

## Task 1：请求快照与奖励来源

**Files:** 修改 `src/stgtrain/config.py`、`src/stgtrain/envwrap.py`、`src/stgtrain/reward.py`；复用／补充 `tests/test_reward.py` 的真实 EnvWrapper 夹具。

**Interfaces:** `reward.action_source` 默认 executed，可选 request；StepInfo 追加 `request_buttons`、`prev_request_buttons`、`request_dir_hold: Tensor | None`。RawObs 无新增字段。RewardContext 追加来源选择，现有构造默认执行口径。

- [x] 在真实 example_ring、mirror=false、hold=[4,4]/delay=[0,0]/slow=true 中发送动作 ID `[6,14,6,14,14]`。断言执行方向为右／右／右／右／左；请求 key_press 原值 `[2,1,1,1,0]`、quick_change `[0,1,1,1,0]`；执行口径分别 `[2,0,0,0,1]`、全0。预期来自手算按钮序列，不调用被测算法生成。
- [x] 复用真实终止／reset用例，令终止帧请求方向改变：该帧仍按旧请求扣分；新局首帧 quick_change 为0。用保存的 StepInfo 复算终止奖励，确认下一次 step 不污染快照。
- [x] 同 seed、同固定请求序列比较 executed/request 的实际按钮、RawObs 与 v8 特征；覆盖镜像实例。这里不要求 reward 相同。
- [x] 运行上述新增用例，确认未实现时因缺少 request 模式而失败。
- [x] 在 config 默认值和 validate 中添加来源选择与 request/frame_skip约束。旧配置默认 executed，不接受拼错来源。
- [x] EnvWrapper 仅 request 模式记录快照／段长度，先拍终止帧再清零；复用原动作表，不第二次调用 motor，不增加随机抽样。
- [x] RewardContext 提供选定的当前／上次按钮和方向段长度，key_press、quick_change、shift_toggle 使用该来源；其余项不变。request字段缺失时报错，executed保留原dir_hold缺席行为。
- [x] 运行 `uv run --frozen pytest -q tests/test_reward.py tests/test_motor.py tests/test_envwrap.py tests/test_config.py tests/test_episodes.py`，确认所有相关检查通过。

## Task 2：B配置、冒烟与交付

**Files:** 新建 `configs/exp-request-reward-k8.toml`；局部扩展 `tests/test_smoke.py` 的现有v8/v3冒烟参数；更新实验登记、本方案和项目记忆。

**Interfaces:** B 与原 T7 配置的处理差异只有 `reward.action_source="request"`；frame_skip=1显式写出与默认一致。模型构建与导出继续使用v8/v3。

- [x] 复制 T7 参数准备 B 文件，不自行续训／占用T编号；加载展开两份配置，检查实际差异只在来源选择。
- [x] 在现有 `test_train_laser_model_end_to_end_and_export` 中加入 request模式一臂，复用生产train/checkpoint/build_deploy链路。保留原两臂，避免另搭冒烟体系。
- [x] 运行 `uv run --frozen pytest -q tests/test_smoke.py -k 'train_laser_model'` 和 `uv run --frozen pytest -q tests/test_export_v8.py`。检查真实B参数构建的player spec仍15维，输入名／图版本仍6；不新增常量断言测试。
- [x] 核验旧CPU venv可用性，在torch2.5.1/tensordict0.6.2中运行新增reward用例和request冒烟；若没有可用venv，按项目记忆准备隔离CPU环境。不得把CPU通过说成CUDA图通过。
- [x] 更新文档，区分代码准备完成、本地／旧栈通过、GPU待验、未训练；运行 `git diff --check` 和文档链接核对。
- [x] 审查快照生命周期、first-step计数、图输入结构和两臂配置差异。推荐 Native 顺序执行后，用一名独立 reviewer只读检查改动；权限限本任务，不推送／部署／读密钥／再委派。

2026-10-03用户明确要求直接实现并提交B任务；Native执行完成，相关检查和独立审查见方案实施记录。B沿用T7从头seed1／3500轮；本轮只提交B，未追加同期A。用户未授权git提交／推送，采用Magnus现有File Custody交付经SHA校验的源码覆盖包。
