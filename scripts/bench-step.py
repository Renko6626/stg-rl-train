"""训练机上跑的微基准：rollout 一步里到底是谁慢（2 分钟）。

    uv run --frozen python scripts/bench-step.py [--envs 4096] [--threads 32] [--steps 300]

起因（2026-09-20）：N1 / N2 的 `env_step` 阶段比 J 慢一倍（每轮 3.1 s vs 1.5 s），而且从头 300 轮就慢。
PhaseTimer 在阶段进出都同步，运动层的核不算在 `env_step` 里 ⇒ 慢的是 Rust 的 env.step 本身或按键的 D2H，
本机（无 GPU）复现不了。这个脚本在真设备上把几种怀疑拆开量：

  A  随机数调用的单次延迟：带 generator 的 rand / randint / multinomial（意图与镜像每步各调几次）对比计数器式整块预抽
  B  同一个随机策略，「每帧乱按」对比「方向保持 2–6 帧」（= 运动层下的按键形态），Rust env.step 各要多久
  C  EnvWrapper.step 除 Rust 之外的部分（解码 + 意图 + 镜像）要多久

单独跑与「旁边再开一个训练进程」各跑一次，就能看出 GPU 共享时哪一项被放大。
"""
from __future__ import annotations

import argparse
import time

import torch

from stgtrain.config import load_config
from stgtrain.envwrap import EnvWrapper, counter_draw
from stgtrain.train import build_components, pick_device


def sync(dev):
    if dev.type == "cuda":
        torch.cuda.synchronize()


def per_call(fn, dev, n=500) -> float:
    for _ in range(20):
        fn()
    sync(dev)
    t = time.perf_counter()
    for _ in range(n):
        fn()
    sync(dev)
    return (time.perf_counter() - t) / n * 1e3


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--envs", type=int, default=4096)
    ap.add_argument("--threads", type=int, default=32)
    ap.add_argument("--steps", type=int, default=300)
    ap.add_argument("--device", default="auto")
    a = ap.parse_args()
    dev = pick_device(a.device)
    n = a.envs
    print(f"设备 {dev} · {n} env · {a.threads} 线程 · {a.steps} 步\n")

    print("A  随机数：单次调用的端到端延迟（ms，含发射；500 次连发后同步一次）")
    gen = torch.Generator(device=dev); gen.manual_seed(1)
    p = torch.tensor([0.6, 0.3, 0.1], device=dev).expand(n, -1)
    ids = torch.arange(n, device=dev)
    rows = [
        ("rand(n,2, generator)", lambda: torch.rand(n, 2, generator=gen, device=dev)),
        ("randint(n, generator)", lambda: torch.randint(120, 301, (n,), generator=gen, device=dev)),
        ("multinomial(n, generator)", lambda: torch.multinomial(p, 1, replacement=True, generator=gen)),
        ("rand(n,2) 默认发生器", lambda: torch.rand(n, 2, device=dev)),
        ("counter_draw 整块 64 步", lambda: counter_draw(1, ids, 0, 64, 0, 2, 6)),
    ]
    for name, fn in rows:
        print(f"   {name:28s} {per_call(fn, dev):7.3f}")
    print("   （意图每步调 2× rand + 2× randint [+ 2× multinomial]，镜像 1× rand；counter_draw 每 64 步才调一次）\n")

    for label, cfg_path in (("J", "configs/exp-j-quickchange.toml"), ("N2", "configs/exp-n2-motor-delay.toml")):
        cfg = load_config(cfg_path, {"run": {"device": str(dev)}, "env": {"num_envs": n, "threads": a.threads}})
        images, starts, _, _feat, _ = build_components(cfg, dev)
        for style in ("每帧乱按", "保持 2–6 帧"):
            if label == "N2" and style == "保持 2–6 帧":
                continue          # N2 自带运动层，乱按进去、保持着出来
            w = EnvWrapper(cfg, images, starts, dev, seed=1)
            w.reset()
            g = torch.Generator(device=dev); g.manual_seed(0)
            rust = 0.0
            orig = w.env.step

            def timed(b, orig=orig):
                nonlocal rust
                t = time.perf_counter()
                r = orig(b)
                rust += time.perf_counter() - t
                return r

            w.env.step = timed
            act = torch.zeros(n, dtype=torch.int64, device=dev)
            left = torch.zeros(n, dtype=torch.int64, device=dev)
            ended = 0
            sync(dev)
            t0 = time.perf_counter()
            for _ in range(a.steps):
                new = torch.randint(0, 18, (n,), generator=g, device=dev)
                if style == "每帧乱按":
                    act = new
                else:
                    act = torch.where(left <= 0, new, act)
                    left = torch.where(left <= 0, torch.randint(2, 7, (n,), generator=g, device=dev), left) - 1
                _, info = w.step(act)
                ended += int((info.done != 0).sum())
            sync(dev)
            tot = (time.perf_counter() - t0) / a.steps * 1e3
            r = rust / a.steps * 1e3
            print(f"B/C  {label:3s} {style:10s}  整步 {tot:7.2f} ms · Rust env.step {r:7.2f} · 包装层其余 {tot - r:7.2f}"
                  f" · 每步结束 {ended / a.steps:5.2f} 局")
    print("\n读法：B 里两种按键形态的 Rust 耗时差 = 「运动层让局面更费」的部分；"
          "N2 与 J 的「包装层其余」之差 = 运动层 + v4 自己的开销；A 表里哪一项到了毫秒级，哪一项就是 GPU 共享时的坑。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
