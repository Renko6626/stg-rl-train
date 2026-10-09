# 请求动作惩罚 A/B：B 实验准备方案

日期：2026-10-03。用户已确认采用 T7 的 8 根激光，并明确否决在输入中区分请求与执行：保留原 15 维 player 输入，只改 reward。本文件替代本轮先前提出的请求历史输入方案；v9、27 维输入与图版本 7 均撤回。

## 目标和对照

检验将动作切换惩罚从实际执行移到策略原始请求，能否使模型本身输出更平滑，同时交代生存和跟点的代价。

| 臂 | 配置基线 | 模型输入 | 动作惩罚计量对象 |
|---|---|---|---|
| A | T7，激光 K=8 | 原 v8，player 15 维 | 实际执行 |
| B | 同 A | 同 A | 模型原始请求 |

保留 `danger_topk_v8`、`set_attn_v3`、图版本 6；卡池、rank、意图、课程、运动层、逐帧决策、判定放大与 PPO 参数保持一致。请求记录只用于 reward，不加入 RawObs 或特征；不增加 RNN、动作窗口、运动层隐藏状态、want_mismatch、正则项或两帧决策。

## reward 的局部改动

建议在现有 reward 配置增加 `action_source = "executed" | "request"`，默认 executed，旧配置／checkpoint 沿用旧行为。B 显式选择 request，其他 reward 项与系数不变：

- `key_press=-0.003`：比较相邻策略请求的按钮，仍按新按下键位计数，不改成所有动作变化都扣分。
- `quick_change=-0.01`：请求方向改变时，上一段请求方向持续帧数 ≤ 原 `quick_frames=3` 才扣分。
- `shift_toggle=0.0`：仍关闭；实现 source 选择时让这一动作项也使用相同来源，避免之后配置非零时口径不一致。
- death、follow_shaping、hold、segment_survived、edge_hug 等保持现有实际环境结果口径。

只迁移计量对象，不把执行和请求两套惩罚叠加。系数保持只是第一轮控制选择，不能声称累计惩罚强度不变；日志报告各分项，以识别请求更碎造成的总扣分增大。

## 内部请求记账

在 EnvWrapper 中维护 reward 专用的上一请求按钮与请求方向段长度，StepInfo 追加可选的 `request_buttons`、`prev_request_buttons`、`request_dir_hold`，均为固定 [N] int64 张量。RawObs 和策略输入不增加字段。

每次真实 `step(want)` 拍下送入运动层之前的原始请求，运动层仍只调用一次。请求按钮按本局镜像转换为引擎按钮口径，并用原动作表保留恒按 SHOT；本局镜像固定，方向变化／新按键数量不受左右互换影响。

`request_dir_hold` 表示本次决定改变请求前，上一请求方向已经持续的真实帧数；沿用原执行方向段的计数约定：首次请求用 DIR_HOLD_NEVER，故不算短段回抽。只有低速位改变不清方向段。内部计数有安全饱和上限，不新增16帧特征截断。

终止帧先为刚结束的局保存 StepInfo 和惩罚需要的完整请求快照，再逐环境清零上一请求按钮、恢复首段哨兵；下一局首步不与上一局请求比较。显式 reset 同样清零。不得让后续 step 或 reset 原地改写已返回的快照。

只在 request 模式维护／提供这些可选张量；同一次运行字段是否为 None 固定，符合 RolloutGraphs 的打包和 CUDA 图约束。request 模式缺少请求字段时报错，不能静默退回执行口径。奖励计算不增加 CPU 同步、随机数或按张量值走 Python 分支。

本实验 `frame_skip=1`；request 模式暂拒绝其他 frame_skip，避免包装层步数与真实段时长混用。实际按钮、执行计数、prev_action、EpisodeTracker 操作指标及运动层随机流保持原逻辑；现有操作指标仍描述执行，请求统计需明确另列。

## 配置与训练边界

已准备 `configs/exp-request-reward-k8.toml`，复制 [T7 配置](../../../configs/exp-t7-laser-k8.toml)，仅追加 `[reward] action_source="request"` 并显式保留 frame_skip=1。A 可继续用原 T7 配置，默认执行口径。

模型结构不变，旧 T7 权重在技术上可加载；本次按用户的直接提交要求，沿用T7从头seed1／3500updates。历史 T7 不能替代同期 A 的因果对照；本轮只提交B，未追加同期A。

ONNX 输入、GRAPH_VERSION 和部署填表保持版本 6，本轮不需要部署新增请求输入。保留 TH06NC 的 8 帧激光运动平滑，不自动替换现有游戏包。不创建新T编号；用户已授权提交B Magnus任务，未授权git commit/push。

## 验证与判读

复用现有真实 EnvWrapper、RewardFn 和测试夹具，补最少的关键新行为：运动层挡住的请求切换仍扣分，反复请求／撤回的短段计数正确，终止帧保存旧局奖励且新局不跨局比较。检查默认执行模式保持旧结果、固定请求序列下两臂实际轨迹和旧特征一致、镜像请求计量一致。

在现有 v8/v3 CPU 冒烟中覆盖 request 模式的 rollout、奖励、更新与 checkpoint。相关已有 config/motor/reward/envwrap/episodes/smoke/export 检查通过后结束本地验证；旧 torch2.5.1/tensordict0.6.2 CPU 栈先检查训练链路，真实 GPU 再验 CUDA 图和 bf16。CPU 检查不代替 GPU 验收。

训练评测报告普通／激光、Hard/Lunatic、跟点／自由通过率，请求与执行的变向、短段和往返，以及 reward 分项和吞吐。输入没有请求历史，切换成本对策略可能存在部分不可观测性；这是用户选择的本轮处理，不能预先断言必然失败或成功。若请求更稳但通过率下降，明确报告权衡，不只以变向少判成功。

依据：[现有 reward](../../../src/stgtrain/reward.py)、[请求／执行诊断](../../practice-cards/2026-10-03-t7-control-diagnostics.md)、[实施计划](../plans/2026-10-03-request-reward-b.md)。

## 实施记录（2026-10-03）

用户要求直接实现并提交 B 训练，沿用 T7 的3500轮／seed1。本地实现完成：reward.action_source默认executed，B为request；请求数据只存于StepInfo，RawObs/player15/v8/v3/图6保持原接口。展开T7/B配置唯一差异为action_source。

- `uv run --frozen pytest -q tests/test_reward.py tests/test_motor.py tests/test_envwrap.py tests/test_config.py tests/test_episodes.py`：73 passed。
- `uv run --frozen pytest -q tests/test_smoke.py -k train_laser_model tests/test_export_v8.py`：3 passed、12 deselected，覆盖原两臂与request新臂冒烟；该选择表达式未选中导出文件的用例，因此导出另跑。
- `uv run --frozen pytest -q tests/test_export_v8.py`：2 passed，真实torch/包装/ORT对拍。
- 旧CPU栈torch2.5.1+cpu/tensordict0.6.2，以`PYTHONPATH=src`执行`python -m pytest -q tests/test_reward.py tests/test_motor.py tests/test_envwrap.py tests/test_smoke.py -k 'request or train_laser_model'`：7 passed、61 deselected。
- 独立只读审查未发现实质性问题，并核对低速切换、quick_frames边界与固定StepInfo打包结构。

GPU CUDA图尚未本机验证，提交任务使用现有train-specialist入口的GPUCHECK=1闸门，通过后才进入训练。代码以固定base commit加校验过的Magnus File Custody源码覆盖包交付，不将未提交改动误称为commit内容，不commit/push。完整提交与运行状态另登记实验记录。
