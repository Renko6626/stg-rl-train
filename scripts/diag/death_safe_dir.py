"""死亡分类：死前最后一个还来得及的决策点上，有没有安全的走法？（为「每个方向按住 N 帧会怎样」这类特征找依据）

对每次弹致死：命中帧 h（done 前 12 帧里弹边距最小的那帧）。决策帧 f = max(这一段方向开始执行的那帧, h − LOOK)。
在 f 的局面上，用**线性外推**对 9 方向 × 高 / 低速共 18 个动作各算「按住 H = h − f + 1 帧」的最小净距
（自机位置钳在场内；弹按各自速度直线走），再看实际执行的那个动作：
  A  执行的动作按外推会撞（净距 < 0），而存在净距 ≥ MARGIN 的动作      → 预测 / 选择的问题，给它算好的特征有用
  B  18 个动作按外推全都会撞（或都 < MARGIN）                          → 已被逼进死局：更早的站位 / 能力上限
  C  执行的动作按外推是安全的，却还是死了                              → 弹非直线 / 新生成的弹 / 外推口径之外
"""
import sys, json, collections, math, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import eval_cfg
from stgtrain.envwrap import EnvWrapper

ck = load_checkpoint(sys.argv[1], map_location="cpu"); EPS = int(sys.argv[2]); out_path = sys.argv[3]
INTENT = sys.argv[4] if len(sys.argv) > 4 else ""
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}, **({"eval": {"intent": INTENT}} if INTENT else {})}))
device = pick_device("cpu"); torch.set_num_threads(8)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
RING, HITWIN, LOOK, MARGIN, SLOW_SPEED = 64, 12, 8, 2.0, 2.0
DIRS = [(0, 0), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]   # 动作表 v1：0 不动 1 上 2 右上 … 顺时针

def clearance(b, m, p, hit_r, speed, H):
    """[18] 每个动作按住 H 帧的最小净距（线性外推）。"""
    out = []
    bp, bv, br = b[m][:, 0:2], b[m][:, 2:4], b[m][:, 4]
    for a in range(18):
        dx, dy = DIRS[a // 2]; sp = SLOW_SPEED if a % 2 else speed
        n = math.hypot(dx, dy) or 1.0
        v = torch.tensor([dx / n * sp, dy / n * sp])
        best = float("inf"); pos = p.clone()
        for t in range(1, H + 1):
            pos = pos + v
            pos[0] = pos[0].clamp(-192.0, 192.0); pos[1] = pos[1].clamp(0.0, 448.0)
            if bp.shape[0]:
                d = ((bp + bv * t) - pos).norm(dim=-1) - br - hit_r
                best = min(best, float(d.min()))
        out.append(best)
    return out

res = {}
for sp in specs:
    for rank in sp.ranks:
        c = eval_cfg(cfg)
        envw = EnvWrapper(c, {sp.card: images[sp.card]}, [stg_rl.Start(sp.card, 0, rank)], device,
                          seed=int(c["eval"]["seed"]), num_envs=EPS, mirror=False)
        obs = envw.reset(); ring = collections.deque(maxlen=RING)
        first_done = torch.zeros(EPS, dtype=torch.bool); deaths = []
        for step in range(int(c["env"]["max_frames"]) + 2):
            nxt, info = envw.step(ppo.act(feat(obs), True))
            ring.append((obs.bullets.clone(), obs.bullets_mask.clone(), obs.player_xy.clone(), obs.player_hit_r.clone(),
                         obs.player_speed.clone(), nxt.prev_action.clone()))     # 末项 = 这一帧实际执行的动作
            done = info.done.cpu()
            for env in (done != 0).nonzero().flatten().tolist():
                if first_done[env]: continue
                first_done[env] = True
                if done[env] != 1: continue
                # 命中帧
                h, hd = 1, float("inf")
                for k in range(1, min(HITWIN, len(ring)) + 1):
                    b, m, p, hr, _s2, _a = ring[-k]
                    d = ((b[env, :, 0:2] - p[env]).norm(dim=-1) - b[env, :, 4] - hr[env]).masked_fill(~m[env], float("inf")).min()
                    if float(d) < hd: h, hd = k, float(d)
                if hd >= 4.0:
                    deaths.append({"cls": "other", "rank": rank}); continue
                # 这一段方向从哪帧开始：往回找执行方向不变的连续段
                a_hit = int(ring[-h][5][env]); k = h
                while k + 1 <= len(ring) and int(ring[-(k + 1)][5][env]) // 2 == a_hit // 2: k += 1
                seg_start = k                                   # ring[-seg_start] 是这一段的第一帧
                f = min(seg_start, h + LOOK, len(ring))         # 决策帧（倒数下标，越大越早）
                H = f - h + 1
                b, m, p, hr, spd, _a = ring[-f]
                cl = clearance(b[env], m[env], p[env], float(hr[env]), float(spd[env]), H)
                a_exec = int(ring[-f][5][env])
                # 这 H 帧里低速位可能变过：执行动作取决策帧那一帧的
                exec_cl, best = cl[a_exec], max(cl)
                cls = "C" if exec_cl >= 0 else ("A" if best >= MARGIN else "B")
                deaths.append({"cls": cls, "rank": rank, "H": H, "seg_len": seg_start - h + 1, "exec_cl": exec_cl, "best_cl": best,
                               "n_safe": sum(1 for v in cl if v >= MARGIN), "a_exec": a_exec, "a_best": int(max(range(18), key=lambda i: cl[i]))})
            obs = nxt
            if bool(first_done.all()): break
        res[f"{sp.card}_r{rank}"] = deaths
        cnt = collections.Counter(d["cls"] for d in deaths)
        print(sp.card, rank, dict(cnt), flush=True); json.dump(res, open(out_path, "w"))
