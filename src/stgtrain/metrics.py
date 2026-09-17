"""标量记录（spec §7.1）：metrics.jsonl 为权威，TensorBoard 为同名镜像。"""
from __future__ import annotations

import json
import math
import os
import time
from pathlib import Path


class MetricsLogger:
    def __init__(self, run_dir: Path, tensorboard: bool, purge_step: int | None = None):
        self.run_dir = Path(run_dir)
        self.path = self.run_dir / "metrics.jsonl"
        self._f = open(self.path, "a", encoding="utf-8")
        self._t0 = time.time()
        self.tb = None
        if tensorboard:
            from torch.utils.tensorboard import SummaryWriter

            self.tb = SummaryWriter(str(self.run_dir / "tb"), purge_step=purge_step)

    def log(self, update: int, env_steps: int, scalars: dict[str, float]) -> None:
        row: dict = {"update": int(update), "env_steps": int(env_steps), "wall": round(time.time() - self._t0, 3)}
        for k, v in scalars.items():
            v = float(v)
            row[k] = v if math.isfinite(v) else None
            if self.tb is not None and math.isfinite(v):
                self.tb.add_scalar(k, v, int(env_steps))
        self._f.write(json.dumps(row, ensure_ascii=False) + "\n")
        self._f.flush()

    def close(self) -> None:
        self._f.close()
        if self.tb is not None:
            self.tb.close()


def read_jsonl(path) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def truncate_after(path, update: int) -> int:
    """续训前把 checkpoint 之后的残留行截掉：保留无 "update" 键或 update <= 给定值的行。
    返回被丢弃的行数；文件不存在返回 0。重写走临时文件 + os.replace，保证原子。
    硬杀可能留下半行 JSON：只容忍「最后一个非空行」解析失败并丢弃它，其余坏行照旧抛错。"""
    path = Path(path)
    if not path.exists():
        return 0
    lines = path.read_text(encoding="utf-8").splitlines()
    last = max((i for i, line in enumerate(lines) if line.strip()), default=-1)
    keep: list[dict] = []
    dropped = 0
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            if i == last:
                dropped += 1
                continue
            raise
        if "update" not in row or int(row["update"]) <= int(update):
            keep.append(row)
        else:
            dropped += 1
    if dropped:
        tmp = path.with_name(path.name + ".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            for r in keep:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        os.replace(tmp, path)
    return dropped


def summarize_episodes(records: list[dict], prefix: str = "ep/") -> dict[str, float]:
    if not records:
        return {}
    n = len(records)
    out: dict[str, float] = {f"{prefix}count": float(n)}
    for code in (1, 2, 3):
        out[f"{prefix}done{code}"] = sum(1 for r in records if r["done"] == code) / n
    for key in records[0]:
        if key in ("env", "done"):
            continue
        out[f"{prefix}{key}"] = sum(float(r[key]) for r in records) / n
    for side in ("in_r", "out_r"):  # 点内 / 点外方向变化率：按总时长合并，不对各局比率取平均
        c, s = f"dir_changes_{side}", f"secs_{side}"
        if c in records[0]:
            secs = sum(float(r[s]) for r in records)
            out[f"{prefix}dir_changes_{side}_per_s"] = sum(float(r[c]) for r in records) / secs if secs > 0 else 0.0
    return out
