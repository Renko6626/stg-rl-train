import pytest
import torch

from conftest import mirror_obs, raw_obs, small_cfg
from stgtrain.featurize.danger_topk_v1 import closest_approach
from stgtrain.registry import FEATURIZERS, load_builtins

load_builtins()


def feat(**featurize):
    return FEATURIZERS.get("danger_topk_v1")(small_cfg(featurize=featurize))


def test_closest_approach_matches_brute_force():
    g = torch.Generator().manual_seed(0)
    p = torch.randn(200, 2, generator=g) * 100
    v = torch.randn(200, 2, generator=g) * 5
    r = torch.rand(200, generator=g) * 5
    d, t = closest_approach(p, v, r, 60.0)
    ts = torch.linspace(0, 60, 60001)
    brute = (p[:, None, :] + v[:, None, :] * ts[None, :, None]).norm(dim=-1).min(dim=1).values - r
    assert torch.allclose(d, brute, atol=1e-2)
    assert ((t >= 0) & (t <= 60)).all()


def test_output_shapes_match_spec():
    f = feat()
    o = raw_obs(n=3, bullets=[[(10.0, 300.0, 0.0, 1.0, 2.0)]])
    out = f(o)
    assert set(out) == set(f.spec())
    for k, shape in f.spec().items():
        assert tuple(out[k].shape) == (3, *shape), k
    assert f.spec()["bullets"] == (16, 7) and f.spec()["density"] == (2, 14, 12)


def test_player_velocity_towards_target_or_zero_inside_hold_radius():
    f = feat()
    o = raw_obs(n=2, player=[(0.0, 400.0), (0.0, 400.0)], target=[(0.0, 300.0), (0.0, 390.0)], speed=5.0)
    v = f.player_velocity(o)
    assert torch.allclose(v[0], torch.tensor([0.0, -5.0]))
    assert torch.equal(v[1], torch.zeros(2))


def test_topk_ranks_by_danger_not_distance():
    # 自机在指令点上（v_p = 0）。A 近但静止；B 远但正面高速飞来；C 横向远离。
    a, b, c = (0.0, 300.0, 0.0, 0.0, 2.0), (0.0, 200.0, 0.0, 8.0, 2.0), (100.0, 384.0, 8.0, 0.0, 2.0)
    o = raw_obs(n=1, player=(0.0, 384.0), target=(0.0, 384.0), bullets=[[a, b, c]])
    out = feat(k_bullets=2)(o)
    assert out["bullets_mask"][0].tolist() == [True, True]
    assert out["bullets"][0, 0, 1] == pytest.approx((200 - 384) / 192), "B 最危险，排第一"
    assert out["bullets"][0, 1, 1] == pytest.approx((300 - 384) / 192)
    out3 = feat(k_bullets=3, d_max=90.0)(o)
    assert out3["bullets_mask"][0].tolist() == [True, True, False], "C 的 d_min=96 > d_max=90"
    assert torch.equal(out3["bullets"][0, 2], torch.zeros(7)), "未入选行清零"


def test_enemies_selected_and_boss_flag():
    o = raw_obs(n=1, player=(0.0, 384.0), target=(0.0, 384.0),
                enemies=[[(0.0, 100.0, 16.0, 1.0), (50.0, 360.0, 12.0, 0.0)]])
    out = feat(d_max=300.0)(o)
    assert out["enemies_mask"][0, :2].tolist() == [True, True]
    assert out["enemies"][0, 0, 5] == 0.0 and out["enemies"][0, 1, 5] == 1.0, "近的杂兵排前，boss 其次"


def test_empty_field_is_finite_and_masked():
    out = feat()(raw_obs(n=2))
    assert not out["bullets_mask"].any() and not out["enemies_mask"].any()
    for k, v in out.items():
        assert torch.isfinite(v.float()).all(), k
    assert torch.equal(out["bullets"], torch.zeros_like(out["bullets"]))
    assert torch.equal(out["density"], torch.zeros_like(out["density"]))


def test_density_counts_and_mirror_consistency():
    rows = [(10.5, 300.5, 0.0, 3.0, 2.0), (-100.5, 20.5, 1.0, 0.0, 2.0), (170.5, 440.5, -2.0, -1.0, 2.0)]
    o = raw_obs(n=1, player=(20.5, 380.5), target=(-60.5, 250.5), bullets=[rows])
    f = feat(d_max=1000.0)
    a, b = f(o), f(mirror_obs(o))
    assert a["density"][0, 0].sum() == 3
    assert a["density"][0, 0, int(300.5 // 32), int((10.5 + 192) // 32)] == 1
    assert torch.allclose(b["density"], a["density"].flip(-1))
    assert torch.equal(a["bullets_mask"], b["bullets_mask"])
    assert torch.allclose(b["bullets"][..., [0, 2]], -a["bullets"][..., [0, 2]], atol=1e-6)
    assert torch.allclose(b["bullets"][..., [1, 3, 4, 5, 6]], a["bullets"][..., [1, 3, 4, 5, 6]], atol=1e-6)
    assert torch.allclose(b["cond"][:, 0], -a["cond"][:, 0]) and torch.allclose(b["cond"][:, 1:], a["cond"][:, 1:])
    assert torch.allclose(b["player"][:, 0], -a["player"][:, 0])


def test_v3_uses_enemy_velocity_in_closest_approach():
    """danger_topk_v3（实验 G）= v2 + 敌人速度：把敌人当移动而非静止算最近接近（速度由引擎给出）。"""
    v1 = FEATURIZERS.get("danger_topk_v1")(small_cfg())
    v3 = FEATURIZERS.get("danger_topk_v3")(small_cfg(featurize={"name": "danger_topk_v3"}))
    assert v3.spec()["enemies"] == (v1.spec()["enemies"][0], v1.F_ENEMY + 2)
    # 自机在 (0,380)；敌在正上方 (0,300)，以每帧 4 px 俯冲 ⇒ 20 帧后撞上
    o = raw_obs(n=1, player=(0.0, 380.0), target=(0.0, 380.0),
                enemies=[[(0.0, 300.0, 16.0, 0.0, 0.0, 4.0)]])
    f1, f3 = v1(o), v3(o)
    d1 = f1["enemies"][0, 0, 3].item()          # v1：把敌当静止，最近距离 = 当前距离
    d3 = f3["enemies"][0, 0, 3].item()
    assert d1 > 0.4 and d3 < 0.05, f"v1 看不出会撞上（{d1:.3f}），v3 应预测到贴近（{d3:.3f}）"
    assert f3["enemies"][0, 0, 6:8].tolist() == pytest.approx([0.0, 0.5]), "末两列 = 速度 / 8"


def test_density_mirror_exact_on_cell_edges():
    # x 落在内部格线上（32 的整数倍），旧实现整颗记到右侧格，镜像后不等于左右翻转。
    xs = [0.0, -160.0, 32.0, 192.0, -192.0]
    ys = [16.0, 80.0, 144.0, 208.0, 272.0]
    vxs = [1.0, -2.0, 3.0, -1.0, 2.0]
    rows = [(x, y, vx, 1.0, 2.0) for x, y, vx in zip(xs, ys, vxs)]
    o = raw_obs(n=1, player=(13.5, 371.5), target=(-41.5, 260.5), bullets=[rows])
    f = feat(d_max=1000.0)
    a, b = f(o), f(mirror_obs(o))
    assert torch.equal(b["density"], a["density"].flip(-1))
    assert a["density"][0, 0].sum() == 5
    # x = 0.0 在内部格线上：第 0 行第 5、6 列各 0.5。
    assert a["density"][0, 0, 0, 5] == 0.5 and a["density"][0, 0, 0, 6] == 0.5
