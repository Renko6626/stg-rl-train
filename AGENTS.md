# stg-rl-train 项目指引

## 进入项目先读

- 每次开始任务，先读 [项目记忆索引](docs/agent-memory/MEMORY.md)，再按任务打开相关条目；这些是跨会话保存的用户约定和项目经验。
- 项目是 stg-engine 躲弹模型的 PPO 训练仓，同时包含 TH06 弹幕转写流水线。
- 开发入口见 [README.md](README.md)；训练设计见 [设计文档](docs/2026-09-15-stg-rl-train-design.md)；实验经过与结论见 [实验记录](docs/experiments.md)。
- Magnus 工作先读 [迁移说明](docs/magnus-migration.md)；转写工作先读 [转写说明](transcribe/README.md)、[转写设计](docs/2026-09-16-th06-transcribe-design.md) 和 `transcribe/contracts/` 中对应阶段的约定。

## 用户约定

- 在 `main` 上工作，不自行创建功能分支或 worktree。用户明确要求提交才 commit，明确要求推送才 `git push origin main`；两项授权分开。不要把历史记忆中的操作命令当作当前执行请求。
- 研究方案优先改环境或引擎的真实机制。避免向观测塞入人为构造的几何答案，也不要用固定罚款式 reward 塑形代替真实后果；确需这样做时先说明理由并征求用户同意。
- 需要引擎接口时直接在 stg-engine 解决；修改前读取该仓库适用的 `AGENTS.md`，以及尚未迁移的 `CLAUDE.md`。保留原有引擎要求：P4 坏参数 no-op + 计数、写 API 钳制、`ENGINE_VER` bump 评审、golden 校验和对拍。
- 难度 rank 从 0 开始：`0 = Easy`、`1 = Normal`、`2 = Hard`、`3 = Lunatic`；`r2` 是 Hard，`r3` 是 Lunatic。

## 开发与验证

```bash
uv sync --frozen
uv run --frozen pytest -q
bash run.sh configs/smoke.toml smoke
```

- 根据改动运行相关测试。纯文档改动检查内容与链接即可；不要为了文档迁移启动训练。
- 本地依赖以 `pyproject.toml` / `uv.lock` 为准。迁移时（2026-09-26）本地为 Python 3.12、torch 2.14.0、tensordict 0.14.2；Magnus 的 `magnus/bootstrap.sh` 使用 Python 3.11、torch 2.5.1+cu124、tensordict 0.6.2。
- 修改 PPO、CUDA 图或 torch / tensordict API 后，提交 Magnus Job 前必须先在旧版本 CPU venv 跑相关测试；CUDA 图仍需实际 GPU 验证。具体命令见 [旧版本栈记忆](docs/agent-memory/magnus-old-torch-stack.md)。
- 升级 `stg_rl` 必须同步 `pyproject.toml`、`uv.lock`、`magnus/wheels/*.whl` 和 `magnus/wheels/SHA256SUMS`，核对哈希一致；引擎变化后同批重跑对照。

## 训练资源与长任务

- Magnus Job 一律显式 `--job-type B2`，不用 A2。提交前 `magnus cluster` 查看 `cpu_free` 和 GPU 空闲量，不默认申请 64 核；提交后几分钟检查状态。
- 租机的 `nproc` 和逐核占用可能是宿主机数据，不能当作实例配额。开跑前检查 cgroup 的 `cpu.max` / `cpu.stat`，并行训练按实际配额分线程。24 核租机、112 核 Magnus 节点是历史记录，换实例后重新确认。
- 环境变量放在 `taskset` / 命令前。后台启动后检查目标 Python 进程、CPU 占用和日志，不能只看到外层 shell 就报告“在跑”。监控同时处理结果完成和进程提前退出。
- 非交互执行已获授权的 `magnus job kill` 时需要 `-f`；该参数本身不构成终止任务的授权。

## 转写与产物

- 转写 worker 的现有后端是 dsh-flash；历史备用方案是 `transcribe/tools/claude-worker`，Sonnet 用 `--jobs 4`，dsh 审核后必须有 Opus 抽检与逐条复核，详见 [worker 记忆](docs/agent-memory/transcribe-claude-worker-fallback.md)。迁移项目指引不等于更换流水线后端或取消抽检要求。
- `transcribe/work/` 含原作 ECL 摘录，永不入库；`runs/`、`dist/`、虚拟环境和构建产物遵守现有 `.gitignore`。
- ONNX 导出后检查自动 torch / onnxruntime 对拍；改图签名时训练侧与部署侧一起更新 `GRAPH_VERSION`。细节见 README。

## 维护项目记忆

- 本仓库用 `docs/agent-memory/` 保存可版本管理的记忆，由本文件要求读取；不要依赖 Claude 私有目录或假定这些 Markdown 会由 Codex 自动递归加载。
- 新的长期用户反馈、确定的技术约束和踩坑结论写入对应条目，并更新索引；临时进度与实验结果写入相应项目文档。
- 区分用户偏好、历史观察与当前事实。版本、资源、余额、运行状态和“未提交”等信息需核验，更新时注明日期和依据。
