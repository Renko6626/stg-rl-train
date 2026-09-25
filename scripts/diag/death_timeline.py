"""诊断：看见了却没躲开 —— 每次弹致死往前看 15 帧，拆成「手来不及 / 决策错（赶路 or 不赶路）/ 死局 / 外推安全却死」。

对每一帧，按**运动层最坏情形**（同 rescue_probe.py：想换方向 / 低速位要等「剩余锁定 [lo,hi] + 延迟 [lo,hi]」，
对最早 / 居中 / 最晚三种生效时刻各外推一条分段轨迹，取 H 帧内最小净距；离自机最近 NB 颗有判定的弹、线性外推）
给 18 个动作打分，只在死掉的那一局、死前那几帧上算（环形缓冲里存观测，死了再算，便宜）。

归类（取窗口里**最后一个还有安全动作的帧** f*，「安全」= 最坏净距 ≥ SAFE）：
  死局        窗口内（命中前 WIN 帧）没有任何一帧存在安全动作
  手来不及    f* 上请求的动作安全，但此后执行的动作被运动层压着没换过去（执行 ≠ 请求）
  决策错      f* 上请求的动作本身不安全（又分：赶路 = 离目标点 > hold_radius；不赶路）
  外推安全却死 f* 上请求安全、执行也跟上了，按线性外推仍安全 —— 精度 / 外推口径之外

    PYTHONPATH=src python scripts/diag/death_timeline.py <ckpt> <run_dir> <out.json> [intent] [episodes]
"""
import collections
import json
import os
import sys

import stg_rl
import torch

from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import deep_merge, from_dict
from stgtrain.envwrap import EnvWrapper, _fx, _off
from stgtrain.eval_ckpt import PPO, build_components, pick_device
from stgtrain.evaluate import eval_cfg

ckp, run_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
INTENT = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else ""
EPS = int(sys.argv[5]) if len(sys.argv) > 5 else 64
TOP = int(os.environ.get("TOP", 10))
H, NB, SAFE = 8, 128, 2.0
WIN, RING, HITWIN = 15, 40, 12

ck = load_checkpoint(ckp, map_location="cpu")
over = {"run": {"device": "cpu"}}
if INTENT:
    over["eval"] = {"intent": INTENT}
cfg = eval_cfg(from_dict(deep_merge(ck["cfg"], over)))
torch.set_num_threads(int(os.environ.get("THREADS", 16)))
images, _s, _specs, feat, factory = build_components(cfg, pick_device("cpu"))
ppo = PPO(cfg, factory, torch.device("cpu"))
ppo.load_state_dict(ck["state"])
HOLD_R = float(cfg["reward"]["hold_radius"])
mot = cfg["motor"]
M_ON, M_SLOW = bool(mot["enabled"]), bool(mot.get("slow", False))
hold_lo, hold_hi = (int(v) for v in mot["hold"]) if M_ON else (0, 0)
del_lo, del_hi = (int(v) for v in mot["delay"]) if M_ON else (0, 0)

starts = json.load(open(f"{run_dir}/env.json"))["starts"]
last = json.loads(open(f"{run_dir}/curriculum.jsonl").read().strip().splitlines()[-1])
hard = sorted(range(len(starts)), key=lambda i: -last["fail"][i])[:TOP]
groups = [tuple(starts[i].split(":")) for i in hard]
envw = EnvWrapper(cfg, {}, [], torch.device("cpu"), seed=int(cfg["eval"]["seed"]), num_envs=EPS, mirror=False,
                  groups=[({c: images[c]}, stg_rl.Start(c, int(m), int(r))) for c, m, r in groups])
n = envw.n

DIRS = torch.tensor([(0, 0), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)], dtype=torch.float32)
DIRS = DIRS / DIRS.norm(dim=-1, keepdim=True).clamp_min(1.0)
A_DIR, A_SLOW = torch.arange(18) // 2, torch.arange(18) % 2


def clearances(f):
    """单个 env 单帧 → [18] 每个请求在运动层最坏生效时刻下 H 帧内的最小净距（同 rescue_probe.clearances）。"""
    p = f["pxy"]
    rel = f["b"][:, 0:2] - p
    edge = (rel.norm(dim=-1) - f["b"][:, 4]).masked_fill(~f["m"], float("inf"))
    idx = edge.topk(min(NB, edge.shape[0]), largest=False).indices
    b, bm = f["b"][idx], f["m"][idx]
    bp, bv, br = b[:, 0:2], b[:, 2:4], b[:, 4] + f["hr"]
    cur_dir, cur_slow = f["prev"] // 2, f["prev"] % 2

    def k_range(h):
        return max(hold_lo - h, 0) + del_lo, max(hold_hi - h, 0) + del_hi
    kd_lo, kd_hi = k_range(f["held"])
    ks_lo, ks_hi = k_range(f["sheld"]) if M_SLOW else (0, 0)
    worst = torch.full((18,), float("inf"))
    for frac in (0.0, 0.5, 1.0):
        kd = torch.full((18,), round(kd_lo + (kd_hi - kd_lo) * frac))
        ks = torch.full((18,), round(ks_lo + (ks_hi - ks_lo) * frac))
        kd[A_DIR == cur_dir] = 0
        ks[A_SLOW == cur_slow] = 0
        pos = p[None, :].expand(18, 2).clone()
        best = torch.full((18,), float("inf"))
        for t in range(1, H + 1):
            d_idx = torch.where(t <= kd, torch.full((18,), cur_dir), A_DIR)
            s_idx = torch.where(t <= ks, torch.full((18,), cur_slow), A_SLOW)
            sp = torch.where(s_idx == 1, f["slo"], f["shi"])
            pos = pos + DIRS[d_idx] * sp[:, None]
            pos = torch.stack([pos[:, 0].clamp(-192.0, 192.0), pos[:, 1].clamp(0.0, 448.0)], dim=-1)
            bt = bp + bv * t
            dd = ((bt[None, :, :] - pos[:, None, :]).norm(dim=-1) - br[None, :]).masked_fill(~bm[None, :], float("inf"))
            best = torch.minimum(best, dd.min(dim=-1).values)
        worst = torch.minimum(worst, best)
    return worst


ring = collections.deque(maxlen=RING)
first = [None] * n
recs = []
obs = envw.reset()
speed_lo = _fx(envw.buf["player"], _off("player", "speed_focus")).clone()   # 批量分组的缓冲要 reset 之后才有
for step in range(int(cfg["env"]["max_frames"]) + 2):
    want = ppo.act(feat(obs), True).cpu().to(torch.int64)
    ring.append({"b": obs.bullets.clone(), "m": obs.bullets_mask.clone(), "pxy": obs.player_xy.clone(),
                 "hr": obs.player_hit_r.clone(), "shi": obs.player_speed.clone(), "prev": obs.prev_action.clone(),
                 "held": obs.dir_held.clone(), "sheld": obs.slow_held.clone(), "tgt": obs.target_xy.clone(),
                 "want": want})
    nxt, info = envw.step(want)
    ring[-1]["exec"] = nxt.prev_action.clone()        # 这一帧实际执行的（运动层之后）
    done = info.done.cpu()
    for e in range(n):
        if first[e] is not None or done[e] == 0:
            continue
        first[e] = int(done[e])
        if done[e] != 1:
            continue
        # 命中帧：末 HITWIN 帧里边距最小的那帧
        hit, hd = None, float("inf")
        for h in range(1, min(HITWIN, len(ring)) + 1):
            r = ring[-h]
            d = ((r["b"][e, :, 0:2] - r["pxy"][e]).norm(dim=-1) - r["b"][e, :, 4] - r["hr"][e]).masked_fill(~r["m"][e], float("inf"))
            if float(d.min()) < hd:
                hit, hd = h, float(d.min())
        rec = {"card": groups[e // EPS][0], "hit_dist": hd}
        if hd >= 4.0 or hit + WIN > len(ring):
            rec["cls"] = "非弹 / 窗口不足"
            recs.append(rec)
            continue
        frames = []
        for back in range(WIN, 0, -1):                 # 命中前 WIN 帧 … 前 1 帧（时间顺序）
            r = ring[-(hit + back)]
            f = {"b": r["b"][e], "m": r["m"][e], "pxy": r["pxy"][e], "hr": float(r["hr"][e]), "shi": float(r["shi"][e]),
                 "slo": float(speed_lo[e]), "prev": int(r["prev"][e]), "held": int(min(int(r["held"][e]), 1000)),
                 "sheld": int(min(int(r["sheld"][e]), 1000))}
            cl = clearances(f)
            w, x = int(r["want"][e]), int(r["exec"][e])
            frames.append({"back": back, "want": w, "exec": x, "want_cl": float(cl[w]), "best_cl": float(cl.max()),
                           "n_safe": int((cl >= SAFE).sum()),
                           "transit": float((r["tgt"][e] - r["pxy"][e]).norm()) > HOLD_R})
        chances = [fr for fr in frames if fr["best_cl"] >= SAFE]
        if not chances:
            rec["cls"] = "死局"
        else:
            fs = chances[-1]
            rec.update(last_chance_back=fs["back"], n_safe=fs["n_safe"], transit=fs["transit"])
            later = [fr for fr in frames if fr["back"] <= fs["back"]]
            if fs["want_cl"] < SAFE:
                rec["cls"] = "决策错·赶路" if fs["transit"] else "决策错·不赶路"
            elif any(fr["exec"] != fr["want"] for fr in later):
                rec["cls"] = "手来不及"
            else:
                rec["cls"] = "外推安全却死"
        rec["frames"] = frames
        recs.append(rec)
    obs = nxt
    if all(f is not None for f in first):
        break

surv = sum(1 for f in first if f != 1) / n
json.dump({"intent": cfg["eval"]["intent"], "surv": surv, "deaths": recs}, open(out_path, "w"), ensure_ascii=False)
c = collections.Counter(r["cls"] for r in recs)
tot = sum(c.values())
print(f"意图 {cfg['eval']['intent']} · 撑过 {surv:.3f} · 死亡 {tot}")
for k, v in c.most_common():
    print(f"  {k:10} {v:4d}  {v / tot:.0%}")
lc = [r["last_chance_back"] for r in recs if "last_chance_back" in r]
if lc:
    lc.sort()
    print(f"最后一个有安全动作的帧：命中前 中位 {lc[len(lc) // 2]} 帧；当时安全动作数中位 "
          f"{sorted(r['n_safe'] for r in recs if 'n_safe' in r)[len(lc) // 2]}")
