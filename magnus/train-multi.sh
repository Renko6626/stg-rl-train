#!/usr/bin/env bash
# Run several trainings concurrently on this Job's one GPU, then hand back one bundle.
#
#   bash magnus/train-multi.sh configs/exp-m0-rebase.toml:m0-s1 configs/exp-m0-rebase.toml:m0-s2:2
#
# Each argument is config:name[:seed]. Env threads per run = (affinity CPUs − 2K) / K unless
# THREADS is set. Trainer flags for every run go after "--" (e.g. -- --total-updates 20).
# Whatever happens (success, a failed run, SIGTERM from Magnus) the EXIT trap packs every run
# directory — checkpoints included — into one tar.gz and uploads it.
set -euo pipefail
source "$(dirname "$0")/bootstrap.sh"
source "$(dirname "$0")/lib.sh"

specs=()
MAGNUS_TRAIN_ARGS=()
while [[ $# -gt 0 ]]; do
    if [[ $1 == -- ]]; then shift; MAGNUS_TRAIN_ARGS=("$@"); break; fi
    specs+=("$1"); shift
done
(( ${#specs[@]} > 0 )) || { echo '用法：bash magnus/train-multi.sh 配置:名字[:种子] … [-- 训练器参数]' >&2; exit 2; }

out_dir="runs/multi-${MAGNUS_JOB_ID:-local}"
threads=${THREADS:-$(magnus_threads_for "${#specs[@]}")}
MAGNUS_PIDS=()

on_exit() {
    local rc=$?
    set +e
    trap - EXIT TERM INT
    magnus_stop_runs
    if [[ -d $out_dir ]]; then
        magnus_pack_upload "$out_dir" || echo '结果包上传失败' >&2
    fi
    exit "$rc"
}
trap on_exit EXIT
trap 'echo "收到 SIGTERM，停止训练并打包已有结果" >&2; exit 0' TERM INT

magnus_launch_runs "$out_dir" "$threads" "${specs[@]}"
failed=0
magnus_wait_runs || failed=$?
MAGNUS_PIDS=()
(( failed == 0 )) || { echo "$failed 条训练失败" >&2; exit 1; }
