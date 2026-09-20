#!/usr/bin/env bash
# 无人值守串行跑一批实验（队列见下面的 EXPS；单条 2000 轮约 2h、3500 轮约 3h40）。
#
#   tmux new -s night
#   bash scripts/run-night.sh                        # 自动选线程（未知机器先 bench 一次，三条复用）
#   bash scripts/run-night.sh --threads 32
#   bash scripts/run-night.sh --only h,i             # 只跑其中几条
#   bash scripts/run-night.sh --retries 3            # 单条最多续训几次（默认 2）
#   bash scripts/run-night.sh --smoke                # 30 秒 CPU 冒烟：先确认脚本本身没问题再放它跑整夜
#   bash scripts/run-night.sh --loose-check          # gpucheck 不通过也继续（只打印 WARN）
#   bash scripts/run-night.sh --no-check             # 完全跳过 gpucheck
#   bash scripts/run-night.sh --parallel 2           # 同机并行 2 条（受限于显存，见下）
#   bash scripts/run-night.sh --no-preflight         # 跳过「每条配置真跑 2 轮」的试车
#
# 设计要点（都是为了睡觉时别白跑）：
#   · **开跑前先体检**：GPU 可见 + gpucheck（真做一次前向/反向，编译与 CUDA 图都走一遍）+ 磁盘余量。
#     7.5 小时的活，不值得在第 1 分钟才发现 torch 看不见卡。
#   · **崩了自动续训**：train.py 的 --resume 吃 run 目录，本脚本自己找最新的那个，最多续 N 次。
#     上次实验 F 就是跑到一半服务器自己坏了。
#   · **一条挂了继续下一条**：所以不开 `set -e`。H 和 I 都只跟 G0 比，G0 没跑成也不必整夜停摆。
#   · **线程只 bench 一次**：run-exp.sh 是单条脚本，每条都会 bench（约 5 分钟）；这里测一次三条复用。
#   · 日志：runs/<名>.console.log（单条）与 runs/night-<时间>.log（总）。
#   · **并行**：单条实测占显存 10.1G、GPU 利用率中位 37%、128 逻辑核只用掉约 6.7 个
#     （env 线程 32 个，但 env_step 只占一轮的 24%）。所以同机并行卡在**显存**而不是算力：
#     24G 的卡塞得下 2 条（20.2G），3 条不行。两条合计吞吐约 1.4 倍（那 40% 的 update 阶段会串行化），
#     **2026-09-19 实测**（I2 + J 并行 3500 轮）：单条 47.8k / 47.1k 帧/s，合计 94.9k
#     = 单跑 70k 的 1.36 倍；每条 5.33h / 5.41h（单跑约 3h40）。要线性加速就另租一台，别硬塞第三条。
set -uo pipefail
cd "$(dirname "$0")/.."

# 当前队列（跑完一批就换成下一批；G0/H/I、I2/J 已于 2026-09-19 跑完，见 docs/experiments.md）
# N3（低速键也过运动层）‖ M（N3 + edge_hug），两条同机并行：  bash scripts/run-night.sh --parallel 2
EXPS=(
  "n3 configs/exp-n3-motor-slow.toml"
  "m  configs/exp-m-edgehug.toml"
)
THREADS=""; RETRIES=2; ONLY=""; SMOKE=0; CHECK=strict; PAR=1; PREFLIGHT=1
VRAM_PER_RUN_MB=11000     # 单条实测峰值 10.1G，留一点余量
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --only)    ONLY=",$2,";  shift 2 ;;
    --smoke)   SMOKE=1;      shift 1 ;;
    --loose-check) CHECK=loose; shift 1 ;;
    --no-check)    CHECK=off;   shift 1 ;;
    --parallel)    PAR="$2";    shift 2 ;;
    --no-preflight) PREFLIGHT=0; shift 1 ;;
    *) echo "未知参数 $1" >&2; exit 2 ;;
  esac
done

mkdir -p runs
NIGHT_LOG="runs/night-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$NIGHT_LOG") 2>&1
say() { echo "[$(date +%H:%M:%S)] $*"; }

say "仓库 $(git rev-parse --short HEAD) · $(git log -1 --format=%s | cut -c1-60)"
export PATH="$HOME/.local/bin:$PATH"
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync --frozen || { say "uv sync 失败，停"; exit 1; }

if [[ $SMOKE -eq 1 ]]; then    # 冒烟：三条都换成 CPU 小配置，跳过体检与 bench
  EXPS=("smoke-g0 configs/smoke.toml" "smoke-h configs/smoke.toml" "smoke-i configs/smoke.toml")
  THREADS=4
  say "冒烟模式：三条都用 configs/smoke.toml 跑 3 次更新（CPU），只验脚本本身"
fi

# ── 体检 ────────────────────────────────────────────────────────────────────
if [[ $SMOKE -eq 0 ]]; then
uv run --frozen python - <<'PY' || { echo "GPU 不可用，停"; exit 1; }
import torch, sys
if not torch.cuda.is_available():
    sys.exit(1)
p = torch.cuda.get_device_properties(0)
print(f"GPU {p.name} · 显存 {p.total_memory / 2**30:.0f} GiB · torch {torch.__version__}")
PY
FREE_G=$(df -BG --output=avail . | tail -1 | tr -dc '0-9')
say "磁盘余量 ${FREE_G}G（一条 run 含 tar.gz 约 1–2G）"
[[ "$FREE_G" -lt 8 ]] && say "⚠ 磁盘不足 8G，先清 runs/ 再跑" && exit 1
if [[ "$CHECK" == off ]]; then
  say "跳过 gpucheck（--no-check）"
else
  say "gpucheck（真跑一次前向/反向 + 编译 + CUDA 图）……"
  GC_ARGS=("${EXPS[0]#* }")
  [[ "$CHECK" == loose ]] && GC_ARGS+=(--warn-only)
  uv run --frozen python -m stgtrain.gpucheck "${GC_ARGS[@]}" || { say "gpucheck 没过，停（确认是浮点噪声就加 --loose-check）"; exit 1; }
fi
fi

# ── 并行前的资源闸 ──────────────────────────────────────────────────────────
if [[ "$PAR" -gt 1 && $SMOKE -eq 0 ]]; then
  FREE_MB=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
  NEED=$((PAR * VRAM_PER_RUN_MB))
  say "并行 $PAR 条：需显存约 ${NEED}MB，当前空闲 ${FREE_MB}MB"
  if [[ "$FREE_MB" -lt "$NEED" ]]; then
    say "✘ 显存不够（单条实测峰值 10.1G）。降并行度，或把 env.num_envs 调小——"
    say "  但 num_envs 是实验变量，改了就不能和既有实验直接比。"
    exit 1
  fi
  # 显存碎片：两条同卡时 expandable_segments 能少踩一次 OOM
  export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
fi

# ── 线程：只测一次，整个队列复用 ────────────────────────────────────────────
if [[ -z "$THREADS" ]]; then
  CPU="$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
  if [[ "$CPU" == *"EPYC 7742"* && "$(nproc)" -ge 255 ]]; then
    THREADS=32
    say "识别到 $CPU × $(nproc) 逻辑核 → threads = 32（实测最快）"
  else
    say "未知机器（$CPU × $(nproc) 逻辑核），bench 选线程（约 5 分钟，只做这一次）……"
    uv run --frozen python -m stgtrain.train "${EXPS[0]#* }" bench-night --bench
    BENCH="$(ls -td runs/*bench-night*/ | head -1)"
    THREADS="$(uv run --frozen python -c "import json,sys;print(json.load(open(sys.argv[1]))['recommended']['threads'])" "$BENCH/bench.json")"
    say "bench 推荐 threads = $THREADS"
  fi
fi

# ── 试车：每条配置真跑 2 轮 ─────────────────────────────────────────────────
# gpucheck 只验模型的前向/反向，**包装层里的新东西它碰不到**（N1/N2 的手部运动层在 GPU 上第一次跑就是这里）。
# 每条约 1–2 分钟（主要是编译）。任何一条试车失败就整批停 —— 半夜第 1 分钟崩掉、续训再崩，等于白挂一夜。
if [[ $SMOKE -eq 0 && $PREFLIGHT -eq 1 ]]; then
  PF_DIR="runs/preflight-$(date +%Y%m%d-%H%M%S)"
  for e in "${EXPS[@]}"; do
    read -r name cfg <<<"$e"
    [[ -n "$ONLY" && "$ONLY" != *",$name,"* ]] && continue
    pf_cfg="$PF_DIR/$name.toml"; mkdir -p "$PF_DIR"
    sed "s/^threads = .*/threads = $THREADS/" "$cfg" > "$pf_cfg"
    say "试车 $name（2 轮，不打包）……"
    uv run --frozen python -m stgtrain.train "$pf_cfg" "pf-$name" --runs-dir "$PF_DIR" --total-updates 2 --no-pack \
      > "$PF_DIR/$name.log" 2>&1 \
      || { say "✘ 试车 $name 失败，整批停。日志：$PF_DIR/$name.log"; tail -n 25 "$PF_DIR/$name.log"; exit 1; }
    say "✔ 试车 $name 通过"
  done
  rm -rf "$PF_DIR"
fi

latest_run() { ls -td "runs/"*-"$1"/ 2>/dev/null | head -1; }

run_one() {           # $1 = 名字, $2 = 配置
  local name="$1" cfg="$2" run_cfg="runs/$1.toml" tries=0 rc=0 dir
  sed "s/^threads = .*/threads = $THREADS           # run-night.sh 选定/" "$cfg" > "$run_cfg"
  grep -q "^threads = $THREADS" "$run_cfg" || { say "$name：配置里没有 threads 行"; return 1; }
  say "▶ $name 开跑（配置副本 $run_cfg）"
  uv run --frozen python -m stgtrain.train "$run_cfg" "$name" 2>&1 | tee "runs/$name.console.log"
  rc=${PIPESTATUS[0]}
  while [[ $rc -ne 0 && $tries -lt $RETRIES ]]; do
    tries=$((tries + 1))
    dir="$(latest_run "$name")"
    if [[ -z "$dir" || ! -f "$dir/checkpoints/latest.pt" ]]; then
      say "$name：退出码 $rc，且没有可续训的 checkpoint，放弃"
      return 1
    fi
    say "$name：退出码 $rc，第 $tries/$RETRIES 次续训 ← $dir"
    sleep 30
    uv run --frozen python -m stgtrain.train --resume "$dir" 2>&1 | tee -a "runs/$name.console.log"
    rc=${PIPESTATUS[0]}
  done
  [[ $rc -eq 0 ]] && say "✔ $name 完成" || say "✘ $name 最终失败（退出码 $rc）"
  return $rc
}

if [[ "$PAR" -gt 1 ]]; then
  CORES=$(nproc)
  (( PAR * THREADS > CORES )) && say "⚠ 并行 $PAR × threads $THREADS = $((PAR*THREADS)) 超过 $CORES 逻辑核，env 会互相抢"
fi
running=0
for e in "${EXPS[@]}"; do
  read -r name cfg <<<"$e"
  [[ -n "$ONLY" && "$ONLY" != *",$name,"* ]] && { say "跳过 $name"; continue; }
  if [[ "$PAR" -gt 1 ]]; then
    (( running >= PAR )) && { wait -n; running=$((running - 1)); }   # 任一条结束立刻补位，不轮询
    run_one "$name" "$cfg" &
    running=$((running + 1))
  else
    run_one "$name" "$cfg"
  fi
done
wait

# ── 汇总：每条的末次评测 ────────────────────────────────────────────────────
say "════════ 汇总 ════════"
uv run --frozen python - <<'PY'
import json, pathlib
rows = []
for d in sorted(pathlib.Path("runs").glob("*-*")):
    if not d.is_dir() or not (d / "eval").is_dir():
        continue
    evals = sorted((d / "eval").glob("*.json"), key=lambda p: int(p.stem))
    if not evals:
        continue
    o = json.loads(evals[-1].read_text(encoding="utf-8"))["overall"]
    rows.append((d.name, int(evals[-1].stem), o))
hdr = (f"{'run':34}{'更新':>7}{'撑过':>8}{'跟点':>8}{'方向/s':>9}{'连击':>8}{'临危/s':>9}{'平时/s':>9}"
       f"{'点按≤2':>9}{'shift/s':>9}{'<12px':>8}{'手做主':>8}")
print(hdr)
for name, upd, o in rows[-12:]:
    print(f"{name:34}{upd:7}{o.get('survival', 0):8.3f}{o.get('in_r_frac', 0):8.3f}"
          f"{o.get('dir_changes_per_s', 0):9.2f}{o.get('quick_frac', 0):8.1%}"
          f"{o.get('dir_changes_near_per_s', 0):9.2f}{o.get('dir_changes_far_per_s', 0):9.2f}"
          f"{o.get('seg_le2_frac', 0):9.1%}{o.get('shift_toggles_per_s', 0):9.2f}"
          f"{o.get('close12_frac', 0):8.1%}{o.get('motor_override_frac', 0):8.1%}")
PY
say "打包在 runs/*.tar.gz；总日志 $NIGHT_LOG"
