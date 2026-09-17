#!/usr/bin/env bash
# 上机跑一个实验：装依赖 → 选线程数 → 训练（结束自动评测、出图、打包）。
#
#   bash scripts/run-exp.sh configs/exp-d-keypress.toml exp-d            # 自动选线程
#   bash scripts/run-exp.sh configs/exp-d-keypress.toml exp-d --threads 32
#
# 线程数：显式 --threads 优先；EPYC 7742（255 逻辑核）直接用实测最快的 32（docs/perf-baseline.md）；
# 其他机器先跑 --bench（约 5 分钟）取推荐值。选定的值写进 runs/<名>.toml 副本，仓库本身不改（避免 git sha 带 -dirty）。
# 终端输出同时写 runs/<名>.console.log。建议在 tmux 里跑。
set -euo pipefail
cd "$(dirname "$0")/.."

[[ $# -ge 2 ]] || { echo "用法：bash scripts/run-exp.sh <配置> <运行名> [--threads N]" >&2; exit 2; }
CFG=$1; NAME=$2; shift 2
THREADS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="$2"; shift 2 ;;
    *) echo "未知参数 $1" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync --frozen
mkdir -p runs

if [[ -z "$THREADS" ]]; then
  CPU="$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
  if [[ "$CPU" == *"EPYC 7742"* && "$(nproc)" -ge 255 ]]; then
    THREADS=32
    echo "识别到 $CPU × $(nproc) 逻辑核 → threads = 32（实测最快）"
  else
    echo "未知机器（$CPU × $(nproc) 逻辑核），先跑 bench 选线程……"
    uv run --frozen python -m stgtrain.train "$CFG" "$NAME" --bench
    BENCH="$(ls -td runs/*bench-"$NAME"*/ | head -1)"
    THREADS="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['recommended']['threads'])" "$BENCH/bench.json")"
    echo "bench 推荐 threads = $THREADS（$BENCH/bench.json）"
  fi
fi

RUN_CFG="runs/$NAME.toml"
sed "s/^threads = .*/threads = $THREADS           # run-exp.sh 选定/" "$CFG" > "$RUN_CFG"
grep -q "^threads = $THREADS" "$RUN_CFG" || { echo "配置里没有 threads 行，无法写入线程数" >&2; exit 1; }
echo "配置副本：$RUN_CFG（仓库 $(git rev-parse --short HEAD)）"
uv run --frozen python -m stgtrain.train "$RUN_CFG" "$NAME" 2>&1 | tee "runs/$NAME.console.log"
