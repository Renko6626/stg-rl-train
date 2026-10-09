"""P2 u1000/u1500阶段诊断与固定u2000最终评测，保存首局配对记录。"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


def sha(path: Path) -> str:
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--device", choices=("cuda", "cpu"), default="cuda")
    ap.add_argument("--update", type=int, choices=(1000, 1500, 2000), default=2000)
    a = ap.parse_args()
    checkpoint = a.run_dir / "checkpoints" / f"u{a.update}.pt"
    if not checkpoint.is_file():
        raise FileNotFoundError(checkpoint)
    final = a.update == 2000
    out = a.run_dir / "final-eval" if final else a.run_dir / "stage-eval" / f"u{a.update}"
    out.mkdir(parents=True, exist_ok=True)
    inputs = [checkpoint, Path("eval/splits-laser.toml"), Path("eval/splits-laser-specialist.toml")]
    manifest = {"update": a.update, "role": "final" if final else "stage",
                "files": {str(p): sha(p) for p in inputs}, "commands": [], "episodes": 0}
    ids = set()
    seeds = (12345, 23456, 34567) if final else (12345,)
    work = [
            ("original", "follow", inputs[1]), ("original", "free", inputs[1]),
            ("specialist", "free", inputs[2]),
    ] if final else [("original", "free", inputs[1]), ("specialist", "free", inputs[2])]
    for seed in seeds:
        for pool, intent, splits in work:
            label = f"{pool}-{intent}-seed{seed}"
            destination = out / f"{label}.json"
            cmd = [sys.executable, "-m", "stgtrain.eval_ckpt", str(checkpoint), "--device", a.device,
                   "--splits", str(splits), "--ranks", "2,3", "--episodes", "32", "--records",
                   "--eval-seed", str(seed), "--intent",
                   "follow_player_v1" if intent == "free" else "lower_half_uniform_v1",
                   "--out", str(destination)]
            manifest["commands"].append(cmd)
            (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
            with (out / f"{label}.log").open("w") as log:
                subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True)
            result = json.loads(destination.read_text())
            rows = result["records"]
            expected = 832 if pool == "original" else 320
            if len(rows) != expected:
                raise ValueError(f"{label}需要{expected}局，实际{len(rows)}")
            for r in rows:
                key = (pool, intent, seed, r["card"], r["rank"], r["env"])
                if key in ids or r["eval_seed"] != seed or r["rank"] not in (2, 3):
                    raise ValueError(f"逐局身份不一致：{key}")
                ids.add(key)
                r.update(pool=pool, intent=intent, train_seed=result["checkpoint"]["train_seed"],
                         arm="cnn" if result["checkpoint"]["density_enabled"] else "none",
                         update=result["checkpoint"]["update"], motor=dict(result["checkpoint"]["motor"]))
            if result["checkpoint"]["update"] != a.update or not result["checkpoint"]["motor"]["enabled"]:
                raise ValueError(f"需要固定u{a.update}与开启运动层")
            if abs(sum(r["done"] == 2 for r in rows) / expected - result["overall"]["survival"]) > 1e-12:
                raise ValueError("逐局存活与汇总不符")
            destination.write_text(json.dumps(result, ensure_ascii=False, indent=2))
            manifest["episodes"] += len(rows)
            print(f"{label}: {len(rows)}局，撑过率{result['overall']['survival']:.4%}", flush=True)
    expected_total = 5952 if final else 1152
    if manifest["episodes"] != expected_total or any(sha(Path(p)) != digest for p, digest in manifest["files"].items()):
        raise ValueError("评测数量或来源文件发生变化")
    manifest["completed"] = True
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
