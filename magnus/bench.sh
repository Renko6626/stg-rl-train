#!/usr/bin/env bash
# Benchmark the cached CUDA 12.4 image, then return bench.json through Magnus.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

config=${1:-configs/base.toml}
name=${2:-a100-bench}
if [[ -r /sys/fs/cgroup/cpu.max ]]; then
    printf 'cgroup cpu.max: '
    cat /sys/fs/cgroup/cpu.max
fi
python -m stgtrain.train "$config" "$name" --bench

bench_path=$(find runs -maxdepth 2 -type f -name bench.json -printf '%T@ %p\n' \
    | sort -nr | head -n 1 | cut -d' ' -f2-)
test -n "$bench_path" && test -f "$bench_path"

python - "$bench_path" <<'PY'
import os
import sys
from pathlib import Path

import magnus

secret = magnus.custody_file(sys.argv[1], expire_minutes=240)
Path(os.environ["MAGNUS_RESULT"]).write_text(secret + "\n", encoding="utf-8")
print("bench.json 已交给 Magnus File Custody；secret 见 Job Result", flush=True)
PY
