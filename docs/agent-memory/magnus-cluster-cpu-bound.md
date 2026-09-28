---
name: magnus-cluster-cpu-bound
description: Magnus 节点 Rise-AGI 是 6×A100 但只有 112 核，CPU 才是瓶颈；提交前先 magnus cluster 看 cpu_free
metadata:
  type: project
---

Magnus 的 A100 节点 Rise-AGI：**6 张 A100、112 核、500 GB 内存**。一个 Job 申请 64 核就吃掉过半 CPU，
后面的 Job 即使 GPU 大量空闲也会一直 Pending（2026-09-25 实测：M0 占 64 核后只剩 44 核，要 64 / 48 核的 Job 都排不上）。

**Why:** Job 的 Pending 原因不显示；GPU 看着空闲会误以为能开跑。
**How to apply:**
- 提交前 `magnus cluster` 看 `cpu_free` / `free`（GPU），核数按空闲量切，别默认 64。
- 夜里卡空闲时，用户选「一张卡跑一条」（每条约 22 核）而不是一张卡塞两条（[magnus-job-type-b2](magnus-job-type-b2.md) 照旧用 B2）。
- `magnus job kill` 要交互确认，非交互必须加 `-f`，否则静默失败、旧 Job 还在。
