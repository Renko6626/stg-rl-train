"""独立评测 checkpoint：不训练，只跑贪心评测并输出 json + 终端块。

    python -m stgtrain.eval_ckpt runs/<run>/checkpoints/best.pt                     # 用 checkpoint 配置里的评测划分
    python -m stgtrain.eval_ckpt <ckpt> --all-cards --ranks 2,3 --out all.json      # 卡池全部卡 × 指定档（与卡 meta 的 ranks 取交集）

模型、特征化、reward、frame_skip 一律取 checkpoint 里的配置；只覆盖设备、卡池目录、局数。
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import torch

from . import console
from .cards import EvalSpec, allowed_ranks, discover
from .checkpoint import load_checkpoint
from .config import deep_merge, from_dict
from .evaluate import evaluate
from .ppo import PPO
from .train import build_components, pick_device


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.eval_ckpt", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("checkpoint")
    ap.add_argument("--device", default="auto", choices=("auto", "cpu", "cuda"))
    ap.add_argument("--cards-dir", default=None, help="覆盖配置里的 env.cards_dir")
    ap.add_argument("--all-cards", action="store_true", help="评卡池里所有卡（含训练卡），不用评测划分")
    ap.add_argument("--ranks", default="2", help="--all-cards 时评哪些档，逗号分隔（默认 2）")
    ap.add_argument("--episodes", type=int, default=None, help="每组局数（默认取配置 eval.episodes / 划分文件）")
    ap.add_argument("--hysteresis", type=float, default=0.0,
                    help="诊断用：最优动作 logit 比上一步高出超过 τ 才换（0 = 纯 argmax）")
    ap.add_argument("--out", default=None, help="结果 json（默认 checkpoint 同目录 eval-<名>-<时间>.json）")
    a = ap.parse_args(argv)

    ck = load_checkpoint(a.checkpoint, map_location="cpu")
    over: dict = {"run": {"device": a.device}}
    if a.cards_dir:
        over["env"] = {"cards_dir": a.cards_dir}
    cfg = from_dict(deep_merge(ck["cfg"], over))
    device = pick_device(cfg["run"]["device"])
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))
    images, _starts, specs, featurizer, factory = build_components(cfg, device)

    if a.all_cards:
        want = [int(r) for r in a.ranks.split(",")]
        n = a.episodes or int(cfg["eval"]["episodes"])
        specs = [EvalSpec(card=c.id, ranks=tuple(r), episodes=n)
                 for c in discover(cfg["env"]["cards_dir"]).values() if (r := allowed_ranks(c, want))]
    elif a.episodes:
        specs = [EvalSpec(s.card, s.ranks, a.episodes) for s in specs]
    if not specs:
        raise SystemExit("没有可评的 (卡, 档)")

    ppo = PPO(cfg, factory, device)
    ppo.load_state_dict(ck["state"])
    t0 = time.perf_counter()
    res = evaluate(cfg, ppo, featurizer, images, specs, device, hysteresis=a.hysteresis)
    res["checkpoint"] = {"path": str(a.checkpoint), "update": int(ck["update"]), "env_steps": int(ck["env_steps"]),
                         "hysteresis": a.hysteresis}
    print(console.eval_block(int(ck["update"]), res, False, time.perf_counter() - t0), flush=True)

    ckp = Path(a.checkpoint)
    out = Path(a.out) if a.out else ckp.parent / f"eval-{ckp.stem}-{time.strftime('%Y%m%d-%H%M%S')}.json"
    out.write_text(json.dumps(res, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"结果：{out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
