"""评测时消融：把危险度特征（外推最近距离 d、到达时刻 t）清零 / 换掉，看**已经训好的**模型有多依赖它们。不改仓库。

  zero      弹与敌的 d、t 两列清零
  shuffle   d、t 两列在同一帧的入选弹之间打乱（保留分布、打掉与具体哪颗弹的对应）
量的是「现有解法对这两列的依赖」，不是「不给这两列重训会怎样」。
"""
import sys, json, torch
from stgtrain.checkpoint import load_checkpoint
from stgtrain.config import from_dict, deep_merge
from stgtrain.eval_ckpt import build_components, pick_device, PPO
from stgtrain.evaluate import evaluate

ckp, mode, out = sys.argv[1], sys.argv[2], sys.argv[3]
ck = load_checkpoint(ckp, map_location="cpu")
cfg = from_dict(deep_merge(ck["cfg"], {"run": {"device": "cpu"}}))
device = pick_device("cpu"); torch.set_num_threads(8)
images, _s, specs, feat, factory = build_components(cfg, device)
ppo = PPO(cfg, factory, device); ppo.load_state_dict(ck["state"])
g = torch.Generator().manual_seed(0)

class Ablate:
    def __call__(self, obs):
        f = dict(feat(obs))
        for key, cols in (("bullets", (5, 6)), ("enemies", (3, 4))):
            x = f[key].clone()
            if mode == "zero":
                x[..., cols[0]:cols[1] + 1] = 0.0
            elif mode == "shuffle":
                n, k, _ = x.shape
                perm = torch.argsort(torch.rand(n, k, generator=g), dim=1)
                for c in cols:
                    x[..., c] = torch.gather(x[..., c], 1, perm) * f[key + "_mask"]
            f[key] = x
        return f
    def spec(self): return feat.spec()
    def __getattr__(self, k): return getattr(feat, k)

res = evaluate(cfg, ppo, Ablate() if mode != "none" else feat, images, specs, device)
json.dump(res, open(out, "w"))
print(mode, {r: round(v["survival"], 3) for r, v in res["by_rank"].items()}, "跟点", round(res["overall"]["in_r_frac"], 3))
