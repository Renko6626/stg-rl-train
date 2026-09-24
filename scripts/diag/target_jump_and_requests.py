"""两个离线 / 旁路诊断（不改训练、不改动作）：

A  目标点跳变对模型输入的冲击：冻结同一帧，只把目标点换成别处，量「入选的 64 颗弹」重合率、危险度两列的变化、策略输出的变化；
   对照 = 同一局相邻两帧之间（目标点不变）的自然变化。目标点决定假想自机速度 → 相对速度 / 外推最近距离 / top-K 选择全跟着变。
B  请求 → 执行：模型想换方向之后多久真的换了？中途改主意 / 撤回的比例？（运动层的 pend / wait 对模型不可见）

    target_jump_and_requests.py <ckpt> <out.json>
"""
import sys, json, collections, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import eval_cfg
from stgtrain.envwrap import EnvWrapper
from stgtrain.featurize.danger_topk_v1 import closest_approach

ck = load_checkpoint(sys.argv[1], map_location="cpu"); out = sys.argv[2]
cfg = eval_cfg(from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}})))
device = pick_device("cpu"); torch.set_num_threads(12)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
groups = [(sp.card, rk) for sp in specs for rk in sp.ranks]; K = 16
envw = EnvWrapper(cfg, {}, [], device, seed=int(cfg["eval"]["seed"]), num_envs=K, mirror=False,
                  groups=[({c: images[c]}, stg_rl.Start(c, 0, r)) for c, r in groups])
n = envw.n; model = ppo.agent_inference.model
g = torch.Generator().manual_seed(0)

def selected(obs):
    pos = obs.player_xy[:, None, :]
    pb = obs.bullets[..., 0:2] - pos
    vb = obs.bullets[..., 2:4] - feat.player_velocity(obs)[:, None, :]
    dmin, _ = closest_approach(pb, vb, obs.bullets[..., 4] + obs.player_hit_r[:, None], feat.horizon)
    dmin = dmin.masked_fill(~obs.bullets_mask, float("inf"))
    kth = dmin.sort(1).values[:, feat.kb - 1:feat.kb]
    return (dmin <= kth) & (dmin <= feat.d_max) & obs.bullets_mask, dmin

def logits_of(obs):
    with torch.no_grad():
        lg, _ = model(feat(obs)); return lg

def compare(o1, o2):
    s1, d1 = selected(o1); s2, d2 = selected(o2)
    inter = (s1 & s2).sum(1).float(); union = (s1 | s2).sum(1).float().clamp_min(1)
    both = s1 & s2
    dd = ((d1 - d2).abs() * both).sum(1) / both.sum(1).clamp_min(1)
    l1, l2 = logits_of(o1), logits_of(o2)
    p1 = l1.softmax(-1); kl = (p1 * (l1.log_softmax(-1) - l2.log_softmax(-1))).sum(-1)
    flip = (l1.argmax(-1) // 2) != (l2.argmax(-1) // 2)
    has = s1.sum(1) > 0
    return inter / union, dd, kl, flip, has

acc = collections.defaultdict(list)
req = {"fulfilled": 0, "changed": 0, "withdrawn": 0, "lat": []}
pend_dir = torch.full((n,), -1, dtype=torch.int64); pend_age = torch.zeros(n, dtype=torch.int64)
obs = envw.reset(); first_done = torch.zeros(n, dtype=torch.bool); prev_obs = None
for step in range(int(cfg["env"]["max_frames"]) + 2):
    want = ppo.act(feat(obs), True).cpu().to(torch.int64)
    live = ~first_done
    # ---- B：请求 → 执行 ----
    cur = obs.prev_action.to(torch.int64) // 2; wd = want // 2
    for e in live.nonzero().flatten().tolist():
        p, w_, c_ = int(pend_dir[e]), int(wd[e]), int(cur[e])
        if p >= 0:
            if c_ == p: req["fulfilled"] += 1; req["lat"].append(int(pend_age[e])); p = -1
            elif w_ == c_: req["withdrawn"] += 1; p = -1
            elif w_ != p: req["changed"] += 1; p = -1
        if p < 0 and w_ != c_: p = w_; pend_age[e] = 0
        pend_dir[e] = p
    pend_age += 1
    # ---- A：每 40 帧抽一次 ----
    if step % 40 == 20:
        if prev_obs is not None:
            j, dd, kl, flip, has = compare(prev_obs, obs); m = live & has
            for k_, v in (("nat_jaccard", j), ("nat_dd", dd), ("nat_kl", kl), ("nat_flip", flip.float())): acc[k_] += v[m].tolist()
        alt = obs.__class__(**{**obs.__dict__})
        u = torch.rand(n, 2, generator=g)
        alt.target_xy = torch.stack([-176 + u[:, 0] * 352, 224 + u[:, 1] * 208], dim=-1)
        j, dd, kl, flip, has = compare(obs, alt); m = live & has
        far_now = (obs.target_xy - obs.player_xy).norm(dim=-1) > 24
        for k_, v in (("jump_jaccard", j), ("jump_dd", dd), ("jump_kl", kl), ("jump_flip", flip.float())): acc[k_] += v[m].tolist()
        acc["jump_jaccard_from_inR"] += j[m & ~far_now].tolist(); acc["jump_jaccard_from_far"] += j[m & far_now].tolist()
    prev_obs = obs if step % 40 == 19 else prev_obs
    nxt, info = envw.step(want)
    ended = (info.done != 0).cpu(); first_done |= ended
    pend_dir[ended] = -1
    obs = nxt
    if bool(first_done.all()): break
mean = lambda v: sum(v) / max(len(v), 1)
lat = sorted(req["lat"]); tot = req["fulfilled"] + req["changed"] + req["withdrawn"]
res = {"A": {k: round(mean(v), 4) for k, v in acc.items()}, "A_n": len(acc["jump_kl"]),
       "B": {"requests": tot, "fulfilled": req["fulfilled"] / tot, "changed_mind": req["changed"] / tot, "withdrawn": req["withdrawn"] / tot,
             "latency_p50": lat[len(lat) // 2], "latency_p90": lat[int(len(lat) * .9)], "latency_mean": mean(lat)}}
json.dump(res, open(out, "w")); print(json.dumps(res, ensure_ascii=False, indent=1))
