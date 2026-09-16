"""探测模式（新机器 / 朋友的机器）：系统信息 → gpucheck → bench 选参 → 限时训练 → 汇总 → 一个结果包。

    bash run.sh --probe [--minutes 20]          # 推荐入口：先做网络探测与计时安装，再调本模块
    uv run python -m stgtrain.probe --out runs/probe-x [--minutes 20]

每一步单独计时、失败不中断，最后照样打包成 `<out>.tar.gz`，把这一个文件发回来即可。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tarfile
import time
import traceback
from pathlib import Path

import torch

from .config import deep_merge, dump_toml, load_config
from .perf import machine_info
from .train import REPO_ROOT, train

CPU_BENCH_GRID = [64, 128, 256]
# torch 的 CUDA 大版本 → Linux 最低驱动（NVIDIA CUDA 兼容表）
MIN_DRIVER = {"11": "450.80", "12": "525.60", "13": "580"}
CMDS: dict[str, list[str]] = {
    "uname.txt": ["uname", "-a"],
    "os-release.txt": ["cat", "/etc/os-release"],
    "lscpu.txt": ["lscpu"],
    "free.txt": ["free", "-h"],
    "df.txt": ["df", "-h", str(REPO_ROOT)],
    "nvidia-smi.txt": ["nvidia-smi"],
    "nvidia-smi-q.txt": ["nvidia-smi", "-q"],
    "nproc.txt": ["nproc"],
    "uv.txt": ["uv", "--version"],
}


class Steps:
    """逐步执行、计时、捕获异常，状态随时落盘 probe.json（中途被杀也留得下前几步）。"""

    def __init__(self, out: Path):
        self.out = out
        self.rows: dict[str, dict] = {}
        self.extra: dict = {}

    def run(self, name: str, fn):
        print(f"\n===== {name} =====", flush=True)
        t0 = time.perf_counter()
        try:
            res = fn()
            self.rows[name] = {"ok": True, "seconds": round(time.perf_counter() - t0, 1)}
            if res is not None:
                self.rows[name]["result"] = res
        except Exception as e:  # noqa: BLE001 —— 探测模式：记下来继续
            res = None
            self.rows[name] = {"ok": False, "seconds": round(time.perf_counter() - t0, 1),
                               "error": f"{type(e).__name__}: {e}"}
            (self.out / f"{name}.error.txt").write_text(traceback.format_exc(), encoding="utf-8")
            print(f"✘ {name} 失败：{e}（详情 {name}.error.txt），继续下一步", flush=True)
        self.save()
        return res

    def save(self) -> None:
        (self.out / "probe.json").write_text(json.dumps({"steps": self.rows, **self.extra}, indent=2,
                                                        ensure_ascii=False, default=str), encoding="utf-8")


def collect_sysinfo(out: Path) -> dict:
    d = out / "sysinfo"
    d.mkdir(exist_ok=True)
    for fname, cmd in CMDS.items():
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            (d / fname).write_text(p.stdout + p.stderr, encoding="utf-8")
        except (OSError, subprocess.TimeoutExpired) as e:
            (d / fname).write_text(f"不可用：{e}\n", encoding="utf-8")
    info = machine_info()
    info["cuda_available"] = torch.cuda.is_available()
    info["gpu_diagnosis"] = gpu_diagnosis(d / "nvidia-smi.txt", info)
    (d / "machine.json").write_text(json.dumps(info, indent=2, ensure_ascii=False), encoding="utf-8")
    return {"cpu": info["cpu_model"], "cpu_logical": info["cpu_logical"], "mem_gb": info["mem_gb"],
            "gpus": info["gpus"], "driver": info["driver"], "torch": info["torch"], "cuda": info["cuda"],
            "gpu_diagnosis": info["gpu_diagnosis"]}


def gpu_diagnosis(nvsmi: Path, info: dict, proc: Path = Path("/proc/driver/nvidia/version")) -> str:
    """区分「没有 N 卡」「有卡但 torch 用不了 CUDA（多半驱动太旧）」「CUDA 可用」——否则探测会静默退化成纯 CPU。"""
    if info["cuda_available"]:
        return f"CUDA 可用：{', '.join(info['gpus'])}（驱动 {info['driver']}，torch 编译 CUDA {info['cuda']}）"
    drv = info.get("driver")
    if not drv and proc.exists():
        m = re.search(r"Kernel Module\s+(?:for \S+\s+)?([\d.]+)", proc.read_text(encoding="utf-8", errors="replace"))
        drv = m.group(1) if m else "?"
    text = nvsmi.read_text(encoding="utf-8") if nvsmi.exists() else ""
    if not drv and "Driver Version:" in text:
        drv = text.split("Driver Version:")[1].split()[0]
    if not drv:
        return "没有检测到 NVIDIA 驱动，按纯 CPU 跑。"
    need = MIN_DRIVER.get((info.get("cuda") or "").split(".")[0], "?")
    perm = "；nvidia-smi 列不出设备，也可能是 /dev/nvidia* 没有权限" if "No devices were found" in text else ""
    return (f"⚠ 有 NVIDIA 驱动（{drv}）但 torch 用不了 CUDA，本次按纯 CPU 跑。torch {info['torch']} 用 CUDA "
            f"{info['cuda']} 编译，Linux 驱动需 ≥ {need}——多半是驱动太旧{perm}。")


def run_gpucheck(out: Path, config: Path, timeout_min: float) -> str:
    if not torch.cuda.is_available():
        return "skip（没有 CUDA）"
    log = out / "gpucheck.log"
    with log.open("w", encoding="utf-8") as f:
        p = subprocess.run([sys.executable, "-m", "stgtrain.gpucheck", str(config)], cwd=REPO_ROOT,
                           stdout=f, stderr=subprocess.STDOUT, timeout=timeout_min * 60)
    if p.returncode != 0:
        raise RuntimeError(f"gpucheck 退出码 {p.returncode}（见 gpucheck.log）")
    return "PASS"


def base_cfg(config: Path, adapt: bool) -> dict:
    over: dict = {}
    if adapt and not torch.cuda.is_available():
        over = {"ppo": {"compile": False, "cudagraphs": False}, "bench": {"num_envs": CPU_BENCH_GRID},
                "env": {"num_envs": CPU_BENCH_GRID[-1]}}
    elif adapt and torch.cuda.is_available():
        # 显存够大就多试一档：4090 实测 4096 env 只占 10 GB / 24 GB，GPU 利用率 64%，还有余量
        vram_gb = torch.cuda.get_device_properties(0).total_memory / 2**30
        cfg = load_config(config)
        if vram_gb >= 20 and max(cfg["bench"]["num_envs"]) < 8192:
            over = {"bench": {"num_envs": [*cfg["bench"]["num_envs"], 8192]}}
    return load_config(config, over or None)


def run_bench_step(out: Path, cfg: dict) -> dict:
    d = out / "bench"
    d.mkdir(exist_ok=True)
    from .bench import run_bench

    res = run_bench(cfg, d)
    return res["recommended"]


def run_train_step(out: Path, cfg: dict, minutes: float, recommended: dict | None) -> dict:
    env_over = dict(recommended) if recommended else {}
    # perf_sync_every = 1：探测只跑几次更新，按默认的 20 会一行分阶段计时都采不到
    c = deep_merge(cfg, {"env": env_over, "log": {"perf_sync_every": 1},
                         "run": {"max_minutes": float(minutes), "total_updates": 1_000_000}})
    run_dir = out / "train"
    for sub in ("checkpoints", "eval", "plots"):
        (run_dir / sub).mkdir(parents=True, exist_ok=True)
    dump_toml(c, out / "probe-train-config.toml")
    train(load_config(out / "probe-train-config.toml"), run_dir, pack_result=False)
    env = json.loads((run_dir / "env.json").read_text(encoding="utf-8"))
    ps = env.get("perf_summary", {})
    rows = [json.loads(line) for line in (run_dir / "metrics.jsonl").read_text(encoding="utf-8").splitlines() if line]
    sps = [r["perf/sps"] for r in rows if "perf/sps" in r]  # 逐次更新的端到端 SPS，不依赖分阶段采样
    updates = max((r["update"] for r in rows), default=0)
    return {"num_envs": c["env"]["num_envs"], "threads": c["env"]["threads"], "minutes": round(float(minutes), 2),
            "updates": updates, "stopped_at_update": env.get("stopped_early_at_update"),
            "sps": round(sum(sps) / len(sps), 1) if sps else ps.get("sps"),
            "sps_last": round(sps[-1], 1) if sps else None,
            "phase_frac": ps.get("phase_frac"),
            "load": {k: v for k, v in ps.items() if k.startswith("load/")}}


def write_summary(out: Path, steps: Steps) -> None:
    lines = [f"# 探测结果 {out.name}", ""]
    diag = steps.rows.get("sysinfo", {}).get("result", {}).get("gpu_diagnosis")
    if diag:
        lines += [f"**GPU：** {diag}", ""]
    inst = out / "install.json"
    if inst.exists():
        lines += ["## 安装", "", "```json", inst.read_text(encoding="utf-8").strip(), "```", ""]
    net = out / "net.txt"
    if net.exists():
        lines += ["## 网络", "", "```", net.read_text(encoding="utf-8").strip(), "```", ""]
    lines += ["## 步骤", "", "| 步骤 | 结果 | 秒 | 备注 |", "|---|---|---|---|"]
    for name, r in steps.rows.items():
        note = r.get("error") or (json.dumps(r["result"], ensure_ascii=False) if "result" in r else "")
        lines.append(f"| {name} | {'✔' if r['ok'] else '✘'} | {r['seconds']} | {note[:300]} |")
    tr = steps.rows.get("train", {}).get("result")
    if tr:
        lines += ["", "## 训练负载", "",
                  f"- num_envs {tr['num_envs']} · threads {tr['threads']} · SPS {tr['sps']}",
                  f"- 分阶段占比：{json.dumps(tr['phase_frac'], ensure_ascii=False)}",
                  f"- 平均负载：{json.dumps(tr['load'], ensure_ascii=False)}",
                  "- 图：`train/plots/load.png`（CPU / GPU / 显存 / 功耗随时间）、`train/plots/*.png`（训练指标）",
                  "- 原始数据：`train/perf.jsonl`（每秒一行负载 + 分阶段计时）、`train/metrics.jsonl`、`bench/bench.json`"]
    (out / "SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def pack(out: Path) -> Path:
    dst = out.parent / f"{out.name}.tar.gz"

    def keep(ti: tarfile.TarInfo):
        return None if "/checkpoints/" in ti.name and ti.name.endswith(".pt") and "/latest.pt" not in ti.name else ti

    with tarfile.open(dst, "w:gz") as tf:
        tf.add(out, arcname=out.name, filter=keep)
    return dst


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.probe")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--minutes", type=float, default=20.0, help="总时长预算（分钟，不含安装）")
    ap.add_argument("--config", type=Path, default=REPO_ROOT / "configs" / "probe.toml")
    ap.add_argument("--min-train-minutes", type=float, default=3.0)
    ap.add_argument("--no-adapt", action="store_true", help="不按有无 CUDA 改 bench 网格 / compile（测试用）")
    ap.add_argument("--skip-gpucheck", action="store_true")
    a = ap.parse_args(argv)
    out = a.out
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.perf_counter()
    steps = Steps(out)
    steps.extra = {"minutes_budget": a.minutes, "started": time.strftime("%Y-%m-%d %H:%M:%S")}

    steps.run("sysinfo", lambda: collect_sysinfo(out))
    if not a.skip_gpucheck:
        steps.run("gpucheck", lambda: run_gpucheck(out, a.config, timeout_min=max(3.0, a.minutes * 0.25)))
    cfg = steps.run("config", lambda: base_cfg(a.config, adapt=not a.no_adapt))
    rec = None
    if cfg is not None:
        rec = steps.run("bench", lambda: run_bench_step(out, cfg))
        remaining = a.minutes - (time.perf_counter() - t0) / 60.0
        steps.run("train", lambda: run_train_step(out, cfg, max(remaining, a.min_train_minutes), rec))
    # config 的结果是整份配置，不进 probe.json 的步骤表
    if "config" in steps.rows:
        steps.rows["config"].pop("result", None)
    steps.extra["total_minutes"] = round((time.perf_counter() - t0) / 60.0, 2)
    steps.save()
    write_summary(out, steps)
    dst = pack(out)
    ok = all(r["ok"] for r in steps.rows.values())
    print(f"\n{'全部步骤通过' if ok else '有步骤失败（见 SUMMARY.md）'}。结果包：{dst}")
    print("把这个文件发回来即可。")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
