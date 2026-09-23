#!/usr/bin/env bash
# 临时兼容性验证：复用站点缓存的 PyTorch 2.5.1+cu124 镜像。
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"

# 此次只验证兼容性，不使用主仓为 Vast.ai 锁定的 torch 2.14/CUDA 13 环境。
python -m stgtrain.gpucheck configs/base.toml
python -m stgtrain.train configs/base.toml magnus-cu124-smoke --total-updates 2

bundle=$(find runs -maxdepth 1 -name '*magnus-cu124-smoke.tar.gz' -print -quit)
test -n "$bundle"
python - "$bundle" <<'PY'
import os
import sys
from pathlib import Path

import magnus

secret = magnus.custody_file(sys.argv[1], expire_minutes=240)
Path(os.environ["MAGNUS_RESULT"]).write_text(secret + "\n", encoding="utf-8")
print("结果包已交给 Magnus File Custody；secret 见 Job Result", flush=True)
PY
