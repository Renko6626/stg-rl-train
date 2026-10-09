"""Recompute experiment 1 metrics from saved same-trajectory observations.

Rates are pooled over pre-step Alive frames of first episodes. Short segments
include idle directions; moving-only short segments are also reported. Initial
action selection is not counted as a direction change. Unfinished final runs
are right-censored. These differ deliberately from historical episode averages.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path

import numpy as np

from request_execution import save_json, sha, verify_batch


LASER_CARDS = {"th06_s1_b3", "th06_s4_w16", "th06_s4_b12"}


def events(data):
    active = data["first_episode"].astype(bool) & (data["state"] == 1)
    shape = active.shape
    out = {"active": active}
    for key in ("want", "executed"):
        for name in ("change", "short2", "short3", "backtrack3", "moving_end", "moving_short2", "slow_change"):
            out[f"{key}_{name}"] = np.zeros(shape, dtype=bool)
    for name in ("started", "fulfilled", "changed", "withdrawn", "censored"):
        out[f"request_{name}"] = np.zeros(shape, dtype=bool)
    out["request_latency"] = np.full(shape, np.nan)
    for col in range(shape[1]):
        ix = np.flatnonzero(active[:, col])
        if not len(ix):
            continue
        # Do not silently stitch separate Alive stretches across death/reset.
        assert np.all(np.diff(ix) == 1)
        for key in ("want", "executed"):
            seq = data[key][ix, col]
            directions = seq // 2
            changes = np.flatnonzero(np.diff(directions) != 0) + 1
            durations = np.diff(np.r_[0, changes])
            out[f"{key}_change"][ix[changes], col] = True
            out[f"{key}_short2"][ix[changes[durations <= 2]], col] = True
            out[f"{key}_short3"][ix[changes[durations <= 3]], col] = True
            moving = directions[changes - 1] != 0
            out[f"{key}_moving_end"][ix[changes[moving]], col] = True
            out[f"{key}_moving_short2"][ix[changes[moving & (durations <= 2)]], col] = True
            if len(changes) > 1:
                back = (directions[changes[1:]] == directions[changes[:-1] - 1]) & (durations[1:] <= 3)
                out[f"{key}_backtrack3"][ix[changes[1:][back]], col] = True
            slow = np.flatnonzero(np.diff(seq % 2) != 0) + 1
            out[f"{key}_slow_change"][ix[slow], col] = True
        pending = -1
        start = -1
        for t in ix:
            wanted = int(data["want"][t, col]) // 2
            previous = int(data["prev_exec"][t, col]) // 2
            executed = int(data["executed"][t, col]) // 2
            if pending >= 0:
                if wanted == previous:
                    out["request_withdrawn"][t, col] = True
                    pending = -1
                elif wanted != pending:
                    out["request_changed"][t, col] = True
                    pending = -1
            if pending < 0 and wanted != previous:
                pending, start = wanted, t
                out["request_started"][t, col] = True
            if pending >= 0 and executed == pending:
                out["request_fulfilled"][t, col] = True
                out["request_latency"][t, col] = t - start
                pending = -1
        if pending >= 0:
            out["request_censored"][ix[-1], col] = True
    assert out["request_started"].sum() == sum(out[f"request_{k}"].sum() for k in ("fulfilled", "changed", "withdrawn", "censored"))
    out["override"] = data["want"] != data["executed"]
    out["direction_override"] = data["want"] // 2 != data["executed"] // 2
    out["slow_override"] = data["want"] % 2 != data["executed"] % 2
    return out


def quantiles(values):
    if not values:
        return None
    v = np.concatenate(values)
    if not len(v):
        return None
    return {"n": int(len(v)), "mean": float(v.mean()),
            "p10": float(np.quantile(v, .1)), "p50": float(np.quantile(v, .5)),
            "p90": float(np.quantile(v, .9)), "le_0_1_frac": float((v <= .1).mean())}


class Aggregate:
    def __init__(self):
        self.counts = defaultdict(int)
        self.samples = defaultdict(list)

    def add(self, data, ev, mask):
        mask = mask & ev["active"]
        self.counts["frames"] += int(mask.sum())
        for k, v in ev.items():
            if k not in ("active", "request_latency"):
                self.counts[k] += int((v & mask).sum())
        for name, selector in (("all", mask), ("request_change", mask & ev["want_change"]),
                               ("request_short2", mask & ev["want_short2"]),
                               ("overridden", mask & ev["direction_override"])):
            for field in ("margin", "direction_margin", "keep_advantage"):
                self.samples[f"{field}_{name}"].append(data[field][selector])
        latency = ev["request_latency"][mask & ev["request_fulfilled"]]
        self.samples["latency_frames"].append(latency)

    def result(self):
        c = dict(self.counts)
        def ratio(n, d):
            return n / d if d else None
        seconds = c["frames"] / 60
        result = {"counts": c, "seconds": seconds}
        for key in ("want", "executed"):
            result[key] = {
                "direction_changes_per_s": ratio(c[f"{key}_change"], seconds),
                "short2_frac": ratio(c[f"{key}_short2"], c[f"{key}_change"]),
                "short3_frac": ratio(c[f"{key}_short3"], c[f"{key}_change"]),
                "moving_short2_frac": ratio(c[f"{key}_moving_short2"], c[f"{key}_moving_end"]),
                "backtrack3_per_s": ratio(c[f"{key}_backtrack3"], seconds),
                "slow_changes_per_s": ratio(c[f"{key}_slow_change"], seconds),
            }
        result["override_fraction"] = {k: ratio(c[k], c["frames"]) for k in ("override", "direction_override", "slow_override")}
        result["samples"] = {k: quantiles(v) for k, v in self.samples.items()}
        # Outcomes are attributed at resolution; stratum-specific starts/outcomes can differ.
        return result


def analyze(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    assert manifest["status"] == "complete"
    accum = defaultdict(Aggregate)
    outcome = defaultdict(list)
    sources = []
    for batch in manifest["batches"]:
        stem = batch["stem"]
        for suffix in ("npz", "json"):
            path = directory / f"{stem}.{suffix}"
            assert sha(path) == batch[f"{suffix}_sha256"]
            sources.append({"path": str(path), "sha256": sha(path)})
        records = json.loads((directory / f"{stem}.json").read_text())
        with np.load(directory / f"{stem}.npz") as archive:
            data = {k: archive[k] for k in archive.files}
        n = manifest["episodes_per_group"]
        verify_batch(data, records["records"], n)
        ev = events(data)
        target_distance = np.linalg.norm(data["xy"] - data["target"], axis=-1)
        near = np.minimum(data["bullet_clearance"], data["laser_clearance"]) < 24
        warning = data["warning_clearance"] < 24
        in_target = target_distance < manifest["config"]["reward"]["hold_radius"]
        strata = {"all": np.ones_like(near), "near": near, "far": ~near,
                  "far_no_near_warning": ~near & ~warning,
                  "near_warning": warning, "in_target": in_target, "out_target": ~in_target,
                  "near_out_target": near & ~in_target, "far_in_target": ~near & in_target,
                  "hold_locked": data["held"] < data["motor_need"],
                  "hold_ready": data["held"] >= data["motor_need"]}
        memberships = defaultdict(list)
        for gi, (card, rank) in enumerate(records["groups"]):
            cols = list(range(gi * n, (gi + 1) * n))
            for label in ("all", "lasers" if card in LASER_CARDS else "ordinary", f"r{rank}", card, f"{card}:r{rank}"):
                memberships[label].extend(cols)
                outcome[label].extend(records["records"][gi])
        for label, cols in memberships.items():
            selected = np.zeros(ev["active"].shape[1], dtype=bool)
            selected[cols] = True
            for stratum, mask in strata.items():
                # Detailed context cuts for pooled card classes, per-card reports stay compact.
                if label not in ("all", "ordinary", "lasers") and stratum != "all":
                    continue
                accum[f"{label}/{stratum}"].add(data, ev, mask & selected[None, :])
    result = {key: a.result() for key, a in accum.items()}
    for label, rows in outcome.items():
        result[f"{label}/all"]["episodes"] = {
            "count": len(rows), "survived": sum(r["done"] == 2 for r in rows),
            "died": sum(r["done"] == 1 for r in rows), "timeout": sum(r["done"] == 3 for r in rows),
        }
    for label in outcome:
        c = result[f"{label}/all"]["counts"]
        assert c["request_started"] == sum(c[f"request_{k}"] for k in ("fulfilled", "changed", "withdrawn", "censored"))
    return {"mode": manifest["mode"], "manifest": str(directory / "manifest.json"),
            "manifest_sha256": sha(directory / "manifest.json"), "checkpoint_sha256": manifest["checkpoint_sha256"],
            "sources": sources, "groups": result}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directories", type=Path, nargs="+")
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    result = {"method": __doc__, "analysis_sha256": sha(__file__), "modes": {}}
    for directory in a.directories:
        value = analyze(directory)
        assert value["mode"] not in result["modes"]
        result["modes"][value["mode"]] = value
        print(value["mode"], json.dumps(value["groups"]["all/all"], ensure_ascii=False), flush=True)
    save_json(a.out, result)


if __name__ == "__main__":
    main()
