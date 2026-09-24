"""诊断：打死自机的那颗弹，死前 N 帧时在不在 top-K 里？不改仓库。

做法：自己跑评测循环，环形缓冲存最近 32 帧的弹表与入选掩码。某 env 第一局死亡（done==1）时，
取末帧「一帧后离自机最近」的弹当凶手，沿它的速度反推 k 帧前的位置，在那一帧的弹表里找 3px 内最近的弹，
看它当时入没入选。对照组：每局随机抽的存活帧上，同样取「此刻最近的弹」反推（= 没打死人的近身弹）。
"""
import sys, json, collections, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import eval_cfg
from stgtrain.envwrap import EnvWrapper
from stgtrain.featurize.danger_topk_v1 import closest_approach

ck = load_checkpoint(sys.argv[1], map_location="cpu"); EPS = int(sys.argv[2]); out_path = sys.argv[3]; INTENT = sys.argv[4] if len(sys.argv) > 4 else ""
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}, **({"eval": {"intent": INTENT}} if INTENT else {})}))
device = pick_device("cpu"); torch.set_num_threads(8)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
K, DMAX, HZ = feat.kb, feat.d_max, feat.horizon
LAGS = (1, 3, 5, 10, 15, 20, 30); RING = 46; HITWIN = 12

def select_mask(obs):
    pos = obs.player_xy[:, None, :]
    pb = obs.bullets[..., 0:2] - pos
    vb = obs.bullets[..., 2:4] - feat.player_velocity(obs)[:, None, :]
    dmin, _ = closest_approach(pb, vb, obs.bullets[..., 4] + obs.player_hit_r[:, None], HZ)
    dmin = dmin.masked_fill(~obs.bullets_mask, float("inf"))
    kth = dmin.sort(1).values[:, K - 1:K]
    sel = (dmin <= kth) & (dmin <= DMAX) & obs.bullets_mask
    n_danger = (dmin <= DMAX).sum(1)
    return sel, n_danger

def find_hit(ring, env):
    """引擎判中弹后约 6–7 帧才给 done（决死窗口，凶手已被清掉）。在末 HITWIN 帧里找边距最小的那帧当命中帧。
    返回 (命中帧在 ring 里的倒数下标 h>=1, 凶手行号, 边距)。"""
    best = (None, None, float("inf"))
    for h in range(1, min(HITWIN, len(ring)) + 1):
        b, m, _sel, _nd, pxy, hr = ring[-h]
        d = ((b[env, :, 0:2] - pxy[env]).norm(dim=-1) - b[env, :, 4] - hr[env]).masked_fill(~m[env], float("inf"))
        j = int(d.argmin())
        if float(d[j]) < best[2]: best = (h, j, float(d[j]))
    return best


def backtrack(ring, env, lag, bx, by, bvx, bvy, base=1):
    """凶手 lag 帧前应在 (bx - lag*vx, by - lag*vy)；在那帧弹表里找 3px 内最近的。返回 1 入选 / 0 没入选 / None 没找到。"""
    if base + lag - 1 > len(ring): return None
    b, m, sel, nd, _p, _h = ring[-(base + lag - 1)]
    px, py = bx - (lag - 1) * bvx, by - (lag - 1) * bvy      # ring[-1] 就是末帧（lag=1）
    d = ((b[env, :, 0] - px) ** 2 + (b[env, :, 1] - py) ** 2).sqrt().masked_fill(~m[env], float("inf"))
    j = int(d.argmin())
    if not torch.isfinite(d[j]) or d[j] > 3.0: return None
    return int(sel[env, j]), int(nd[env] > K)

def nearest_after_one_frame(obs, env):
    b = obs.bullets[env]; m = obs.bullets_mask[env]
    p = obs.player_xy[env]
    nx = b[:, 0:2] + b[:, 2:4] - p
    d = (nx.norm(dim=-1) - b[:, 4] - obs.player_hit_r[env]).masked_fill(~m, float("inf"))
    j = int(d.argmin()); return j, float(d[j])

results = {}
g = torch.Generator().manual_seed(0)
for sp in specs:
    for rank in sp.ranks:
        c = eval_cfg(cfg)
        envw = EnvWrapper(c, {sp.card: images[sp.card]}, [stg_rl.Start(sp.card, 0, rank)], device,
                          seed=int(c["eval"]["seed"]), num_envs=EPS, mirror=False)
        obs = envw.reset(); ring = collections.deque(maxlen=RING)
        first_done = torch.zeros(EPS, dtype=torch.bool)
        deaths, ctrl = [], []
        max_steps = int(c["env"]["max_frames"]) // envw.frame_skip + 2
        for step in range(max_steps):
            sel, nd = select_mask(obs)
            ring.append((obs.bullets.clone(), obs.bullets_mask.clone(), sel, nd, obs.player_xy.clone(), obs.player_hit_r.clone()))
            action = ppo.act(feat(obs), True)
            nxt, info = envw.step(action)
            done = info.done.cpu()
            for env in range(EPS):
                if first_done[env]: continue
                if done[env] != 0:
                    first_done[env] = True
                    if done[env] == 1:
                        h, j, dist = find_hit(ring, env)
                        b = ring[-h][0][env, j]
                        rec = {"dist": dist, "step": step, "hit_lag": h,
                               "x": float(ring[-h][4][env, 0]), "y": float(ring[-h][4][env, 1])}
                        rec["n_danger"] = int(ring[-h][3][env]); rec["rank"] = rank; rec["card"] = sp.card
                        if dist < 4.0:
                            for lag in LAGS:
                                rec[lag] = backtrack(ring, env, lag, float(b[0]), float(b[1]), float(b[2]), float(b[3]), base=h)
                        deaths.append(rec)
                elif step >= RING and torch.rand(1, generator=g).item() < 0.01:
                    # 对照：存活帧上「一帧后最近」且确实贴身（<24px）的弹
                    j, dist = nearest_after_one_frame(obs, env)
                    if dist < 24.0:
                        b = obs.bullets[env, j]; rec = {"dist": dist}
                        for lag in LAGS:
                            rec[lag] = backtrack(ring, env, lag, float(b[0]), float(b[1]), float(b[2]), float(b[3]))
                        ctrl.append(rec)
            obs = nxt
            if bool(first_done.all()): break
        key = f"{sp.card}_r{rank}"; results[key] = {"deaths": deaths, "ctrl": ctrl, "episodes": EPS}
        nb = [d for d in deaths if d["dist"] < 4.0]
        def unseen(rs, lag):
            v = [r[lag] for r in rs if r.get(lag) is not None]
            return (sum(1 for s, _ in v if not s), len(v))
        print(key, f"死 {len(deaths)}/{EPS}（弹致死 {len(nb)}）",
              " ".join(f"t-{l}:{unseen(nb,l)[0]}/{unseen(nb,l)[1]}" for l in LAGS),
              "| 对照", " ".join(f"t-{l}:{unseen(ctrl,l)[0]}/{unseen(ctrl,l)[1]}" for l in (5, 10, 20)), flush=True)
        json.dump(results, open(out_path, "w"))
