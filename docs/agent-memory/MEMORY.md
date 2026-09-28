# 项目记忆索引

2026-09-26 从 `~/.claude/projects/-data-sunyunbo-www-stg-rl-train/memory/` 迁入：10 条记忆及本索引。

每次开始任务先读本索引，再读相关条目。用户反馈继续适用；机器资源、软件版本、余额和运行状态是记录时的观察，执行前以当前环境核验。条目保留 Claude 来源元数据用于追溯，它不是 Codex 专有配置。

- [直接在 main 上提交](commit-directly-on-main.md) — stg-rl-train 不开功能分支，提交/推送都走 main
- [Astra 委派代码执行工作](astra-delegates-code-work.md) — 改代码与大量代码库阅读优先交给子代理；类似任务优先 Sol / medium，主代理负责判断与审查
- [Luna 练习卡生产与试产经验](luna-practice-card-workflow.md) — 用户优先低成本扩卡；独立写审、READY/FROZEN+SHA、来源隔离、严格机器门及批量化边界
- [租的训练机只有 24 核 CPU 配额](rented-box-cpu-quota.md) — nproc 的 255 是宿主机的；并行两条会被 cgroup 节流，下一轮开跑前要先确认
- [Magnus 是旧 torch 栈](magnus-old-torch-stack.md) — torch 2.5.1 / tensordict 0.6.2；提交 Job 前先在同版本 venv 跑测试
- [Magnus 用 B2 优先级](magnus-job-type-b2.md) — 提交 Job 一律 --job-type B2，不用 A2（用户要求礼貌）
- [Magnus 节点 CPU 是瓶颈](magnus-cluster-cpu-bound.md) — 6×A100 只配 112 核；提交前 magnus cluster 看 cpu_free；kill 要 -f
- [rank 从 0 开始](rank-is-zero-based.md) — r2 = Hard、r3 = Lunatic（0 Easy · 1 Normal · 2 Hard · 3 Lunatic）
- [少构造、改真实机制](prefer-real-mechanics-over-shaping.md) — 不喂构造特征、不用罚款塑形；改环境 / 直接改引擎
- [后台任务要确认真在跑](verify-background-launch.md) — env 变量写在 taskset 前；ps 看 python 进程；监视要盯提前退出
- [stg_rl 升版两边同步](stg-rl-wheel-sync.md) — pyproject/uv.lock 与 magnus/wheels+SHA256SUMS 必须同一版
- [转写 worker 可换 Sonnet](transcribe-claude-worker-fallback.md) — DeepSeek 没余额就 STG_DSH_BIN=claude-worker；并发 4；dsh 审核必须配 opus 抽检

## 迁移说明

- 迁移时仓库内没有 `CLAUDE.md` / `claude.md` 或既有 `AGENTS.md`。根目录的 [AGENTS.md](../../AGENTS.md) 根据这些记忆、README 和现有配置整理为 Codex 项目入口。
- 用户级 `~/.claude/CLAUDE.md` 和父目录 `~/www/CLAUDE.md` 是机器与跨项目说明，本次没有修改或整体复制到本项目；原 Claude 记忆和 `.claude/` 均保留。
- 将原有 `[[条目名]]` 交叉引用改为相对 Markdown 链接。跨仓库引擎规范改为优先读取适用的 `AGENTS.md`，同时保留尚未迁移的 `CLAUDE.md` 入口。
- `rented-box-cpu-quota.md` 中 2026-09-21 的“未提交”已补充仓库核验结果；没有把旧待办当作刚刚执行过的操作。
- `claude-worker`、Sonnet 和 Opus 是现有流水线的真实工具与历史约定，保留原名；本次没有把它们机械替换成 Codex，也没有迁移 `.claude/skills/` 或改动流水线程序。
- Codex 的标准项目入口与加载时机依据 [OpenAI 官方 AGENTS.md 文档](https://developers.openai.com/codex/guides/agents-md/)；`docs/agent-memory/` 是本仓库通过根指引要求读取的普通文档目录。
