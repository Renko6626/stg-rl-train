"""诊断：难卡上的弹致死 —— 凶手从哪来（含「从后方 / 下方来」）、死前有没有被看见、是不是非匀速弹。

对 checkpoint 在指定起点上跑贪心评测（带运动层，除非 MOTOR=off），环形缓冲存最近 RING 帧。
每局第一次 done == 1 时：
  1. 末 HITWIN 帧里找边距最小的那帧当命中帧、那颗弹当凶手（引擎判中后约 6–7 帧才给 done）；
  2. **逐帧往回追**凶手：在前一帧里找「位置 + 自身速度」离当前位置 3 px 内的弹（转弯 / 减速 / 反弹都跟得上，
     旧脚本沿末速度直线反推会跟丢）；
  3. 记录：命中前 10 帧凶手相对自机的方位（上 / 侧 / 下）、运动方向（向下飞 / 横飞 / 向上飞 = 从后方来）、
     命中前 5 / 10 帧是否在「按边缘距离最近的 K 颗」里、最近 20 帧速度方向变化角与速率变化、分量是否翻转（反弹）。
对照组（基准率）：存活帧上随机抽样，取离自机 48 px 内的全部有判定的弹，统计同样的方位 / 运动方向分布。

    PYTHONPATH=src python scripts/diag/hard_deaths.py <ckpt> <run_dir> <out.json> [intent] [episodes]
    MOTOR=off … 关掉运动层（只比撑过率）

起点取 run_dir/curriculum.jsonl 最后一条里死亡率最高的 TOP 个训练起点（这些是训练卡，诊断的是「难在哪」而非泛化）。
"""
import collections
import json
import math
import os
import sys

import stg_rl
import torch

from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import deep_merge, from_dict
from stgtrain.envwrap import EnvWrapper
from stgtrain.eval_ckpt import PPO, build_components, pick_device
from stgtrain.evaluate import eval_cfg

ckp, run_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
INTENT = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else ""
EPS = int(sys.argv[5]) if len(sys.argv) > 5 else 64
TOP = int(os.environ.get("TOP", 10))
RING, HITWIN, TRACK = 48, 12, 30

ck = load_checkpoint(ckp, map_location="cpu")
over = {"run": {"device": "cpu"}}
if INTENT:
    over["eval"] = {"intent": INTENT}
if os.environ.get("MOTOR") == "off":
    over["motor"] = {"enabled": False}
cfg = eval_cfg(from_dict(deep_merge(ck["cfg"], over)))
torch.set_num_threads(int(os.environ.get("THREADS", 16)))
images, _s, _specs, feat, factory = build_components(cfg, pick_device("cpu"))
ppo = PPO(cfg, factory, torch.device("cpu"))
ppo.load_state_dict(ck["state"])
K = int(cfg["featurize"]["k_bullets"])

starts = json.load(open(f"{run_dir}/env.json"))["starts"]
last = json.loads(open(f"{run_dir}/curriculum.jsonl").read().strip().splitlines()[-1])
hard = sorted(range(len(starts)), key=lambda i: -last["fail"][i])[:TOP]
groups = []
for i in hard:
    card, mark, rank = starts[i].split(":")
    groups.append((card, int(mark), int(rank), last["fail"][i]))
envw = EnvWrapper(cfg, {}, [], torch.device("cpu"), seed=int(cfg["eval"]["seed"]), num_envs=EPS, mirror=False,
                  groups=[({c: images[c]}, stg_rl.Start(c, m, r)) for c, m, r, _ in groups])
n = envw.n


def edge(b, m, pxy, hr):
    return ((b[..., 0:2] - pxy[:, None, :]).norm(dim=-1) - b[..., 4] - hr[:, None]).masked_fill(~m, float("inf"))


def near_k(b, m, pxy, hr):
    e = edge(b, m, pxy, hr)
    kth = e.topk(min(K, e.shape[1]), dim=1, largest=False).values[:, -1:]
    return (e <= kth) & m


def sector(dx, dy):
    """自机看凶手：屏幕 y 向下为正。上方 = 在自机上面（dy < 0）。按 ±45° 分三区。"""
    ang = math.degrees(math.atan2(dy, dx))       # 0 右、90 下、−90 上
    if -135 <= ang <= -45:
        return "上"
    if 45 <= ang <= 135:
        return "下"
    return "侧"


def heading(vx, vy):
    """弹往哪飞：向下飞 = 从上方压过来（常规）；向上飞 = 从后方来。"""
    if math.hypot(vx, vy) < 0.05:
        return "静止"
    ang = math.degrees(math.atan2(vy, vx))
    if 45 <= ang <= 135:
        return "向下飞"
    if -135 <= ang <= -45:
        return "向上飞"
    return "横飞"


ring = collections.deque(maxlen=RING)
first = [None] * n
deaths, base = [], collections.Counter()
base_head = collections.Counter()
g = torch.Generator().manual_seed(0)
obs = envw.reset()
for step in range(int(cfg["env"]["max_frames"]) + 2):
    sel = near_k(obs.bullets, obs.bullets_mask, obs.player_xy, obs.player_hit_r)
    ring.append((obs.bullets.clone(), obs.bullets_mask.clone(), sel, obs.player_xy.clone(), obs.player_hit_r.clone()))
    act = ppo.act(feat(obs), True)
    nxt, info = envw.step(act)
    done = info.done.cpu()
    # 基准率：约 2% 的存活帧，48 px 内全部有判定的弹
    live = [e for e in range(n) if first[e] is None and done[e] == 0]
    for e in live:
        if torch.rand(1, generator=g).item() >= 0.02:
            continue
        b, m = obs.bullets[e], obs.bullets_mask[e]
        rel = b[:, 0:2] - obs.player_xy[e]
        d = rel.norm(dim=-1) - b[:, 4] - obs.player_hit_r[e]
        for j in torch.nonzero(m & (d < 48.0)).flatten().tolist():
            base[sector(float(rel[j, 0]), float(rel[j, 1]))] += 1
            base_head[heading(float(b[j, 2]), float(b[j, 3]))] += 1
    for e in range(n):
        if first[e] is not None or done[e] == 0:
            continue
        first[e] = int(done[e])
        if done[e] != 1:
            continue
        gi = e // EPS
        best = (None, None, float("inf"))
        for h in range(1, min(HITWIN, len(ring)) + 1):
            b, m, _sel, pxy, hr = ring[-h]
            d = edge(b[e:e + 1], m[e:e + 1], pxy[e:e + 1], hr[e:e + 1])[0]
            j = int(d.argmin())
            if float(d[j]) < best[2]:
                best = (h, j, float(d[j]))
        h, j, dist = best
        rec = {"card": groups[gi][0], "rank": groups[gi][2], "dist": dist, "step": step}
        if dist < 4.0:
            traj = []                      # (x, y, vx, vy, 当时是否在最近 K 颗里)，从命中帧往前
            b, m, sel, pxy, hr = ring[-h]
            cur = b[e, j]
            traj.append((float(cur[0]), float(cur[1]), float(cur[2]), float(cur[3]), bool(sel[e, j])))
            for back in range(1, TRACK + 1):
                if h + back > len(ring):
                    break
                pb, pm, psel, _p, _h = ring[-(h + back)]
                pred = pb[e, :, 0:2] + pb[e, :, 2:4]
                dd = (pred - torch.tensor(traj[-1][:2])).norm(dim=-1).masked_fill(~pm[e], float("inf"))
                k = int(dd.argmin())
                if float(dd[k]) > 3.0:
                    break
                traj.append((float(pb[e, k, 0]), float(pb[e, k, 1]), float(pb[e, k, 2]), float(pb[e, k, 3]), bool(psel[e, k])))
            rec["tracked"] = len(traj) - 1
            hp = ring[-h][3][e]
            at10 = traj[min(10, len(traj) - 1)]
            p10 = ring[-(h + min(10, len(traj) - 1))][3][e]
            rec["sector10"] = sector(at10[0] - float(p10[0]), at10[1] - float(p10[1]))
            rec["heading"] = heading(traj[min(3, len(traj) - 1)][2], traj[min(3, len(traj) - 1)][3])
            rec["seen5"] = traj[5][4] if len(traj) > 5 else None
            rec["seen10"] = traj[10][4] if len(traj) > 10 else None
            if len(traj) > 20:
                v0, v1 = traj[20][2:4], traj[1][2:4]
                s0, s1 = math.hypot(*v0), math.hypot(*v1)
                turn = abs(math.degrees(math.atan2(v1[1], v1[0]) - math.atan2(v0[1], v0[0])))
                rec["turn20"] = min(turn, 360 - turn) if s0 > 0.05 and s1 > 0.05 else None
                rec["speed_ratio20"] = s1 / s0 if s0 > 0.05 else None
                flips = [(traj[i][2] * traj[i + 1][2] < 0 and abs(traj[i][2]) > 0.3) or
                         (traj[i][3] * traj[i + 1][3] < 0 and abs(traj[i][3]) > 0.3) for i in range(1, 20)]
                rec["flip20"] = any(flips)
        deaths.append(rec)
    obs = nxt
    if all(f is not None for f in first):
        break

surv = {}
for gi, (c, m, r, fail) in enumerate(groups):
    done_e = [first[gi * EPS + i] for i in range(EPS)]
    surv[f"{c}_r{r}"] = {"surv": sum(1 for x in done_e if x != 1) / EPS, "train_fail": fail}
res = {"intent": cfg["eval"]["intent"], "motor": cfg["motor"]["enabled"], "episodes": EPS, "surv": surv,
       "deaths": deaths, "base_sector": dict(base), "base_heading": dict(base_head)}
json.dump(res, open(out_path, "w"), ensure_ascii=False)

bullet = [d for d in deaths if d["dist"] < 4.0]
print(f"意图 {res['intent']} · 运动层 {'开' if res['motor'] else '关'} · 每起点 {EPS} 局")
for k, v in surv.items():
    print(f"  {k:22} 撑过 {v['surv']:.2f}（训练采样死亡率 {v['train_fail']:.2f}）")
print(f"总撑过 {sum(v['surv'] for v in surv.values()) / len(surv):.3f} · 死亡 {len(deaths)} · 弹致死 {len(bullet)}")
if bullet:
    def dist(key):
        c = collections.Counter(d.get(key) for d in bullet if d.get(key) is not None)
        tot = sum(c.values())
        return " ".join(f"{k} {v / tot:.0%}" for k, v in c.most_common()) + f"（n={tot}）"
    bt, bh = sum(base.values()), sum(base_head.values())
    print("凶手方位（命中前 10 帧）：", dist("sector10"))
    print("  基准（存活帧 48 px 内的弹）：", " ".join(f"{k} {v / bt:.0%}" for k, v in base.most_common()))
    print("凶手运动方向：", dist("heading"))
    print("  基准：", " ".join(f"{k} {v / bh:.0%}" for k, v in base_head.most_common()))
    for key in ("seen5", "seen10", "flip20"):
        v = [d[key] for d in bullet if d.get(key) is not None]
        if v:
            print(f"{key}：{sum(v) / len(v):.0%}（n={len(v)}）")
    tv = [d["turn20"] for d in bullet if d.get("turn20") is not None]
    sr = [d["speed_ratio20"] for d in bullet if d.get("speed_ratio20") is not None]
    if tv:
        print(f"最近 20 帧转向 >15°：{sum(t > 15 for t in tv) / len(tv):.0%} · 速率变化 >20%："
              f"{sum(abs(s - 1) > 0.2 for s in sr) / max(1, len(sr)):.0%}（n={len(tv)}）")
    print(f"追踪到的帧数中位 {sorted(d.get('tracked', 0) for d in bullet)[len(bullet) // 2]}")
