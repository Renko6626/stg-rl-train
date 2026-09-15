"""标量记录（spec §7.1）：metrics.jsonl 为权威，TensorBoard 为同名镜像。"""
from __future__ import annotations

import json
import math
import time
from pathlib import Path


class MetricsLogger:
    def __init__(self, run_dir: Path, tensorboard: bool):
        self.run_dir = Path(run_dir)
        self.path = self.run_dir / "metrics.jsonl"
        self._f = open(self.path, "a", encoding="utf-8")
        self._t0 = time.time()
        self.tb = None
        if tensorboard:
            from torch.utils.tensorboard import SummaryWriter

            self.tb = SummaryWriter(str(self.run_dir / "tb"))

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
    return out
