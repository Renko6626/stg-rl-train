---
name: rank-is-zero-based
description: 训练 / 评测的 rank 从 0 开始：0 Easy · 1 Normal · 2 Hard · 3 Lunatic；r2 = Hard、r3 = Lunatic
metadata:
  type: project
---

`env.ranks` / 评测里的 r2、r3 是 **rank 下标，从 0 开始**：0 Easy · 1 Normal · 2 Hard · 3 Lunatic。
所以 r2 = **Hard**、r3 = **Lunatic**，不是 Normal / Hard。

**Why:** 2026-09-25 我在 th06nc 发布包的玩家 README / ini / 开发 README 里把 r2 / r3 写成 Normal / Hard（09-21 的 l-best 说明也错了），
用户指出后返工重打包（renkolab `b45ea8a`）。
**How to apply:** 任何面向玩家或文档的难度表述，r2 → Hard、r3 → Lunatic；拿不准就写 rank 下标而不是难度名。
