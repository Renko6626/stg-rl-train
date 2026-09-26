"""danger_topk_v7：v6 + 激光 token。"""
import math

import pytest
import torch

from conftest import small_cfg
from stgtrain.envwrap import LASER_COLS, RawObs, mirror_lasers_
from stgtrain.featurize.danger_topk_v7 import F_LASER
from stgtrain.registry import FEATURIZERS, load_builtins
from test_featurize_v6 import random_obs

load_builtins()
C = {name: k for k, name in enumerate(LASER_COLS)}
V6 = {"frame": "static", "dt": False}


def feats(**f):
    return FEATURIZERS.get("danger_topk_v7")(small_cfg(featurize={"name": "danger_topk_v7", **V6, **f}))


def laser(x=0.0, y=100.0, deg=90.0, start=0.0, end=400.0, half_h=8.0, speed=0.0, omega=0.0, vx=0.0, vy=0.0,
          t_active=0.0, state=1.0):
    return [x, y, math.radians(deg) % (2 * math.pi), start, end, half_h, speed, omega, vx, vy, t_active, state]


def with_lasers(o: RawObs, rows_per_env, cap=64) -> RawObs:
    n = o.player_xy.shape[0]
    lz = torch.zeros(n, cap, len(LASER_COLS))
    m = torch.zeros(n, cap, dtype=torch.bool)
    for i, rows in enumerate(rows_per_env):
        for j, r in enumerate(rows):
            lz[i, j] = torch.tensor(r, dtype=torch.float32)
            m[i, j] = True
    o.lasers, o.lasers_mask = lz, m
    return o


def random_lasers(o: RawObs, seed=0, per_env=20) -> RawObs:
    g = torch.Generator().manual_seed(seed)
    u = lambda: float(torch.rand(1, generator=g))  # noqa: E731
    rows = [[laser(x=u() * 384 - 192, y=u() * 300, deg=u() * 360, start=u() * 50, end=100 + u() * 400,
                   half_h=1 + u() * 20, speed=u() * 4, omega=(u() - 0.5) * 0.05, vx=u() - 0.5, vy=u() - 0.5,
                   t_active=float(int(u() * 60)), state=float(int(u() * 3)))
             for _ in range(per_env)] for _ in range(o.player_xy.shape[0])]
    return with_lasers(o, rows)


def test_spec_and_v6_outputs_unchanged():
    f7, f6 = feats(), FEATURIZERS.get("danger_topk_v6")(small_cfg(featurize={"name": "danger_topk_v6", **V6}))
    s = f7.spec()
    assert s["lasers"] == (16, F_LASER) and s["lasers_mask"] == (16,)
    assert {k: v for k, v in s.items() if not k.startswith("lasers")} == f6.spec()
    o = random_lasers(random_obs(seed=4))
    a, b = f7(o), f6(o)
    for k in b:
        assert torch.equal(a[k], b[k]), k
    for k, shape in s.items():
        assert tuple(a[k].shape[1:]) == shape, k


def test_token_columns():
    o = with_lasers(random_obs(n=1), [[laser(x=30.0, y=100.0, deg=90.0, start=10.0, end=400.0, half_h=6.0,
                                             speed=2.0, omega=0.01, vx=1.0, vy=-2.0, t_active=90.0, state=0.0)]])
    o.player_xy = torch.tensor([[50.0, 300.0]])
    out = feats(laser_local=True)(o)
    t = out["lasers"][0, 0]
    exp = [-20 / 192, -200 / 192, 0.0, 1.0, 10 / 192, 400 / 192, 6 / 8, 2 / 8, 0.6, 1 / 8, -2 / 8, 1.0, 1.5,
           # 自机在激光系：沿射线 200、横向 −20（激光朝下，法向 = (−1, 0)·… 见 laser_frame）
           200 / 192, -20 / 192]
    assert torch.allclose(t, torch.tensor(exp), atol=1e-5), t
    assert out["lasers_mask"][0].tolist() == [True] + [False] * 15
    assert (out["lasers"][0, 1:] == 0).all()


def test_t_active_capped():
    o = with_lasers(random_obs(n=1), [[laser(t_active=500.0, state=0.0)]])
    assert feats()(o)["lasers"][0, 0, 12].item() == pytest.approx(2.0)


def test_selects_nearest_by_box_distance_regardless_of_row_order():
    o = random_lasers(random_obs(n=4, seed=2), seed=3, per_env=40)
    f = feats(k_lasers=8, laser_local=True)
    a = f(o)
    perm = torch.randperm(64, generator=torch.Generator().manual_seed(9))
    o.lasers, o.lasers_mask = o.lasers[:, perm], o.lasers_mask[:, perm]
    b = f(o)
    assert torch.equal(a["lasers_mask"], b["lasers_mask"])
    assert torch.allclose(a["lasers"], b["lasers"], atol=1e-6), "选出的行与顺序都只由几何决定"


def test_nearest_really_are_nearest():
    """人工摆：一条压在自机身上、一条远、一条近但在收缩态、一条近但掩码关。k=2 只该选前两条（按距离）。"""
    rows = [laser(x=-150.0, y=0.0, deg=90.0, end=100.0),          # 远
            laser(x=0.0, y=0.0, deg=90.0, end=448.0),             # 穿过自机
            laser(x=20.0, y=0.0, deg=90.0, end=448.0, state=2.0),  # 近，收缩态 → 不选
            laser(x=10.0, y=0.0, deg=90.0, end=448.0)]            # 近，掩码关 → 不选
    o = with_lasers(random_obs(n=1), [rows])
    o.player_xy = torch.tensor([[0.0, 384.0]])
    o.lasers_mask[0, 3] = False
    out = feats(k_lasers=2)(o)
    rel_x = (out["lasers"][0, :, 0] * 192).tolist()
    assert out["lasers_mask"][0].tolist() == [True, True]
    assert rel_x == pytest.approx([0.0, -150.0])


def test_fade_and_masked_rows_never_selected():
    o = random_lasers(random_obs(n=3, seed=5), seed=6)
    out = feats(k_lasers=64)(o)
    live = o.lasers_mask & (o.lasers[..., C["state"]] != 2)
    assert (out["lasers_mask"].sum(1) == live.sum(1)).all()


def test_empty_lasers():
    o = with_lasers(random_obs(n=2), [[], []])
    out = feats()(o)
    assert not out["lasers_mask"].any() and (out["lasers"] == 0).all()


def test_mirror_equivariance():
    """镜像世界的 token = 原 token 的 x 类列取反（相对 x、cos、omega、vx；local 的 perp 也取反）。"""
    o = random_lasers(random_obs(n=4, seed=7), seed=8)
    f = feats(k_lasers=12, laser_local=True)
    a = f(o)
    o.player_xy = o.player_xy * torch.tensor([-1.0, 1.0])
    mirror_lasers_(o.lasers, o.lasers_mask)
    b = f(o)
    flip = torch.ones(F_LASER + 2)
    flip[[0, 2, 8, 9, 14]] = -1.0
    assert torch.equal(a["lasers_mask"], b["lasers_mask"])
    assert torch.allclose(a["lasers"] * flip, b["lasers"], atol=1e-4)


def test_requires_lasers_in_obs():
    with pytest.raises(ValueError, match="lasers"):
        feats()(random_obs(n=2))


@pytest.mark.parametrize("bad", [0, 65])
def test_k_lasers_range(bad):
    with pytest.raises(ValueError, match="k_lasers"):
        feats(k_lasers=bad)


def test_laser_local_must_be_bool():
    with pytest.raises(ValueError, match="laser_local"):
        feats(laser_local="yes")
