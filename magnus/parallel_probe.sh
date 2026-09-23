#!/usr/bin/env bash
# Compare one training process with two concurrent processes on one A100.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

python - <<'PY'
import os
print(f"os.cpu_count={os.cpu_count()} affinity_cpus={len(os.sched_getaffinity(0))}", flush=True)
PY
for cgroup_file in /sys/fs/cgroup/cpu.max /sys/fs/cgroup/cpu/cpu.cfs_quota_us \
                   /sys/fs/cgroup/cpu/cpu.cfs_period_us /sys/fs/cgroup/cpuset.cpus.effective; do
    if [[ -r "$cgroup_file" ]]; then
        printf '%s=' "$cgroup_file"
        cat "$cgroup_file"
    fi
done
sed -n 's/^Cpus_allowed_list:[[:space:]]*/Cpus_allowed_list=/p' /proc/self/status

probe_dir="runs/a100-parallel-probe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
sed -E -e 's/^threads = 0[[:space:]].*$/threads = 28/' \
       -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
       configs/base.toml > "$probe_dir/single.toml"
sed -E -e 's/^threads = 0[[:space:]].*$/threads = 14/' \
       -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
       configs/base.toml > "$probe_dir/pair-a.toml"
sed -E -e 's/^seed = 1$/seed = 2/' \
       -e 's/^threads = 0[[:space:]].*$/threads = 14/' \
       -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
       configs/base.toml > "$probe_dir/pair-b.toml"

single_start=$(date +%s)
python -u -m stgtrain.train "$probe_dir/single.toml" single-28 \
    --runs-dir "$probe_dir" --total-updates 20 --no-pack \
    2>&1 | tee "$probe_dir/single.console.log"
single_wall=$(( $(date +%s) - single_start ))

pair_start=$(date +%s)
(
    set -o pipefail
    python -u -m stgtrain.train "$probe_dir/pair-a.toml" pair-a-14 \
        --runs-dir "$probe_dir" --total-updates 20 --no-pack \
        2>&1 | tee "$probe_dir/pair-a.console.log" | sed -u 's/^/[A] /'
) &
pair_a_pid=$!
(
    set -o pipefail
    python -u -m stgtrain.train "$probe_dir/pair-b.toml" pair-b-14 \
        --runs-dir "$probe_dir" --total-updates 20 --no-pack \
        2>&1 | tee "$probe_dir/pair-b.console.log" | sed -u 's/^/[B] /'
) &
pair_b_pid=$!
set +e
wait "$pair_a_pid"; pair_a_rc=$?
wait "$pair_b_pid"; pair_b_rc=$?
set -e
pair_wall=$(( $(date +%s) - pair_start ))

export MAGNUS_PROBE_DIR="$probe_dir" MAGNUS_SINGLE_WALL="$single_wall" MAGNUS_PAIR_WALL="$pair_wall"
export MAGNUS_PAIR_A_RC="$pair_a_rc" MAGNUS_PAIR_B_RC="$pair_b_rc"
python - <<'PY'
import json
import os
from pathlib import Path
from statistics import median

root = Path(os.environ["MAGNUS_PROBE_DIR"])
out = {"single_wall_s": int(os.environ["MAGNUS_SINGLE_WALL"]),
       "pair_wall_s": int(os.environ["MAGNUS_PAIR_WALL"]),
       "pair_exit_codes": [int(os.environ["MAGNUS_PAIR_A_RC"]), int(os.environ["MAGNUS_PAIR_B_RC"])],
       "runs": {}}
for label in ("single-28", "pair-a-14", "pair-b-14"):
    matches = list(root.glob(f"*-{label}"))
    if len(matches) != 1:
        out["runs"][label] = {"error": f"expected one run directory; found {len(matches)}"}
        continue
    metrics = matches[0] / "metrics.jsonl"
    if not metrics.exists():
        out["runs"][label] = {"error": "metrics.jsonl missing"}
        continue
    rows = [json.loads(line) for line in metrics.read_text().splitlines() if line]
    steady = [row["perf/sps"] for row in rows if 5 <= row.get("update", 0) <= 19 and "perf/sps" in row]
    perf_path = matches[0] / "perf.jsonl"
    phases = [json.loads(line) for line in perf_path.read_text().splitlines() if line] if perf_path.exists() else []
    phases = [row for row in phases if row.get("kind") == "phase"]
    phase_keys = sorted({key for row in phases for key in row if key.endswith("_s")})
    out["runs"][label] = {"updates": max((r.get("update", 0) for r in rows), default=0),
                          "steady_median_sps": median(steady) if steady else None,
                          "steady_rows": len(steady),
                          "phase_samples": len(phases),
                          "phase_median_s": {key: median(row[key] for row in phases if key in row)
                                             for key in phase_keys}}
print(json.dumps(out, ensure_ascii=False, indent=2), flush=True)
(root / "summary.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
PY

archive="$probe_dir.tar.gz"
tar -czf "$archive" -C runs "$(basename "$probe_dir")"
python - "$archive" <<'PY'
import os
import sys
from pathlib import Path
import magnus

secret = magnus.custody_file(sys.argv[1], expire_minutes=240)
Path(os.environ["MAGNUS_RESULT"]).write_text(secret + "\n", encoding="utf-8")
print("并行探测结果包已上传；secret 见 Job Result", flush=True)
PY

if (( pair_a_rc != 0 || pair_b_rc != 0 )); then
    exit 1
fi
