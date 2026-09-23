# stg-rl-train

stg-engine 躲弹小模型的训练仓。设计见 `docs/2026-09-15-stg-rl-train-design.md`。
Magnus A100 的短 Job 验证与迁移限制见 [`docs/magnus-migration.md`](docs/magnus-migration.md)。

## 一条命令跑训练（任意有 GPU 的 Linux）

```bash
git clone https://github.com/Renko6626/stg-rl-train && cd stg-rl-train
bash run.sh configs/base.toml my-run          # 装依赖 → 训练 → 评测 → 出图 → runs/<时间>-my-run.tar.gz
bash run.sh --resume runs/<目录>               # 续训
bash run.sh configs/base.toml --bench          # 新机器先测吞吐，选 threads × num_envs
```

租机注意：env 在 CPU 上跑，吞吐主要吃 CPU 核数。

## 探测模式：新机器先跑这个

测安装可达性（uv / PyPI / GitHub）与 CPU / GPU 负载，约 20 分钟，产出**一个**结果包：

```bash
git clone https://github.com/Renko6626/stg-rl-train && cd stg-rl-train
bash run.sh --probe                    # 可选 --minutes 60
# → runs/probe-<主机名>-<时间>.tar.gz，把这个文件发回来
```

顺序：网络探测（各域名连通 + torch wheel 下载测速）→ 计时安装 → 系统信息（lscpu / nvidia-smi …）→
gpucheck（有 CUDA 才跑）→ bench 选 num_envs / threads → 用 `probe/cards` 的 7 张卡限时训练。
每步失败都记下来继续，照样打包。包里 `SUMMARY.md` 是汇总，`train/plots/load.png` 是负载曲线，
`train/perf.jsonl` 是每秒一行的原始负载数据。

## 导出部署用的 ONNX 图

把一个 checkpoint 导成**特征化 + 网络合体**的单文件定形图，给 th06nc / TH18 的 DLL 用
（ORT CPU 跑）。特征化也进图，所以 C 侧不必复刻 topk / 密度图 / 归一化 —— 逐位一致由
「两边是同一张图」保证。设计见 renkolab `docs/superpowers/specs/2026-09-18-th06nc-onnx-policy-design.md`。

```bash
uv run --frozen python -m stgtrain.export_onnx runs/<run>/checkpoints/best.pt --out dist --name j-best
# → dist/j-best.onnx（约 1.4 MB，权重内联，单文件）+ dist/j-best.manifest.json（出处与图签名）
```

导出后会自动拿 onnxruntime 与 torch 对一遍 logits（偏差 > 1e-5 或 argmax 不同就退非零码）。
支持 `danger_topk_v2` / `danger_topk_v3`，两者导出的都是**图版本 2** 的同一套签名（`enemies` 六列，
后两列是敌人速度；v2 的图不读它们），所以同一个 DLL 能换着装。敌人速度的差分**不在图里**，
由 C 端 `sa_model_fill` 按 id 跨帧做（口径 = `envwrap.enemy_velocity`，含 16 px 瞬移守卫）。
再换特征化器要在 `EXPORT_FEATURIZERS` 加一个可导出孪生；动了图签名还要两边一起 bump `GRAPH_VERSION`。`dist/` 不入库，按 `rl-vX` wheel 的先例走 Release 分发。

## 开发

```bash
uv sync --frozen
uv run --frozen pytest -q
bash run.sh configs/smoke.toml smoke           # CPU 冒烟
uv run --frozen python -m stgtrain.plots runs/<目录>   # 重画曲线
```
