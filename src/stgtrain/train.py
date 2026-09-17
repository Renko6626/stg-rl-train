"""入口（spec §2.2）。

python -m stgtrain.train <config> [name]            训练
python -m stgtrain.train --resume <run 目录> [--total-updates N]
python -m stgtrain.train <config> [name] --bench     测吞吐
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tarfile
import time
from pathlib import Path

import stg_rl
import torch

from . import console, plots
from .actions import ACTION_TABLE_VERSION
from .cards import compile_cards, discover, load_splits, train_starts
from .checkpoint import load_checkpoint, restore_rng, save_checkpoint
from .config import deep_merge, dump_toml, from_dict, load_config
from .envwrap import EnvWrapper
from .episodes import EpisodeTracker
from .evaluate import evaluate, score
from .metrics import MetricsLogger, read_jsonl, summarize_episodes, truncate_after
from .perf import LoadSampler, PerfWriter, PhaseTimer, machine_info, summarize
from .ppo import PPO
from .registry import FEATURIZERS, MODELS, check_compat, load_builtins
from .reward import RewardFn

REPO_ROOT = Path(__file__).resolve().parents[2]


def pick_device(name: str) -> torch.device:
    if name == "cpu":
        return torch.device("cpu")
    if name == "cuda":
        if not torch.cuda.is_available():
            raise RuntimeError("run.device = cuda，但 torch.cuda.is_available() 为 False")
        return torch.device("cuda")
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def git_sha() -> str:
    try:
        run = lambda *a: subprocess.run(["git", *a], cwd=REPO_ROOT, capture_output=True, text=True, check=True).stdout.strip()
        sha = run("rev-parse", "--short", "HEAD")
        return sha + ("-dirty" if run("status", "--porcelain", "--untracked-files=no") else "")
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def make_run_dir(runs_dir: Path, name: str) -> Path:
    d = Path(runs_dir) / f"{time.strftime('%Y%m%d-%H%M%S')}-{name}"
    for sub in ("checkpoints", "eval", "plots"):
        (d / sub).mkdir(parents=True, exist_ok=True)
    return d


def _update_env_json(run_dir: Path, **fields) -> None:
    p = run_dir / "env.json"
    info = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
    info.update(fields)
    p.write_text(json.dumps(info, indent=2, ensure_ascii=False), encoding="utf-8")


def pack(run_dir: Path) -> Path:
    out = run_dir.parent / f"{run_dir.name}.tar.gz"
    with tarfile.open(out, "w:gz") as tf:
        tf.add(run_dir, arcname=run_dir.name)
    return out


def build_components(cfg: dict, device: torch.device):
    load_builtins()
    cards = discover(cfg["env"]["cards_dir"])
    specs = load_splits(cfg["env"]["eval_splits"], cfg["eval"]["episodes"])
    missing = [s.card for s in specs if s.card not in cards]
    if missing:
        raise ValueError(f"评测划分里的卡在 {cfg['env']['cards_dir']} 下不存在：{missing}")
    images = compile_cards(cards)
    starts = train_starts(cards, {s.card for s in specs}, cfg["env"]["ranks"])
    featurizer = FEATURIZERS.get(cfg["featurize"]["name"])(cfg)
    spec = featurizer.spec()
    model_cls = MODELS.get(cfg["model"]["name"])

    def factory():
        return model_cls(cfg, spec)

    check_compat(factory().requires(), spec)
    return images, starts, specs, featurizer, factory


def train(cfg: dict, run_dir: Path, resume: dict | None = None, pack_result: bool = True) -> Path:
    run_dir = Path(run_dir)
    device = pick_device(cfg["run"]["device"])
    total = int(cfg["run"]["total_updates"])
    if resume is not None and total <= int(resume["update"]):
        raise ValueError(f"total_updates={total} 不大于 checkpoint 的 update={resume['update']}，没有要续训的更新")
    torch.manual_seed(int(cfg["run"]["seed"]))
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))
    dump_toml(cfg, run_dir / "config.toml")
    images, starts, specs, featurizer, factory = build_components(cfg, device)
    ppo = PPO(cfg, factory, device)

    start, env_steps, best = 1, 0, None
    if resume is not None:
        ppo.load_state_dict(resume["state"])
        restore_rng(resume)
        start, env_steps = int(resume["update"]) + 1, int(resume["env_steps"])
        # best.pt 可能比 latest.pt 新（eval 后才崩溃）：有 best.pt 以它为准，否则退回 latest.pt 里的 extra
        best_ck = run_dir / "checkpoints" / "best.pt"
        best_extra = load_checkpoint(best_ck, map_location="cpu")["extra"] if best_ck.exists() else resume["extra"]
        best = tuple(best_extra["best"]) if best_extra.get("best") is not None else None
    if not (run_dir / "env.json").exists():
        _update_env_json(run_dir, stg_rl=stg_rl.build_info(), train_repo_sha=git_sha(),
                         action_table_version=ACTION_TABLE_VERSION, machine=machine_info())

    envw = EnvWrapper(cfg, images, starts, device, seed=int(cfg["run"]["seed"]) + start - 1)  # Ruling 7
    reward_fn = RewardFn(cfg)
    tracker = EpisodeTracker(envw.n, device, list(reward_fn.terms), cfg["reward"]["hold_radius"],
                             cfg["reward"]["edge_margin"], envw.frame_skip, cfg["intent"]["interval"][1])
    if resume is not None:
        # 崩溃残留 / 上次提前退出可能在 checkpoint 之后又写了日志，续训前截掉，避免重复行与 TB 回退步
        truncate_after(run_dir / "metrics.jsonl", int(resume["update"]))
        truncate_after(run_dir / "perf.jsonl", int(resume["update"]))
    # logger 的 x 轴是 post-increment env_steps，checkpoint 那个 update 恰好记在 resume["env_steps"]；
    # SummaryWriter(purge_step=s) 删的是 step >= s 的点，故传 env_steps + 1，只清 checkpoint 之后的
    # 崩溃残留，而不误删 update U 自己的 ppo/*、eval/* 点。
    logger = MetricsLogger(run_dir, bool(cfg["log"]["tensorboard"]),
                           purge_step=env_steps + 1 if resume is not None else None)
    perf_writer = PerfWriter(run_dir / "perf.jsonl")
    sampler = LoadSampler(perf_writer, float(cfg["log"]["sample_hz"]))
    timer = PhaseTimer(int(cfg["log"]["perf_sync_every"]), device)
    steps_per_iter = int(cfg["ppo"]["num_steps"]) * envw.n * envw.frame_skip
    ckpt_dir = run_dir / "checkpoints"
    phase_rows: list[dict] = []
    budget_s = float(cfg["run"]["max_minutes"]) * 60.0  # 0 = 不限时；到点把当前 update 当最后一个
    t_start = time.perf_counter()
    stopped_early = None
    say = lambda text: print(text, flush=True)  # noqa: E731 —— 接 tee 时 stdout 块缓冲，必须 flush
    progress = console.Throttle(console.PROGRESS_EVERY_S)
    say(console.banner(run_dir, device, len(images), len(starts), sum(len(s.ranks) for s in specs), cfg, start))

    sampler.start()
    try:
        obs = envw.reset()
        for update in range(start, total + 1):
            timer.start_iteration(update)
            t0 = time.perf_counter()
            obs, container, next_value = ppo.rollout(envw, featurizer, reward_fn, tracker, timer, obs)
            with timer.phase("update"):
                stats = ppo.train_step(container, next_value, update, total)
            env_steps += steps_per_iter
            scalars = {f"ppo/{k}": v for k, v in stats.items()}
            scalars.update(summarize_episodes(tracker.pop_finished(), "ep/"))
            scalars["perf/sps"] = steps_per_iter / (time.perf_counter() - t0)
            row = timer.pop_iteration()
            if row is not None:
                phase_rows.append(row)
                perf_writer.write({"kind": "phase", "update": update, **row})
                scalars.update({f"perf/{k}": v for k, v in row.items()})
            logger.log(update, env_steps, scalars)
            now = time.perf_counter()
            last = update == total or (budget_s > 0 and now - t_start >= budget_s)
            if progress.ready(now) or last:
                done = update - start + 1
                say(console.progress_line(update, total, env_steps, now - t_start,
                                          console.eta(done, total - update, now - t_start), scalars))

            if specs and (update % int(cfg["run"]["eval_every"]) == 0 or last):
                t_eval = time.perf_counter()
                res = evaluate(cfg, ppo, featurizer, images, specs, device)
                (run_dir / "eval" / f"{update}.json").write_text(json.dumps(res, indent=2, ensure_ascii=False),
                                                               encoding="utf-8")
                logger.log(update, env_steps, {f"eval/{k}": v for k, v in res["overall"].items()})
                sc = score(res["overall"])
                is_best = best is None or sc > best
                if is_best:
                    best = sc
                    save_checkpoint(ckpt_dir / "best.pt", ppo=ppo, update=update, env_steps=env_steps, cfg=cfg,
                                    extra={"best": list(best), "eval": res["overall"]})
                say(console.eval_block(update, res, is_best, time.perf_counter() - t_eval))

            if update % int(cfg["run"]["ckpt_every"]) == 0 or last:
                save_checkpoint(ckpt_dir / "latest.pt", ppo=ppo, update=update, env_steps=env_steps, cfg=cfg,
                                extra={"best": list(best) if best is not None else None})
                saved = ["latest.pt"]
                if update % int(cfg["run"]["ckpt_every"]) == 0:
                    shutil.copyfile(ckpt_dir / "latest.pt", ckpt_dir / f"u{update}.pt")
                    saved.append(f"u{update}.pt")
                say(console.ckpt_line(update, saved))
            if last and update != total:
                stopped_early = update
                say(f"到达 run.max_minutes={cfg['run']['max_minutes']}，在 update {update} 停止")
                break
    finally:
        sampler.stop()
        perf_writer.close()
        logger.close()

    say(console.finish_line(update, env_steps, time.perf_counter() - t_start, best, stopped_early is not None))
    _update_env_json(run_dir, perf_summary=summarize(phase_rows, sampler.summary(), steps_per_iter),
                     stopped_early_at_update=stopped_early)
    plots.plot_runs({run_dir.name: read_jsonl(run_dir / "metrics.jsonl")}, run_dir / "plots")
    plots.plot_load(plots.load_perf(run_dir / "perf.jsonl"), run_dir / "plots")
    if pack_result:
        print(f"结果包：{pack(run_dir)}", flush=True)
    return run_dir


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m stgtrain.train")
    ap.add_argument("config", nargs="?", help="配置 TOML（--resume 时省略）")
    ap.add_argument("name", nargs="?", default="run", help="运行名，拼进结果目录名")
    ap.add_argument("--resume", metavar="RUN_DIR", help="从 RUN_DIR/checkpoints/latest.pt 续训")
    ap.add_argument("--bench", action="store_true", help="只测吞吐（spec §7.3）")
    ap.add_argument("--runs-dir", default="runs")
    ap.add_argument("--total-updates", type=int, default=None, help="覆盖 run.total_updates（续训加长用）")
    ap.add_argument("--no-pack", action="store_true", help="不打 tar.gz")
    args = ap.parse_args(argv)
    overrides = {"run": {"total_updates": args.total_updates}} if args.total_updates is not None else {}

    if args.resume:
        run_dir = Path(args.resume)
        ck = load_checkpoint(run_dir / "checkpoints" / "latest.pt")
        cfg = from_dict(deep_merge(ck["cfg"], overrides))
        ck = load_checkpoint(run_dir / "checkpoints" / "latest.pt", map_location=pick_device(cfg["run"]["device"]))
        train(cfg, run_dir, resume=ck, pack_result=not args.no_pack)
        return 0
    if not args.config:
        ap.error("需要配置文件，或 --resume RUN_DIR")
    cfg = load_config(args.config, overrides or None)
    if args.bench:
        from .bench import run_bench

        run_bench(cfg, make_run_dir(Path(args.runs_dir), f"bench-{args.name}"))
        return 0
    train(cfg, make_run_dir(Path(args.runs_dir), args.name), pack_result=not args.no_pack)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
