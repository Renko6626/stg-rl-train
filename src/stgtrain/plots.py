"""出图（spec §7.1）：按键名前缀分组，每组一张 PNG；可对中途拷回的 jsonl 或 tar 包重画、多 run 叠加。

用法：python -m stgtrain.plots <run 目录或 .tar.gz>... [--out DIR]
"""
from __future__ import annotations

import argparse
import io
import json
import math
import tarfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

_AXIS_KEYS = {"update", "env_steps", "wall"}


def group_of(key: str) -> str:
    parts = key.split("/")
    if len(parts) == 1:
        return "misc"
    if parts[0] == "ep" and len(parts) > 2:
        return "ep/term" if parts[1] == "term" else "/".join(parts[:2])
    return parts[0]


def _read_lines(text: str) -> list[dict]:
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def _read_member(path: Path, name: str) -> list[dict]:
    if path.is_dir():
        f = path / name
        return _read_lines(f.read_text(encoding="utf-8")) if f.exists() else []
    with tarfile.open(path, "r:gz") as tf:
        for m in tf.getmembers():
            if m.name.endswith("/" + name) or m.name == name:
                return _read_lines(io.TextIOWrapper(tf.extractfile(m), encoding="utf-8").read())
    return []


def load_run(path) -> list[dict]:
    return _read_member(Path(path), "metrics.jsonl")


def load_perf(path) -> list[dict]:
    p = Path(path)
    rows = _read_member(p.parent, p.name) if p.name == "perf.jsonl" else _read_member(p, "perf.jsonl")
    return [r for r in rows if r.get("kind") == "load"]


def _groups(runs: dict[str, list[dict]]) -> dict[str, list[str]]:
    keys: dict[str, set[str]] = {}
    for rows in runs.values():
        for r in rows:
            for k, v in r.items():
                if k in _AXIS_KEYS or not isinstance(v, (int, float)) or isinstance(v, bool):
                    continue
                if math.isfinite(float(v)):
                    keys.setdefault(group_of(k), set()).add(k)
    return {g: sorted(ks) for g, ks in keys.items()}


def _grid(n: int):
    cols = min(3, n)
    rows = math.ceil(n / cols)
    fig, axes = plt.subplots(rows, cols, figsize=(5 * cols, 3.2 * rows), squeeze=False)
    flat = [ax for row in axes for ax in row]
    for ax in flat[n:]:
        ax.set_visible(False)
    return fig, flat[:n]


def plot_runs(runs: dict[str, list[dict]], out_dir: Path) -> list[Path]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for group, keys in sorted(_groups(runs).items()):
        fig, axes = _grid(len(keys))
        for ax, key in zip(axes, keys):
            for name, rows in runs.items():
                pts = [(r["env_steps"], r[key]) for r in rows if r.get(key) is not None]
                if pts:
                    ax.plot([p[0] for p in pts], [p[1] for p in pts], label=name)
            ax.set_title(key, fontsize=9)
            ax.set_xlabel("env steps", fontsize=8)
            ax.grid(alpha=0.3)
        if len(runs) > 1:
            axes[0].legend(fontsize=7)
        fig.tight_layout()
        p = out_dir / f"{group.replace('/', '_')}.png"
        fig.savefig(p, dpi=110)
        plt.close(fig)
        paths.append(p)
    return paths


def plot_load(rows: list[dict], out_dir: Path) -> Path | None:
    if not rows:
        return None
    keys = sorted({k for r in rows for k, v in r.items()
                   if k not in ("kind", "wall") and isinstance(v, (int, float)) and not isinstance(v, bool)})
    if not keys:
        return None
    fig, axes = _grid(len(keys))
    for ax, key in zip(axes, keys):
        pts = [(r["wall"], r[key]) for r in rows if r.get(key) is not None]
        ax.plot([p[0] for p in pts], [p[1] for p in pts])
        ax.set_title(key, fontsize=9)
        ax.set_xlabel("wall s", fontsize=8)
        ax.grid(alpha=0.3)
    fig.tight_layout()
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    p = out_dir / "load.png"
    fig.savefig(p, dpi=110)
    plt.close(fig)
    return p


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.plots")
    ap.add_argument("runs", nargs="+", help="run 目录或 .tar.gz")
    ap.add_argument("--out", default=None, help="输出目录；缺省 = 第一个 run 目录下的 plots/（tar 包则 ./plots）")
    args = ap.parse_args(argv)
    paths = [Path(r) for r in args.runs]
    runs = {p.name.removesuffix(".tar.gz"): load_run(p) for p in paths}
    out = Path(args.out) if args.out else (paths[0] / "plots" if paths[0].is_dir() else Path("plots"))
    written = plot_runs(runs, out)
    if len(paths) == 1:
        load = plot_load(load_perf(paths[0]), out)
        if load:
            written.append(load)
    for w in written:
        print(w)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
