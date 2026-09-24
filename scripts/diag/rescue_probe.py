"""闭环救援探针：保留运动层，只在「模型的请求按外推会撞、且另一个动作明显更安全」时替换请求，跑完整局。

回答的问题：死亡分类里「当时存在安全走法」的那一半（A 类），**换过去到底救不救得活**？
  - 明显救活 ⇒ 几何信息确实有用，给模型加「每个动作的短期净距」特征值得花一整轮训练（这个救援层本身也是不用训练的部署方案）
  - 局部判断改善、整局不改善 ⇒ 需要更长的预测或退路判断，单纯加几十维未必够

纪律：预测只用**当前观测**（位置、速度、半径、自机状态、held），不用未来真值、不用运动层抽到的隐藏量。
运动层语义按**最坏情形**计入：想换方向 / 低速位时，新取值要等「剩余锁定 [lo,hi] + 延迟 [lo,hi]」帧才生效，这期间继续执行当前取值；
对 (最早, 居中, 最晚) 三种生效时刻各外推一条分段轨迹，取最小净距。用离自机最近的 NB 颗**全部有判定的弹**（不是模型入选的那 64 颗）。

    rescue.py <ckpt> <mode: off|on> <out.json> [intent]
"""
import sys, json, math, torch, stg_rl
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import eval_cfg
from stgtrain.envwrap import EnvWrapper, _fx, _off
from stgtrain.episodes import EpisodeTracker
from stgtrain.reward import RewardFn

ckp, MODE, out = sys.argv[1], sys.argv[2], sys.argv[3]
INTENT = sys.argv[4] if len(sys.argv) > 4 else ""
H, NB = 8, 128                  # 外推帧数；参与外推的最近弹数
DANGER, SAFE, GAIN = 0.5, 4.0, 4.0   # 请求的净距 < DANGER 算危险；替代动作净距 ≥ SAFE 且比请求高出 ≥ GAIN 才换
ck = load_checkpoint(ckp, map_location="cpu")
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}, **({"eval": {"intent": INTENT}} if INTENT else {})}))
cfg = eval_cfg(cfg)
device = pick_device("cpu"); torch.set_num_threads(12)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
groups = [(sp.card, rk) for sp in specs for rk in sp.ranks]; K = 32
envw = EnvWrapper(cfg, {}, [], device, seed=int(cfg["eval"]["seed"]), num_envs=K, mirror=False,
                  groups=[({c: images[c]}, stg_rl.Start(c, 0, r)) for c, r in groups])
n = envw.n
mot = cfg["motor"]; M_ON = bool(mot["enabled"]); M_SLOW = bool(mot.get("slow", False))
hold_lo, hold_hi = (int(v) for v in mot["hold"]) if M_ON else (0, 0)
del_lo, del_hi = (int(v) for v in mot["delay"]) if M_ON else (0, 0)

DIRS = torch.tensor([(0, 0), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)], dtype=torch.float32)
DIRS = DIRS / DIRS.norm(dim=-1, keepdim=True).clamp_min(1.0)          # 动作表 v1：0 不动 1 上 2 右上 … 顺时针；斜向归一
A_DIR = torch.arange(18) // 2; A_SLOW = torch.arange(18) % 2

def clearances(obs, speed_hi, speed_lo):
    """[n, 18] 每个候选请求在最坏生效时刻下、H 帧内的最小净距（线性外推）。"""
    p = obs.player_xy                                                   # [n,2]
    rel = obs.bullets[..., 0:2] - p[:, None, :]
    edge = (rel.norm(dim=-1) - obs.bullets[..., 4]).masked_fill(~obs.bullets_mask, float("inf"))
    idx = edge.topk(min(NB, edge.shape[1]), dim=1, largest=False).indices
    g = lambda t: torch.gather(t, 1, idx.unsqueeze(-1).expand(-1, -1, t.shape[-1]))
    b = g(obs.bullets); bm = torch.gather(obs.bullets_mask, 1, idx)
    bp, bv, br = b[..., 0:2], b[..., 2:4], b[..., 4] + obs.player_hit_r[:, None]
    cur = obs.prev_action.to(torch.int64); cur_dir, cur_slow = cur // 2, cur % 2
    held = obs.dir_held.clamp(max=1000); sheld = obs.slow_held.clamp(max=1000)
    def k_range(h):   # 想换时，新取值最早 / 最晚第几帧之后才生效
        lo = (hold_lo - h).clamp_min(0) + del_lo; hi = (hold_hi - h).clamp_min(0) + del_hi
        return lo, hi
    kd_lo, kd_hi = k_range(held)
    ks_lo, ks_hi = k_range(sheld) if M_SLOW else (torch.zeros_like(held), torch.zeros_like(held))
    worst = torch.full((n, 18), float("inf"))
    for frac in (0.0, 0.5, 1.0):                                        # 三种生效时刻：最早 / 居中 / 最晚
        kd = (kd_lo + (kd_hi - kd_lo) * frac).round().long()[:, None].expand(n, 18).clone()
        ks = (ks_lo + (ks_hi - ks_lo) * frac).round().long()[:, None].expand(n, 18).clone()
        kd[A_DIR[None, :] == cur_dir[:, None]] = 0                      # 不换的那一路没有等待
        ks[A_SLOW[None, :] == cur_slow[:, None]] = 0
        pos = p[:, None, :].expand(n, 18, 2).clone()
        best = torch.full((n, 18), float("inf"))
        for t in range(1, H + 1):
            d_idx = torch.where(t <= kd, cur_dir[:, None].expand(n, 18), A_DIR[None, :].expand(n, 18))
            s_idx = torch.where(t <= ks, cur_slow[:, None].expand(n, 18), A_SLOW[None, :].expand(n, 18))
            sp = torch.where(s_idx == 1, speed_lo[:, None], speed_hi[:, None])
            pos = pos + DIRS[d_idx] * sp.unsqueeze(-1)
            pos = torch.stack([pos[..., 0].clamp(-192.0, 192.0), pos[..., 1].clamp(0.0, 448.0)], dim=-1)
            bt = bp + bv * t                                            # [n,NB,2]
            d = (bt[:, None, :, :] - pos[:, :, None, :]).norm(dim=-1) - br[:, None, :]
            d = d.masked_fill(~bm[:, None, :], float("inf")).min(dim=-1).values
            best = torch.minimum(best, d)
        worst = torch.minimum(worst, best)
    return worst

rf = RewardFn(cfg)
tr = EpisodeTracker(n, device, list(rf.terms), cfg["reward"]["hold_radius"], cfg["reward"]["edge_margin"],
                    envw.frame_skip, cfg["intent"]["interval"][1])
first = {}; obs = envw.reset()
speed_lo = _fx(envw.buf["player"], _off("player", "speed_focus")).clone()
last_override = torch.full((n,), -1, dtype=torch.int64)
n_frames = n_danger = n_replaced = n_nosafe = 0
boss_frames = under_frames = 0      # 「打得到」：有 boss 在场的帧里，自机在 boss 正下方 ±32 px 内的占比
for step in range(int(cfg["env"]["max_frames"]) + 2):
    want = ppo.act(feat(obs), True).cpu().to(torch.int64)
    req = want
    if MODE == "on":
        cl = clearances(obs, obs.player_speed, speed_lo)                # [n,18]
        want_cl = cl.gather(1, want[:, None]).squeeze(1)
        danger = want_cl < DANGER
        ok = (cl >= SAFE) & (cl - want_cl[:, None] >= GAIN)
        # 在安全的替代动作里挑：上一帧替换过且仍安全 → 沿用（不然自己会反复重抽延迟）；否则朝目标点进度最大的，平手取净距大的
        to_t = obs.target_xy - obs.player_xy
        dist = to_t.norm(dim=-1, keepdim=True)
        unit = torch.where(dist > cfg["reward"]["hold_radius"], to_t / dist.clamp_min(1e-6), torch.zeros_like(to_t))
        sp = torch.where(A_SLOW[None, :] == 1, speed_lo[:, None], obs.player_speed[:, None])
        progress = (DIRS[A_DIR][None, :, :] * unit[:, None, :]).sum(-1) * sp            # [n,18] px/帧
        score = progress + 0.02 * cl.clamp(max=24.0)
        score = score.masked_fill(~ok, float("-inf"))
        keep = (last_override >= 0) & ok.gather(1, last_override.clamp_min(0)[:, None]).squeeze(1)
        pick = torch.where(keep, last_override.clamp_min(0), score.argmax(dim=1))
        replace = danger & ok.any(dim=1)
        req = torch.where(replace, pick, want)
        last_override = torch.where(replace, pick, torch.full_like(pick, -1))
        live = torch.ones(n, dtype=torch.bool)
        n_danger += int(danger.sum()); n_replaced += int(replace.sum()); n_nosafe += int((danger & ~ok.any(dim=1)).sum())
    n_frames += n
    is_boss = (obs.enemies[..., 3] != 0) & obs.enemies_mask
    has_boss = is_boss.any(dim=1)
    bx = obs.enemies[torch.arange(n), is_boss.float().argmax(dim=1), 0]
    boss_frames += int(has_boss.sum()); under_frames += int((has_boss & ((obs.player_xy[:, 0] - bx).abs() <= 32.0)).sum())
    nxt, info = envw.step(req)
    ended = (info.done != 0).cpu()
    last_override = torch.where(ended, torch.full_like(last_override, -1), last_override)
    total, raw = rf(obs, nxt, info); tr.update(obs, nxt, info, total, raw); obs = nxt
    if (step + 1) % 64 == 0:
        for r in tr.pop_finished(): first.setdefault(r["env"], r)
        if len(first) == n: break
for r in tr.pop_finished(): first.setdefault(r["env"], r)
res = {"mode": MODE, "intent": cfg["intent"]["name"], "danger_frac": n_danger / n_frames, "replaced_frac": n_replaced / n_frames,
       "danger_nosafe_frac": n_nosafe / n_frames,
       "under_boss_frac": under_frames / max(boss_frames, 1), "by": {}, "cards": {}}
for rank in (2, 3):
    recs = [first[g * K + i] for g, (c, rk) in enumerate(groups) if rk == rank for i in range(K)]
    m = lambda k: sum(r[k] for r in recs) / len(recs)
    res["by"][f"r{rank}"] = {"surv": sum(1 for r in recs if r["done"] != 1) / len(recs), "in_r": m("in_r_frac"), "dir_s": m("dir_changes_per_s"),
                             "shift_s": m("shift_toggles_per_s"), "close12": m("close12_frac"), "edge": m("edge_frac"), "override": m("motor_override_frac")}
for g, (c, rk) in enumerate(groups):
    res["cards"][f"{c}_r{rk}"] = sum(1 for i in range(K) if first[g * K + i]["done"] != 1) / K
json.dump(res, open(out, "w")); print(json.dumps({k: v for k, v in res.items() if k != "cards"}, ensure_ascii=False))
