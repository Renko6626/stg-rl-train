"""入口（spec §2.2）。

python -m stgtrain.train <config> [name]            训练
python -m stgtrain.train <config> [name] --init-from <checkpoint>  从权重开始新训练
python -m stgtrain.train --resume <run 目录> [--total-updates N]
python -m stgtrain.train <config> [name] --bench     测吞吐
"""
from __future__ import annotations

import argparse
import hashlib
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
from .cards import card_manifest, compile_cards, discover, load_splits, train_starts, start_intent_mixes
from .checkpoint import load_checkpoint, restore_rng, save_checkpoint
from .config import deep_merge, dump_toml, from_dict, load_config
from .curriculum import Curriculum
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


def initialize_from_checkpoint(ppo: PPO, cfg: dict, path: str | Path) -> dict:
    """新运行只继承兼容模型的权重，并返回可追溯的来源信息。"""
    return _initialize_checkpoint(ppo, cfg, path, density_ablation=False)


def initialize_density_from_checkpoint(ppo: PPO, cfg: dict, path: str | Path) -> dict:
    """v8/v3密度消融专用：仅允许density_enabled变化，全部张量仍严格加载。"""
    return _initialize_checkpoint(ppo, cfg, path, density_ablation=True)


def _initialize_checkpoint(ppo: PPO, cfg: dict, path: str | Path, *, density_ablation: bool) -> dict:
    path = Path(path).resolve()
    ck = load_checkpoint(path, map_location=ppo.device)
    source_cfg = from_dict(ck["cfg"])
    if density_ablation:
        for c in (source_cfg, cfg):
            if c["model"]["name"] != "set_attn_v3" or c["featurize"]["name"] != "danger_topk_v8":
                raise ValueError("密度消融初始化只支持danger_topk_v8/set_attn_v3")
            if not isinstance(c["model"].get("density_enabled", True), bool):
                raise ValueError("model.density_enabled须为布尔值")
    for section in ("model", "featurize"):
        source, target = source_cfg[section], cfg[section]
        different = [key for key in sorted(source.keys() | target.keys())
                     if source.get(key) != target.get(key)
                     and not (density_ablation and section == "model" and key == "density_enabled")]
        if different:
            fields = ", ".join(f"{section}.{key}" for key in different)
            raise ValueError(f"--init-from checkpoint 与新配置不兼容：{fields}")
    try:
        ppo.load_agent_state_dict(ck["state"]["agent"])
    except RuntimeError as exc:
        raise ValueError(f"--init-from checkpoint 模型权重不兼容：{path}\n{exc}") from exc
    with path.open("rb") as f:
        sha256 = hashlib.file_digest(f, "sha256").hexdigest()
    provenance = {
        "path": str(path), "sha256": sha256,
        "source_update": int(ck["update"]), "source_env_steps": int(ck["env_steps"]),
        "source_model": source_cfg["model"], "source_featurize": source_cfg["featurize"],
        "source_action_table_version": ck["action_table_version"],
    }
    source_env = path.parent.parent / "env.json"
    if source_env.exists():
        provenance["source_stg_rl"] = json.loads(source_env.read_text(encoding="utf-8")).get("stg_rl")
    if density_ablation:
        provenance["migration"] = {
            "kind": "density_ablation_v3",
            "model.density_enabled": {"source": source_cfg["model"].get("density_enabled", True),
                                      "target": cfg["model"].get("density_enabled", True)},
            "loaded_keys": sorted(ck["state"]["agent"]), "new_keys": [], "ignored_keys": [],
        }
    return provenance


def train(cfg: dict, run_dir: Path, resume: dict | None = None, pack_result: bool = True,
          *, init_from: str | Path | None = None, init_density_from: str | Path | None = None) -> Path:
    if sum(x is not None for x in (resume, init_from, init_density_from)) > 1:
        raise ValueError("--init-from、--init-density-from 与 --resume 不能同时使用")
    run_dir = Path(run_dir)
    device = pick_device(cfg["run"]["device"])
    total = int(cfg["run"]["total_updates"])
    if resume is not None and total <= int(resume["update"]):
        raise ValueError(f"total_updates={total} 不大于 checkpoint 的 update={resume['update']}，没有要续训的更新")
    torch.manual_seed(int(cfg["run"]["seed"]))
    torch.set_num_threads(int(cfg["run"]["torch_threads"]))
    dump_toml(cfg, run_dir / "config.toml")
    images, starts, specs, featurizer, factory = build_components(cfg, device)
    start_mixes = start_intent_mixes(discover(cfg["env"]["cards_dir"]), starts, cfg["intent"]["mix"],
                                     cfg["intent"].get("card_mix_enabled", False))
    ppo = PPO(cfg, factory, device)
    initial_checkpoint = initialize_from_checkpoint(ppo, cfg, init_from) if init_from is not None else None
    if init_density_from is not None:
        initial_checkpoint = initialize_density_from_checkpoint(ppo, cfg, init_density_from)

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
                         action_table_version=ACTION_TABLE_VERSION, machine=machine_info(),
                         # 起点顺序 = 课程权重向量的列序（curriculum.jsonl 按它回看）
                         starts=[f"{s.image}:{s.mark}:{s.rank}" for s in starts],
                         cards=card_manifest(discover(cfg["env"]["cards_dir"])),
                         start_intent_mixes=start_mixes)
    if initial_checkpoint is not None:
        _update_env_json(run_dir, initial_checkpoint=initial_checkpoint)
    if init_density_from is not None:
        save_checkpoint(run_dir / "checkpoints" / "u0.pt", ppo=ppo, update=0, env_steps=0, cfg=cfg,
                        extra={"initial_checkpoint": initial_checkpoint})
        # u0仅诊断，不参与best选择，不恢复源optimizer/课程/计数。
        for label, intent in (("follow", cfg["eval"]["intent"]), ("free", "follow_player_v1")):
            evaluation_cfg = deep_merge(cfg, {"eval": {"intent": intent}})
            res = evaluate(evaluation_cfg, ppo, featurizer, images, specs, device, include_records=True)
            (run_dir / "eval" / f"u0-{label}.json").write_text(json.dumps(res, ensure_ascii=False, indent=2))

    envw = EnvWrapper(cfg, images, starts, device, seed=int(cfg["run"]["seed"]) + start - 1,
                      start_intent_mixes=start_mixes)  # Ruling 7
    laser_indices = {i for i, s in enumerate(starts)
                     if discover(cfg["env"]["cards_dir"])[s.image].laser_intent_mix is not None}
    curriculum = Curriculum(len(starts), cfg["curriculum"], laser_indices=laser_indices)
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
                stats = ppo.train_step(container, next_value, update, total, timer=timer)
            env_steps += steps_per_iter
            scalars = {f"ppo/{k}": v for k, v in stats.items()}
            finished = tracker.pop_finished()
            scalars.update(summarize_episodes(finished, "ep/"))
            if curriculum.enabled:
                curriculum.observe(finished)
                if curriculum.due(update):
                    w = curriculum.weights()
                    envw.set_start_weights(w)
                    # 逐起点留档：聚合的 w_max/w_min 看不出「到底哪几张卡最难」，
                    # 事后要按卡回看就得有这份。列名在 env.json 的 starts 里。
                    with (run_dir / "curriculum.jsonl").open("a", encoding="utf-8") as f:
                        f.write(json.dumps({"update": update, "w": [round(x, 4) for x in w],
                                            "fail": [round(x, 4) for x in curriculum.fail.tolist()],
                                            "seen": curriculum.seen.tolist()}) + "\n")
                scalars.update(curriculum.stats())
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
                logger.log(update, env_steps, {f"eval/{k}": v for k, v in res["overall"].items()}
                           | {f"eval/{rk}/{k}": v for rk, d in res.get("by_rank", {}).items() for k, v in d.items()})
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
    checkpoint_args = ap.add_mutually_exclusive_group()
    checkpoint_args.add_argument("--resume", metavar="RUN_DIR", help="从 RUN_DIR/checkpoints/latest.pt 续训")
    checkpoint_args.add_argument("--init-from", metavar="CHECKPOINT", help="只继承模型权重，按新配置开始训练")
    checkpoint_args.add_argument("--init-density-from", metavar="CHECKPOINT", help="v8/v3密度消融专用严格权重初始化")
    ap.add_argument("--bench", action="store_true", help="只测吞吐（spec §7.3）")
    ap.add_argument("--runs-dir", default="runs")
    ap.add_argument("--total-updates", type=int, default=None, help="覆盖 run.total_updates（续训加长用）")
    ap.add_argument("--no-pack", action="store_true", help="不打 tar.gz")
    args = ap.parse_args(argv)
    if (args.init_from or args.init_density_from) and args.bench:
        ap.error("权重初始化仅用于训练，不能与 --bench 同时使用")
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
    train(cfg, make_run_dir(Path(args.runs_dir), args.name), pack_result=not args.no_pack,
          init_from=args.init_from, init_density_from=args.init_density_from)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
