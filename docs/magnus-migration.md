# Magnus 训练迁移记录（2026-09-23 起）

Magnus（北大站点）上用 A100 跑训练，替代在 Vast.ai 租卡。本文记录环境事实、Job 入口与正式训练前的待办；吞吐数据在 `docs/perf-baseline.md`。

## 已验证的环境

- Magnus `Renko6626/stg-rl-train` 仓库和 `a100` GPU 类型可以提交 Job。
- A100 80GB 节点驱动为 550.163.01。缓存镜像 `docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime` 内的 Python 3.11.10、PyTorch 2.5.1+cu124 能看到 GPU（Job `81ec9987f70e198d`，Success）。
- 主仓 `uv.lock` 固定 PyTorch 2.14.0，安装的是 CUDA 13 包；在该节点上 `gpucheck` 报驱动过旧，CUDA 不可用（Job `c44ff59c0e0023fe`）。因此不能直接运行 `bash run.sh`。
- `docker://python:3.12` Job 的 `UV_CACHE_DIR` 未设置，默认 `/magnus/.cache/uv`。两次 `uv sync --frozen` 分别下载 68 个包，耗时 8 分 09 秒、8 分 13 秒，跨 Job 没有命中缓存。
- 缓存的 PyTorch 镜像没有 `git`，Job 内直连 GitHub 下载 `stg-rl` wheel 发生超时。Magnus 注入的 SDK 也缺少 `typer` 等 Python 依赖，使用 `magnus receive` / `custody` 前要安装 `magnus-sdk`。
- 该镜像自带的 `ninja 1.11.1.1` 会让全环境 `pip check` 返回非零，与本仓依赖无关；短 Job 改为只验证实际使用的包版本与训练路径。
- `2.5.1-cuda12.4-cudnn9-runtime` 缺少 C 编译器，`torch.compile` 失败。换成站点已缓存的同版本 `devel` 镜像后，Job `1c1be6b6ac0da812` 的 `gpucheck` 所有数值对拍通过，并完成两次 PPO 更新、640 局评测、checkpoint、出图与打包，Job 状态为 Success。结果包已取回到本地 `runs/20260923-190104-magnus-cu124-smoke.tar.gz`（约 8 MB）。
- 可复用训练入口 `magnus/train.sh` 也经 Job `bd399f020e27bb86` 完整验证：两次更新、评测、checkpoint、打包、Result secret 和本机下载均通过。结果包在 `runs/20260923-203522-magnus-wrapper-smoke.tar.gz`（约 8 MB）。
- File Custody 的 SDK 结果协议另用 CPU Job `46285c4e0fd0a54e` 验证：上传小文件、写 `$MAGNUS_RESULT`、从 `magnus job status` 读 secret、本机 `magnus receive` 下载，全部通过。
- **CPU 可见性**：容器内 `os.cpu_count()` 返回宿主机的 112，进程亲和性只有申请到的 CPU（32 核 Job 为 `Cpus_allowed_list=2-17,58-73`，即单插槽 16 物理核加超线程），CFS quota 为 `-1`（Job `032ea8f38643e7dd`）。`env.threads = 0` 已改为取亲和性（`envwrap.usable_cpus`），不再开 112 个线程。

## 与本地 / Vast 环境的差异（踩过的坑）

- **版本栈不同**：Magnus 是 Python 3.11 + torch 2.5.1+cu124 + tensordict 0.6.2（`magnus/bootstrap.sh` 现装），本地与 Vast 是 Python 3.12 + torch 2.14 + tensordict 0.14。两边实验结果不能逐位对比。API 也有差：0.6.2 的 `CudaGraphModule` 没有 `device` 参数，首个 rollout 图 Job `356819cb7a21700f` 因此在 gpucheck 就失败了。**改到 torch / tensordict API 的代码，提交 Job 前先在同版本 CPU venv 里跑相关测试**（torch 2.5.1+cpu、tensordict 0.6.2、`PYTHONPATH=src`）。
- **跨 Job 波动约 6%**：同一份代码在不同 Job 之间，稳态帧率实测相差约 6%（69.1k 对 73.4k）。比较改动时优先在同一 Job 内做 A/B（`graph_probe.sh`、`phase_probe.sh 28 32`），跨 Job 比较时主要看分阶段耗时。

## Job 入口

所有入口先 `source magnus/bootstrap.sh`（校验镜像版本、安装 `magnus/wheels` 与小依赖、设置 `PYTHONPATH=src`），结束时把结果交给 File Custody，secret 写进 Job Result。

| 入口 | 用途 | 结果 |
|---|---|---|
| `bash magnus/smoke.sh` | 环境冒烟：`gpucheck` + 两次 PPO 更新 | 训练结果包 |
| `bash magnus/train.sh <配置> <运行名> [训练器参数]` | 正式单次训练；参数原样传给 `stgtrain.train`（`--total-updates N`、`--resume RUN_DIR`；`--runs-dir` 由脚本固定为 `runs/job-<JobID>`） | `job-<JobID>.tar.gz` |
| `bash magnus/train-multi.sh 配置:名字[:种子] … [-- 训练器参数]` | 同一张卡并跑 K 条训练；每条 env 线程 = (亲和性核数 − 2K) / K（`THREADS=` 可覆盖），配置副本写进结果目录 | `multi-<JobID>.tar.gz`（所有 run 一个包） |
| `bash magnus/bench.sh [配置] [名字]` | `threads × num_envs` 吞吐扫描（`stgtrain.train --bench`） | `bench.json` |
| `[GPUCHECK=1] bash magnus/phase_probe.sh [线程数 …]` | 分阶段计时：每个线程数各跑 20 次更新，每 5 次采一次同步计时，汇总稳态帧率、各阶段中位秒数与每步计数；`GPUCHECK=1` 时先跑 gpucheck | `summary.json` + 各 run |
| `bash magnus/graph_probe.sh` | rollout CUDA 图开 / 关 A/B（先跑 gpucheck） | `summary.json` + 各 run |
| `[KS="1 2 3 4"] [CONFIG=…] [UPDATES=20] bash magnus/parallel_probe.sh` | 同卡并跑 K 条的吞吐扫描（线程按 `train-multi.sh` 的同一公式分），记每条 / 合计稳态帧率与显存峰值；默认配置 `exp-m0-rebase.toml` | `summary.json` + 各 run |

**结果一定交回**：`train.sh` / `train-multi.sh` / `parallel_probe.sh` 都装了 `trap EXIT`，正常结束、训练失败、
Magnus 发 SIGTERM（终止 / 超时）三种情形都会把已有的 run 目录（含 checkpoint）打包交给 File Custody；
收到 SIGTERM 时先停训练、写好 Result 再以 0 退出，Job 记为 Success。任一条训练失败时以非零码退出。
共用函数在 `magnus/lib.sh`。

**⚠ 手动 kill 救不回来**（2026-09-25，M0 Job `f58d88682d4b428d` 被用户终止）：Magnus 终止时**先清掉工作区**，训练进程还活着，
接着写 tensorboard 报 `FileNotFoundError` 退出；退出 trap 去打包时 run 目录已不存在，什么都没上传。兜底只对「训练自己失败」
与「超时 SIGTERM 且工作区还在」有效。要在终止前留住结果，得先让训练自己停（例如 `run.max_minutes`），或以后加「中途定期上传」。
评测数字仍在 Job 日志里（`magnus job logs`），可以解析出来。另：Job 实际跑在 zhustation 本机（tfevents 文件名里的主机名）。（2026-09-25 本机 CPU 用 smoke 配置验过三种情形，上传换成桩。）

## 提交与取回

用已推送的固定 commit SHA，分支为 `main`。**优先级一律 `B2`（站点默认；用户 09-25 定，共享集群不抢 A2）**。近期测量都申请 32 核、64 GB：

```bash
magnus job submit \
  --task-name stg-rl-train-<名字> \
  --namespace Renko6626 --repo-name stg-rl-train \
  --branch main --commit-sha <已推送的完整 SHA> \
  --gpu-type a100 --gpu-count 1 --cpu-count 32 --memory-demand 64G \
  --ephemeral-storage 20G --job-type B2 \
  --container-image docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel \
  --entry-command 'bash magnus/train.sh configs/base.toml <运行名>'
```

Job 完成后先用 `magnus job status <ID>` 取得 Result 中的 File Custody secret，再用 `magnus receive <SECRET> --output <本地结果包.tar.gz>` 取回。secret 有效期 240 分钟。

`--resume` 指向的 run 目录必须在 Job 启动前已放进 Job 可见的持久挂载路径；目前尚未确认本站给该账号提供的挂载点。

## 项目自有 wheel

`magnus/wheels/` 放两个项目自有依赖，避免 Job 容器直连 GitHub 的不稳定性：
- `stg_rl` 取自 `stg-engine` 的 `rl-v0.4.0` Release（2026-09-25）：在 0.3.0（激光池，`ENGINE_VER` 24、Tier 0 lasers 表）之上加
  **自机判定写口** `VecEnv.set_hit_radius_extra`（训练侧 `env.hit_extra`，实验 S）；ENGINE_VER 不变。
  ⚠ 09-25 之前 `pyproject.toml` 已切到 0.3.0（转录那边的 `470d1eb`）而这里仍是 0.2.0 —— Q1 … R2 在 Magnus 上都是 0.2.0，
  本机诊断 / 探针是 0.3.0；卡池没变，结论不受影响。从 S 批起两边统一 0.4.0。
  （更早：0.2.0 敌人行 vx/vy、ENGINE_VER 23；0.1.1 VecEnv 分块修复。）
- `stgagent` 从 `stg-agent-proto` 的 `v0.1.0`（commit `6b61fa052640377d640e5a7ecee9641b6ac3df96`）构建。

`SHA256SUMS` 固定了字节内容，更新依赖时必须一起更新 wheel 与校验和。`stg_rl` 升级时还要同步 `pyproject.toml` 与 `uv.lock`（Vast 用），两边哈希应当相同。

## 正式训练前还需完成

1. **独立锁定 Magnus 路径**：现在由 `bootstrap.sh` 按固定版本号现装，没有锁文件。要做到不改变 Vast 的 `uv.lock`，并在运行时记录实际的 Python、PyTorch、CUDA、TensorDict 与 wheel SHA。
2. **持久存储**：确认站点可用的持久挂载，把 `--runs-dir` 指向它。Magnus 会清理 Job 工作区，File Custody 只保留 240 分钟，不能作为正式续训的唯一存储。尚未收到本站的持久挂载路径。
3. ~~**失败也要交回结果**~~：2026-09-25 已做，见「Job 入口」下的说明。
4. **定下 `num_envs` 与训练目标**：线程数已不必手选。`threads = 0` 取亲和性，32 核 Job 上 28 与 32 线程在噪声以内。还要明确训练目标是固定环境帧数还是固定更新次数；改 `num_envs` 会改变每次更新的样本数。
5. 若每个 Job 安装小依赖仍过慢，再按 Magnus 的镜像指南用同一锁文件 `uv sync --frozen` 预热缓存，发布专用镜像；目前先复用已缓存镜像。

Magnus 参考：`/data/sunyunbo/magnus-docs/official/docs/internals/job-runtime.zh-CN.md` 与 `.../uv-image.zh-CN.md`。
