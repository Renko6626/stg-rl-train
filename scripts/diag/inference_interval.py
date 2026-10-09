"""Offline 1/2/3/4/6-frame inference comparison; environment and motor remain at 60Hz."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import fields
import json
from pathlib import Path
import time

import numpy as np
import stg_rl
import torch

from stgtrain import actions, evaluate
from stgtrain.cards import discover
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import deep_merge, from_dict
from stgtrain.envwrap import EnvWrapper, RawObs, _off
from stgtrain.export_onnx import deploy_inputs, input_names
from stgtrain.ppo import PPO
from stgtrain.train import build_components

from request_execution import sha, save_json, verify_batch
from summarize_request_execution import events


class IntervalPolicy:
    def __init__(self, ppo, feat, interval):
        self.ppo, self.feat, self.interval = ppo, feat, interval
        self.forward_calls = self.inferred_rows = 0
        self.inference_seconds = 0.0

    def reset(self, n):
        self.age = torch.full((n,), self.interval, dtype=torch.int64)
        self.cache = torch.zeros(n, dtype=torch.int64)

    def ended(self, mask):
        self.age[mask] = self.interval
        self.cache[mask] = 0

    @torch.no_grad()
    def act(self, obs, greedy):
        assert greedy
        due = self.age >= self.interval
        self.last_due = due.clone()
        if bool(due.any()):
            start = time.perf_counter()
            selected = obs if bool(due.all()) else RawObs(**{
                f.name: getattr(obs, f.name)[due] if isinstance(getattr(obs, f.name), torch.Tensor)
                else getattr(obs, f.name) for f in fields(RawObs)
            })
            self.cache[due] = self.ppo.act(self.feat(selected), True)
            self.inference_seconds += time.perf_counter() - start
            self.forward_calls += 1
            self.inferred_rows += int(due.sum())
            self.age[due] = 0
        self.age += 1
        return self.cache.clone()


@contextmanager
def observe(policy, cfg, *, capture=False):
    rows, feeds, feed_meta = [], [], []

    class ObservedEnv(EnvWrapper):
        def reset(self):
            obs = super().reset()
            self.obs = obs
            self.finished = torch.zeros(self.n, dtype=torch.bool)
            policy.reset(self.n)
            return obs

        def step(self, want, timer=None):
            obs = self.obs
            first = ~self.finished
            state = self.buf["player"][:, _off("player", "state")].clone()
            row = {"first_episode": first.numpy().copy(), "state": state.numpy().copy(),
                   "want": want.numpy().copy(), "prev_exec": obs.prev_action.numpy().copy(),
                   "inferred": policy.last_due.numpy().copy()}
            if capture and len(rows) % 120 == 0 and len(feeds) < 96:
                k = self._group_k or self.n
                for base in range(0, self.n, k):
                    candidates = (first[base:base + k] & (state[base:base + k] == 1)).nonzero().flatten()
                    if not len(candidates) or len(feeds) >= 96:
                        continue
                    i = base + int(candidates[0])
                    values = deploy_inputs(obs, i, bullets_rows=640, enemies_rows=256,
                                           with_held=2, with_lasers=True, with_start_len=True)
                    feeds.append(dict(zip(input_names(cfg), [v.numpy().copy() for v in values])))
                    feed_meta.append({"step": len(rows), "env": i,
                                      "raw_bullets": int(obs.bullets_mask[i].sum()),
                                      "raw_lasers": int(obs.lasers_mask[i].sum())})
            motor_t = self.motor.t
            nxt, info = super().step(want, timer)
            assert self.motor.t == motor_t + 1
            matches = info.buttons[:, None] == actions.buttons_table(want.device)[None, :]
            assert bool(matches.sum(1).eq(1).all())
            executed = matches.long().argmax(1)
            assert torch.equal(info.overridden, executed != want)
            row.update(executed=executed.numpy().copy(), done=info.done.numpy().copy(),
                       ep_frames=info.ep_frames.numpy().copy())
            rows.append(row)
            self.finished |= info.done != 0
            policy.ended(info.done != 0)
            self.obs = nxt
            if len(rows) % 600 == 0:
                print(f"  step={len(rows)} first_done={int(self.finished.sum())}/{self.n}", flush=True)
            return nxt, info

    original = evaluate.EnvWrapper
    evaluate.EnvWrapper = ObservedEnv
    try:
        yield rows, feeds, feed_meta
    finally:
        evaluate.EnvWrapper = original


def verify_schedule(data, interval):
    first = data["first_episode"].astype(bool)
    ticks = np.arange(first.shape[0])[:, None]
    assert np.array_equal(data["inferred"][first], np.broadcast_to(ticks % interval == 0, first.shape)[first])
    # Includes resets after first episodes while the batch waits for its last env.
    assert bool(data["inferred"][1:][data["done"][:-1] != 0].all())
    if interval > 1:
        skip = first[1:] & ~data["inferred"][1:]
        assert np.array_equal(data["want"][1:][skip], data["want"][:-1][skip])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("checkpoint", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--mode", choices=("deploy", "free"), default="deploy")
    ap.add_argument("--interval", type=int, choices=(1, 2, 3, 4, 6), default=1)
    ap.add_argument("--episodes", type=int, default=16)
    ap.add_argument("--threads", type=int, default=2)
    ap.add_argument("--cards", nargs="+")
    ap.add_argument("--preflight", action="store_true")
    a = ap.parse_args()
    assert a.episodes > 0 and a.threads > 0
    a.out.mkdir(parents=True, exist_ok=True)
    assert not (a.out / "manifest.json").exists(), "Existing run must not be overwritten"
    ck = load_checkpoint(a.checkpoint)
    cfg = evaluate.eval_cfg(from_dict(deep_merge(ck["cfg"], {
        "run": {"device": "cpu", "torch_threads": a.threads}, "env": {"threads": a.threads},
        "eval": {"intent": "boss_or_free_v1" if a.mode == "deploy" else "follow_player_v1",
                 "seed": 12345, "greedy": True, "motor": "train"},
        "intent": {"pressure_on": 16, "pressure_off": 8, "pressure_radius": 96.0, "pressure_hold": 60},
        "ppo": {"compile": False, "cudagraphs": False, "rollout_cudagraphs": False},
    })))
    assert cfg["env"]["frame_skip"] == 1 and cfg["motor"]["enabled"]
    torch.set_num_threads(a.threads)
    device = torch.device("cpu")
    images, _starts, specs, feat, factory = build_components(cfg, device)
    if a.cards:
        assert set(a.cards).issubset({s.card for s in specs})
        specs = [s for s in specs if s.card in a.cards]
    ppo = PPO(cfg, factory, device)
    ppo.load_state_dict(ck["state"])
    cards = discover(cfg["env"]["cards_dir"])
    manifest = {"status": "running", "mode": a.mode, "interval": a.interval,
                "episodes_per_group": a.episodes, "config": cfg,
                "checkpoint": str(a.checkpoint.resolve()), "checkpoint_sha256": sha(a.checkpoint),
                "checkpoint_update": int(ck["update"]), "engine": stg_rl.build_info(), "torch": torch.__version__,
                "script_sha256": sha(__file__), "split_sha256": sha(cfg["env"]["eval_splits"]),
                "card_source_sha256": {s.card: {str(p): sha(p) for p in sorted(cards[s.card].path.rglob("*")) if p.is_file()} for s in specs},
                "production_source_sha256": {str(p): sha(p) for p in sorted(Path("src/stgtrain").rglob("*.py"))},
                "diagnostic_helpers_sha256": {str(p): sha(p) for p in (
                    Path(__file__).with_name("request_execution.py"),
                    Path(__file__).with_name("summarize_request_execution.py"))},
                "batches": [], "preflight": a.preflight}
    save_json(a.out / "manifest.json", manifest)
    started = time.monotonic()
    for i in range(0, len(specs), 3):
        chosen = specs[i:i + 3]
        groups = [(images[s.card], s.card, r) for s in chosen for r in s.ranks]
        print(f"{a.mode} interval={a.interval} batch={i // 3} groups={[(c,r) for _,c,r in groups]}", flush=True)
        policy = IntervalPolicy(ppo, feat, a.interval)
        with observe(policy, cfg, capture=a.preflight) as (rows, feeds, feed_meta):
            records = evaluate.run_groups(cfg, policy, lambda obs: obs, groups, a.episodes, device)
        data = {k: np.stack([r[k] for r in rows]) for k in rows[0]}
        verify_batch(data, records, a.episodes)
        verify_schedule(data, a.interval)
        if a.preflight and a.interval == 1:
            plain = evaluate.run_groups(cfg, ppo, feat, groups, a.episodes, device)
            assert records == plain
            print("PREFLIGHT PASS: interval1 records match unmodified evaluator exactly", flush=True)
        if feeds:
            np.savez_compressed(a.out / "feeds.npz", **{k: np.stack([f[k] for f in feeds]) for k in feeds[0]})
            save_json(a.out / "feeds-meta.json", feed_meta)
            manifest["feed_source"] = {"batch": i // 3,
                "feeds_sha256": sha(a.out / "feeds.npz"), "meta_sha256": sha(a.out / "feeds-meta.json")}
        # Exact first-episode schedule counts; post-reset extra inference is kept separately.
        ev = events(data)
        active = ev["active"]
        control = {k: int((v & active).sum()) for k,v in ev.items() if k not in ("active", "request_latency")}
        control["alive_frames"] = int(active.sum())
        first_inferred = int((data["inferred"] & data["first_episode"]).sum())
        result = {"groups": [[c,r] for _,c,r in groups], "records": records,
                  "overall": evaluate.summarize_eval([r for rs in records for r in rs]), "control_counts": control,
                  "timing": {"forward_calls": policy.forward_calls, "inferred_rows_including_resets": policy.inferred_rows,
                             "first_episode_inferred_rows": first_inferred,
                             "first_episode_rows": int(data["first_episode"].sum()),
                             "batched_torch_inference_seconds": policy.inference_seconds}}
        stem = f"batch-{i // 3:02d}"
        np.savez_compressed(a.out / f"{stem}.npz", **data)
        save_json(a.out / f"{stem}.json", result)
        manifest["batches"].append({"stem": stem, "npz_sha256": sha(a.out / f"{stem}.npz"), "json_sha256": sha(a.out / f"{stem}.json")})
        manifest["wall_seconds"] = time.monotonic() - started
        save_json(a.out / "manifest.json", manifest)
        print(f"saved {stem} survival={result['overall']['survival']:.4f} elapsed={manifest['wall_seconds']:.1f}s", flush=True)
    manifest["status"] = "complete"
    save_json(a.out / "manifest.json", manifest)
    print("COMPLETE", a.out, flush=True)


if __name__ == "__main__":
    main()
