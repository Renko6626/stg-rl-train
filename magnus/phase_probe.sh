#!/usr/bin/env bash
# Per-phase timing on the cached A100 image; positional args = env thread counts to run in turn (default 28).
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

probe_dir="runs/a100-phase-probe-${MAGNUS_JOB_ID:-local}"
mkdir -p "$probe_dir"
# 位置参数 = 依次要测的 env 线程数（默认只测 28）；同一 Job 内比较，避开跨 Job 的节点波动
thread_counts=("${@:-28}")
for t in "${thread_counts[@]}"; do
    sed -E -e "s/^threads = 0[[:space:]].*\$/threads = $t/" \
           -e 's/^perf_sync_every = 20$/perf_sync_every = 5/' \
           configs/base.toml > "$probe_dir/config-$t.toml"
    # sed 没匹配上不会报错；配置写法一变，数据就会贴错标签，所以逐项确认
    for want in "^threads = $t\$" '^perf_sync_every = 5$'; do
        grep -Eq "$want" "$probe_dir/config-$t.toml" || { echo "配置替换失败：$want" >&2; exit 1; }
    done
    python -u -m stgtrain.train "$probe_dir/config-$t.toml" "phase-$t" \
        --runs-dir "$probe_dir" --total-updates 20 --no-pack \
        2>&1 | tee "$probe_dir/console-$t.log"
done

export MAGNUS_PHASE_PROBE_DIR="$probe_dir"
python - <<'PY'
import json
import os
from pathlib import Path
from statistics import median

root = Path(os.environ["MAGNUS_PHASE_PROBE_DIR"])
summary = {}
for run in sorted(root.glob("*-phase-*")):
    if not run.is_dir():
        continue
    rows = [json.loads(line) for line in (run / "perf.jsonl").read_text().splitlines() if line]
    phases = [row for row in rows if row.get("kind") == "phase"]
    keys = sorted({key for row in phases for key in row if key.endswith("_s")})
    counts = sorted({key for row in phases for key in row if key.endswith(("_mean", "_max"))})
    metrics = [json.loads(line) for line in (run / "metrics.jsonl").read_text().splitlines() if line]
    steady = [r["perf/sps"] for r in metrics if 5 <= r.get("update", 0) <= 19 and "perf/sps" in r]
    summary[run.name.split("-phase-")[-1] + "_threads"] = {
        "steady_median_sps": median(steady), "steady_rows": len(steady),
        "phase_samples": len(phases), "sampled_updates": [row["update"] for row in phases],
        "median_seconds": {key: median(row[key] for row in phases if key in row) for key in keys},
        # 每步计数（弹行数、敌人数上限等）：先在一次更新的 64 步里取均值 / 最大，再对各采样更新取中位数
        "median_counts": {key: median(row[key] for row in phases if key in row) for key in counts},
    }
if not summary:
    raise SystemExit("no phase runs found")
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
