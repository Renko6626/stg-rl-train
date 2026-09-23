#!/usr/bin/env bash
# Run one Magnus training job; all positional options are passed to stgtrain.train.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

job_log=$(mktemp)
trap 'rm -f "$job_log"' EXIT
python -m stgtrain.train "$@" | tee "$job_log"

bundle_line=$(sed -n 's/^结果包：//p' "$job_log" | tail -n 1)
bundle=${bundle_line%% *}
test -n "$bundle" && test -f "$bundle" || {
    echo '训练结束，但未找到训练结果包行；检查是否传入了 --no-pack' >&2
    exit 1
}

python - "$bundle" <<'PY'
import os
import sys
from pathlib import Path

import magnus

secret = magnus.custody_file(sys.argv[1], expire_minutes=240)
Path(os.environ["MAGNUS_RESULT"]).write_text(secret + "\n", encoding="utf-8")
print("训练结果包已交给 Magnus File Custody；secret 见 Job Result", flush=True)
PY
