#!/usr/bin/env bash
# P2: strict GPU gate, density-only initialization, fixed final paired evaluation.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"
source "$(dirname "$0")/lib.sh"
out_dir="runs/job-${MAGNUS_JOB_ID:-local}"
mkdir -p "$out_dir"
MAGNUS_PIDS=()
on_exit() {
    local rc=$?
    set +e
    trap - EXIT TERM INT
    magnus_stop_runs
    local upload_rc=0
    magnus_pack_upload "$out_dir" || upload_rc=$?
    if (( upload_rc != 0 )); then
        echo '结果包上传失败' >&2
        (( rc != 0 )) || rc=$upload_rc
    fi
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到终止信号，打包已有结果" >&2; exit 0' TERM INT
python - "$1" "$out_dir/gpucheck.toml" <<'PY'
import sys
from stgtrain.config import dump_toml, load_config
dump_toml(load_config(sys.argv[1], {"ppo": {"amp": "off"}}), sys.argv[2])
PY
python -u -m stgtrain.gpucheck "$out_dir/gpucheck.toml" 2>&1 | tee "$out_dir/gpucheck.log"
(
    set -o pipefail
    python -u -m stgtrain.train "$@" --runs-dir "$out_dir" --no-pack 2>&1 | tee "$out_dir/console.log"
) &
MAGNUS_PIDS=("$!")
wait "${MAGNUS_PIDS[0]}"
MAGNUS_PIDS=()
mapfile -t run_dirs < <(find "$out_dir" -mindepth 1 -maxdepth 1 -type d)
[[ ${#run_dirs[@]} == 1 ]] || { echo '需要唯一训练目录' >&2; exit 1; }
for update in 1000 1500 2000; do
    python -u tools/eval_density_checkpoints.py "${run_dirs[0]}" --device cuda --update "$update" \
        2>&1 | tee "$out_dir/eval-u$update.log"
done
