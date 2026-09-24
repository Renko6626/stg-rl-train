#!/usr/bin/env bash
# Shared helpers for Magnus entry scripts; source after bootstrap.sh.
#
#   magnus_upload FILE              hand FILE to File Custody, write the secret to $MAGNUS_RESULT
#   magnus_pack_upload DIR          tar DIR next to itself and upload it (used by EXIT traps)
#   magnus_launch_runs DIR T SPEC…  start one trainer per SPEC in the background, T env threads each;
#                                   fills MAGNUS_PIDS / MAGNUS_LABELS
#   magnus_wait_runs                wait for MAGNUS_PIDS; returns the number of failed runs
#
# Extra trainer flags for every run go in the array MAGNUS_TRAIN_ARGS (e.g. --total-updates 20).
#
# SPEC is "config.toml:name[:seed]". Each run gets its own config copy DIR/<name>.toml with
# env.threads (and run.seed) overridden, so the repo stays clean and the copy records what ran.

magnus_upload() {
    python - "$1" <<'PY'
import os
import sys
from pathlib import Path

import magnus

secret = magnus.custody_file(sys.argv[1], expire_minutes=240)
Path(os.environ["MAGNUS_RESULT"]).write_text(secret + "\n", encoding="utf-8")
print(f"结果包已交给 Magnus File Custody（{Path(sys.argv[1]).name}）；secret 见 Job Result", flush=True)
PY
}

magnus_pack_upload() {
    local dir=$1
    local archive="$dir.tar.gz"
    tar -czf "$archive" -C "$(dirname "$dir")" "$(basename "$dir")"
    magnus_upload "$archive"
}

# Env threads per run when K runs share this Job's CPUs: leave two per run for the main
# and torch threads (32 CPUs, K = 2 → 14, the split measured on 2026-09-23).
magnus_threads_for() {
    local k=$1
    local cpus
    cpus=$(python -c 'import os; print(len(os.sched_getaffinity(0)))')
    local t=$(( (cpus - 2 * k) / k ))
    (( t >= 1 )) || t=1
    echo "$t"
}

magnus_launch_runs() {
    local dir=$1 threads=$2
    shift 2
    MAGNUS_PIDS=()
    MAGNUS_LABELS=()
    mkdir -p "$dir"
    local spec cfg name seed names=()
    # Write and validate every config copy first: a typo in the last spec must not start
    # (and then kill) the runs before it.
    for spec in "$@"; do
        IFS=: read -r cfg name seed <<<"$spec"
        test -n "$cfg" && test -n "$name" || { echo "运行规格须为 配置:名字[:种子]，得 $spec" >&2; return 2; }
        python - "$cfg" "$dir/$name.toml" "$threads" "${seed:-}" <<'PY'
import sys

from stgtrain.config import dump_toml, load_config

src, dst, threads, seed = sys.argv[1:]
over = {"env": {"threads": int(threads)}}
if seed:
    over["run"] = {"seed": int(seed)}
dump_toml(load_config(src, over), dst)
PY
        names+=("$name")
    done
    for name in "${names[@]}"; do
        (
            set -o pipefail
            python -u -m stgtrain.train "$dir/$name.toml" "$name" --runs-dir "$dir" --no-pack ${MAGNUS_TRAIN_ARGS[@]+"${MAGNUS_TRAIN_ARGS[@]}"} \
                2>&1 | tee "$dir/$name.console.log" | sed -u "s/^/[$name] /"
        ) &
        MAGNUS_PIDS+=("$!")
        MAGNUS_LABELS+=("$name")
        echo "启动 $name：$(sed -n 's/^seed = //p' "$dir/$name.toml" | head -1 | sed 's/^/seed=/')，threads=$threads，pid $!" >&2
    done
}

magnus_wait_runs() {
    local failed=0 i rc
    for i in "${!MAGNUS_PIDS[@]}"; do
        rc=0
        wait "${MAGNUS_PIDS[$i]}" || rc=$?
        if (( rc != 0 )); then
            echo "${MAGNUS_LABELS[$i]} 以 $rc 退出" >&2
            failed=$(( failed + 1 ))
        fi
    done
    return "$failed"
}

# SIGTERM from Magnus (terminate / time limit): stop the trainers so the EXIT trap can pack
# whatever checkpoints exist. Writing $MAGNUS_RESULT before exiting 0 lets the Job end as Success.
magnus_stop_runs() {
    local pid
    for pid in "${MAGNUS_PIDS[@]:-}"; do
        [[ -n "$pid" ]] || continue
        pkill -TERM -P "$pid" 2>/dev/null || true
        kill -TERM "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
