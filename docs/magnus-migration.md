# Magnus 训练迁移记录（2026-09-23）

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
- A100 性能扫描 Job `69aca4cf66a70501` 已扫 28 个 `threads × num_envs` 组合，原始结果保存在 `runs/bench-a100-cpu16-20260923.json`，结论与局限见 `docs/perf-baseline.md`。
- 同卡双实验 Job `032ea8f38643e7dd` 成功完成受控单跑/并跑对比与分阶段计时；两条并跑的稳态总吞吐比单跑高约 39%，CPU 亲和性与阶段结果见 `docs/perf-baseline.md`。
- 组件细分 Job `7a39b00b6d0846b2` 在 20 次更新里采了 4 次 CUDA 同步计时，区分弹 `top-k`、密度图、敌人处理、奖励项与逐局统计；实测和优化顺序见 `docs/perf-baseline.md`。

rollout 图（`ppo.rollout_cudagraphs`，把每步的特征化、reward + 逐局统计各录成一张 CUDA 图）的验收与 A/B：入口改为 `bash magnus/graph_probe.sh`，申请 32 核。它先跑 `gpucheck`（含逐步对拍录图与 eager 的特征、奖励和 tracker 状态），再在同一 Job 里依次跑录图关 / 开各 20 次更新，`summary.json` 给出两边稳态帧率中位数与加速比。Job `d302175a23bd0b8f` 已验证：gpucheck PASS，稳态吞吐 +7.5%，详见 `docs/perf-baseline.md`。注意镜像里是 tensordict 0.6.2，`CudaGraphModule` 没有 `device` 参数（首个 Job `356819cb7a21700f` 因此失败）。

复测吞吐时，沿用下文的镜像与资源参数，将 Job 入口改为 `bash magnus/bench.sh configs/base.toml a100-cpu16`；Job Result 会返回 `bench.json` 的 File Custody secret。

## 当前验证路径

先复用站点缓存的 `docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel` 镜像，运行 `bash magnus/smoke.sh`。它在 Job 中安装 TensorDict 0.6.2 和少量运行依赖，再执行 `gpucheck`、两次 PPO 更新和结果回传。它使用 `PYTHONPATH=src`，暂时绕开主仓 Python 3.12 / PyTorch 2.14 的安装约束；通过只能证明 CUDA 12.4 方案可行，**不能**视为正式训练环境已经锁定。

提交时用已推送的固定 commit SHA：

```bash
magnus job submit \
  --task-name stg-rl-train-cu124-smoke \
  --namespace Renko6626 --repo-name stg-rl-train \
  --branch feat/magnus-training --commit-sha <已推送的完整 SHA> \
  --gpu-type a100 --gpu-count 1 --cpu-count 16 --memory-demand 32G \
  --ephemeral-storage 10G --job-type A2 \
  --container-image docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel \
  --entry-command 'bash magnus/smoke.sh'
```

Job 完成后先用 `magnus job status <ID>` 取得 Result 中的 File Custody secret，再用 `magnus receive <SECRET> --output <本地结果包.tar.gz>` 取回。secret 有效期 240 分钟。最初的训练 Job 用 CLI 输出 secret 到日志；当前脚本改用已验证的 SDK Result 协议。

短验证通过后，正式单次训练入口是 `bash magnus/train.sh`；配置、运行名和训练参数原样传给现有训练器：

```bash
magnus job submit \
  --task-name stg-rl-train-exp-name \
  --namespace Renko6626 --repo-name stg-rl-train \
  --branch feat/magnus-training --commit-sha <已推送的完整 SHA> \
  --gpu-type a100 --gpu-count 1 --cpu-count 16 --memory-demand 32G \
  --ephemeral-storage 20G --job-type A2 \
  --container-image docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel \
  --entry-command 'bash magnus/train.sh configs/base.toml exp-name'
```

也可以传 `--total-updates N`、`--runs-dir PATH` 或 `--resume RUN_DIR`。`--resume` 指向的 run 目录必须在 Job 启动前已放进 Job 可见的持久挂载路径；目前尚未确认本站给该账号提供的挂载点。单次训练完成后，`train.sh` 会把打包结果交给 File Custody。

`magnus/wheels/` 有两个项目自有依赖：`stg_rl` 取自 `stg-engine` 的 `rl-v0.1.1` Release（2026-09-24 从 `rl-v0.1.0` 升级：VecEnv 分块修复 + `tick_steps` 遇 END 即停，观测输出不变）；`stgagent` 从 `stg-agent-proto` 的 `v0.1.0`（commit `6b61fa052640377d640e5a7ecee9641b6ac3df96`）构建。`SHA256SUMS` 固定了本次验证的字节内容，更新依赖时必须一起更新 wheel 与校验和。放在仓库内是为了避免 Job 容器直连 GitHub 的不稳定性，合计约 804 KB。

## 正式训练前还需完成

1. 给 Magnus 路径做独立锁定，不改变 Vast.ai 当前的 `uv.lock`；运行时必须记录实际的 Python、PyTorch、CUDA、TensorDict 与 wheel SHA。
2. 确认站点可用的持久存储，将 `--runs-dir` 指向持久路径。Magnus 会清理 Job 工作区，File Custody 只有短期有效，不能作为正式续训的唯一存储。尚未收到本站持久挂载路径。
3. 按 `docs/perf-baseline.md` 的扫描结果选择 `env.threads` 和 `num_envs`，明确训练目标是固定环境帧数还是固定更新次数；长期任务不要沿用 `base.toml` 的 `threads=0`。
4. 若每个 Job 安装小依赖仍过慢，再按 Magnus 的镜像指南用同一锁文件 `uv sync --frozen` 预热缓存，发布专用镜像；目前先复用已缓存镜像。

Magnus 参考：`/data/sunyunbo/magnus-docs/official/docs/internals/job-runtime.zh-CN.md` 与 `.../uv-image.zh-CN.md`。
