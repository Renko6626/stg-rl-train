# T7／T8：激光候选数8／4的完整训练对照

2026-10-02：用户要求执行激光N=16→8和16→4两条实验，编号继续使用T系列。命名T7和T8。

用户中途要求暂停并确认“进入编码器的激光数量”确实改变。实际前向hook确认：K16/8/4时激光MLP输入为[B,16/8/4,14]，联合层输入为[B,80/72/68,64]。不是保留80长度只屏蔽行。随后用户明确要求把两项任务挂上去，恢复提交与开跑。

## 唯一处理变量

| 实验 | 配置 | 激光K | 联合序列长度 | 起点 |
|---|---|---:|---:|---|
| T6历史基线 | exp-t6-laser-joint.toml | 16 | 80 | 随机初始化，seed1 |
| T7 | [exp-t7-laser-k8.toml](../../configs/exp-t7-laser-k8.toml) | 8 | 72 | 随机初始化，seed1 |
| T8 | [exp-t8-laser-k4.toml](../../configs/exp-t8-laser-k4.toml) | 4 | 68 | 随机初始化，seed1 |

两条均从T6配置复制，规范化后的唯一差异为`featurize.k_lasers`。不加载T6权重继续训练；之前同权重裁剪的结果已经单独保存在[T6记录](2026-10-01-t6-experiment.md)。此次检验低K从头学习后的水平，避免把训练时K16造成的分布依赖当作低K能力上限。

沿用4096env、64steps、3500updates＝917,504,000环境帧／条，seed1、bf16、学习率衰减、卡池、rank2训练、reward、意图、课程、运动层和判定放大设置。模型仍为v8／v3，383,443参数；不引入稀疏注意力或改变子弹64的数量。K改变的是固定形状关系层的长度和激光可见范围，不改变MLP参数数量。

## 评测与比较

- 每250轮保存模型并评原13卡，仍用原best选择规则。
- 训练后沿用4项best意图／运动层探针和8份五张专项留出评测。
- 与T6主结果比较末四次u2750/3000/3250/3500，分普通10卡／激光3卡、rank2／3、专项家族和rank0..3。
- 特别关注水符与瞄准回退、短棒提升是否保留；不能只用专项总体均值判定无损。
- 分阶段计时与稳态SPS使用同一窗口，GPU、CPU申请和实际版本栈均记录。理论配对减少19%／27.75%不是实际加速保证。
- 每臂只有一次seed1训练，T6是历史对照而非本轮同期控制；不作多训练种子的显著性结论。

## 执行路线

分别提交两个Magnus Job，每条1×A100、32CPU、64G，B2，缓存CUDA12.4 devel镜像。保持单训练／GPU的计时口径，沿用`GPUCHECK=1 bash magnus/train-specialist.sh`：先对本K形状做严格GPU验收，PASS后才正式训练。失败保存已有产物，仍有240分钟File Custody取回窗口。

准备时资源实查：0张A100空闲、60核CPU空闲；Job需排队，不以提交成功或Pending声称已经开始训练。每个Job用固定已推送完整SHA。本机为两条分别启动结果取回监视器，保留PID、状态和下载证据；监视器不是平台持久存储。

## 验证与范围

纯现有配置对照，不新增永久测试或重构训练器。提交前检查与T6的完整配置差异、卡池和留出隔离、模型参数／初始权重一致、现有相关检查，以及旧torch2.5.1 CPU栈下K4和K8的短PPO冒烟。实际命令、提交SHA和Job结果随后追加。

已验证：规范化配置仅k_lasers不同；383,443参数及seed1初始权重逐张量一致；213加载卡、195训练起点、5张专项留出隔离。`uv run --frozen pytest -q tests/test_featurize_v8.py tests/test_model_v3.py tests/test_export_v8.py`为21 passed。旧torch2.5.1+cpu／tensordict0.6.2／stg_rl0.4.1使用`PYTHONPATH=src <v062>/bin/python runs/t6-preflight/t7-t8-cpu-smoke.py`完成K8/K4各1次bf16 PPO更新、夹具评测、checkpoint和部署包装；每条16env×16steps，使用160帧上限，仅检验链路。初版临时脚本漏掉eval目录初始化，改用项目make_run_dir后两条均通过，不修改生产训练器。配置差异复核、入口bash语法与git diff空白检查通过。

缩短序列在数学上减少计算：attention配对减少19%／27.75%，现有联合block主要矩阵乘MAC约减少12.14%／18.04%。实际GPU内核和训练SPS是否提升、提升多少仍由本次运行测量，不保证理论比例或固定完成时刻。

不改游戏部署调用方，不扩大稀疏注意力范围。工作目录中既有`:memory:.ses`与实验无关，保留本地。

## 提交记录（2026-10-02）

实验配置和T6结果记录已提交并推送到origin/main，训练快照为`5997cecdda500e87ff794da1e7ecd1959007e7c1`。

| 实验 | Job | 状态（提交后实查） | 入口 |
|---|---|---|---|
| T7，K8 | [82677c563c5b0cc1](http://162.105.151.134:3011/jobs/82677c563c5b0cc1) | Pending | GPUCHECK=1 bash magnus/train-specialist.sh configs/exp-t7-laser-k8.toml t7-laser-k8 |
| T8，K4 | [28a4532abf792cc4](http://162.105.151.134:3011/jobs/28a4532abf792cc4) | Pending | GPUCHECK=1 bash magnus/train-specialist.sh configs/exp-t8-laser-k4.toml t8-laser-k4 |

Job list逐项核验了固定SHA、B2、1GPU和32CPU。两条均为64G内存、20G临时盘、CUDA12.4 devel镜像；目前尚未进入安装／GPU验收／正式训练。排队等待不可据GPU历史速度预测，未承诺半夜完成时刻。

分别在`runs/t7-monitor/`、`runs/t8-monitor/`启动本机监视器，Python PID2548425／2548447已确认存活并记录Pending。它们每60秒检查状态，在Success或提前退出时保存日志、尝试取回结果，检查u3500、最终原作评测和8份专项JSON。领取码数字长度不固定；监视最长72小时以覆盖排队，不会修改Job时限。进程若因本机关闭而停止，仍需在240分钟领取窗口内人工取回。

用户本次明确要求将两项任务挂上去；没有新增续训、稀疏注意力或其他卡池实验。
