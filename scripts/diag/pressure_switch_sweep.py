"""自动压力切换的仿真验证：boss_or_free_v1 扫阈值。批量跑 20 组 × 32 局，报 60 s / 30 s 撑过率、自由档占比、切换次数。"""
import sys, json, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.envwrap import EnvWrapper
from stgtrain.episodes import EpisodeTracker
from stgtrain.reward import RewardFn

ckp, on, radius, out = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
ck = load_checkpoint(ckp, map_location="cpu")
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"},
      "intent": {"name": "boss_or_free_v1", "pressure_on": on, "pressure_off": on // 2, "pressure_radius": radius}}))
device = pick_device("cpu"); torch.set_num_threads(8)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
groups = [(sp.card, rk) for sp in specs for rk in sp.ranks]; K = 32
envw = EnvWrapper(cfg, {}, [], device, seed=int(cfg["eval"]["seed"]), num_envs=K, mirror=False,
                  groups=[({c: images[c]}, stg_rl.Start(c, 0, r)) for c, r in groups])
rf = RewardFn(cfg)
tr = EpisodeTracker(envw.n, device, list(rf.terms), cfg["reward"]["hold_radius"], cfg["reward"]["edge_margin"],
                    envw.frame_skip, cfg["intent"]["interval"][1])
first = {}; obs = envw.reset()
for step in range(int(cfg["env"]["max_frames"]) + 2):
    nxt, info = envw.step(ppo.act(feat(obs), True))
    total, raw = rf(obs, nxt, info); tr.update(obs, nxt, info, total, raw); obs = nxt
    if (step + 1) % 64 == 0:
        for r in tr.pop_finished(): first.setdefault(r["env"], r)
        if len(first) == envw.n: break
for r in tr.pop_finished(): first.setdefault(r["env"], r)
parts = envw.intent.parts
res = {"on": on, "radius": radius, "free_frac": sum(p.free_frames for p in parts) / max(1, sum(p.total_frames for p in parts)),
       "switches_per_min": sum(p.switches for p in parts) / max(1, sum(p.total_frames for p in parts)) * 3600, "by": {}}
for rank in (2, 3):
    recs = [first[g * K + i] for g, (c, rk) in enumerate(groups) if rk == rank for i in range(K)]
    boss = [first[g * K + i] for g, (c, rk) in enumerate(groups) if rk == rank and "_w" not in c for i in range(K)]
    s60 = lambda rs: sum(1 for r in rs if r["done"] != 1) / len(rs)
    s30 = lambda rs: sum(1 for r in rs if not (r["done"] == 1 and r["frames"] <= 1800)) / len(rs)
    res["by"][f"r{rank}"] = {"surv60": s60(recs), "surv30": s30(recs), "boss_surv60": s60(boss), "boss_surv30": s30(boss),
                             "edge": sum(r["edge_frac"] for r in recs) / len(recs)}
json.dump(res, open(out, "w"))
print(json.dumps(res, ensure_ascii=False))
