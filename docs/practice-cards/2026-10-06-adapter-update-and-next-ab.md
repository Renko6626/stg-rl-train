# 适配层排序优化接入与下一轮 A/B 候选

日期：2026-10-06。用户授权应用等价排序优化，并随后确认暂不改变运动层、并行运行两个惩罚实验。以下参数已用于准备两组短轮任务，提交与状态见后续实验记录。

## 当前资源

`magnus cluster -f json` 显示 Rise-AGI 有 6 张空闲 A100、108 核空闲 CPU、495904 MB 空闲内存，无 Pending Job。按每条 1 GPU / 32 CPU，资源可容纳三条，两条有较多余量。提交时仍需重新查询，并显式使用 B2；资源空闲不保证两条的吞吐与单条相同。

## 已接入的优化

训练侧升级为 `stg-rl==0.4.2`，`pyproject.toml`、`uv.lock`、Magnus wheel 和 `SHA256SUMS` 同步。来源是 stg-engine 提交 `3db7736d95b3d5ba51f5f42de1687795b5fa646a`，保留训练已依赖的未提交 `current_start_indices()` 接口。

在导出的临时源码快照中将 Python 包版本升为 0.4.2，没有修改引擎工作区原有未提交内容。快照无 Git 元数据，`build_info().git_sha` 为 `unknown`；基准提交、原有补丁哈希和 wheel 哈希记在[来源及对拍记录](reports/stg-rl-042-adoption.json)。未发布上游 Release。

优化保留 `(距离², 池索引)` 选弹规则、池索引升序输出及字段编码；未超 cap 直接编码，超 cap 用位图枚举替代第二次排序。ENGINE_VER=24、tables_hash=`37a7ff12fe40e24e`，模型输入和图签名不变。

旧 0.4.1 与新 0.4.2 使用同一固定动作序列：dense3/dense12 × cap1/64/1024，4 环境、2 线程、每例 600 步，共 14400 env-steps，包含显式与自动 reset。全部观测、事件、done 缓冲以及起点索引逐字节一致。Rust 编码测试另覆盖选择集合与并列边界；这些检查不等于穷举所有轨迹。

验证：`uv lock`、`uv sync --frozen` 通过；`sha256sum -c SHA256SUMS` 和锁文件哈希交叉检查通过。`cargo test -p stg-core -p stg-rl -p stg-harness --quiet` 通过；引擎 Python `python -m pytest -q crates/stg-py/tests/test_smoke.py` 15 passed。训练仓 `uv run --frozen pytest -q tests/test_envwrap.py tests/test_envwrap_lasers.py tests/test_reward.py tests/test_smoke.py` 53 passed；同一命令用旧 CPU 栈 Python（torch2.5.1+cpu/tensordict0.6.2）再测53 passed。没有新增排序测试。尚未进行 GPU 端到端性能测量。

## 两个实验的建议

两组使用新 wheel、T7 的 K=8、相同起始模型和训练 seed，保持 player15 维、当前运动层及卡池。

| 参数 | A：较轻请求惩罚 | B：额外 Shift 惩罚 |
|---|---:|---:|
| action_source | request | request |
| key_press | −0.001 | −0.001 |
| quick_change | −0.003 | −0.003 |
| shift_toggle | 0 | −0.003 |

这里只惩罚 Shift 翻转，按下与松开均计一次，持续保持 Shift 不因本项扣分。`key_press` 仍会在按下时计新按键，两项在 B 的 Shift 按下处会叠加。先不收紧 Shift 运动层，便于把两组差异归因于 Shift reward。

原 B 的方向请求惩罚使策略更平滑，但激光撑过率下降，故两组共同降低 key_press/quick_change。该配对主要检验 Shift 罚分；共同改动的收益需要与 T7 起始模型、原 B 分开比较，不能视为完整因素消融。

建议从同一个 T7 u3500 权重分叉，重置优化器，以较小学习率（候选 1e-4）先训练 1000 轮，250/500/1000 轮评测；500 轮只作中途观察。新 reward 下 value 需要重新适应。现有 `--resume` 只沿用旧配置续训，实施时需增加明确的初始权重入口，不能直接用它替代新实验初始化。短轮结果验证已有模型的适应，不能证明从零训练的收敛结果。

比较持续静止段 Shift 翻转率、运动时翻转率、低速占比、普通/激光撑过率；保留关运动层评测，判断模型本身是否减少无效请求，防止学成一直按住或一直松开。

## 缩短等待

B 的 `perf.jsonl` 最终墙钟为 15752.957 秒（4.38 小时）。175 个同步计时样本的平均迭代为 4.326 秒，阶段比例：PPO update 51.34%、H2D 17.86%、env_step 14.41%。同步采样存在测量开销，比例只作瓶颈定位，不能精确预测加速。

排序优化只作用于环境步进的一部分；历史 dense12 的批量 +72% 不是训练整体提速。B 的同步采样没有记录子弹超 cap，因此不能直接套用 dense12 收益。

按旧速度线性估算，1000 轮约 75 分钟，加编译及评测留出约 80–90 分钟；两组并行应能在一次等待内获得对照，但需要实测并行资源影响。500 轮可在约 40 分钟观察趋势。先筛选，再决定是否延长，避免所有候选默认跑满 3500。

若继续优化每轮耗时，可单独测 PPO `update_epochs=4→2`：它能减少更新计算，但改变优化强度，需要独立对照；本轮 reward A/B 保持相同设置。
