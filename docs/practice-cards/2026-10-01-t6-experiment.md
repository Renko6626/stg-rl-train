# T6：14维激光 token 与联合自注意力

2026-10-01：用户确认新版设计与实现后，明确授权提交、推送和启动一轮训练。

## 实验设置

配置：[exp-t6-laser-joint.toml](../../configs/exp-t6-laser-joint.toml)。沿用T5卡池、seed=1、reward、混合意图、运动层和课程；从随机初始化训练。

- `danger_topk_v8`：14维局部几何／观测运动／伸长余量／预警token。
- `set_attn_v3`：弹与激光独立MLP、类型嵌入，一层联合自注意力替换T5弹专用层；交流后分别池化，主干保持704→256→256。
- 参数383,443，相比T5增加192。
- 4096环境×64steps×3500updates＝917,504,000环境帧；checkpoint和原作评测间隔250。
- 保持原13卡评测与best选择；5张专项留出仍由`tools/eval_specialist_checkpoints.py`在训练结束后评测。
- 单训练seed、组合改动，没有同期组件消融；与T5的比较是历史对照，不将收益归因到单独token或注意力。

## 入口与验收

沿用`magnus/train-specialist.sh`，以`GPUCHECK=1`启用正式训练前的严格GPU检查。gpucheck配置仅在检查阶段将AMP设为off，比对eager／compile／CUDA图；正式训练仍读取原T6配置，使用bf16。GPU检查失败则Job返回非零并通过EXIT trap保存日志，不进入正式训练，不使用warn-only绕过。

Magnus检查提交前资源，再申请1×A100、32核、64G，优先级显式B2，缓存镜像`pytorch:2.5.1-cuda12.4-cudnn9-devel`。提交固定已推送的完整SHA；启动后区分安装、GPU检查和真实训练更新。

本地模型／ONNX和旧torch2.5.1 CPU栈已验证，详见[实施证据](../superpowers/specs/2026-10-01-laser-token-joint-attention-design.md)。本次追加入口开关的验证是shell语法与配置覆盖检查。

提交前将旧CPU venv的stg_rl同步到当前仓库wheel 0.4.1，以`PYTHONPATH=src`运行`python -m pytest -q tests/test_featurize_v8.py tests/test_model_v3.py tests/test_envwrap_lasers.py tests/test_smoke.py -k 'v8 or v3 or lasers'`：27 passed、11 deselected，包含新版bf16 CPU PPO冒烟。`bash -n magnus/train-specialist.sh`、GPU检查配置覆盖／TOML往返、registry模型构建、两份wheel SHA及`git diff --check`通过。新入口不改变未设置GPUCHECK时的旧行为。

提交前资源实查：6张A100空闲、108核空闲、495,904MB内存空闲，足够申请上述单训练资源；读数只代表当次查询。

结果仍由EXIT trap打包交给File Custody，保留期240分钟。启动本机取回监视器时必须同时处理完成与提前退出，领取码数字长度不作固定限制；本机监视器不等于平台持久调度。

## 部署边界

本次只训练模型，游戏调用方尚未适配图版本6的`laser_start_len`输入。GPU检查与训练启动不能证明部署可用或训练收益。
