# 激光专项卡作者可行性检查

该检查器直接编译指定卡片并运行 `stg_rl` 引擎。它用当前观测到的激光行和玩家状态，在短预测窗口内给18个方向/低速动作打分，再把选中的动作交给真实 `EnvWrapper`；碰撞、运动限制、判定半径和 episode 结束都由引擎处理。它是离线启发式检查器，不是训练策略，也不会改观测或 reward。

从项目根目录运行单卡：

```bash
.venv/bin/python -m stgtrain.specialist_feasibility /tmp/sunyunbo/stg-laser-batch3/<card_id> --json /tmp/sunyunbo/stg-laser-batch3/reports/feasibility
```

检查一个卡片根目录下的全部卡片，并显式复跑全部难度档：

```bash
.venv/bin/python -m stgtrain.specialist_feasibility /tmp/sunyunbo/stg-laser-batch3 --all --ranks 0 1 2 3 --seeds 1 7 --json /tmp/sunyunbo/stg-laser-batch3/reports/feasibility
```

专项卡 `ranks = [lo, hi]` 按闭区间解释；不传 `--ranks` 时检查该卡声明区间内的全部档。显式请求未声明或超出 0..3 的 rank 会报错。默认种子为 `1,7`。每张卡的 JSON 报告记录声明区间、实际 rank/seed 矩阵、卡片文件 SHA256、检查器 SHA256、`stg_rl` 版本、可复制的单卡命令、起始玩家 hit radius/speed/focus、引擎 `done`、帧数及轨迹 SHA256。逐帧 JSONL 也包含实际按钮、方向、hit radius、速度和 focus 状态，放在 `/tmp/sunyunbo/stg-laser-batch3/trajectories/`；可以用 `STG_SPECIALIST_TRAJECTORY_DIR` 改写这个临时目录。`done=2` 是段落成功，`done=1` 是死亡，`done=3` 是超时；运行在首个非零 `done` 后停止，因此引擎自动 reset 后返回的新局观察不会算进本局。

可加 `--baselines` 运行固定位置基线：出生点原地不动、中下/左下/右下/左上/右上，以及四个场角。目标通过真实动作到达；报告区分是否到达、到达后继续执行的非零实际方向帧数、最长连续实际静止帧数、静止期最大漂移和最终位置相对目标的偏移。`stationary_qualified` 只有在实际方向连续为零至少120帧、静止期漂移不超过4px，且最终位置及到达后最大漂移都在目标4px容差内时才为真；其他情况标为 `NOT_REACHED`、`TARGET_NOT_PROVEN` 或 `NOT_PROVEN`。仅请求 action 0 或到达目标不算站桩通过。所有基线也在首个 `done` 后停止。

启发式只把当前可见激光的原点速度、角速度、长度速度和预警倒计时向前外推18帧，并使用引擎当前报告的玩家速度推算两档移动速度。随机运动层会真实执行并写入轨迹，但预测不模拟未来随机抽样；新激光、轨迹弯折、后续速度变化也不在当前窗口内。因此成功只说明这条有限轨迹在该随机实例中完成，失败状态必须记为 `NOT_PROVEN`，不能据此判断卡片无解。单次或少数种子成功也不证明全部随机实例可解。
