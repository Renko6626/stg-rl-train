"""Verify and compare inference-interval screening arms, including archived controls."""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path

import numpy as np

from stgtrain.evaluate import summarize_eval
from inference_interval import verify_schedule
from request_execution import sha, save_json, verify_batch
from summarize_request_execution import events, LASER_CARDS


def read_arm(root):
    path = root / "manifest.json"
    manifest = json.loads(path.read_text())
    assert manifest["status"] == "complete"
    groups, controls, source_files, layout = {}, defaultdict(int), [], []
    timings = defaultdict(float)
    for batch in manifest["batches"]:
        stem = batch["stem"]
        for suffix in ("npz", "json"):
            path = root / f"{stem}.{suffix}"
            assert sha(path) == batch[f"{suffix}_sha256"]
            source_files.append({"path": str(path), "sha256": sha(path)})
        d = json.loads((root / f"{stem}.json").read_text())
        layout.append(d["groups"])
        with np.load(root / f"{stem}.npz") as archive:
            arrays = {k: archive[k] for k in archive.files}
        verify_batch(arrays, d["records"], manifest["episodes_per_group"])
        verify_schedule(arrays, manifest["interval"])
        ev = events(arrays)
        for key, value in d["control_counts"].items():
            expected = int(ev["active"].sum()) if key == "alive_frames" else int((ev[key] & ev["active"]).sum())
            assert value == expected
            controls[key] += value
        for key, value in d["timing"].items():
            timings[key] += value
        for (card, rank), rows in zip(d["groups"], d["records"]):
            assert (card, rank) not in groups
            assert len(rows) == manifest["episodes_per_group"]
            assert [r["env"] for r in rows] == list(range(len(rows)))
            groups[(card, rank)] = rows
    rates = {}
    seconds = controls["alive_frames"] / 60
    for stream in ("want", "executed"):
        n = controls[f"{stream}_change"]
        moving = controls[f"{stream}_moving_end"]
        rates[stream] = {"direction_changes_per_s": controls[f"{stream}_change"] / seconds,
                         "short2_frac": controls[f"{stream}_short2"] / n if n else None,
                         "moving_short2_frac": controls[f"{stream}_moving_short2"] / moving if moving else None,
                         "backtrack3_per_s": controls[f"{stream}_backtrack3"] / seconds}
    rates["direction_override_frac"] = controls["direction_override"] / controls["alive_frames"]
    rates["inference_fraction_first_episodes"] = timings["first_episode_inferred_rows"] / timings["first_episode_rows"]
    cohorts = {
        "all": [r for rows in groups.values() for r in rows],
        "ordinary": [r for (c, _), rows in groups.items() if c not in LASER_CARDS for r in rows],
        "lasers": [r for (c, _), rows in groups.items() if c in LASER_CARDS for r in rows],
    }
    for rank in (2, 3):
        cohorts[f"r{rank}"] = [r for (_, rk), rows in groups.items() if rk == rank for r in rows]
    summaries = {}
    for label, rows in cohorts.items():
        summaries[label] = summarize_eval(rows)
        summaries[label]["survived"] = sum(r["done"] == 2 for r in rows)
    cards = {f"{card}:r{rank}": summarize_eval(rows) for (card,rank),rows in groups.items()}
    return manifest, groups, {"summaries": summaries, "cards": cards, "control_counts": dict(controls),
                             "control_rates": rates, "timing": dict(timings), "wall_seconds": manifest["wall_seconds"],
                             "manifest": str(root / "manifest.json"), "manifest_sha256": sha(root / "manifest.json"),
                             "source_files": source_files, "batch_layout": layout}


def compare(one, two):
    assert set(one) == set(two)
    totals = {label: defaultdict(int) for label in ("all", "ordinary", "lasers")}
    card_pairs = {}
    for (card, rank), first in one.items():
        second = two[(card, rank)]
        assert len(first) == len(second)
        c = defaultdict(int)
        for a, b in zip(first, second):
            assert a["env"] == b["env"] and a["start"] == b["start"]
            assert a["done"] != 3 and b["done"] != 3
            good_a, good_b = a["done"] == 2, b["done"] == 2
            key = "both_survived" if good_a and good_b else "both_died" if not good_a and not good_b else "lost" if good_a else "gained"
            c[key] += 1
            c["episodes"] += 1
        label = "lasers" if card in LASER_CARDS else "ordinary"
        for target in (totals["all"], totals[label]):
            for key, value in c.items():
                target[key] += value
        c["survival_delta_pp"] = (c["gained"] - c["lost"]) / c["episodes"] * 100
        card_pairs[f"{card}:r{rank}"] = dict(c)
    for c in totals.values():
        c["survival_delta_pp"] = (c["gained"] - c["lost"]) / c["episodes"] * 100
    return {"cohorts": {k: dict(v) for k,v in totals.items()}, "cards": card_pairs}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--intervals", type=int, nargs="+", choices=(1,2,3,4,6), default=[1,2])
    ap.add_argument("--benchmark", type=Path)
    a = ap.parse_args()
    assert a.intervals == sorted(set(a.intervals)) and a.intervals[0] == 1
    report = {"scope": "T8 u3500, motor-on, frame_skip1; screening 16eps/card/rank, one eval seed; raw request cached between inference steps.",
              "script_sha256": sha(__file__), "intervals": a.intervals, "arms": {}, "comparisons": {}}
    collector = Path(__file__).with_name("inference_interval.py")
    current_sha = sha(collector)
    allowed_collectors = {current_sha}
    current_lines = collector.read_text().splitlines()
    current_arg = next(line for line in current_lines if 'ap.add_argument("--interval",' in line)
    report["collector_revisions"] = []
    for archive in sorted(a.root.glob("collector-before-i*.py")):
        # Reuse historical controls only after proving that scheduling code is unchanged.
        old = archive.read_text()
        old_lines = old.splitlines()
        old_arg = next(line for line in old_lines if 'ap.add_argument("--interval",' in line)
        assert old.count(old_arg) == 1
        expected = old.replace(old_lines[0], current_lines[0], 1).replace(old_arg, current_arg, 1)
        assert expected == collector.read_text()
        allowed_collectors.add(sha(archive))
        report["collector_revisions"].append({"archive": str(archive), "archive_sha256": sha(archive),
                                        "current_sha256": current_sha, "change": "docstring and CLI choices only; scheduler unchanged"})
    for mode in ("deploy", "free"):
        loaded = {i: read_arm(a.root / f"{mode}-i{i}") for i in a.intervals}
        m1, rows1, result1 = loaded[1]
        for interval,(m,rows,result) in loaded.items():
            assert m["mode"] == mode and m["interval"] == interval and m["episodes_per_group"] == 16
            assert result["batch_layout"] == result1["batch_layout"] and m["config"] == m1["config"]
            assert m["script_sha256"] in allowed_collectors
            for key in ("checkpoint_sha256", "split_sha256", "engine", "torch", "card_source_sha256", "production_source_sha256", "diagnostic_helpers_sha256"):
                assert m1[key] == m[key], key
            assert len(rows) == 26 and len({c for c,r in rows}) == 13 and {r for c,r in rows} == {2,3}
            assert result["summaries"]["all"]["episodes"] == 416
            report["arms"][f"{mode}-i{interval}"] = result
        for reference in a.intervals:
            for candidate in a.intervals:
                if candidate <= reference:
                    continue
                key = mode if (reference,candidate)==(1,2) else f"{mode}:i{reference}-i{candidate}"
                report["comparisons"][key] = compare(loaded[reference][1], loaded[candidate][1])
                print(key, report["comparisons"][key]["cohorts"], flush=True)
    bench = a.benchmark or a.root / "onnx-benchmark.json"
    report["onnx_benchmark"] = json.loads(bench.read_text())
    report["onnx_benchmark_sha256"] = sha(bench)
    capture = a.root / "preflight-i1"
    benchmark = report["onnx_benchmark"]
    assert all(str(i) in benchmark["benchmark"] for i in a.intervals)
    deploy = Path("dist/t8-laser-k4-best.manifest.json")
    deploy_meta = json.loads(deploy.read_text())
    assert benchmark["feeds_sha256"] == sha(capture / "feeds.npz")
    assert benchmark["model_sha256"] == deploy_meta["sha256"]["onnx"] == sha(deploy.parent / deploy_meta["onnx"])
    assert m1["checkpoint_sha256"] == deploy_meta["sha256"]["checkpoint"]
    report["deployment_manifest_sha256"] = sha(deploy)
    report["benchmark_sources"] = {str(p): sha(p) for p in (capture / "feeds.npz", capture / "feeds-meta.json", capture / "manifest.json")}
    report["diagnostic_source_sha256"] = {str(p): sha(p) for p in sorted(Path(__file__).parent.glob("*interval*.py"))}
    save_json(a.out, report)


if __name__ == "__main__":
    main()
