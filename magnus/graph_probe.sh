#!/usr/bin/env bash
# A/B the rollout CUDA graphs (featurize + reward/episode stats) on one A100: gpucheck, then off vs on.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

python -m stgtrain.gpucheck configs/base.toml

probe_dir="runs/a100-graph-probe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
for mode in off on; do
    flag=$([[ $mode == on ]] && echo true || echo false)
    sed -E -e 's/^threads = 0[[:space:]].*$/threads = 28/' \
           -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
           -e "s/^rollout_cudagraphs = true([[:space:]].*)?$/rollout_cudagraphs = $flag/" \
           configs/base.toml > "$probe_dir/$mode.toml"
    # sed 没匹配上不会报错；配置写法一变，数据就会贴错标签，所以逐项确认
    for want in '^threads = 28$' '^perf_sync_every = 5$' "^rollout_cudagraphs = $flag\$"; do
        grep -Eq "$want" "$probe_dir/$mode.toml" || { echo "配置替换失败：$want" >&2; exit 1; }
    done
done

for mode in off on; do
    python -u -m stgtrain.train "$probe_dir/$mode.toml" "graphs-$mode" \
        --runs-dir "$probe_dir" --total-updates 20 --no-pack \
        2>&1 | tee "$probe_dir/$mode.console.log"
done

export MAGNUS_PROBE_DIR="$probe_dir"
python - <<'PY'
import json
import os
from pathlib import Path
from statistics import median

root = Path(os.environ["MAGNUS_PROBE_DIR"])
out = {}
for mode in ("off", "on"):
    (run,) = root.glob(f"*-graphs-{mode}")
    rows = [json.loads(line) for line in (run / "metrics.jsonl").read_text().splitlines() if line]
    steady = [r["perf/sps"] for r in rows if 5 <= r.get("update", 0) <= 19 and "perf/sps" in r]
    phases = [json.loads(line) for line in (run / "perf.jsonl").read_text().splitlines() if line]
    phases = [r for r in phases if r.get("kind") == "phase"]
    keys = sorted({k for r in phases for k in r if k.endswith("_s")})
    out[mode] = {"steady_median_sps": median(steady), "steady_rows": len(steady),
                 "phase_samples": len(phases),
                 "phase_median_s": {k: median(r[k] for r in phases if k in r) for k in keys}}
out["speedup"] = out["on"]["steady_median_sps"] / out["off"]["steady_median_sps"]
(root / "summary.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(out, ensure_ascii=False, indent=2), flush=True)
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
print("rollout 图 A/B 结果包已上传；secret 见 Job Result", flush=True)
PY
