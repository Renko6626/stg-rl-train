---
name: transcribe-claude-worker-fallback
description: 转写流水线的 worker 可换成 Claude Sonnet（STG_DSH_BIN=transcribe/tools/claude-worker）；并发 4，dsh 审核必须配 opus 抽检
metadata:
  node_type: memory
  type: project
  originSessionId: 6019f84a-05fb-4b39-b7f5-4f3c5c5d28c6
  modified: 2026-09-26T00:43:26.696Z
---

转写流水线（`stgtranscribe.pipeline`）的 worker 默认是 dsh-flash（DeepSeek）。DeepSeek 余额耗尽时，用
`STG_DSH_BIN=$PWD/transcribe/tools/claude-worker STG_CLAUDE_MODEL=sonnet` 换成 Claude Code 无头模式，流水线其余不变。

**Why:** 2026-09-25/26 激光批 DeepSeek 余额两次耗尽，用户明确说「不要充值，开 sonnet 干」。Sonnet 8 路并发时本机代理会
掐断连接（ECONNRESET，24 个 worker 同时失败）；降到 4 路 + claude-worker 内置退避重试后零失败。
dsh 审核照抄卡内注释当期望、漏判严重（一轮抽检漏 2 critical / 16 major），opus 抽检不能省。

**How to apply:** 批量用 `--jobs 4`；批量脚本用 `setsid nohup … & disown` 脱离会话（会话退出会杀后台任务）；
worker 日志在 `transcribe/work/logs/<id>.<阶段>.*.stdout`，监控要看这些而不是批量总日志。收卡前 opus 抽检 + 逐条复核。
相关：[verify-background-launch](verify-background-launch.md)。
