"""v8：局部几何和有限运动可恢复，伸长状态与长预警保留。"""
import math

import pytest
import torch

from conftest import small_cfg
from stgtrain.envwrap import mirror_lasers_
from stgtrain.registry import FEATURIZERS, load_builtins
from test_featurize_v6 import random_obs
from test_featurize_v7 import C, laser, with_lasers

load_builtins()


def feats():
    return FEATURIZERS.get("danger_topk_v8")(small_cfg(
        featurize={"name": "danger_topk_v8", "frame": "static", "dt": False, "k_lasers": 8}))


def obs(rows=None, start_len=None):
    rows = rows or [laser(x=30, y=100, deg=90, start=10, end=400, half_h=6,
                          speed=2, omega=math.pi / 2, vx=1, vy=-2, state=0, t_active=300)]
    o = with_lasers(random_obs(n=1), [rows])
    o.player_xy = torch.tensor([[50., 300.]])
    o.laser_start_len = torch.zeros_like(o.lasers_mask, dtype=torch.float32)
    o.laser_start_len[0, :len(rows)] = torch.tensor(start_len or [500.] * len(rows))
    return o


def test_geometry_and_large_rotation_motion():
    t = feats()(obs())["lasers"][0, 0]
    # 当前方向朝下，自机投影距原点200px，最近点(30,300)。
    # 上帧朝右，固定200px射线点的位移=(1,-2)+(-200,200)=(-199,198)。
    expected = [20/192, -190/192, 200/192, 0, 1, 6/8,
                198/8, 199/8, math.pi/2*60, 200/192, 2/8, 110/192, 1, math.log1p(5)]
    torch.testing.assert_close(t, torch.tensor(expected), atol=2e-5, rtol=1e-5)


@pytest.mark.parametrize("player", [(50., 300.), (50., 90.), (50., 550.)])
def test_original_geometry_and_displacement_can_be_recovered(player):
    o = obs()
    o.player_xy[:] = torch.tensor(player)
    t = feats()(o)["lasers"][0, 0]
    d, a, b = t[:3] * 192
    e = t[3:5]
    n = torch.stack([-e[1], e[0]])
    c = torch.minimum(torch.maximum(torch.tensor(0.), a), b)
    s_near = t[9] * 192
    u = s_near - c
    origin = o.player_xy[0] - u * e + d * n
    torch.testing.assert_close(origin, torch.tensor([30., 100.]), atol=2e-5, rtol=1e-5)
    torch.testing.assert_close(torch.stack([a + u, b + u]), torch.tensor([10., 400.]))
    delta = float(t[8] / 60)
    previous_e = torch.tensor([math.cos(math.pi/2-delta), math.sin(math.pi/2-delta)])
    v = t[6]*8*e + t[7]*8*n - s_near*(e-previous_e)
    torch.testing.assert_close(v, torch.tensor([1., -2.]), atol=4e-5, rtol=1e-5)
    assert float(t[11]*192 + b-a) == pytest.approx(500.)
    assert float(torch.expm1(t[13])*60) == pytest.approx(300.)


def test_growth_and_long_warning_are_distinguishable():
    f = feats()
    a = f(obs(start_len=[390.]))["lasers"][0, 0]
    b = f(obs(start_len=[500.]))["lasers"][0, 0]
    assert a[11] == 0 and b[11] > 0
    o = obs()
    o.lasers[..., C["t_active"]] = 600
    assert f(o)["lasers"][0, 0, 13] > b[13]


def test_mirror_and_empty_mask():
    o, f = obs(), feats()
    a = f(o)["lasers"][0, 0]
    o.player_xy[:, 0] *= -1
    mirror_lasers_(o.lasers, o.lasers_mask)
    b = f(o)["lasers"][0, 0]
    signs = torch.ones(14)
    signs[[0, 3, 7, 8]] = -1
    torch.testing.assert_close(b, a * signs, atol=2e-5, rtol=1e-5)
    o.lasers_mask[:] = False
    out = f(o)
    assert not out["lasers_mask"].any() and (out["lasers"] == 0).all()


def test_start_len_is_required_and_aligned():
    o, f = obs(), feats()
    o.laser_start_len = None
    with pytest.raises(ValueError, match="laser_start_len"):
        f(o)
    o.laser_start_len = torch.zeros(1, 2)
    with pytest.raises(ValueError, match="同行"):
        f(o)
