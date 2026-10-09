"""Batch1 CPU benchmark of a deployment graph on fixed real-observation inputs.

This measures ONNX work per simulated game frame. It does not include the C
extractor/fill/motor/hook or claim Windows gameplay performance.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import platform
import sys
import time
import zipfile

import numpy as np

from request_execution import sha, save_json


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--feeds", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--runtime-wheel", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--intervals", type=int, nargs="+", choices=(1,2,3,4,6), default=[1,2])
    a = ap.parse_args()
    assert 1 in a.intervals and len(set(a.intervals)) == len(a.intervals)
    receipt = json.loads((a.runtime_wheel.parent / "SOURCE.json").read_text())
    assert sha(a.runtime_wheel) == receipt["sha256"]
    target = a.out.parent / "ort122-package"
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(a.runtime_wheel) as archive:
        for name in archive.namelist():
            if name.startswith("onnxruntime/"):
                assert ".." not in Path(name).parts
                archive.extract(name, target)
    sys.path.insert(0, str(target.resolve()))
    import onnxruntime as ort
    assert ort.__version__ == "1.22.0"
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = opts.inter_op_num_threads = 1
    opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    session = ort.InferenceSession(str(a.model), opts, providers=["CPUExecutionProvider"])
    with np.load(a.feeds) as archive:
        arrays = {k: archive[k] for k in archive.files}
    assert set(arrays) == {i.name for i in session.get_inputs()}
    count = len(next(iter(arrays.values())))
    feeds = [{k: np.ascontiguousarray(v[i]) for k,v in arrays.items()} for i in range(count)]
    assert count >= 8
    for feed in feeds:
        output = session.run(None, feed)[0]
        assert output.shape == (18,) and np.isfinite(output).all()
    # Alternate pair order to reduce drift; every arm observes identical frame inputs.
    frames = count * math.lcm(12, *a.intervals)
    shifts = math.lcm(*(math.gcd(count, i) for i in a.intervals))
    rounds = 2 * math.lcm(len(a.intervals), shifts)
    results = {i: [] for i in a.intervals}
    for round_id in range(rounds):
        # Balance both input parities: capture order interleaves card/rank groups.
        # Both arms see the same shifted frame stream within each paired round.
        feed_shift = round_id % shifts  # balances the input residue classes each stride visits
        order = a.intervals[round_id % len(a.intervals):] + a.intervals[:round_id % len(a.intervals)]
        if (round_id // len(a.intervals)) % 2:
            order = order[::-1]
        for position, interval in enumerate(order):
            start = time.perf_counter()
            calls = 0
            for step in range(frames):
                if step % interval == 0:
                    session.run(None, feeds[(step + feed_shift) % count])
                    calls += 1
            wall = time.perf_counter() - start
            results[interval].append({"frames": frames, "calls": calls, "wall_s": wall, "feed_shift": feed_shift,
                                      "round": round_id, "position": position,
                                      "ms_per_game_frame": wall / frames * 1000,
                                      "ms_per_call": wall / calls * 1000})
    summary = {}
    for interval, samples in results.items():
        summary[str(interval)] = {"samples": samples,
            "median_ms_per_game_frame": float(np.median([s["ms_per_game_frame"] for s in samples])),
            "median_ms_per_call": float(np.median([s["ms_per_call"] for s in samples]))}
    summary["onnx_work_reduction_fraction"] = {str(i): 1 - summary[str(i)]["median_ms_per_game_frame"] / summary["1"]["median_ms_per_game_frame"] for i in a.intervals}
    result = {"scope": __doc__, "runtime": ort.__version__, "provider": session.get_providers(),
              "threads": 1, "platform": platform.platform(), "machine": platform.machine(),
              "model_sha256": sha(a.model), "feeds_sha256": sha(a.feeds), "feed_count": count,
              "rounds": rounds, "input_shifts": shifts, "intervals": a.intervals,
              "runtime_receipt": receipt, "script_sha256": sha(__file__), "benchmark": summary}
    save_json(a.out, result)
    print(json.dumps(summary["onnx_work_reduction_fraction"], indent=2))
    print("median ms/game-frame:", {str(i): summary[str(i)]["median_ms_per_game_frame"] for i in a.intervals})


if __name__ == "__main__":
    main()
