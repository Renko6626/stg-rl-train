# 密度图 CNN 即时消融（P1）

2026-10-08。用户授权先执行即时消融，仅CPU推理评测；未授权启动P2/P3训练或替换部署。

状态：正式3968局评测完成，六个工作项齐全，独立逐局重算与来源哈希检查通过。

结论：该权重关闭密度分支后出现净退化，原作自由−1.44pp、跟点−2.64pp，专项自由−5.94pp。高密度原作子集自由持平、跟点反而提高；退化集中于Lunatic及个别卡，不能概括为“远场高密度普遍依赖CNN”。尚不支持直接无损删除，也不能由即时消融推断无CNN适应训练的上限。

## 撑过率结果

每行两臂局数相同，差值为关闭减开启，pp为百分点。子集与总体存在包含关系，不应把行数相加当作新样本。

| 场景 | 每臂局数 | CNN开启 | CNN关闭 | 差值 |
|---|---:|---:|---:|---:|
| 原作自由，总体 | 832 | 95.79%（797） | 94.35%（785） | −1.44pp |
| 原作自由，普通 | 640 | 95.78%（613） | 94.53%（605） | −1.25pp |
| 原作自由，激光 | 192 | 95.83%（184） | 93.75%（180） | −2.08pp |
| 原作自由，高密度 | 256 | 92.19%（236） | 92.19%（236） | 0.00pp |
| 原作跟点，总体 | 832 | 92.07%（766） | 89.42%（744） | −2.64pp |
| 原作跟点，普通 | 640 | 92.81%（594） | 90.31%（578） | −2.50pp |
| 原作跟点，激光 | 192 | 89.58%（172） | 86.46%（166） | −3.12pp |
| 原作跟点，高密度 | 256 | 91.02%（233） | 93.36%（239） | +2.34pp |
| 专项自由，总体 | 320 | 52.50%（168） | 46.56%（149） | −5.94pp |

### 难度与逐卡风险

| 场景 | Hard差值 | Lunatic差值 |
|---|---:|---:|
| 原作自由 | 0.00pp | −2.88pp |
| 原作跟点 | 0.00pp | −5.29pp |
| 专项自由 | −2.50pp | −9.38pp |

自由档较大的逐卡损失：th06_s1_b4/r3由32/32→27/32（−15.63pp），th06_s3_b7/r3由31/32→27/32（−12.50pp）。跟点档th06_s2_mb1/r3与水符th06_s4_b12/r3均减少8/32（−25pp）。专项通道laser_sp_corridor_04/r3由31/32→23/32（−25pp），错峰laser_sp_stagger_04/r3由24/32→17/32（−21.88pp）。

也有改善，例如th06_s3_w12/r2自由27/32→30/32、跟点24/32→28/32。逐卡每rank仅32局，这些是本次观察，不是稳定效果或根因证明。

### 配对变化

| 场景 | 开启存活、关闭失败 | 开启失败、关闭存活 | 净少存活 |
|---|---:|---:|---:|
| 原作自由 | 40 | 28 | 12 |
| 原作跟点 | 80 | 58 | 22 |
| 专项自由 | 58 | 39 | 19 |

原作高密度自由虽净持平，仍有15局损失与15局改善；净持平不代表行为或失败集合相同。

## 如何理解专项退化

此次消融把整个density64维输出归零，连同网络在空密度图上的常量响应也移除了。对同一checkpoint额外执行真实CNN分支空图前向，64维中37维非零，L2范数5.5535，最大值2.1184。

所以专项退化不能直接等同于丢失了大量远场子弹信息：关闭分支本身也改变了主干收到的基准激活。已有“分布突变”边界在这里尤其重要。P2配对适应可以检验主干能否重新适应；这轮未做常量响应补偿或改权重的附加消融。

下一步仍按已确认路线进行CNN/无CNN同预算适应实验，主看固定u1000的自由原作、高密度与专项风险。即时结果尚不足以取消该对照或宣布Perceiver有收益；本轮没有启动后续训练。

## 协议与来源

- 计划：[密度图消融与Perceiver实验计划](../superpowers/plans/2026-10-08-density-ablation-perceiver.md)。
- 最新B/Shift K8 u1000 best.pt；SHA256 `8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88`，本次重算匹配，权重严格加载。
- 同一模型参数，两种前向路径：原CNN；跳过CNN/投影，在主干拼接前返回严格零的64维向量。主干704维、近场子弹64、激光8、敌人8、动作表与其他分支不变。
- CPU FP32，Python3.11.15、torch2.5.1+cpu、tensordict0.6.2、stg_rl0.4.2、ENGINE_VER24。临时旧CPU venv仅安装了仓库冻结的0.4.2 wheel，不改变本地uv锁栈。
- torch线程8、环境线程4、interop线程1；cgroup v1 `cpu/user.slice/cpu.cfs_quota_us=-1`、period=100000，未设置额外CPU quota；线程数量是本次选择，不由宿主机112个逻辑CPU推定实例配额。
- eval seed12345，贪心、无滞回、无镜像、frame_skip=1。motor开启、hold=[2,6]、delay=[0,2]、slow=true；真实判定半径评测，hit_extra由生产eval_cfg关闭。
- 原作13卡×Hard/Lunatic×32局，跟点/自由两档、两臂，共3328局；专项5卡×Hard/Lunatic×32局，自由档、两臂，共640局。总计3968局，均只取各环境首局。
- 两臂同设备、线程、卡/难度顺序和批量布局，原作每臂一次26组×32=832环境，专项10组×32=320环境。
- 跟点为lower_half_uniform_v1，自由为follow_player_v1；训练意图仍保存在来源配置，不拿训练reward当主指标。

高密度分组预先固定：th06_s2_b6、th06_s3_w12、th06_s3_mb3、th06_s4_w16，各rank2/3。普通/激光分组仅适用于原作；专项单列，不算入普通卡。

## 产物与复跑

正式输出：`runs/density-ablation-20261008/`，包括manifest、六份原始逐局JSON、summary、complete.json和独立重算脚本validate.py；这些运行产物按现有gitignore不入库。可版本管理汇总：[P1汇总JSON](reports/density-ablation-p1-summary.json)，记录各产物SHA、逐组计数及逐卡结果。

后续准备P2之前，已将P1完整输入（619个文件和原checkpoint）留存至同目录`source-snapshot.tar.gz`，SHA由`source-snapshot.json`记录。P2开发改变工作树后，validate.py核验该冻结快照，仍可重算P1；不会用新源码冒充旧实验输入。

六个正式评测工作项累计1576.03秒，即26分16秒，不包含准备、预检和导入/编译组件。开启/关闭用时分别为：原作跟点362.46/356.23秒、原作自由348.33/338.77秒、专项自由86.54/83.70秒。轨迹不同，未将这些差值当作严格推理性能收益。

命令（实际CPU venv路径为本机历史临时环境，其他机器需先准备同版本CPU栈）：

```bash
OMP_NUM_THREADS=8 MKL_NUM_THREADS=8 MPLCONFIGDIR=/tmp/sunyunbo/mpl-density-ablation PYTHONPATH=src /tmp/sunyunbo/claude-1007/-data-sunyunbo-www-stg-rl-train/6ef04b69-4ce5-41e3-85e9-6ef735bfcd15/scratchpad/v062/bin/python -u scripts/diag/density_ablation.py --torch-threads 8 --env-threads 4
```

脚本拒绝覆盖已存在的manifest，复跑须通过`--out`使用新目录。来源checkpoint、源码、卡池与划分、wheel均以SHA冻结，完成时重查输入文件未变。

## 实现与验证

- `set_attn_v3`增加默认开启的density_enabled开关，不增加/删除checkpoint参数；旧checkpoint仍严格加载。
- 生产evaluate增加可选include_records；默认返回结构不变，逐局记录附card/rank/eval_seed，保留env编号。
- 独立诊断脚本用生产特征化、环境与evaluate，纯FP32策略前向，不创建optimizer、不跑训练或CUDA图。
- 此次只执行P1，未扩展eval_ckpt CLI或实现P2的缓存省算/初始化迁移，也未实现Perceiver。
- 真实观测预检确认默认与显式开启输出逐元素相等；关闭后改变density输入不会改变logits/value；独立观察主干输入的density切片全零。
- 旧CPU栈相关检查：`OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 MPLCONFIGDIR=/tmp/sunyunbo/mpl-density-ablation PYTHONPATH=src <CPU_VENV>/bin/python -m pytest -q tests/test_density_ablation.py tests/test_model_v3.py tests/test_evaluate.py tests/test_export_v8.py`，**24 passed in 45.87s**。
- 两项新增行为先观察到预期失败，再实现开关/逐局输出；专项分组修复复用真实pair_summary验证，不以mock或源码字符串断言。
- 独立只读审阅发现专项激光被标为普通的汇总问题，已修正并复核。未重复运行产品测试。
- 调试预检曾主动中止，未合并进正式数据。正式run的逐局结果才用于本次结论。
- `python runs/density-ablation-20261008/validate.py`：3968局重算通过，ID唯一/两臂匹配、总体与分组撑过数、平均帧数、配对净差、checkpoint与冻结输入SHA全部核对，生成上述汇总JSON。
- `git diff --check`通过。纯CPU评测，无训练、GPU任务或游戏UI操作；未提交/推送。

## 解释边界

本次测的是该权重对密度分支的即时依赖，包含关闭分支造成的输入分布突变。单checkpoint、单eval seed、固定已多次使用的留出卡，不能推出无CNN重训上限，也不能评价Perceiver收益。CPU结果只与本次CPU对照比较，不用历史GPU得分计算消融差值。

此脚本保留密度图特征化，两臂都照常构图；用时差不是完整删除密度分支/缓存后的省算收益。本轮不做Windows实机验收，也不修改部署。
