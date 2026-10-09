"""Observe requested/executed actions through the unmodified production evaluator.

Run from the repository root. No training, action filtering, or extra RNG draws.
The recorder is scoped to this process and saves first episodes only.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import subprocess
import time

import numpy as np
import stg_rl
import torch

from stgtrain import actions, evaluate
from stgtrain.cards import discover
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import deep_merge, from_dict
from stgtrain.envwrap import EnvWrapper, _off
from stgtrain.featurize.danger_topk_v7 import box_distance, laser_frame
from stgtrain.ppo import PPO
from stgtrain.train import build_components


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def clearance(obs):
    """Current geometric separation, for offline strata only; not future safety."""
    far = torch.full_like(obs.player_hit_r, 1e6)
    bullet = far
    if obs.bullets.shape[1]:
        distances = ((obs.bullets[..., :2] - obs.player_xy[:, None]).norm(dim=-1)
                     - obs.bullets[..., 4] - obs.player_hit_r[:, None])
        bullet = distances.masked_fill(~obs.bullets_mask, 1e6).min(1).values
    _, _, along, perp = laser_frame(obs.lasers, obs.player_xy)
    distances = box_distance(obs.lasers, along, perp) - obs.player_hit_r[:, None]
    active = obs.lasers_mask & (obs.lasers[..., 11] == 1)
    warning = obs.lasers_mask & (obs.lasers[..., 11] == 0)
    return (bullet, distances.masked_fill(~active, 1e6).min(1).values,
            distances.masked_fill(~warning, 1e6).min(1).values)


class Recorder:
    def __init__(self, detailed=True):
        self.detailed = detailed
        self.rows = []
        self.logits = None

    def forward(self, _module, _inputs, output):
        self.logits = output[0].detach()

    def arrays(self):
        return {k: np.stack([r[k] for r in self.rows]) for k in self.rows[0]}

    @contextmanager
    def install(self, model):
        recorder = self

        class RecordingEnv(EnvWrapper):
            def reset(self):
                obs = super().reset()
                self._record_obs = obs
                self._finished = torch.zeros(self.n, dtype=torch.bool)
                return obs

            def step(self, want, timer=None):
                obs = self._record_obs
                # Copy pre-step state: auto-reset can replace both observation and motor state.
                before = {
                    "first_episode": ~self._finished,
                    "state": self.buf["player"][:, _off("player", "state")].clone(),
                    "want": want, "prev_exec": obs.prev_action,
                    "xy": obs.player_xy, "target": obs.target_xy,
                }
                if recorder.detailed:
                    assert torch.equal(want, recorder.logits.argmax(-1))
                    lg = recorder.logits.float()
                    best = lg.topk(2, dim=-1).values
                    direction = lg.reshape(self.n, 9, 2).max(-1).values
                    dbest = direction.topk(2, dim=-1).values
                    bd, ld, wd = clearance(obs)
                    before.update(
                        bullet_clearance=bd, laser_clearance=ld, warning_clearance=wd,
                        margin=best[:, 0] - best[:, 1],
                        direction_margin=dbest[:, 0] - dbest[:, 1],
                        keep_advantage=best[:, 0] - lg.gather(1, obs.prev_action[:, None]).squeeze(1),
                        held=obs.dir_held,
                        motor_need=self.motor.dir_state[0],
                        motor_pending=self.motor.dir_state[1],
                        motor_wait=self.motor.dir_state[2],
                    )
                row = {k: v.detach().cpu().numpy().copy() for k, v in before.items()}
                nxt, info = super().step(want, timer)
                # info.buttons still belongs to this step, even when nxt has already reset.
                table = actions.buttons_table(want.device)
                matches = info.buttons[:, None] == table[None, :]
                assert bool(matches.sum(1).eq(1).all())
                executed = matches.to(torch.int64).argmax(1)
                assert torch.equal(info.overridden, executed != want)
                continuing = info.done == 0
                assert torch.equal(nxt.prev_action[continuing], executed[continuing])
                row.update(executed=executed.numpy().copy(), done=info.done.numpy().copy(),
                           ep_frames=info.ep_frames.numpy().copy(),
                           buttons=info.buttons.numpy().copy(),
                           next_xy=nxt.player_xy.numpy().copy())
                recorder.rows.append(row)
                self._finished |= info.done != 0
                self._record_obs = nxt
                if len(recorder.rows) % 600 == 0:
                    print(f"  step={len(recorder.rows)} first_done={int(self._finished.sum())}/{self.n}", flush=True)
                return nxt, info

        old = evaluate.EnvWrapper
        hook = model.register_forward_hook(self.forward) if self.detailed else None
        evaluate.EnvWrapper = RecordingEnv
        try:
            yield
        finally:
            evaluate.EnvWrapper = old
            if hook is not None:
                hook.remove()


def verify_batch(arrays, records, episodes):
    valid = arrays["first_episode"].astype(bool)
    for gi, group in enumerate(records):
        for ei, record in enumerate(group):
            col = gi * episodes + ei
            terminal = np.flatnonzero(valid[:, col] & (arrays["done"][:, col] != 0))
            assert len(terminal) == 1
            step = terminal[0]
            assert int(arrays["done"][step, col]) == record["done"]
            assert int(arrays["ep_frames"][step, col]) == record["frames"]
            assert int(valid[:, col].sum()) == record["steps"]
    assert sum(len(g) for g in records) == valid.shape[1]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("checkpoint", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--mode", choices=("follow", "free"), default="follow")
    ap.add_argument("--episodes", type=int, default=32)
    ap.add_argument("--batch-cards", type=int, default=3)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--cards", nargs="+")
    ap.add_argument("--preflight", action="store_true", help="compare detailed/minimal recording and plain evaluator")
    a = ap.parse_args()
    if min(a.episodes, a.batch_cards, a.threads) < 1:
        ap.error("episodes, batch-cards and threads must be positive")
    a.out.mkdir(parents=True, exist_ok=True)
    if (a.out / "manifest.json").exists():
        raise SystemExit("Refusing to overwrite an existing experiment directory")
    torch.set_num_threads(a.threads)
    ck = load_checkpoint(a.checkpoint, map_location="cpu")
    cfg = from_dict(deep_merge(ck["cfg"], {
        "run": {"device": "cpu", "torch_threads": a.threads},
        "env": {"threads": a.threads},
        "eval": {"intent": "lower_half_uniform_v1" if a.mode == "follow" else "follow_player_v1",
                 "motor": "train", "seed": 12345, "greedy": True},
        "ppo": {"compile": False, "cudagraphs": False, "rollout_cudagraphs": False},
    }))
    cfg = evaluate.eval_cfg(cfg)
    assert cfg["motor"]["enabled"] and cfg["env"]["frame_skip"] == 1
    device = torch.device("cpu")
    images, _starts, specs, feat, factory = build_components(cfg, device)
    if a.cards:
        assert set(a.cards).issubset({s.card for s in specs})
        specs = [s for s in specs if s.card in a.cards]
    ppo = PPO(cfg, factory, device)
    ppo.load_state_dict(ck["state"])
    cards = discover(cfg["env"]["cards_dir"])
    manifest = {
        "status": "running", "checkpoint": str(a.checkpoint.resolve()),
        "checkpoint_sha256": sha(a.checkpoint), "checkpoint_update": int(ck["update"]),
        "engine": stg_rl.build_info(), "torch": torch.__version__, "device": "cpu",
        "mode": a.mode, "episodes_per_group": a.episodes, "batch_cards": a.batch_cards,
        "config": cfg, "script_sha256": sha(__file__), "batches": [],
        "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "split_sha256": sha(cfg["env"]["eval_splits"]),
        "card_source_sha256": {s.card: {str(p): sha(p) for p in sorted(cards[s.card].path.rglob("*"))
                                        if p.is_file()} for s in specs},
        "production_source_sha256": {str(p): sha(p) for p in sorted(Path("src/stgtrain").rglob("*.py"))},
        "scope": "First episodes only; diagnostic control metrics use pre-step Alive state (1).",
    }
    save_json(a.out / "manifest.json", manifest)
    start = time.monotonic()
    with torch.no_grad():
        for i in range(0, len(specs), a.batch_cards):
            chosen = specs[i:i + a.batch_cards]
            groups = [(images[s.card], s.card, rank) for s in chosen for rank in s.ranks]
            print(f"{a.mode} batch={i // a.batch_cards} groups={[(c, r) for _, c, r in groups]}", flush=True)
            recorder = Recorder()
            with recorder.install(ppo.agent_inference.model):
                records = evaluate.run_groups(cfg, ppo, feat, groups, a.episodes, device)
            arrays = recorder.arrays()
            verify_batch(arrays, records, a.episodes)
            if a.preflight:
                minimal = Recorder(detailed=False)
                with minimal.install(ppo.agent_inference.model):
                    repeated = evaluate.run_groups(cfg, ppo, feat, groups, a.episodes, device)
                control = minimal.arrays()
                for key, value in control.items():
                    np.testing.assert_array_equal(arrays[key], value, err_msg=key)
                assert records == repeated
                plain = evaluate.run_groups(cfg, ppo, feat, groups, a.episodes, device)
                assert records == plain
                print("PREFLIGHT PASS: detailed/minimal trajectories exact; plain evaluator records exact", flush=True)
            stem = f"batch-{i // a.batch_cards:02d}"
            np.savez_compressed(a.out / f"{stem}.npz", **arrays)
            result = {"groups": [[c, r] for _, c, r in groups], "records": records,
                      "overall": evaluate.summarize_eval([r for rs in records for r in rs])}
            save_json(a.out / f"{stem}.json", result)
            manifest["batches"].append({"stem": stem, "npz_sha256": sha(a.out / f"{stem}.npz"),
                                        "json_sha256": sha(a.out / f"{stem}.json")})
            manifest["wall_seconds"] = time.monotonic() - start
            save_json(a.out / "manifest.json", manifest)
            print(f"{a.mode} saved={stem} survival={result['overall']['survival']:.4f} elapsed={manifest['wall_seconds']:.1f}s", flush=True)
    manifest["status"] = "complete"
    manifest["preflight"] = a.preflight
    save_json(a.out / "manifest.json", manifest)
    print(f"COMPLETE {a.out}", flush=True)


if __name__ == "__main__":
    main()
