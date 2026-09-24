#!/usr/bin/env bash
# How many concurrent trainings fit one A100 best: run K = 1, 2, … copies of one config for a few
# updates each, record per-run and total steady throughput plus the GPU memory peak.
#
#   [KS="1 2 3 4"] [CONFIG=configs/exp-m0-rebase.toml] [UPDATES=20] bash magnus/parallel_probe.sh
#
# Env threads per run follow train-multi.sh ((affinity CPUs − 2K) / K), so the result is what
# train-multi would actually get. Steady = median perf/sps over updates 5..UPDATES-1.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"
source "$(dirname "$0")/lib.sh"

KS=${KS:-1 2 3 4}
CONFIG=${CONFIG:-configs/exp-m0-rebase.toml}
UPDATES=${UPDATES:-20}
probe_dir="runs/a100-kprobe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
MAGNUS_PIDS=()

python - <<'PY'
import os
print(f"os.cpu_count={os.cpu_count()} affinity_cpus={len(os.sched_getaffinity(0))}", flush=True)
PY
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true

on_exit() {
    local rc=$?
    set +e
    trap - EXIT TERM INT
    magnus_stop_runs
    [[ -n ${smi_pid:-} ]] && kill "$smi_pid" 2>/dev/null
    magnus_pack_upload "$probe_dir" || echo '结果包上传失败' >&2
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到 SIGTERM，打包已有结果" >&2; exit 0' TERM INT

# Denser phase sampling than a real run; everything else is the config under test.
python - "$CONFIG" "$probe_dir/base.toml" <<'PY'
import sys

from stgtrain.config import dump_toml, load_config

dump_toml(load_config(sys.argv[1], {"log": {"perf_sync_every": 5}}), sys.argv[2])
PY

MAGNUS_TRAIN_ARGS=(--total-updates "$UPDATES")
for k in $KS; do
    kdir="$probe_dir/k$k"
    threads=$(magnus_threads_for "$k")
    specs=()
    for i in $(seq 1 "$k"); do specs+=("$probe_dir/base.toml:k$k-r$i:$i"); done
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -l 2 > "$kdir.gpumem" 2>/dev/null &
    smi_pid=$!
    start=$(date +%s)
    magnus_launch_runs "$kdir" "$threads" "${specs[@]}"
    failed=0
    magnus_wait_runs || failed=$?
    MAGNUS_PIDS=()
    echo "k=$k threads=$threads wall=$(( $(date +%s) - start ))s failed=$failed" | tee -a "$probe_dir/walls.txt"
    kill "$smi_pid" 2>/dev/null || true
    smi_pid=
done

python - "$probe_dir" "$UPDATES" <<'PY'
import json
import sys
from pathlib import Path
from statistics import median

root, updates = Path(sys.argv[1]), int(sys.argv[2])
out = {"walls": (root / "walls.txt").read_text().splitlines(), "k": {}}
for kdir in sorted(p for p in root.glob("k*") if p.is_dir()):
    runs = {}
    for metrics in sorted(kdir.glob("*/metrics.jsonl")):
        rows = [json.loads(line) for line in metrics.read_text().splitlines() if line]
        steady = [r["perf/sps"] for r in rows if 5 <= r.get("update", 0) < updates and "perf/sps" in r]
        perf = metrics.parent / "perf.jsonl"
        phases = [json.loads(line) for line in perf.read_text().splitlines() if line] if perf.exists() else []
        phases = [r for r in phases if r.get("kind") == "phase"]
        keys = sorted({k for r in phases for k in r if k.endswith("_s")})
        runs[metrics.parent.name] = {
            "updates": max((r.get("update", 0) for r in rows), default=0),
            "steady_median_sps": median(steady) if steady else None,
            "phase_median_s": {k: median(r[k] for r in phases if k in r) for k in keys},
        }
    mem = kdir.with_suffix(".gpumem")
    mem_mib = [int(x) for x in mem.read_text().split() if x.isdigit()] if mem.exists() else []
    sps = [r["steady_median_sps"] for r in runs.values() if r["steady_median_sps"]]
    out["k"][kdir.name] = {"runs": runs, "total_sps": sum(sps) if len(sps) == len(runs) else None,
                           "gpu_mem_peak_mib": max(mem_mib, default=None)}
print(json.dumps(out, ensure_ascii=False, indent=2), flush=True)
(root / "summary.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
PY
