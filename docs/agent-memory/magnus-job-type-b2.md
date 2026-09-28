---
name: magnus-job-type-b2
description: Magnus Job 一律用默认优先级 --job-type B2，不要用 A2
metadata:
  type: feedback
---

提交 Magnus Job 用 `--job-type B2`（站点默认优先级），不要再用 A2。

**Why:** 用户 2026-09-25 明确交代「我们要有礼貌一些」——共享集群上别抢高优先级；之前的测量 Job 都用了 A2。

**How to apply:** 所有 `magnus job submit` / `magnus submit` 都带 `--job-type B2`；排队可能变长，提交后隔几分钟看一次状态即可（见 [magnus-old-torch-stack](magnus-old-torch-stack.md)）。
