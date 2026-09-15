import numpy as np
import pytest
import stg_rl
import torch
from stgagent import consts as C

from conftest import FIXTURES, small_cfg
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import EnvWrapper
from stgtrain.registry import load_builtins

load_builtins()
CPU = torch.device("cpu")
IMAGES = compile_cards(discover(FIXTURES / "cards"))


def ring(seed=1, mirror=False, **env):
    cfg = small_cfg(env={"mirror": mirror, **env})
    return EnvWrapper(cfg, IMAGES, [stg_rl.Start("example_ring", 0, 2)], CPU, seed=seed)


def fx_col(u8: np.ndarray, off: int) -> np.ndarray:
    return np.frombuffer(np.ascontiguousarray(u8[..., off:off + 4]).tobytes(), "<i4").astype(np.float64) / 65536


def still(n):
    return torch.zeros(n, dtype=torch.int64)


def test_reset_shapes():
    w = ring()
    o = w.reset()
    assert o.player_xy.shape == (8, 2) and o.bullets.shape == (8, 256, 5) and o.bullets_mask.shape == (8, 256)
    assert o.enemies.shape == (8, 256, 4) and o.enemies_mask.shape == (8, 256) and o.target_xy.shape == (8, 2)
    assert (o.player_xy[:, 0].abs() <= 192).all() and (o.player_xy[:, 1] <= 448).all()
    assert torch.allclose(o.target_xy, w.intent.target)


def test_decode_matches_raw_buffers():
    w = ring()
    w.reset()
    for _ in range(200):
        o, _ = w.step(still(8))
    p = w.buf["player"].numpy()
    x_off = stg_rl.OFFSETS["player"]["x"][0]
    assert np.allclose(o.player_xy[:, 0].numpy(), fx_col(p, x_off))
    rows, offs = w.buf["bullets"].numpy(), w.buf["bullets_offsets"].numpy()
    assert offs[-1] > 0, "200 帧后场上应有弹"
    bo = stg_rl.OFFSETS["bullets"]
    for i in range(8):
        r = rows[offs[i]:offs[i + 1]]
        k = len(r)
        assert np.allclose(o.bullets[i, :k, 0].numpy(), fx_col(r, bo["x"][0]))
        assert np.allclose(o.bullets[i, :k, 4].numpy(), fx_col(r, bo["radius"][0]))
        assert o.bullets_mask[i, :k].numpy().tolist() == ((r[:, bo["flags"][0]] & 1) != 0).tolist()
        assert not o.bullets_mask[i, k:].any()
    assert (o.enemies_mask.sum(1) >= 1).all(), "boss 本体可碰撞"


def test_mirror_flips_x_consistently():
    a, b = ring(seed=5, mirror=False), ring(seed=5, mirror=True)
    a.reset()
    b.reset()
    for _ in range(120):
        oa, _ = a.step(still(8))  # 方向 0 在镜像下不变 ⇒ 两边物理输入相同
        ob, _ = b.step(still(8))
    s = torch.where(b.mirrored, -1.0, 1.0)
    assert b.mirrored.any() and (~b.mirrored).any(), "种子 5 下 8 个 env 应两种都有"
    assert torch.allclose(ob.player_xy[:, 0], s * oa.player_xy[:, 0])
    assert torch.allclose(ob.player_xy[:, 1], oa.player_xy[:, 1])
    assert torch.allclose(ob.target_xy[:, 0], s * oa.target_xy[:, 0])
    assert torch.allclose(ob.bullets[..., 0], s[:, None] * oa.bullets[..., 0])
    assert torch.allclose(ob.bullets[..., 2], s[:, None] * oa.bullets[..., 2])


def test_actions_are_mirrored_before_sending():
    w = ring(mirror=False)
    w.reset()
    right = torch.full((8,), 6, dtype=torch.int64)
    w.mirrored[:4] = True
    _, info = w.step(right)
    assert info.buttons[:4].eq(C.BTN_LEFT | C.BTN_SHOT).all()
    assert info.buttons[4:].eq(C.BTN_RIGHT | C.BTN_SHOT).all()
    _, info2 = w.step(right)
    assert torch.equal(info2.prev_buttons, info.buttons)


def test_done_resets_per_env_state():
    cfg = small_cfg(env={"mirror": True, "warmup_max": 0})
    w = EnvWrapper(cfg, IMAGES, [stg_rl.Start("example_calm", 0, 2)], CPU, seed=2)
    w.reset()
    for _ in range(400):
        _, info = w.step(torch.full((8,), 10, dtype=torch.int64))  # 一直按下：贴底，远离 (0,100) 的 boss 本体，不会撞死
        if (info.done == 2).all():
            break
    else:
        pytest.fail("静场卡 300 帧应以 done=2 收段")
    assert (info.ep_frames > 250).all()
    assert w.prev_buttons.eq(0).all(), "新局首步的上一帧按键清零"
    assert not info.refreshed.any(), "结束的 env 本步不算刷新"
    assert (w.intent.countdown >= 120).all()


def test_same_seed_is_deterministic():
    a, b = ring(seed=11, mirror=True), ring(seed=11, mirror=True)
    oa, ob = a.reset(), b.reset()
    g = torch.Generator().manual_seed(0)
    for _ in range(60):
        act = torch.randint(0, 18, (8,), generator=g)
        oa, ia = a.step(act)
        ob, ib = b.step(act)
    for f in ("player_xy", "bullets", "bullets_mask", "enemies", "target_xy"):
        assert torch.equal(getattr(oa, f), getattr(ob, f)), f
    assert torch.equal(ia.done, ib.done)
