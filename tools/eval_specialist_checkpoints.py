"""Evaluate T5 specialist held-out layouts without changing original best selection."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch

from stgtrain.cards import discover, load_splits
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict
from stgtrain.evaluate import evaluate
from stgtrain.ppo import PPO
from stgtrain.train import build_components, pick_device


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--device", default="cuda", choices=("cpu", "cuda"))
    ap.add_argument("--updates", nargs="+", type=int, default=[2750, 3000, 3250, 3500])
    ap.add_argument("--splits", type=Path, default=Path("eval/splits-laser-specialist.toml"))
    a = ap.parse_args()
    paths = [a.run_dir / "checkpoints" / f"u{u}.pt" for u in a.updates]
    paths.append(a.run_dir / "checkpoints" / "best.pt")
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)
    first = load_checkpoint(paths[0])
    cfg = from_dict(first["cfg"])
    cfg["run"]["device"] = a.device
    device = pick_device(a.device)
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))
    images, starts, _, feat, factory = build_components(cfg, device)
    specs = load_splits(a.splits, cfg["eval"]["episodes"])
    cards = discover(cfg["env"]["cards_dir"])
    if len(specs) != 5 or len({s.card for s in specs}) != 5:
        raise ValueError("Expected five distinct specialist held-out layouts")
    for spec in specs:
        card = cards[spec.card]
        if card.meta.get("synthetic_kind") != "laser_specialist" or card.meta.get("split") != "held-out":
            raise ValueError(f"Not a specialist held-out layout: {spec.card}")
        if any(s.image == spec.card for s in starts):
            raise ValueError(f"Held-out layout leaked into starts: {spec.card}")
    out = a.run_dir / "specialist-eval"
    out.mkdir(exist_ok=True)
    (out / "splits.toml").write_bytes(a.splits.read_bytes())
    ppo = PPO(cfg, factory, device)
    for path in paths:
        ck = load_checkpoint(path)
        if ck["cfg"] != first["cfg"]:
            raise ValueError(f"Checkpoint configuration differs: {path}")
        ppo.load_state_dict(ck["state"])
        probes = [("follow", cfg["eval"]["intent"])]
        if path.stem == "best":
            probes += [("free", "follow_player_v1"), ("anchor", "fixed_point_v1"),
                       ("boss_or_free16", "boss_or_free_v1")]
        for label, intent in probes:
            cfg["eval"]["intent"] = intent
            result = evaluate(cfg, ppo, feat, images, specs, device)
            result["checkpoint"] = {"path": str(path), "update": int(ck["update"]),
                                    "env_steps": int(ck["env_steps"])}
            result["specialist_probe"] = {"intent": intent, "split": str(a.splits)}
            target = out / f"{path.stem}-{label}.json"
            target.write_text(json.dumps(result, ensure_ascii=False, indent=2))
            print(f"{target}: survival={result['overall']['survival']:.4f}", flush=True)


if __name__ == "__main__":
    main()
