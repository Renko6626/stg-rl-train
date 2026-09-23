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

# 两个项目自有的小 wheel 固定在仓库里，避免 Job 容器直连 GitHub 的超时。
python -m pip install --no-deps magnus/wheels/*.whl
python -m pip install 'tensordict==0.6.2' matplotlib psutil nvidia-ml-py tensorboard 'magnus-sdk==0.8.2'
python -m pip check
python -m pip freeze

# 此次只验证兼容性，不使用主仓为 Vast.ai 锁定的 torch 2.14/CUDA 13 环境。
export PYTHONPATH="$PWD/src"
python -m stgtrain.gpucheck configs/base.toml
python -m stgtrain.train configs/base.toml magnus-cu124-smoke --total-updates 2

bundle=$(find runs -maxdepth 1 -name '*magnus-cu124-smoke.tar.gz' -print -quit)
test -n "$bundle"
magnus custody "$bundle" --expire-minutes 240 | tee "$MAGNUS_RESULT"
