#!/usr/bin/env bash
# Operator-level profile of one PPO minibatch update (no env): scripts/profile_update.py for each config,
# fp32 and bf16. Results (per-config tables + summary.json) are packed and uploaded even on failure.
#
#   bash magnus/profile_update.sh configs/exp-q2-raw.toml configs/exp-r1a-sa1.toml
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"
source "$(dirname "$0")/lib.sh"

out_dir="runs/a100-update-profile-${MAGNUS_JOB_ID:-local}"
mkdir -p "$out_dir"
MAGNUS_PIDS=()
on_exit() {
    local rc=$?
    set +e
    trap - EXIT TERM INT
    magnus_pack_upload "$out_dir" || echo '结果包上传失败' >&2
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到 SIGTERM，打包已有结果" >&2; exit 0' TERM INT

python -u scripts/profile_update.py "$out_dir" "$@" 2>&1 | tee "$out_dir/console.log"
