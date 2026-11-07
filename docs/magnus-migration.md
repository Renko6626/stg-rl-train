# Magnus 训练迁移记录（2026-09-23 起）

Magnus（北大站点）上用 A100 跑训练，替代在 Vast.ai 租卡。本文保留迁移时的环境证据，维护 Job 入口、版本兼容和 wheel 来源；简要流程见[启动概况](agent-memory/training-workflow.md)，当前研究安排见[下一步](next-steps.md)，吞吐数据见[性能记录](perf-baseline.md)。

## 迁移初期的环境证据（2026-09）

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

**退出时尝试交回结果**：`train.sh` / `train-multi.sh` / `parallel_probe.sh` 都装了 `trap EXIT`，正常结束、训练失败、
Magnus 发 SIGTERM（终止 / 超时）三种情形都会尝试把已有的 run 目录（含 checkpoint）打包交给 File Custody；
收到 SIGTERM 时先停训练、尝试写好 Result 再以 0 退出，Job 可能记为 Success，仍须检查实际训练与结果包。任一条训练失败时以非零码退出。
共用函数在 `magnus/lib.sh`。

**⚠ 手动 kill 救不回来**（2026-09-25，M0 Job `f58d88682d4b428d` 被用户终止）：Magnus 终止时**先清掉工作区**，训练进程还活着，
接着写 tensorboard 报 `FileNotFoundError` 退出；退出 trap 去打包时 run 目录已不存在，什么都没上传。兜底只对「训练自己失败」
与「超时 SIGTERM 且工作区还在」有效。要在终止前留住结果，得先让训练自己停（例如 `run.max_minutes`），或以后加「中途定期上传」。
评测数字仍在 Job 日志里（`magnus job logs`），可以解析出来。另：Job 实际跑在 zhustation 本机（tfevents 文件名里的主机名）。（2026-09-25 本机 CPU 用 smoke 配置验过三种情形，上传换成桩。）

## 提交与取回

用已推送的固定 commit SHA，分支为 `main`。**优先级一律 `B2`（站点默认；用户 09-25 定，共享集群不抢 A2）**。下例的 32 核、64 GB 来自 2026-09 的测量，核数和内存须按当前空闲量与任务需要调整：

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

## 旧 CPU 栈检查

涉及 PPO、CUDA 图或 torch／tensordict API 的修改，提交 Magnus 前先在对应旧 CPU 栈运行受影响的已有测试。首次准备示例（`<检查目录>` 自行替换；不要复用旧会话的临时绝对路径）：

```bash
uv venv -p 3.11 <检查目录>/v062
uv pip install --python <检查目录>/v062/bin/python \
  --extra-index-url https://download.pytorch.org/whl/cpu \
  'torch==2.5.1+cpu' 'tensordict==0.6.2' 'numpy<2.3' \
  pytest matplotlib psutil nvidia-ml-py tensorboard magnus/wheels/*.whl
PYTHONPATH=src <检查目录>/v062/bin/python -m pytest -q tests/test_ppo.py
```

最后一行按实际改动选择相关测试。CPU 通过不能替代 CUDA 图在实际 GPU 的验证。

## 项目自有 wheel

本地 `pyproject.toml` 的 `tool.uv.sources` 与 Magnus bootstrap 共用 `magnus/wheels/`。升级时同步 `pyproject.toml`、`uv.lock`、wheel 与 `SHA256SUMS`，核对两端字节一致；构建快照可以基于已核对的源码和补丁，不要求先发布上游 Release。

### 当前版本与来源（2026-11-08）

- `stg_rl` 为 **0.4.7／ENGINE_VER35**，文件 `stg_rl-0.4.7-cp310-abi3-manylinux_2_34_x86_64.whl`。来源是引擎 main `df6676f82d46545f898d41c95f46e0049e9113de` 加已审阅工作区修改；用导出源码快照构建，仅在快照调整 Python 包装版本，`maturin --release --compatibility manylinux_2_34`。`build_info().git_sha` 为 `unknown`，不能据此伪称 wheel 来自干净提交。
- 该版包含 VM 每任务 4096／全局 65536 指令预算、xform 标签／wait／goto／loop、单值 STEP 修复和限时屏外保活 `offscreen_keep`；xform 段池为 **2048**。2026-11-07 临时的 0.4.8／ENGINE_VER36／4096 段已撤销，不能作为现行能力或验收依据。
- 当时的接入检查包括 Python 3.12／3.11 返场 probe、三卡固定动作对 0.4.6 的 18 项缓冲逐字节回放一致、TH18 二面首符四档 validate 通过。过程证据在忽略目录 `transcribe/work/wheel-upgrade/0.4.7/`；构建快照和命令当时留在 `/tmp/stg-rl-047-build/`，临时目录可能被清理。以上不代表已在 Magnus 或原作动态验收。
- 默认仍为 LEGACY／擦弹开启。0.4.5→0.4.6 的 ENGINE_VER32 修改了擦弹统计，旧版 graze 不能直接作同口径对照；该轮三卡回放其余缓冲一致。校验值只维护在 lock 和 `SHA256SUMS`，不在记忆另抄一份。
- `stgagent` wheel 为 0.1.0，来自 `stg-agent-proto` 的 `v0.1.0`（`6b61fa052640377d640e5a7ecee9641b6ac3df96`）。

早期接入的来源与检查分别见 [0.4.3](practice-cards/reports/stg-rl-043-adoption.json)、[0.4.4](practice-cards/reports/stg-rl-044-adoption.json)、[0.4.5](practice-cards/reports/stg-rl-045-adoption.json)；更早实验保留当时版本，不因升级改写其结果。

## 续训与结果保留

续训目录必须先放到 Job 可见的位置；本页尚未登记可直接复用的本站持久挂载路径，实际使用前核验。File Custody 是结果取回渠道，不能作为唯一长期存储；手动终止的工作区丢失风险见上文。迁移初期的锁定环境、专用镜像等建议不再列为当前自动执行待办，研究顺序以[下一步](next-steps.md)为准。

Magnus 参考：`/data/sunyunbo/magnus-docs/official/docs/internals/job-runtime.zh-CN.md` 与 `.../uv-image.zh-CN.md`。
