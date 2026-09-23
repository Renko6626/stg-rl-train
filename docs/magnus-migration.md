# Magnus 训练迁移记录（2026-09-23）

## 已验证的环境

- Magnus `Renko6626/stg-rl-train` 仓库和 `a100` GPU 类型可以提交 Job。
- A100 80GB 节点驱动为 550.163.01。缓存镜像 `docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime` 内的 Python 3.11.10、PyTorch 2.5.1+cu124 能看到 GPU（Job `81ec9987f70e198d`，Success）。
- 主仓 `uv.lock` 固定 PyTorch 2.14.0，安装的是 CUDA 13 包；在该节点上 `gpucheck` 报驱动过旧，CUDA 不可用（Job `c44ff59c0e0023fe`）。因此不能直接运行 `bash run.sh`。
- `docker://python:3.12` Job 的 `UV_CACHE_DIR` 未设置，默认 `/magnus/.cache/uv`。两次 `uv sync --frozen` 分别下载 68 个包，耗时 8 分 09 秒、8 分 13 秒，跨 Job 没有命中缓存。
- 缓存的 PyTorch 镜像没有 `git`，Job 内直连 GitHub 下载 `stg-rl` wheel 发生超时。Magnus 注入的 SDK 也缺少 `typer` 等 Python 依赖，使用 `magnus receive` / `custody` 前要安装 `magnus-sdk`。
- 该镜像自带的 `ninja 1.11.1.1` 会让全环境 `pip check` 返回非零；这项检查改为记录告警，不阻断实际 GPU 路径验证。
- `2.5.1-cuda12.4-cudnn9-runtime` 缺少 C 编译器，`torch.compile` 失败。换成站点已缓存的同版本 `devel` 镜像后，Job `1c1be6b6ac0da812` 的 `gpucheck` 所有数值对拍通过，并完成两次 PPO 更新、640 局评测、checkpoint、出图与打包，Job 状态为 Success。结果包已取回到本地 `runs/20260923-190104-magnus-cu124-smoke.tar.gz`（约 8 MB）。

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

Job 完成后先用 `magnus job status <ID>` 取得 Result 中的 File Custody secret，再用 `magnus receive <SECRET> --output <本地结果包.tar.gz>` 取回。secret 有效期 240 分钟。

`magnus/wheels/` 有两个项目自有依赖：`stg_rl` 取自 `stg-engine` 的 `rl-v0.1.0` Release；`stgagent` 从 `stg-agent-proto` 的 `v0.1.0`（commit `6b61fa052640377d640e5a7ecee9641b6ac3df96`）构建。`SHA256SUMS` 固定了本次验证的字节内容，更新依赖时必须一起更新 wheel 与校验和。放在仓库内是为了避免 Job 容器直连 GitHub 的不稳定性，合计约 804 KB。

## 正式训练前还需完成

1. 给 Magnus 路径做独立锁定，不改变 Vast.ai 当前的 `uv.lock`；运行时必须记录实际的 Python、PyTorch、CUDA、TensorDict 与 wheel SHA。
2. 确认站点可用的持久存储，将 `--runs-dir` 指向持久路径。Magnus 会清理 Job 工作区，File Custody 只有短期有效，不能作为正式续训的唯一存储。
3. 用实际训练卡池跑 `--bench`，按获得的 CPU 配额选 `env.threads`，不要沿用 `base.toml` 的 `threads=0`。
4. 若每个 Job 安装小依赖仍过慢，再按 Magnus 的镜像指南用同一锁文件 `uv sync --frozen` 预热缓存，发布专用镜像；目前先复用已缓存镜像。

Magnus 参考：`/data/sunyunbo/magnus-docs/official/docs/internals/job-runtime.zh-CN.md` 与 `.../uv-image.zh-CN.md`。
