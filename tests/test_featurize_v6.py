"""danger_topk_v6（d / t 对照实验，docs/2026-09-25-dt-ablation-design.md §4）。"""
import pytest
import torch

from conftest import small_cfg
from stgtrain.envwrap import RawObs
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

load_builtins()

HIT_R = 2.0


def feats(**f):
    return FEATURIZERS.get("danger_topk_v6")(small_cfg(featurize={"name": "danger_topk_v6", **f}))


def v5():
    return FEATURIZERS.get("danger_topk_v5")(small_cfg(featurize={"name": "danger_topk_v5"}))


def random_obs(n=6, cap=64, e=12, seed=0, fill=0.7) -> RawObs:
    g = torch.Generator().manual_seed(seed)
    u = lambda *s: torch.rand(*s, generator=g)  # noqa: E731
    b = torch.stack([u(n, cap) * 384 - 192, u(n, cap) * 448, (u(n, cap) - 0.5) * 8, (u(n, cap) - 0.5) * 8,
                     1 + u(n, cap) * 6], dim=-1)
    en = torch.stack([u(n, e) * 384 - 192, u(n, e) * 300, 4 + u(n, e) * 20, (u(n, e) < 0.2).float(),
                      (u(n, e) - 0.5) * 4, (u(n, e) - 0.5) * 4], dim=-1)
    return RawObs(
        player_xy=torch.stack([u(n) * 300 - 150, 250 + u(n) * 180], dim=-1),
        player_hit_r=torch.full((n,), HIT_R), player_speed=torch.full((n,), 4.5),
        player_focus=u(n) < 0.5,
        bullets=b, bullets_mask=u(n, cap) < fill, enemies=en, enemies_mask=u(n, e) < fill,
        target_xy=torch.stack([u(n) * 300 - 150, 250 + u(n) * 180], dim=-1),
        prev_action=(u(n) * 18).long(), dir_held=(u(n) * 20).long(), slow_held=(u(n) * 20).long(),
    )


def test_defaults_equal_v5():
    o = random_obs()
    a, b = v5()(o), feats()(o)
    assert v5().spec() == feats().spec()
    for k in a:
        assert torch.equal(a[k], b[k]), k


@pytest.mark.parametrize("dt", [True, False])
def test_static_frame_ignores_target(dt):
    f = feats(frame="static", dt=dt)
    o = random_obs(seed=1)
    a = f(o)
    o.target_xy = o.target_xy + torch.tensor([37.0, -81.0])
    b = f(o)
    for k in ("bullets", "bullets_mask", "enemies", "enemies_mask", "density", "player"):
        assert torch.equal(a[k], b[k]), k
    assert not torch.equal(a["cond"], b["cond"]), "目标点仍要从 cond 进来"


def test_static_frame_velocity_is_absolute():
    f = feats(frame="static")
    o = random_obs(seed=2)
    out = f(o)
    kept = out["bullets_mask"]
    pos = out["bullets"][..., 0:2] * 192.0 + o.player_xy[:, None, :]
    for i in range(o.player_xy.shape[0]):
        for j in torch.nonzero(kept[i]).flatten().tolist():
            src = ((o.bullets[i, :, 0:2] - pos[i, j]).norm(dim=-1) < 1e-3) & o.bullets_mask[i]
            assert src.any()
            assert torch.allclose(out["bullets"][i, j, 2:4], o.bullets[i, src.nonzero()[0, 0], 2:4] / 8.0, atol=1e-5)


def test_no_dt_shapes():
    s = feats(dt=False).spec()
    kb = small_cfg()["featurize"]["k_bullets"]
    assert s["bullets"] == (kb, 5) and s["enemies"] == (8, 6)
    out = feats(frame="static", dt=False)(random_obs(seed=3))
    for k, shape in s.items():
        assert tuple(out[k].shape[1:]) == shape, k


@pytest.mark.parametrize("frame", ["target", "static"])
def test_no_dt_selects_nearest_by_edge_distance(frame):
    f = feats(frame=frame, dt=False)
    kb = f.kb
    o = random_obs(seed=4, fill=0.9)
    out = f(o)
    for i in range(o.player_xy.shape[0]):
        edge = (o.bullets[i, :, 0:2] - o.player_xy[i]).norm(dim=-1) - o.bullets[i, :, 4] - HIT_R
        edge = edge.masked_fill(~o.bullets_mask[i], float("inf"))
        want = torch.sort(edge).values[:kb]
        want = want[torch.isfinite(want)]
        rel = out["bullets"][i][out["bullets_mask"][i]]
        got = torch.sort(rel[:, 0:2].mul(192.0).norm(dim=-1) - rel[:, 4] * 8.0 - HIT_R).values
        assert got.shape == want.shape
        assert torch.allclose(got, want, atol=1e-3)


def test_no_dt_has_no_distance_cutoff_and_masks_padding():
    f = feats(frame="static", dt=False)
    o = random_obs(n=2, seed=5, fill=0.0)
    o.bullets_mask[0, :3] = True
    o.bullets[0, :3, 0:2] = o.player_xy[0] + torch.tensor([[300.0, 0.0], [0.0, -200.0], [-250.0, -150.0]])
    out = f(o)
    assert out["bullets_mask"][0].sum() == 3, "远处的弹也要入选（不设距离上限）"
    assert out["bullets_mask"][1].sum() == 0
    assert torch.all(out["bullets"][1] == 0) and torch.all(out["bullets"][0][~out["bullets_mask"][0]] == 0)


def test_no_dt_enemy_columns():
    f = feats(frame="static", dt=False)
    o = random_obs(seed=6)
    out = f(o)
    i = 0
    j = int(torch.nonzero(out["enemies_mask"][i])[0])
    row = out["enemies"][i, j]
    pos = row[0:2] * 192.0 + o.player_xy[i]
    src = int(((o.enemies[i, :, 0:2] - pos).norm(dim=-1) < 1e-3).nonzero()[0, 0])
    e = o.enemies[i, src]
    assert torch.allclose(row, torch.cat([(e[0:2] - o.player_xy[i]) / 192.0, e[2:3] / 32.0, e[3:4], e[4:6] / 8.0]),
                          atol=1e-5)


@pytest.mark.parametrize("frame,dt", [("target", True), ("static", True), ("static", False), ("target", False)])
def test_model_builds_and_is_finite(frame, dt):
    cfg = small_cfg(featurize={"name": "danger_topk_v6", "frame": frame, "dt": dt})
    f = FEATURIZERS.get("danger_topk_v6")(cfg)
    model = MODELS.get(cfg["model"]["name"])(cfg, f.spec())
    for fill in (0.7, 0.0):
        logits, value = model(f(random_obs(seed=7, fill=fill)))
        assert torch.isfinite(logits).all() and torch.isfinite(value).all()


def test_bad_options_rejected():
    with pytest.raises(ValueError):
        feats(frame="moving")
    with pytest.raises(ValueError):
        feats(dt="no")
