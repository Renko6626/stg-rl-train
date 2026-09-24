import numpy as np
import pytest
import stg_rl
import torch
from stgagent import consts as C

from conftest import FIXTURES, small_cfg
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import EnvWrapper, _fx
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
    assert o.enemies.shape == (8, 256, 6) and o.enemies_mask.shape == (8, 256) and o.target_xy.shape == (8, 2)
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


def test_fx_decodes_row_strides_not_divisible_by_4():
    """_fx 直测。bullets 表行跨步 = 30 不被 4 整除：切片 (k,4) 在 k==1 时仍是 PyTorch 眼中的
    “连续”张量（size-1 维的步长被忽略），旧实现 `.contiguous().view(int32)` 会抛 stride 错误。
    覆盖 (0,30)/(1,30)/(3,30)/(1,36)/(2,256,38)；单行用例取 (5,30) 的 `[:1]` 切片。
    另测 off=22（bullets `radius` 真实偏移，非 4 对齐）：`contiguous()` 对 size-1 / 空张量是 no-op，
    只压平不归零偏移仍会在空/单行时崩溃。"""
    rng = np.random.default_rng(20240521)

    def probe(shape, off, source_shape=None):
        src = source_shape if source_shape is not None else shape
        u8 = rng.integers(0, 256, size=src, dtype=np.uint8)
        vals = rng.integers(-(2**31), 2**31, size=src[:-1], dtype=np.int64).astype("<i4")
        u8[..., off:off + 4] = np.frombuffer(vals.tobytes(), dtype=np.uint8).reshape(src[:-1] + (4,))
        return (u8[:1] if source_shape is not None else u8), off

    cases = [
        ("(0,30) 空表 off=4", probe((0, 30), 4)),
        ("(0,30) 空表 off=22", probe((0, 30), 22)),
        ("(1,30) 单行切片 off=4", probe((1, 30), 4, source_shape=(5, 30))),
        ("(1,30) 单行切片 off=22", probe((1, 30), 22, source_shape=(5, 30))),
        ("(3,30) 多行 off=4", probe((3, 30), 4)),
        ("(1,36) 跨步整除 off=4", probe((1, 36), 4)),
        ("(2,256,38) 多维 off=4", probe((2, 256, 38), 4)),
    ]
    for name, (u8, off) in cases:
        want = (np.frombuffer(np.ascontiguousarray(u8[..., off:off + 4]).tobytes(), "<i4")
                .astype(np.float64) / 65536).reshape(u8.shape[:-1])
        got = _fx(torch.from_numpy(u8), off).numpy()
        assert got.shape == u8.shape[:-1], name
        assert np.array_equal(got, want.astype(np.float32)), name


def test_prev_action_tracks_agent_frame_and_resets():
    w = ring(mirror=False)
    obs = w.reset()
    assert obs.prev_action.eq(0).all()
    w.mirrored[:4] = True
    ids = torch.tensor([6, 7, 2, 0, 6, 7, 2, 0], dtype=torch.int64)
    obs, info = w.step(ids)
    assert torch.equal(obs.prev_action, ids), "记智能体坐标系的动作 id（镜像前），不是发给游戏的按键"
    obs, info = w.step(torch.zeros(8, dtype=torch.int64))
    assert obs.prev_action.eq(0).all()


def test_prev_action_cleared_on_episode_end():
    cfg = small_cfg(env={"mirror": True, "warmup_max": 0})
    w = EnvWrapper(cfg, IMAGES, [stg_rl.Start("example_calm", 0, 2)], CPU, seed=2)
    w.reset()
    for _ in range(400):
        obs, info = w.step(torch.full((8,), 10, dtype=torch.int64))
        if (info.done == 2).all():
            break
    assert obs.prev_action.eq(0).all()


def test_reported_intent_mode_is_the_finished_episode_not_the_next_one():
    """局结束那一步，StepInfo.intent_mode 必须是**刚结束那局**的档。

    intent.reset(ended) 会给结束的 env 抽下一局的模式；晚读一步就把统计全打乱——
    三档独立抽样时，分组等于随机切一刀，三档指标会一模一样（实验 I 踩过这个坑）。
    """
    w = ring(max_frames=3)                      # 3 帧一局，保证很快有 ended
    w.reset()

    class Stub:                                  # 模式每次 reset 都翻面，便于分辨读的是哪一边
        def __init__(self, n):
            self.mode = torch.zeros(n, dtype=torch.int64)
            self.target = torch.zeros(n, 2)
        def reset(self, mask):
            self.mode = torch.where(mask, 1 - self.mode, self.mode)
        def reset_all(self):
            pass
        def advance(self, frames, active):
            return torch.zeros_like(active)

    w.intent = Stub(w.n)
    seen_ended = False
    for _ in range(12):
        _, info = w.step(still(w.n))
        ended = info.done != 0
        if ended.any():
            seen_ended = True
            # 结束的那些 env：报的必须是翻面**之前**的值，而不是 intent 当前持有的新值
            assert torch.equal(info.intent_mode[ended], 1 - w.intent.mode[ended])
    assert seen_ended, "没等到任何一局结束，测试没押到东西"


H2D_SUBPHASES = {"h2d_copy_s", "h2d_state_s", "h2d_bullets_s", "h2d_enemies_s", "h2d_enemy_velocity_s", "h2d_finish_s"}


def test_step_reports_h2d_subphases_and_counts():
    from stgtrain.perf import PhaseTimer

    w = ring()
    w.reset()
    timer = PhaseTimer(sync_every=1, device=CPU)
    timer.start_iteration(1)
    w.step(still(w.n), timer)
    row = timer.pop_iteration()
    assert H2D_SUBPHASES <= row.keys()
    assert {"bullet_rows_mean", "bullet_rows_max", "bullets_env_max_max", "enemies_max_mean", "enemies_max_max"} <= row.keys()
    assert row["enemies_max_max"] <= stg_rl.ENEMIES_CAP


def test_step_outputs_identical_with_and_without_timer():
    """计时只加了同步边界、把设备拷贝挪到了最前面；观测必须逐位不变。"""
    from stgtrain.perf import PhaseTimer

    a, b = ring(seed=3, mirror=True), ring(seed=3, mirror=True)
    a.reset(), b.reset()
    timer = PhaseTimer(sync_every=1, device=CPU)
    for _ in range(20):
        timer.start_iteration(1)
        oa, ia = a.step(still(a.n))
        ob, ib = b.step(still(b.n), timer)
        timer.pop_iteration()
        for f in ("player_xy", "bullets", "bullets_mask", "enemies", "enemies_mask", "target_xy", "dir_held"):
            assert torch.equal(getattr(oa, f), getattr(ob, f)), f
        assert torch.equal(ia.done, ib.done) and torch.equal(ia.refreshed, ib.refreshed)


# ---- 敌人表只处理到 emax 的分档宽度（2026-09-24）----

def enemy_rows(n, rows_per_env):
    """手搓 [n, ENEMIES_CAP, 38] 敌人字节表。rows_per_env[i] = [(id, x, y, hit_w, collidable), ...]。"""
    t = torch.zeros(n, stg_rl.ENEMIES_CAP, 38, dtype=torch.uint8)
    off = lambda f: stg_rl.OFFSETS["enemies"][f][0]   # noqa: E731

    def put(i, j, o, v, width):
        t[i, j, o:o + width] = torch.tensor(list(int(v).to_bytes(width, "little", signed=width == 4 and v < 0)),
                                            dtype=torch.uint8)

    for i, rows in enumerate(rows_per_env):
        for j, (eid, x, y, r, coll) in enumerate(rows):
            put(i, j, off("x"), int(x * 65536), 4)
            put(i, j, off("y"), int(y * 65536), 4)
            put(i, j, off("hit_w"), int(r * 65536), 4)
            put(i, j, off("flags"), 0x10 if coll else 0, 2)
            put(i, j, off("id"), eid, 4)
    return t


def test_enemy_width_buckets():
    from stgtrain.envwrap import enemy_width

    assert [enemy_width(e) for e in (0, 1, 16, 17, 54, 61, 64, 65, 200, 256)] == \
        [16, 16, 16, 32, 64, 64, 64, 128, 256, 256]


def test_stale_enemy_rows_never_match_and_are_zeroed():
    """Rust 只覆写前 count 行，后面是以前的陈旧行（id 非零）。本步新出现的敌人不许匹配上上一步的陈旧行。"""
    w = ring()
    n = w.n
    count = lambda c: torch.full((n,), c, dtype=torch.int32)   # noqa: E731
    # 上一步：只有 A 活着（count=1），第 1 行是很久以前的 D（陈旧，(0,0)）
    prev = enemy_rows(n, [[(11, 0.0, 0.0, 8.0, True), (44, 0.0, 0.0, 8.0, True)]] * n)
    w._decode_enemies(prev, count(1), 1)
    w._enemy_prev_valid = torch.ones(n, dtype=torch.bool)
    # 这一步：D 真的出现在第 1 行 (5, 0)；第 2 行又是陈旧垃圾
    cur = enemy_rows(n, [[(11, 1.0, 0.0, 8.0, True), (44, 5.0, 0.0, 8.0, True), (99, 7.0, 7.0, 8.0, True)]] * n)
    enemies, emask = w._decode_enemies(cur, count(2), 2)
    assert enemies.shape == (n, stg_rl.ENEMIES_CAP, 6) and emask.shape == (n, stg_rl.ENEMIES_CAP)
    assert enemies[0, 0, 4].item() == pytest.approx(1.0), "A：(0,0)→(1,0)"
    assert enemies[0, 1, 4:6].tolist() == [0.0, 0.0], "D 上一步不在（只有陈旧行），速度记 0"
    assert emask[0, :2].all() and not emask[0, 2:].any()
    assert enemies[:, 2:].abs().sum() == 0, "count 之后的陈旧行清零"


def test_narrowed_enemy_decode_matches_full_width_reference():
    """100 只敌人 ⇒ 宽度 128；结果与在全 256 列上（按 count 屏蔽陈旧 id）算的参考一致。"""
    from stgtrain.envwrap import _fx, _off, _u32, enemy_velocity

    w = ring()
    n = w.n
    g = torch.Generator().manual_seed(0)
    # 按引擎的打包方式造 id：(代数 << 16) | 池槽号，槽号 < ENEMIES_CAP 且互不相同
    ids = (torch.randint(1, 4, (120,), generator=g) << 16) | torch.randperm(stg_rl.ENEMIES_CAP, generator=g)[:120]

    def table(shift):
        rows = [[(int(ids[(j + shift) % 120]), float(j), 2.0 * j + shift, 8.0, j % 3 != 0) for j in range(120)]] * n
        return enemy_rows(n, rows)

    a, b = table(0), table(1)
    w._decode_enemies(a, torch.full((n,), 100, dtype=torch.int32), 100)
    w._enemy_prev_valid = torch.ones(n, dtype=torch.bool)
    enemies, emask = w._decode_enemies(b, torch.full((n,), 100, dtype=torch.int32), 100)

    live = torch.arange(stg_rl.ENEMIES_CAP)[None, :] < 100
    def full(t):
        xy = torch.stack([_fx(t, _off("enemies", "x")), _fx(t, _off("enemies", "y"))], -1)
        return torch.where(live, _u32(t, _off("enemies", "id")), 0), xy
    (pid, pxy), (cid, cxy) = full(a), full(b)
    ref_v = enemy_velocity(pid, pxy, cid, cxy, 1, torch.ones(n, dtype=torch.bool)) * live[..., None]
    assert torch.equal(enemies[..., 4:6], ref_v)
    assert torch.equal(enemies[..., 0:2], cxy * live[..., None])
    assert torch.equal(emask[:, :100], torch.tensor([j % 3 != 0 for j in range(100)]).expand(n, -1))
    assert not emask[:, 100:].any()


def test_step_records_dropped_bullets():
    from stgtrain.perf import PhaseTimer

    w = ring()
    w.reset()
    timer = PhaseTimer(sync_every=1, device=CPU)
    timer.start_iteration(1)
    w.step(still(w.n), timer)
    row = timer.pop_iteration()
    assert {"bullets_dropped_max", "bullets_drop_envs_max"} <= row.keys()


def test_engine_enemy_ids_pack_pool_slot_below_cap():
    """按槽号寻址依赖引擎的 id 打包：低 16 位是池槽号且 < ENEMIES_CAP、同一 env 内活着的 id 互不相同。"""
    w = EnvWrapper(small_cfg(), IMAGES, [stg_rl.Start("example_calm", 0, 2)], CPU, seed=2)
    w.reset()
    seen = 0
    for _ in range(200):
        w.step(still(w.n))
        from stgtrain.envwrap import _off, _u32
        ids = _u32(w.buf["enemies"], _off("enemies", "id"))
        for i in range(w.n):
            live = ids[i, :int(w.buf["enemies_count"][i])]
            assert ((live & 0xFFFF) < stg_rl.ENEMIES_CAP).all() and (live != 0).all()
            assert live.unique().numel() == live.numel()
            seen += live.numel()
    assert seen > 0, "夹具里要有敌人，否则什么也没验"
