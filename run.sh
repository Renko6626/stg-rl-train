#!/usr/bin/env bash
# 一条命令：装依赖（uv sync --frozen）→ 训练 / 续训 / 测速。参数原样交给 python -m stgtrain.train。
#   bash run.sh configs/base.toml my-run
#   bash run.sh --resume runs/<目录> [--total-updates N]
#   bash run.sh configs/base.toml my-box --bench
#
# 探测模式（新机器：测安装可达性 + CPU / GPU 负载，产出一个结果包发回来）：
#   bash run.sh --probe [--minutes 20]
set -euo pipefail
cd "$(dirname "$0")"

ensure_uv() {
  if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

if [[ "${1:-}" != "--probe" ]]; then
  ensure_uv
  uv sync --frozen
  exec uv run --frozen python -m stgtrain.train "$@"
fi

# ── 探测模式 ───────────────────────────────────────────────────────────────
shift
MINUTES=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minutes) MINUTES="$2"; shift 2 ;;
    *) echo "未知参数 $1（--probe 只接受 --minutes N）" >&2; exit 2 ;;
  esac
done
OUT="runs/probe-$(hostname -s 2>/dev/null || echo host)-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
exec > >(tee -a "$OUT/console.log") 2>&1
echo "探测模式：结果目录 $OUT，时长预算 ${MINUTES} 分钟（不含安装）"

pack_and_exit() {
  tar czf "$OUT.tar.gz" -C runs "$(basename "$OUT")"
  echo
  echo "✘ $1"
  echo "结果包（含失败日志）：$OUT.tar.gz —— 把这个文件发回来即可。"
  exit 1
}

echo "===== 网络 ====="
TORCH_WHL="$(grep -o 'https://files.pythonhosted.org/[^"]*torch-2\.14\.0-cp312-cp312-manylinux[^"]*x86_64\.whl' uv.lock | head -1 || true)"
STG_RL_WHL="$(grep -o 'https://github.com/Renko6626/stg-engine/releases/download/[^"]*\.whl' pyproject.toml | head -1 || true)"
{
  echo "# 目标  HTTP码  总耗时  下载字节  下载速度(B/s)"
  for url in https://astral.sh/uv/install.sh https://pypi.org/simple/torch/ "$STG_RL_WHL" \
             https://github.com/Renko6626/stg-agent-proto; do
    [[ -n "$url" ]] || continue
    r="$(curl -sS -L -o /dev/null --max-time 60 -w '%{http_code} %{time_total}s %{size_download} %{speed_download}' "$url" 2>&1 || true)"
    echo "$url  $r"
  done
  if [[ -n "$TORCH_WHL" ]]; then
    r="$(curl -sS -L -o /dev/null --max-time 120 -r 0-8388607 -w '%{http_code} %{time_total}s %{size_download} %{speed_download}' "$TORCH_WHL" 2>&1 || true)"
    echo "torch wheel 前 8MB（files.pythonhosted.org）  $r"
  fi
} | tee "$OUT/net.txt"

echo "===== 安装 ====="
t0=$(date +%s)
had_uv=true; command -v uv >/dev/null 2>&1 || had_uv=false
ensure_uv >"$OUT/install.log" 2>&1 || pack_and_exit "安装 uv 失败（见 install.log）"
t1=$(date +%s)
if ! uv sync --frozen >>"$OUT/install.log" 2>&1; then
  echo "{\"had_uv\": $had_uv, \"uv_install_s\": $((t1 - t0)), \"uv_sync_s\": $(( $(date +%s) - t1 )), \"ok\": false}" >"$OUT/install.json"
  tail -30 "$OUT/install.log"
  pack_and_exit "uv sync 失败（见 install.log 末尾）"
fi
t2=$(date +%s)
echo "{\"had_uv\": $had_uv, \"uv_install_s\": $((t1 - t0)), \"uv_sync_s\": $((t2 - t1)), \"venv_mb\": $(du -sm .venv | cut -f1), \"ok\": true}" | tee "$OUT/install.json"

echo "===== 探测 ====="
uv run --frozen python -m stgtrain.probe --out "$OUT" --minutes "$MINUTES"
