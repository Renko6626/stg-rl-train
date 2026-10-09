---
name: stg-rl-wheel-sync
description: 升 stg_rl 版本要同时改 pyproject/uv.lock 与 magnus/wheels（+SHA256SUMS），两边哈希须相同
metadata:
  type: project
---

stg_rl（stg-engine 的 `rl-v*` Release wheel）有两个消费点：本机 `pyproject.toml` + `uv.lock`，以及 Magnus 用的
`magnus/wheels/*.whl` + `SHA256SUMS`（`magnus/bootstrap.sh` 装它）。**只改一边就会本机与 Magnus 跑不同引擎**。

**Why:** 2026-09-25 发现 pyproject 已被另一会话（转录，`470d1eb`）切到 0.3.0，而 Magnus 仍是 0.2.0——Q1…R2 在 Magnus 上是 0.2.0、
本机诊断是 0.3.0。卡池没变所以结论无碍，但下一次未必。S 批起统一 0.4.0。
**How to apply:** 升版时：`gh release download` 进 magnus/wheels、删旧 whl、重写 SHA256SUMS、改 pyproject URL、`uv lock && uv sync --frozen`，
核对 uv.lock 里的 sha256 与 magnus/wheels 一致；引擎版本变了就同批重跑对照（如 r1c-e04）。见 [magnus-old-torch-stack](magnus-old-torch-stack.md)。

2026-10-06：本地 `tool.uv.sources` 已直接引用 `magnus/wheels`，两端消费同一文件；当前为0.4.2，来源与验证见[接入记录](../practice-cards/2026-10-06-adapter-update-and-next-ab.md)。没有上游 Release 时可从经核对的源码快照构建，记录基准提交及补丁来源，勿将旧的 `gh release download` 当成必要发布操作。下一轮两臂同用新版；旧版结果保留原版本标识。
