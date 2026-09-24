#!/usr/bin/env bash
# Run one Magnus training job; all positional options are passed to stgtrain.train.
# The run directory is packed and uploaded on exit even if training fails or the Job is
# terminated, so checkpoints written so far are never lost with the workspace.
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
    magnus_pack_upload "$out_dir" || echo '结果包上传失败' >&2
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到 SIGTERM，停止训练并打包已有结果" >&2; exit 0' TERM INT

(
    set -o pipefail
    python -u -m stgtrain.train "$@" --runs-dir "$out_dir" --no-pack 2>&1 | tee "$out_dir/console.log"
) &
MAGNUS_PIDS=("$!")
wait "${MAGNUS_PIDS[0]}"
