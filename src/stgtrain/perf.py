"""开销记录（spec §7.2）：分阶段计时（只在采样迭代上 synchronize）、后台负载采样、机器画像、汇总。"""
from __future__ import annotations

import contextlib
import json
import os
import platform
import threading
import time
from pathlib import Path

import psutil
import torch

PHASES = ("env_step", "h2d", "featurize", "policy", "reward", "update")


def maybe_phase(timer, name: str):
    return timer.phase(name) if timer is not None else contextlib.nullcontext()


class PerfWriter:
    def __init__(self, path: Path):
        self.path = Path(path)
        self._lock = threading.Lock()
        self._f = open(self.path, "a", encoding="utf-8")

    def write(self, row: dict) -> None:
        with self._lock:
            self._f.write(json.dumps(row, ensure_ascii=False) + "\n")
            self._f.flush()

    def close(self) -> None:
        with self._lock:
            self._f.close()


class PhaseTimer:
    def __init__(self, sync_every: int, device: torch.device):
        self.sync_every = max(1, int(sync_every))
        self.cuda = device.type == "cuda"
        self._sync = False
        self._acc: dict[str, float] = {}
        self._t0 = 0.0

    def _synchronize(self) -> None:
        if self.cuda:
            torch.cuda.synchronize()

    def start_iteration(self, iteration: int) -> None:
        self._sync = iteration % self.sync_every == 0
        self._acc = {}
        if self._sync:
            self._synchronize()
        self._t0 = time.perf_counter()

    @contextlib.contextmanager
    def phase(self, name: str):
        if not self._sync:
            yield
            return
        self._synchronize()
        t = time.perf_counter()
        try:
            yield
        finally:
            self._synchronize()
            self._acc[name] = self._acc.get(name, 0.0) + time.perf_counter() - t

    def pop_iteration(self) -> dict[str, float] | None:
        if not self._sync:
            return None
        self._synchronize()
        row = {f"{k}_s": v for k, v in self._acc.items()}
        row["total_s"] = time.perf_counter() - self._t0
        self._sync = False
        return row


def _nvml_handles() -> list:
    try:
        import pynvml

        pynvml.nvmlInit()
        return [pynvml.nvmlDeviceGetHandleByIndex(i) for i in range(pynvml.nvmlDeviceGetCount())]
    except Exception:
        return []


class LoadSampler:
    def __init__(self, writer: PerfWriter, hz: float):
        self.writer = writer
        self.period = 1.0 / max(float(hz), 1e-3)
        # 长跑内存有界：只留 running sums / counts，不保留每一行样本
        self._sums: dict[str, float] = {}
        self._counts: dict[str, int] = {}
        self.n_samples = 0
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True, name="perf-sampler")
        self._proc = psutil.Process()
        self._nvml = _nvml_handles()
        self._t0 = time.time()

    def start(self) -> None:
        psutil.cpu_percent(percpu=True)  # 首次调用只建立基准
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._thread.join(timeout=5)

    def sample(self) -> dict:
        per = psutil.cpu_percent(percpu=True)
        row = {
            "kind": "load", "wall": round(time.time() - self._t0, 3),
            "cpu_percent": sum(per) / len(per), "cpu_max_core": max(per), "cpu_per_core": per,
            "rss_mb": self._proc.memory_info().rss / 2**20, "sys_mem_percent": psutil.virtual_memory().percent,
        }
        if self._nvml:
            import pynvml

            for i, h in enumerate(self._nvml):
                row[f"gpu{i}_util"] = pynvml.nvmlDeviceGetUtilizationRates(h).gpu
                row[f"gpu{i}_mem_mb"] = pynvml.nvmlDeviceGetMemoryInfo(h).used / 2**20
                with contextlib.suppress(Exception):
                    row[f"gpu{i}_power_w"] = pynvml.nvmlDeviceGetPowerUsage(h) / 1000.0
        if torch.cuda.is_available():
            row["torch_max_alloc_mb"] = torch.cuda.max_memory_allocated() / 2**20
        return row

    def add(self, row: dict) -> None:
        """把一行数值流式并入 running sums：排除 kind/wall、布尔与列表（如 cpu_per_core），
        只累加数值键；n_samples 记录采样行数。"""
        for k, v in row.items():
            if k in ("kind", "wall") or isinstance(v, bool) or not isinstance(v, (int, float)):
                continue
            self._sums[k] = self._sums.get(k, 0.0) + float(v)
            self._counts[k] = self._counts.get(k, 0) + 1
        self.n_samples += 1

    def _run(self) -> None:
        while not self._stop.wait(self.period):
            row = self.sample()
            self.add(row)
            # stop() 超时后 close() 会关文件，此时再写会抛 ValueError；且 stop 已置位后不再落盘
            if not self._stop.is_set():
                with contextlib.suppress(ValueError):
                    self.writer.write(row)

    def summary(self) -> dict[str, float]:
        return {f"load/{k}": self._sums[k] / self._counts[k] for k in sorted(self._counts)}


def machine_info() -> dict:
    cpu_model = platform.processor()
    with contextlib.suppress(OSError):
        for line in open("/proc/cpuinfo", encoding="utf-8"):
            if line.startswith("model name"):
                cpu_model = line.split(":", 1)[1].strip()
                break
    info = {
        "cpu_model": cpu_model, "cpu_logical": os.cpu_count(), "cpu_physical": psutil.cpu_count(logical=False),
        "mem_gb": round(psutil.virtual_memory().total / 2**30, 1), "python": platform.python_version(),
        "torch": torch.__version__, "cuda": torch.version.cuda, "gpus": [], "driver": None,
    }
    if torch.cuda.is_available():
        info["gpus"] = [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())]
    with contextlib.suppress(Exception):
        import pynvml

        pynvml.nvmlInit()
        v = pynvml.nvmlSystemGetDriverVersion()
        info["driver"] = v.decode() if isinstance(v, bytes) else v
    return info


def summarize(phase_rows: list[dict], load_summary: dict, env_steps_per_iter: int) -> dict:
    if not phase_rows:
        return {"phase_frac": {}, **load_summary}
    n = len(phase_rows)
    total = sum(r["total_s"] for r in phase_rows) / n
    frac = {p: sum(r.get(f"{p}_s", 0.0) for r in phase_rows) / n / total for p in PHASES}
    return {
        "iter_s": total, "sps": env_steps_per_iter / total, "phase_frac": frac,
        "gpu_waits_cpu": frac["env_step"],
        "cpu_waits_gpu": frac["featurize"] + frac["policy"] + frac["reward"] + frac["update"],
        **load_summary,
    }
