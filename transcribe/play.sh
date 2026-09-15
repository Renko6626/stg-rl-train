#!/usr/bin/env bash
# 试玩转写卡：一个常驻 viewer + 一条 SSH 隧道，换卡刷新浏览器即可。
#
#   transcribe/play.sh                    列出可试玩的卡（范例 / 已验收 / 已收卡）
#   transcribe/play.sh <卡 id 或序号> [rank]   切到这张卡（rank 默认取 2，超出卡的 ranks 就夹到范围内）
#   transcribe/play.sh status | stop
#
# 端口 PLAY_PORT（默认 8611）；stg-engine 位置 STG_ENGINE_DIR。viewer 用机体 0：试玩别按 X，就等价于 RL 训练的机体 1。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
ENGINE="${STG_ENGINE_DIR:-/data/sunyunbo/www/stg-engine}"
HARNESS="$ENGINE/target/release/stg-harness"
PY="$REPO/.venv/bin/python"
PORT="${PLAY_PORT:-8611}"
PLAY="$HERE/work/play"
mkdir -p "$PLAY"

[[ -x "$HARNESS" ]] || { echo "找不到 $HARNESS（stg-engine 里 cargo build --release -p stg-harness）" >&2; exit 1; }

# 可玩卡清单：id<TAB>目录<TAB>来源<TAB>ranks<TAB>标题。同 id 优先级 cards/ > 流水线 > 范例。
list_cards() {
  "$PY" - "$REPO" <<'PY'
import json, sys, tomllib
from pathlib import Path
repo = Path(sys.argv[1])
found = {}
def add(d, src):
    m = d / "meta.toml"
    if not m.exists() or d.name in found:
        return
    meta = tomllib.loads(m.read_text(encoding="utf-8"))
    found[d.name] = (d, src, meta.get("ranks", [0, 3]), meta.get("title", ""))
cards = repo / "cards"
for d in sorted(cards.glob("th06_*")) if cards.is_dir() else []:
    add(d, "cards")
state = {}
sp = repo / "transcribe/work/state.jsonl"
if sp.exists():
    for line in sp.read_text(encoding="utf-8").splitlines():
        if line.strip():
            r = json.loads(line); state[r["id"]] = r["state"]
for uid, st in sorted(state.items()):
    if st in ("validated", "reviewed", "collected"):
        add(repo / "transcribe/work/units" / uid / "card" / uid, f"流水线:{st}")
for d in sorted((repo / "transcribe/th06/examples").iterdir()):
    if d.is_dir():
        add(d, "范例")
for uid, (d, src, ranks, title) in sorted(found.items()):
    print(f"{uid}\t{d}\t{src}\t{ranks[0]}-{ranks[1]}\t{title}")
PY
}

running_pid() {
  [[ -f "$PLAY/pid" ]] || return 1
  local pid; pid="$(cat "$PLAY/pid")"
  kill -0 "$pid" 2>/dev/null && echo "$pid"
}

stop_server() {
  local pid
  if pid="$(running_pid)"; then kill "$pid" 2>/dev/null || true; sleep 0.3; fi
  rm -f "$PLAY/pid" "$PLAY/rank"
}

hint() {
  cat <<EOF

浏览器：http://localhost:$PORT
不在这台机器上：先开隧道  ssh -L $PORT:localhost:$PORT $(whoami)@$(hostname)
操作：方向键移动 · Z 射击 · Shift 低速（别按 X）· 刷新浏览器 = 重开这一局 / 载入新切换的卡
EOF
}

case "${1:-}" in
  "")
    echo "可试玩的卡："
    list_cards | awk -F'\t' '{printf "  %2d  %-14s %-18s rank %-4s %s\n", NR, $1, $3, $4, $5}'
    echo
    echo "用法：$0 <序号或 id> [rank]"
    if pid="$(running_pid)"; then echo "viewer 在跑（pid $pid，rank $(cat "$PLAY/rank")，当前 $(readlink "$PLAY/current")）"; fi
    ;;
  stop)
    stop_server; echo "viewer 已停"
    ;;
  status)
    if pid="$(running_pid)"; then
      echo "viewer 在跑：pid $pid · 端口 $PORT · rank $(cat "$PLAY/rank") · 卡 $(readlink "$PLAY/current")"
      hint
    else
      echo "viewer 没在跑"
    fi
    ;;
  *)
    sel="$1"
    line="$(list_cards | awk -F'\t' -v s="$sel" '(NR == s) || ($1 == s)' | head -1)"
    [[ -n "$line" ]] || { echo "没有这张卡：$sel（不带参数运行看清单）" >&2; exit 1; }
    IFS=$'\t' read -r uid dir src ranks title <<<"$line"
    lo="${ranks%-*}"; hi="${ranks#*-}"
    rank="${2:-2}"
    (( rank < lo )) && rank="$lo"
    (( rank > hi )) && rank="$hi"
    if ! "$HARNESS" check "$dir" >/dev/null 2>"$PLAY/check.err"; then
      echo "编译失败，没有切换：" >&2; cat "$PLAY/check.err" >&2; exit 1
    fi
    ln -sfn "$dir" "$PLAY/current"
    if pid="$(running_pid)" && [[ "$(cat "$PLAY/rank")" == "$rank" ]]; then
      echo "已切到 $uid「$title」（rank $rank）——刷新浏览器"
    else
      stop_server
      nohup "$HARNESS" serve --ecl "$PLAY/current" --port "$PORT" --rank "$rank" >"$PLAY/serve.log" 2>&1 &
      echo $! >"$PLAY/pid"; echo "$rank" >"$PLAY/rank"
      sleep 0.5
      if ! running_pid >/dev/null; then echo "viewer 没起来：" >&2; cat "$PLAY/serve.log" >&2; exit 1; fi
      echo "viewer 已启动：$uid「$title」（rank $rank，来源 $src）"
    fi
    hint
    ;;
esac
