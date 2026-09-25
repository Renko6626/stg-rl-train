#!/usr/bin/env bash
# Run one Magnus training job; all positional options are passed to stgtrain.train.
# The run directory is packed and uploaded on exit even if training fails or the Job is
# terminated, so checkpoints written so far are never lost with the workspace.
#
# After a successful run, the routine probes run on this Job's GPU against checkpoints/best.pt
# (640 episodes each, about 1.5 min on an A100) and land in <run>/probe/ inside the bundle.
# PROBES overrides the list ("name|eval_ckpt flags;…"); PROBES= (empty) skips them.
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
MAGNUS_PIDS=()

DEFAULT_PROBES="boss_or_free16|--intent boss_or_free_v1;free|--intent follow_player_v1;anchor|--intent fixed_point_v1;motor_off|--motor off"
run_dir=$(ls -d "$out_dir"/*/ 2>/dev/null | head -n 1)
if [[ -n "${PROBES-$DEFAULT_PROBES}" && -n "$run_dir" && -f "$run_dir/checkpoints/best.pt" ]]; then
    mkdir -p "$run_dir/probe"
    IFS=';' read -ra probes <<<"${PROBES-$DEFAULT_PROBES}"
    for probe in "${probes[@]}"; do
        name=${probe%%|*}
        read -ra flags <<<"${probe#*|}"
        echo "探针 $name：${flags[*]}"
        python -u -m stgtrain.eval_ckpt "$run_dir/checkpoints/best.pt" --device "${PROBE_DEVICE:-cuda}" "${flags[@]}" \
            --out "$run_dir/probe/$name.json" > "$run_dir/probe/$name.log" 2>&1 \
            && grep -m1 "撑过" "$run_dir/probe/$name.log" || echo "探针 $name 失败（见 probe/$name.log），不影响训练结果"
    done
fi
