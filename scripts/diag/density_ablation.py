"""CPU同权重密度分支消融；复用生产特征化、环境与首局评测。"""
from __future__ import annotations

import argparse
import copy
import faulthandler
import hashlib
import json
import os
import platform
import time
from pathlib import Path

import stg_rl
import tensordict
import torch

from stgtrain.cards import EvalSpec, discover, load_splits
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict
from stgtrain.envwrap import EnvWrapper
from stgtrain.evaluate import evaluate, summarize_eval
from stgtrain.train import build_components

CHECKPOINT = "runs/job-b3ef72c1ca44515d/20261006-151317-request-light-shift-k8/checkpoints/best.pt"
CHECKPOINT_SHA = "8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88"
DENSE = {"th06_s2_b6", "th06_s3_w12", "th06_s3_mb3", "th06_s4_w16"}
LASER = {"th06_s4_w16", "th06_s4_b12", "th06_s1_b3"}


def sha(path: Path) -> str:
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def write_json(path: Path, value) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


class GreedyPolicy:
    """evaluate的act接口；纯FP32推理，不构建optimizer或编译训练图。"""

    def __init__(self, model, label: str):
        self.model, self.label = model, label
        self.calls, self.samples = 0, 0
        self.started = time.perf_counter()

    def act(self, feats, greedy):
        if not greedy:
            raise ValueError("即时消融只允许贪心评测")
        self.calls += 1
        self.samples += feats["player"].shape[0]
        if self.calls % 256 == 0:
            print(json.dumps({"progress": self.label, "calls": self.calls, "frame_samples": self.samples,
                              "elapsed_s": round(time.perf_counter() - self.started, 2),
                              "cpu_s": round(time.process_time(), 2)}, ensure_ascii=False), flush=True)
        return self.model(feats)[0].argmax(-1)


def pair_summary(on: list[dict], off: list[dict]) -> dict:
    def keyed(rows):
        out = {(r["card"], r["rank"], r["eval_seed"], r["env"]): r for r in rows}
        if len(out) != len(rows):
            raise ValueError("逐局ID重复")
        return out

    a, b = keyed(on), keyed(off)
    if a.keys() != b.keys():
        raise ValueError("两臂逐局ID不匹配")
    groups = {"overall": lambda card: True}
    if all(r["pool"] in ("original", "preflight") for r in on + off):
        groups.update(dense=lambda card: card in DENSE,
                      ordinary=lambda card: card not in LASER, laser=lambda card: card in LASER)
    result = {}
    for name, select in groups.items():
        keys = [k for k in a if select(k[0])]
        if not keys:
            continue
        sa = summarize_eval([a[k] for k in keys])
        sb = summarize_eval([b[k] for k in keys])
        result[name] = {"cnn": sa, "none": sb,
                        "delta_survival_pp": 100 * (sb["survival"] - sa["survival"]),
                        "cnn_survived_none_failed": sum(a[k]["done"] == 2 and b[k]["done"] != 2 for k in keys),
                        "cnn_failed_none_survived": sum(a[k]["done"] != 2 and b[k]["done"] == 2 for k in keys)}
    result["by_card_rank"] = {}
    for card, rank in sorted({(k[0], k[1]) for k in a}):
        keys = [k for k in a if k[:2] == (card, rank)]
        na = sum(a[k]["done"] == 2 for k in keys)
        nb = sum(b[k]["done"] == 2 for k in keys)
        result["by_card_rank"][f"{card}/r{rank}"] = {
            "episodes": len(keys), "cnn_survived": na, "none_survived": nb,
            "delta_survival_pp": 100 * (nb - na) / len(keys)}
    return result


def main():
    faulthandler.dump_traceback_later(120, repeat=True)
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checkpoint", type=Path, default=Path(CHECKPOINT))
    ap.add_argument("--out", type=Path, default=Path("runs/density-ablation-20261008"))
    ap.add_argument("--torch-threads", type=int, default=4)
    ap.add_argument("--env-threads", type=int, default=4)
    ap.add_argument("--preflight-only", action="store_true")
    a = ap.parse_args()
    print(f"读取基线 pid={os.getpid()}", flush=True)
    a.out.mkdir(parents=True, exist_ok=True)
    if (a.out / "manifest.json").exists():
        raise FileExistsError(f"拒绝覆盖已有实验：{a.out}")
    if sha(a.checkpoint) != CHECKPOINT_SHA:
        raise ValueError("基线checkpoint SHA不一致")
    info = stg_rl.build_info()
    if info["version"] != "0.4.2" or str(info["engine_ver"]) != "24":
        raise ValueError(f"需要stg_rl0.4.2/ENGINE_VER24，实际{info}")
    torch.set_num_threads(a.torch_threads)
    torch.set_num_interop_threads(1)
    device = torch.device("cpu")
    ck = load_checkpoint(a.checkpoint, map_location="cpu")
    print("checkpoint已读取", flush=True)
    cfg = from_dict(ck["cfg"])
    cfg["run"].update(device="cpu", torch_threads=a.torch_threads)
    cfg["env"]["threads"] = a.env_threads
    cfg["eval"].update(seed=12345, greedy=True, batched=True, motor="train")
    assert cfg["model"]["name"] == "set_attn_v3"
    assert cfg["featurize"]["name"] == "danger_topk_v8" and cfg["featurize"]["k_lasers"] == 8
    assert cfg["env"]["frame_skip"] == 1 and cfg["motor"]["enabled"]
    print("构建生产评测组件", flush=True)
    images, starts, original, feat, factory = build_components(cfg, device)
    print("生产评测组件已构建", flush=True)
    original = [EvalSpec(s.card, tuple(s.ranks), 32) for s in original]
    specialist = [EvalSpec(s.card, (2, 3), 32)
                  for s in load_splits("eval/splits-laser-specialist.toml", 32)]
    assert len(original) == 13 and all(s.ranks == (2, 3) for s in original)
    assert len(specialist) == 5
    assert not {s.card for s in original + specialist} & {s.image for s in starts}
    cards = discover(cfg["env"]["cards_dir"])
    paths = sorted(set(Path("src/stgtrain").rglob("*.py")) |
                   {Path(__file__), Path("cards/density.json"), Path("eval/splits-laser.toml"),
                    Path("eval/splits-laser-specialist.toml"),
                    Path("magnus/wheels/stg_rl-0.4.2-cp310-abi3-manylinux_2_34_x86_64.whl")} |
                   {p for c in cards.values() for p in c.path.rglob("*") if p.is_file()})
    manifest = {"pid": os.getpid(), "python": platform.python_version(), "torch": torch.__version__,
                "tensordict": tensordict.__version__, "engine": info,
                "cpu_affinity": sorted(os.sched_getaffinity(0)),
                "checkpoint": {"path": str(a.checkpoint.resolve()), "sha256": CHECKPOINT_SHA,
                               "update": ck["update"], "env_steps": ck["env_steps"]},
                "source_cfg": ck["cfg"], "eval_cfg": cfg,
                "files": {str(p): sha(p) for p in paths}, "preflight_only": a.preflight_only,
                "arms": {"cnn": "原模型FP32", "none": "仅主干前density64维输出置零"}}
    write_json(a.out / "manifest.json", manifest)
    print("manifest已写入", flush=True)
    net = factory().eval()
    # agent wrapper仅增加model.前缀；所有张量严格加载，不用partial load。
    net.load_state_dict({k.removeprefix("model."): v for k, v in ck["state"]["agent"].items()}, strict=True)
    print(json.dumps({"started": manifest["pid"], "engine": info, "torch": torch.__version__,
                      "torch_threads": a.torch_threads, "env_threads": a.env_threads,
                      "bullets_cap": cfg["env"]["bullets_cap"]}), flush=True)
    with torch.inference_mode():
        spec = original[0]
        env = EnvWrapper(cfg, {spec.card: images[spec.card]},
                         [stg_rl.Start(spec.card, 0, spec.ranks[0])], device,
                         seed=12345, num_envs=32, mirror=False)
        f = feat(env.reset())
        before = net(f)
        net.density_enabled = True
        explicit = net(f)
        assert all(torch.equal(x, y) for x, y in zip(before, explicit))
        net.density_enabled = False
        disabled = net(f)
        changed = net(dict(f, density=torch.full_like(f["density"], 100.0)))
        assert all(torch.equal(x, y) for x, y in zip(disabled, changed))
        # 独立验证切断的是64维最终输出，而不是仅把输入网格清零。
        captured = []
        hook = net.trunk.register_forward_pre_hook(lambda _module, args: captured.append(args[0].clone()))
        net(f)
        hook.remove()
        assert torch.count_nonzero(captured[0][:, 384:448]).item() == 0
        del env, f, captured
        write_json(a.out / "preflight.json", {"default_matches_enabled": True,
                                               "disabled_ignores_density": True,
                                               "disabled_trunk_density_is_zero": True})
        if a.preflight_only:
            work = [("preflight", "follow", original[:1])]
        else:
            work = [("original", "follow", original), ("original", "free", original),
                    ("specialist", "free", specialist)]
        summaries = {}
        for pool, intent, specs in work:
            records = {}
            for arm in ("cnn", "none"):
                net.density_enabled = arm == "cnn"
                current = copy.deepcopy(cfg)
                current["eval"]["intent"] = "follow_player_v1" if intent == "free" else "lower_half_uniform_v1"
                label = f"{pool}-{intent}-{arm}"
                print(f"开始 {label}", flush=True)
                policy = GreedyPolicy(net, label)
                started = time.perf_counter()
                res = evaluate(current, policy, feat, images, specs, device, include_records=True)
                rows = [{**r, "pool": pool, "intent": intent, "arm": arm, "checkpoint_update": ck["update"]}
                        for r in res["records"]]
                res["records"] = rows
                expected = sum(len(s.ranks) * s.episodes for s in specs)
                assert len(rows) == expected
                assert summarize_eval(rows) == res["overall"]
                res["elapsed_s"] = time.perf_counter() - started
                write_json(a.out / f"{label}.json", res)
                records[arm] = rows
                print(json.dumps({"finished": label, "episodes": expected,
                                  "survival": res["overall"]["survival"],
                                  "elapsed_s": round(res["elapsed_s"], 2)}), flush=True)
            summaries[f"{pool}-{intent}"] = pair_summary(records["cnn"], records["none"])
            write_json(a.out / "summary.json", summaries)
    # 输入产物不可在评测期间悄悄变化。
    assert all(sha(Path(p)) == expected for p, expected in manifest["files"].items())
    write_json(a.out / "complete.json", {"episodes": 128 if a.preflight_only else 3968,
                                         "input_hashes_unchanged": True,
                                         "summary_sha256": sha(a.out / "summary.json")})
    print("即时消融完成", flush=True)
    faulthandler.cancel_dump_traceback_later()


if __name__ == "__main__":
    main()
