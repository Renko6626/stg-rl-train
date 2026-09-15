# stg-rl-train

stg-engine 躲弹小模型的训练仓。设计见 `docs/2026-09-15-stg-rl-train-design.md`。

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

## 开发

```bash
uv sync --frozen
uv run --frozen pytest -q
bash run.sh configs/smoke.toml smoke           # CPU 冒烟
uv run --frozen python -m stgtrain.plots runs/<目录>   # 重画曲线
```
