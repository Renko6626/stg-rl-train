"""激光表解码（stg_rl Tier 0 `lasers`）：逐字段对原始缓冲、镜像、窄解码、陈旧行。"""
import math

import numpy as np
import stg_rl
import torch

from conftest import FIXTURES, small_cfg
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import LASER_COLS, EnvWrapper, laser_width, mirror_lasers_
from stgtrain.registry import load_builtins

load_builtins()
CPU = torch.device("cpu")
IMAGES = compile_cards(discover(FIXTURES / "laser_cards"))
C = {name: k for k, name in enumerate(LASER_COLS)}


def env(seed=1, mirror=False):
    cfg = small_cfg(env={"mirror": mirror})
    return EnvWrapper(cfg, IMAGES, [stg_rl.Start("example_laser", 0, 2)], CPU, seed=seed)


def still(n):
    return torch.zeros(n, dtype=torch.int64)


def run(w, frames=140):
    w.reset()
    o = None
    for _ in range(frames):
        o, _ = w.step(still(w.n))
    return o


def col(u8: np.ndarray, off: int, dt: str, size: int, scale: float = 1.0) -> np.ndarray:
    return np.frombuffer(np.ascontiguousarray(u8[..., off:off + size]).tobytes(), dt).astype(np.float64) * scale


def test_decode_matches_raw_buffers():
    w = env()
    o = run(w)
    lz, cnt = w.buf["lasers"].numpy(), w.buf["lasers_count"].numpy()
    assert o.lasers.shape == (w.n, stg_rl.LASERS_CAP, len(LASER_COLS))
    assert (cnt > 0).sum() >= w.n // 2, "夹具卡 140 帧时多数 env 场上应有激光（预热随机，个别 env 恰在空档）"
    off = {k: v[0] for k, v in stg_rl.OFFSETS["lasers"].items()}
    for i in range(w.n):
        k = int(cnt[i])
        r = lz[i, :k]
        fx = lambda name: col(r, off[name], "<i4", 4, 1 / 65536)  # noqa: E731
        for name in ("x", "y", "start", "end", "half_h", "speed", "omega", "vx", "vy"):
            assert np.allclose(o.lasers[i, :k, C[name]].numpy(), fx(name), atol=1e-6), name
        ang = col(r, off["angle"], "<u2", 2, 2 * math.pi / 65536)
        assert np.allclose(o.lasers[i, :k, C["angle"]].numpy(), ang, atol=1e-6)
        assert o.lasers[i, :k, C["t_active"]].tolist() == col(r, off["t_active"], "<i4", 4).tolist()
        assert o.lasers[i, :k, C["state"]].tolist() == r[:, off["state"]].astype(float).tolist()
        assert o.lasers_mask[i, :k].all() and not o.lasers_mask[i, k:].any()
        assert (o.lasers[i, k:] == 0).all(), "掩码外的行清零"


def test_fields_have_expected_physics():
    """夹具的三种形态：生效中的扫射线有 omega、飞行短棒有 speed 且 start > 0、半宽 = width / 2。"""
    o = run(env())
    rows = o.lasers[o.lasers_mask]
    half = sorted(rows[:, C["half_h"]].tolist())
    assert {4.0, 6.0, 12.0} <= set(half), half
    sweep = rows[rows[:, C["half_h"]] == 12.0]
    assert (sweep[:, C["omega"]] > 0).any(), "扫射线生效后有角速度"
    bar = rows[rows[:, C["half_h"]] == 4.0]
    assert (bar[:, C["speed"]] == 3.0).all() and (bar[:, C["start"]] > 0).any()
    assert (rows[:, C["state"]] <= 2).all()
    warn = rows[rows[:, C["state"]] == 0]
    assert (warn[:, C["t_active"]] >= 0).all()
    assert (rows[rows[:, C["state"]] != 0][:, C["t_active"]] == 0).all(), "生效 / 收缩态 t_active 恒 0"


def _world_points(lasers: torch.Tensor) -> torch.Tensor:
    """每条激光 start / end 两个端点的世界坐标 [..., 2, 2]。"""
    x, y, a = lasers[..., C["x"]], lasers[..., C["y"]], lasers[..., C["angle"]]
    d = torch.stack([torch.cos(a), torch.sin(a)], dim=-1)
    o = torch.stack([x, y], dim=-1)
    return torch.stack([o + d * lasers[..., C["start"], None], o + d * lasers[..., C["end"], None]], dim=-2)


def test_mirror_reflects_geometry():
    a, b = env(seed=5, mirror=False), env(seed=5, mirror=True)
    oa, ob = run(a), run(b)
    assert b.mirrored.any() and (~b.mirrored).any()
    # 自机不动 ⇒ 两边世界一样，只是镜像 env 的激光被翻过去（自机狙瞄的是 x=0 的自机，镜像后仍对称）
    for i in range(a.n):
        m = oa.lasers_mask[i]
        assert torch.equal(m, ob.lasers_mask[i])
        pa, pb = _world_points(oa.lasers[i][m]), _world_points(ob.lasers[i][m])
        if b.mirrored[i]:
            pb = pb * torch.tensor([-1.0, 1.0])
            ra, rb = oa.lasers[i][m], ob.lasers[i][m]
            assert torch.allclose(rb[:, C["omega"]], -ra[:, C["omega"]])
            assert torch.allclose(rb[:, C["vx"]], -ra[:, C["vx"]])
            assert (rb[:, C["angle"]] >= 0).all() and (rb[:, C["angle"]] < 2 * math.pi).all()
        assert torch.allclose(pa, pb, atol=1e-3), i


def test_mirror_twice_is_identity():
    g = torch.Generator().manual_seed(0)
    lz = torch.rand(3, 5, len(LASER_COLS), generator=g) * 100
    lz[..., C["angle"]] = torch.rand(3, 5, generator=g) * 2 * math.pi
    m = torch.tensor([True, False, True])[:, None].expand(3, 5)
    twice = mirror_lasers_(mirror_lasers_(lz.clone(), m), m)
    assert torch.allclose(twice, lz, atol=1e-4)
    assert torch.equal(mirror_lasers_(lz.clone(), m)[1], lz[1]), "不镜像的 env 原样"


def test_laser_width_buckets():
    assert [laser_width(k) for k in (0, 1, 8, 9, 33, 64)] == [8, 8, 8, 16, 64, 64]


def test_stale_rows_zeroed_by_count():
    """Rust 只覆写前 count 行：把计数压成 1，第 2 行之后必须清零、掩码为假。"""
    w = env()
    run(w)
    raw = w._copy_in()
    raw["lasers_count"] = torch.ones_like(raw["lasers_count"])
    obs = w._decode(raw)
    assert obs.lasers_mask[:, 0].all() and not obs.lasers_mask[:, 1:].any()
    assert (obs.lasers[:, 1:] == 0).all()


def test_no_laser_card_gives_empty_table():
    ring = compile_cards(discover(FIXTURES / "cards"))
    w = EnvWrapper(small_cfg(), ring, [stg_rl.Start("example_ring", 0, 2)], CPU, seed=1)
    o = w.reset()
    for _ in range(30):
        o, _ = w.step(still(w.n))
    assert not o.lasers_mask.any() and (o.lasers == 0).all()
