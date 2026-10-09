# 密度图 CNN 配对适应训练（P2）准备

2026-10-08，用户要求准备GPU实验。已完成本地代码、两臂配置、旧CPU栈预检、冻结源码与提交参数；**尚未上传、提交Job或启动GPU训练**。P3/Perceiver不在本次准备范围。

2026-10-09后续：用户确认改为u2000协议并启动两臂，要求先提交/推送仓库；以下是10月8日的1000轮历史准备记录，当前协议与运行证据见[u2000实验记录](2026-10-09-density-p2-u2000.md)。旧overlay包不用于此次启动。

## 训练协议

依据[已认可实验计划](../superpowers/plans/2026-10-08-density-ablation-perceiver.md)的P2及[即时消融结果](2026-10-08-density-ablation-results.md)：

| 参数 | A：CNN | B：无CNN |
|---|---|---|
| 配置 | [exp-density-cnn.toml](../../configs/exp-density-cnn.toml) | [exp-density-none.toml](../../configs/exp-density-none.toml) |
| model.density_enabled | true | false |
| 起点 | 最新B/Shift K8 u1000 best.pt | 同一checkpoint |
| seed/更新 | seed1，1000轮 | 相同 |
| 新增帧 | 262,144,000 | 相同 |
| LR | 1e-4，1000轮线性退火 | 相同 |
| PPO | 4096环境×64步，8 minibatch，4 epoch，bf16 | 相同 |
| 保存/标准评测 | 每250轮 | 相同 |
| 运动层与reward | 最新B/Shift完整配置冻结 | 相同 |

两份TOML是来源checkpoint完整配置的显式副本，解析后只差`model.density_enabled`，共同把设备指定为CUDA、torch线程2、环境线程30。近场64弹/8激光/8敌、player15、v8/v3、704维主干、动作18路、frame_skip=1均不变。

源checkpoint SHA256：`8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88`。

两臂新建optimizer、随机流、课程状态、update/env_steps/best；只继承agent张量，不resume。此阶段是同预训练权重的短轮适应筛查，不是从零结构上限或多训练seed确认。

## 已准备的实现

- `--init-density-from`：v8/v3专用白名单初始化，仅允许`model.density_enabled`变化；特征K、维度与其他模型参数仍逐项检查，所有权重张量strict加载。旧`--init-from`和resume行为不放宽。来源和完整加载键写入env.json。
- 无CNN组跳过密度分箱/聚合，特征化返回同shape零占位以保留现有构造契约；模型requires移除density，PPO只缓存模型所需特征，密度图不进入rollout/shuffle buffer。主干拼接位置仍为64维零向量，旧CNN参数保留便于严格迁移。
- 新初始化保存u0.pt，并在训练开始前评测原作跟点/自由，保存首局记录。u0只作诊断，不参与best选择；原训练标准评测仍按跟点选best。
- 评测CLI支持显式eval seed、逐局记录、划分覆盖与rank过滤；默认划分保留全部原rank，全卡默认rank2的旧行为保持。
- `magnus/train-density.sh`：bootstrap→严格FP32 GPUCHECK→bf16训练→固定u1000最终评测→打包取回。训练/评测失败会交回已有产物；上传失败也返回非零，不能把无结果的Job标为正常成功。
- `tools/eval_density_checkpoints.py`：三个eval seed（12345/23456/34567），每card/rank32局，原作跟点+自由、专项自由，仅rank2/3，每臂5952局。输出逐局身份、arm、训练seed、意图、运动层与update，核对数量/ID/汇总及输入SHA。

## 资源与估时

准备完成时资源查询：**2026-10-08 13:25:08 UTC（北京时间21:25:08）**，Rise-AGI，6张A100/108核CPU空闲。快照在`runs/density-p2-submit/cluster-preparation.json`，不能当作稍后提交时仍可用的保证。

拟每臂1×A100、32核CPU、64G主存、20G临时盘，优先级**B2**，使用已验证CUDA12.4 devel镜像；两臂最多并行，共2张GPU/64核CPU。启动时另检查实际亲和性与cgroup配额。

历史1000轮训练含标准评测约76分40秒。本轮增加u0与固定三eval seed评测，每臂预留约90–110分钟、不含排队；GPU编译/安装/打包波动及B实际速度未测。两臂训练新增524,288,000帧，GPU运行预算参考约3–4 GPU小时，不是完成时间承诺。

本轮标准评测共6656局、u0诊断共3328局、最终共11904局，总计21888局GPU评测；其中最终5952/臂是主比较。u0和训练中检查点不当作独立训练seed。

## 验证证据

- 相关已有检查与覆盖缺口：本地`uv run --frozen pytest -q tests/test_checkpoint.py tests/test_featurize.py tests/test_featurize_v8.py tests/test_ppo.py tests/test_model_v3.py tests/test_eval_ckpt.py tests/test_smoke.py`，67 passed，4条CPU CudaGraphModule旁路警告；同一组在torch2.5.1+cpu/tensordict0.6.2旧CPU venv亦67 passed。
- u0新增端到端：本地`pytest -q tests/test_smoke.py::test_train_warm_start_uses_new_config_and_fresh_counters tests/test_eval_ckpt.py`，4 passed；旧CPU栈三种初始化模式3 passed。测试核对真实u0张量等于来源、optimizer空、计数0、基线记录及后续真实PPO更新。
- 最终rank/seed/records CLI检查在旧CPU栈1 passed；覆盖真实划分rank3筛选，不把专项rank0/1混入主口径。
- `runs/density-p2-submit/preflight.py`对真实最新B/Shift权重严格加载两臂：全部源张量一致（含推理副本）、optimizer全新、同真实观测非密度特征相同、B缺density仍能推理、缓存键正确。两臂均PASS，结果在preflight.json。
- `bash -n magnus/train-density.sh`、Python编译、`git diff --check`通过。独立只读审阅发现并修复上传失败退出码问题；准备产物复核未发现新的实质问题。
- P1完整输入已在后续开发前留存，当前P1逐局重算通过冻结快照继续有效，未把新代码当旧实验来源。

本地检查命令使用`UV_CACHE_DIR=/tmp/sunyunbo/uv-cache`、`MPLCONFIGDIR=/tmp/sunyunbo/mpl-density-ablation`、`OMP_NUM_THREADS=2 MKL_NUM_THREADS=2`；旧CPU命令使用`PYTHONPATH=src`及本机历史临时v062解释器。上述测试结果分批记录，存在重复用例，不相加作为独立验收样本。

**尚未验证：** 实际CUDA eager/compile/图重放、bf16正式训练、GPU吞吐/显存、训练收益、最终5952局输出及云端上传取回。GPUCHECK会在每条Job启动后执行，通过才允许训练；CPU旁路检查不等于CUDA验收。

## 冻结提交材料

材料位于`runs/density-p2-submit/`：preflight.json、source-manifest.json、stage/、source-overlay.tar.gz、archive.json、两份submission-args.json、prepare.py/submit.py。运行产物遵守现有gitignore。

- 固定Git main基底：`4a3bc4a35ca57d4fd114cca227206fed658a84a0`，采用已使用过的源码overlay路线，不commit/push。
- 冻结647个文件，归档5,771,466字节。
- 归档SHA256：`64dc393f9feab4f3265ab6488e934543aece096793a47e95c1fe04b25a118fe4`。
- stage含完整训练源码、卡池/划分、两份配置、既有bootstrap/lib、专用runner/final-eval工具、wheel及校验和、初始化权重/env.json。
- 实际Job入口下载后先核验归档/逐文件SHA，再安装固定wheel并启动；旧0.4.1 wheel只从未来Job工作区移除。
- submit.py默认仅生成参数，已执行默认预览，两条均显示NOT SUBMITTED。显式`--submit`才会重新查资源、上传并下载对拍归档、提交两臂；已存在jobs.json时拒绝重复启动。任何输入源码变化需重新冻结，不能悄悄复用旧准备包。

本次准备未上传、未提交Job、未替换模型/部署、未commit/push。提交前需确认本阶段训练预算；启动后按项目约定几分钟内核查真实进程/更新，并监控正常完成与提前退出，及时取回240分钟有效结果。
