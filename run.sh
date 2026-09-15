#!/usr/bin/env bash
# 一条命令：装依赖（uv sync --frozen）→ 训练 / 续训 / 测速。参数原样交给 python -m stgtrain.train。
#   bash run.sh configs/base.toml my-run
#   bash run.sh --resume runs/<目录> [--total-updates N]
#   bash run.sh configs/base.toml my-box --bench
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv sync --frozen
exec uv run --frozen python -m stgtrain.train "$@"
