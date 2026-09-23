#!/usr/bin/env bash
# Measure featurizer and reward subphases on the cached A100 image.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

probe_dir="runs/a100-phase-probe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
sed -E -e 's/^threads = 0[[:space:]].*$/threads = 28/' \
       -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
       configs/base.toml > "$probe_dir/config.toml"
python -u -m stgtrain.train "$probe_dir/config.toml" phase-28 \
    --runs-dir "$probe_dir" --total-updates 20 --no-pack \
    2>&1 | tee "$probe_dir/console.log"

export MAGNUS_PHASE_PROBE_DIR="$probe_dir"
python - <<'PY'
import json
import os
from pathlib import Path
from statistics import median

root = Path(os.environ["MAGNUS_PHASE_PROBE_DIR"])
runs = list(root.glob("*-phase-28"))
if len(runs) != 1:
    raise SystemExit(f"expected one phase run, found {len(runs)}")
rows = [json.loads(line) for line in (runs[0] / "perf.jsonl").read_text().splitlines() if line]
phases = [row for row in rows if row.get("kind") == "phase"]
keys = sorted({key for row in phases for key in row if key.endswith("_s")})
summary = {"phase_samples": len(phases), "sampled_updates": [row["update"] for row in phases],
           "median_seconds": {key: median(row[key] for row in phases if key in row) for key in keys}}
(root / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)
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
print("分阶段探测结果包已上传；secret 见 Job Result", flush=True)
PY
