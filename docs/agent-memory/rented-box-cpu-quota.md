---
name: rented-box-cpu-quota
description: 租的训练机只有 24 个物理核的 CPU 配额（cgroup），nproc 报的 255 是宿主机的；并行跑两条会被节流
metadata:
  node_type: memory
  type: project
  originSessionId: 382fe7d1-16bd-4ff6-a1e0-e327b85e1ca5
  modified: 2026-09-20T19:06:52.318Z
---

stg-rl-train 的训练跑在租来的实例上（RTX 4090 + 双路 EPYC 7742 宿主机）。用户 2026-09-21 指出：实例 profile 上租到的 CPU **只有 24 个物理核**。容器里 `nproc` 报 255、逐核采样也看得到 255 个核在动 —— 那是宿主机全部逻辑核，混着别的租户，不代表我们能用。

**Why:** 平台给的很可能是 cgroup CFS 时间配额而不是 cpuset。每条实验 32 个 env 线程，两条并行的 rollout 撞在一起就超配额、整个容器被掐停，表现为 `env_step` 双峰（1.0–1.5 s ↔ 2.5–4 s）、同一时刻一条快一条慢（N3 5.6 h vs M 7.1 h；N1 / N2 也中招，J / I2 碰巧相位错开）。此前误判过「随机数慢」「机器抽风」「NUMA」，都不对或未证实。

**How to apply:**
- 待办：下一轮实验开跑前先在训练机上 `cat /sys/fs/cgroup/cpu.max` 与 `cpu.stat` 确认配额与节流计数（命令与判据在 `docs/experiments.md`「待办：确认 CPU 配额节流」）。用户说他会在下一轮之前做。
- `scripts/run-night.sh` 已改成按「配额 ÷ 同时跑的条数 − 2」定线程、支持 `--share N`、前后打印节流计数；截至 2026-09-21 **未提交**，等确认结果。
- 估算耗时、分析吞吐、读 `perf.jsonl` 的 CPU 数据时，别把 nproc / 逐核占用当成我们自己的资源；线程数只影响速度不影响实验结果。
- 相关：[commit-directly-on-main](commit-directly-on-main.md)

## 2026-09-26 迁移核验

上述“截至 2026-09-21 未提交”是历史状态。目前 `scripts/run-night.sh` 的配额逻辑、`--share` 和节流计数已在仓库中，相关提交为 `30a157b`（`feat(scripts): 按 cgroup CPU 配额定线程；队列换成 L ‖ O；bench-step 加真模型模式`）。本次没有连接租机验证实时配额，下一次启动训练前仍应检查。
