# 较轻请求惩罚与 Shift 惩罚短轮 A/B

2026-10-06，用户确认并行两组惩罚实验，暂不改变运动层。

## 设计与初始化

两组均从 T7/K8 u3500 的同一权重开始，新建优化器、随机流、课程状态、update/env_steps/best。是新 reward 的短轮适应实验，不能与从零训练1000轮混同。初始 checkpoint SHA256 为 `3bdfd39ad53b152d78cc3094ad01fc129cbdaf66a420678cc78e0355313891e4`，来源 `runs/job-bfd1c1cd62146a55/20261002-152220-t7-laser-k8/checkpoints/latest.pt`（与 u3500.pt 同内容）。

| 参数 | A：request-light-k8 | B：request-light-shift-k8 |
|---|---:|---:|
| action_source | request | request |
| key_press | −0.001 | −0.001 |
| quick_change | −0.003 | −0.003 |
| shift_toggle | 0 | −0.003 |

解析后的完整配置只差 shift_toggle 一项。两组seed1、1000轮，每轮4096×64帧，新增262144000帧，起始学习率1e-4、沿用线性退火。250/500/750/1000轮评测与保存（间隔250）。env线程30，PPO torch线程2。

运动层保持T7的hold=[2,6]、delay=[0,2]、slow=true。player15维、v8/v3、K8、图6与卡池不变。两组同用等价排序优化的stg_rl0.4.2；本地/Magnus同wheel，ENGINE_VER24。

训练后原作探针保留free/motor_off；专项评测显式使用u500/u1000/best（共6份JSON），避免短轮runner尝试加载不存在的u2750..3500。best仍按原作评测选，专项不参与挑选。

重点比较持续静止时Shift请求/执行翻转率、运动时翻转率、低速占比、普通/激光撑过率，并检查关运动层表现。训练日志总体Shift率不能替代静止片段诊断；细轨迹诊断待结果返回后进行。

## 实现与检查

新增 `--init-from`，严格校验模型/特征配置（包括K）、仅加载agent权重并同步agent_inference，不恢复旧optimizer/RNG/计数/best。初始化来源写入新run的env.json。与 `--resume` 互斥。旧resume行为仍用原optimizer恢复逻辑。

`OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 uv run --frozen pytest -q tests/test_checkpoint.py tests/test_smoke.py`：20 passed。相同覆盖在旧CPU栈torch2.5.1+cpu/tensordict0.6.2：20 passed。新增四项真实检查覆盖权重与新状态、特征K不兼容、带新配置的训练/评测、CLI互斥；未新增配置常量测试。`bash -n magnus/train-specialist.sh`、`git diff --check`通过。只读审阅无Critical/Important问题，另用真实T7权重验证严格加载与推理参数共享存储。

## Magnus 提交

北京时间2026-10-06 15:08提交，两条均B2、1×A100、32核CPU、64G内存、20G临时盘。提交前6张GPU/108CPU空闲。

| 组 | Job | 配置 |
|---|---|---|
| A | `9436bd073b636c2b` | [较轻请求惩罚](../../configs/exp-request-light-k8.toml) |
| B | `b3ef72c1ca44515d` | [额外Shift惩罚](../../configs/exp-request-light-shift-k8.toml) |

固定远端main基底 `4a3bc4a35ca57d4fd114cca227206fed658a84a0`，使用既有File Custody覆盖源码和初始化权重，不执行git commit/push。归档SHA256 `5c602e48b4a287285fad4f89d80f17e0b1b73943846e24523359f401990e6144`；上传后下载SHA对拍通过。Job启动逐文件检查，包括新wheel与初始化权重，旧0.4.1 wheel从Job工作区移除后bootstrap安装0.4.2。

提交材料：`runs/request-shift-ab-submit/`。每条Job启动严格GPUCHECK（FP32 eager/compile/图重放），通过才训练。启动检查：两条均Running，归档、逐文件、初始化权重和wheel SHA检查通过；实际CPU亲和性各32核，cgroup v1配额-1（无额外quota限制），各训练环境线程30。运行栈Python3.11.10/torch2.5.1+cu124/tensordict0.6.2/stg_rl0.4.2已在日志确认。15:13检查两条GPUCHECK均PASS（policy/loss/gradient/rollout特征与reward/tracker/GAE均通过）。15:16检查两条均完成u9，每条约240万新增帧，日志本轮SPS分别66.7k/66.4k，确认真实PPO更新正在推进。首次训练录图约128/136秒，初始ETA使用启动累计时间而被高估；本轮SPS不是整轮吞吐或引擎优化的因果收益。GPUCHECK与启动更新通过不包含训练收益结论。

监视器：`runs/request-light-k8-monitor/`（启动Python PID2231092）、`runs/request-light-shift-k8-monitor/`（PID2231093）。每60秒查询，兼顾正常结束/提前退出/Paused恢复，终态尝试下载240分钟有效的结果；检查u1000、eval1000和6份专项JSON。监控依赖本机存活。

旧速度估算1000轮训练加评测约80–90分钟，并行影响及GPU编译开销需看本次实测；未承诺完成时刻。

## 完成结果

两条均完整1000轮、GPUcheck PASS，监视器已取回并校验结果包，各6份专项JSON齐全。训练含常规评测各76分40/41秒；从提交到发现Success约94分钟。额外Shift惩罚使自由实际翻转2.76→0.32/s，关运动层4.08→0.84/s；四卡CPU持续静止自由段3.03→0.12/s。水符四次平均85.16→76.95%，末轮90.62→75.00%，存在场景代价；没有启动后续训练或替换部署。详见[结果与逐帧诊断](2026-10-06-request-shift-short-ab-results.md)。
