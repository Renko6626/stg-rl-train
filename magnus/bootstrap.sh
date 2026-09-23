#!/usr/bin/env bash
# Configure the cached Magnus CUDA 12.4 image for stgtrain.
set -euo pipefail
MAGNUS_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAGNUS_REPO_ROOT=$(cd "$MAGNUS_SCRIPT_DIR/.." && pwd)
cd "$MAGNUS_REPO_ROOT"

python - <<'PY'
import sys
import torch

print(f"Python {sys.version.split()[0]} · torch {torch.__version__} · CUDA {torch.version.cuda}", flush=True)
if sys.version_info[:2] != (3, 11):
    raise SystemExit("Magnus CUDA 12.4 runner currently targets Python 3.11")
if torch.__version__ != "2.5.1+cu124" or not torch.cuda.is_available():
    raise SystemExit("Magnus runner requires torch 2.5.1+cu124 with a visible CUDA device")
print(torch.cuda.get_device_name(0), flush=True)
PY
command -v cc >/dev/null || { echo 'torch.compile needs a C compiler; choose the cached CUDA 12.4 devel image' >&2; exit 1; }

(cd magnus/wheels && sha256sum -c SHA256SUMS)
python -m pip install --no-deps magnus/wheels/*.whl
python -m pip install \
    'tensordict==0.6.2' \
    'matplotlib==3.11.2' \
    'psutil==6.1.0' \
    'nvidia-ml-py==13.610.43' \
    'tensorboard==2.21.0' \
    'magnus-sdk==0.8.2'

python - <<'PY'
import importlib.metadata as meta

for name in ("torch", "tensordict", "numpy", "stg-rl", "stgagent", "magnus-sdk"):
    print(f"{name}=={meta.version(name)}", flush=True)
PY
export PYTHONPATH="$MAGNUS_REPO_ROOT/src${PYTHONPATH:+:$PYTHONPATH}"
