#!/usr/bin/env bash
# 临时兼容性验证：复用站点缓存的 PyTorch 2.5.1+cu124 镜像。
set -euo pipefail
cd "$(dirname "$0")/.."

python - <<'PY'
import torch

print(f"Python/PyTorch: {torch.__version__}, CUDA: {torch.version.cuda}", flush=True)
if torch.__version__ != "2.5.1+cu124" or not torch.cuda.is_available():
    raise SystemExit("需要已验证的 PyTorch 2.5.1+cu124 GPU 镜像")
print(torch.cuda.get_device_name(0), flush=True)
PY
command -v cc >/dev/null || { echo 'torch.compile 需要 C 编译器；请用 CUDA 12.4 devel 镜像' >&2; exit 1; }

# 两个项目自有的小 wheel 固定在仓库里，避免 Job 容器直连 GitHub 的超时。
(cd magnus/wheels && sha256sum -c SHA256SUMS)
python -m pip install --no-deps magnus/wheels/*.whl
python -m pip install 'tensordict==0.6.2' 'matplotlib==3.11.2' 'psutil==6.1.0' \
    'nvidia-ml-py==13.610.43' 'tensorboard==2.21.0' 'magnus-sdk==0.8.2'
python - <<'PY'
import importlib.metadata as meta
for name in ("torch", "tensordict", "numpy", "stg-rl", "stgagent", "magnus-sdk"):
    print(f"{name}=={meta.version(name)}", flush=True)
PY

# 此次只验证兼容性，不使用主仓为 Vast.ai 锁定的 torch 2.14/CUDA 13 环境。
export PYTHONPATH="$PWD/src"
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
