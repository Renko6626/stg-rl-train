"""跟进诊断：贴边死亡是「被指挥过去的」「最后一秒被逼过去的」还是「一直赖在那儿」？只记自机与目标点轨迹，很快。"""
import sys, json, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import eval_cfg
from stgtrain.envwrap import EnvWrapper
ck = load_checkpoint(sys.argv[1], map_location="cpu"); EPS = int(sys.argv[2]); out = sys.argv[3]; INTENT = sys.argv[4] if len(sys.argv) > 4 else ""
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}, **({"eval": {"intent": INTENT}} if INTENT else {})})); device = pick_device("cpu"); torch.set_num_threads(8)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
def wall(xy):  # 到最近边的距离（左右 ±192、下 448、上 0）
    return torch.minimum(torch.minimum(192 - xy[..., 0].abs(), 448 - xy[..., 1]), xy[..., 1])
HIT = 7; res = {}
for sp in specs:
    for rank in sp.ranks:
        c = eval_cfg(cfg)
        envw = EnvWrapper(c, {sp.card: images[sp.card]}, [stg_rl.Start(sp.card, 0, rank)], device,
                          seed=int(c["eval"]["seed"]), num_envs=EPS, mirror=False)
        obs = envw.reset(); P, T = [], []
        first_done = torch.zeros(EPS, dtype=torch.bool); deaths = []
        alive_frames = 0; edge_frames = 0; tgt_edge_frames = 0
        for step in range(int(c["env"]["max_frames"]) + 2):
            P.append(obs.player_xy.clone()); T.append(obs.target_xy.clone())
            live = ~first_done
            alive_frames += int(live.sum()); edge_frames += int((live & (wall(obs.player_xy) <= 16)).sum())
            tgt_edge_frames += int((live & (wall(obs.target_xy) <= 40)).sum())
            nxt, info = envw.step(ppo.act(feat(obs), True)); done = info.done.cpu()
            for env in (done != 0).nonzero().flatten().tolist():
                if first_done[env]: continue
                first_done[env] = True
                if done[env] == 1:
                    h = max(0, len(P) - HIT)
                    def at(k): i = max(0, h - k); return float(wall(P[i][env]))
                    seg = torch.stack([wall(p[env]) for p in P[max(0, h - 120):h + 1]])
                    deaths.append({"w0": at(0), "w30": at(30), "w60": at(60), "w120": at(120),
                                   "tgt_wall": float(wall(T[h][env])), "tgt_dist": float((T[h][env] - P[h][env]).norm()),
                                   "edge_frac_last120": float((seg <= 16).float().mean()), "step": step})
            obs = nxt
            if bool(first_done.all()): break
        res[f"{sp.card}_r{rank}"] = {"deaths": deaths, "alive_frames": alive_frames, "edge_frames": edge_frames,
                                     "tgt_edge_frames": tgt_edge_frames}
        print(sp.card, rank, len(deaths), flush=True); json.dump(res, open(out, "w"))
