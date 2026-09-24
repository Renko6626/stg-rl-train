#!/usr/bin/env bash
# Speed-only probe: each "config:name:amp" spec runs alone on this Job's GPU for UPDATES updates
# (phase timing every 5, tiny final eval), then one summary.json compares steady sps and phase medians.
#
#   bash magnus/amp_probe.sh configs/exp-q2-raw.toml:q2-fp32:off configs/exp-q2-raw.toml:q2-bf16:bf16 …
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"
source "$(dirname "$0")/lib.sh"

UPDATES=${UPDATES:-20}
probe_dir="runs/a100-amp-probe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
MAGNUS_PIDS=()

on_exit() {
    local rc=$?
    set +e
    trap - EXIT TERM INT
    magnus_stop_runs
    magnus_pack_upload "$probe_dir" || echo '结果包上传失败' >&2
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到 SIGTERM，打包已有结果" >&2; exit 0' TERM INT

threads=$(magnus_threads_for 1)
MAGNUS_TRAIN_ARGS=(--total-updates "$UPDATES")
for spec in "$@"; do
    IFS=: read -r cfg name amp <<<"$spec"
    python - "$cfg" "$probe_dir/$name-src.toml" "$amp" <<'PY'
import sys

from stgtrain.config import dump_toml, load_config

src, dst, amp = sys.argv[1:]
dump_toml(load_config(src, {"ppo": {"amp": amp}, "log": {"perf_sync_every": 5}, "eval": {"episodes": 2}}), dst)
PY
    magnus_launch_runs "$probe_dir" "$threads" "$probe_dir/$name-src.toml:$name"
    failed=0
    magnus_wait_runs || failed=$?
    MAGNUS_PIDS=()
    echo "$name amp=$amp failed=$failed" | tee -a "$probe_dir/runs.txt"
done

python - "$probe_dir" "$UPDATES" <<'PY'
import json
import sys
from pathlib import Path
from statistics import median

root, updates = Path(sys.argv[1]), int(sys.argv[2])
out = {}
for metrics in sorted(root.glob("*/metrics.jsonl")):
    rows = [json.loads(line) for line in metrics.read_text().splitlines() if line]
    steady = [r["perf/sps"] for r in rows if 5 <= r.get("update", 0) < updates and "perf/sps" in r]
    perf = metrics.parent / "perf.jsonl"
    phases = [json.loads(line) for line in perf.read_text().splitlines() if line] if perf.exists() else []
    phases = [r for r in phases if r.get("kind") == "phase"]
    keys = ("total_s", "env_step_s", "h2d_s", "featurize_s", "policy_s", "update_s")
    out[metrics.parent.name] = {"steady_median_sps": median(steady) if steady else None,
                                "phase_median_s": {k: median(r[k] for r in phases if k in r)
                                                   for k in keys if any(k in r for r in phases)}}
print(json.dumps(out, ensure_ascii=False, indent=2), flush=True)
(root / "summary.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
PY
