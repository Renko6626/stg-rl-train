"""自由躲弹诊断用意图：目标点每帧锁在自机身上（cond 恒为「距离 0、在圈内」）。"""
import torch

from conftest import small_cfg
from stgtrain.registry import INTENTS, load_builtins

load_builtins()


def test_follow_player_tracks_and_never_refreshes():
    cfg = small_cfg(intent={"name": "follow_player_v1"})
    it = INTENTS.get("follow_player_v1")(cfg, 3, torch.device("cpu"), seed=1)
    assert it.target.shape == (3, 2)
    xy = torch.tensor([[10.0, 300.0], [-50.0, 100.0], [0.0, 448.0]])
    it.track(xy)
    assert torch.equal(it.target, xy)
    refreshed = it.advance(1, torch.ones(3, dtype=torch.bool))
    assert not refreshed.any(), "锁在自机时没有刷新段，到达用时等指标无意义"
    it.reset(torch.tensor([True, False, True]))
    assert torch.equal(it.target, xy), "重置不改目标：下一步 track 会覆盖"


def test_envwrap_tracks_player_for_follow_intent():
    import stg_rl

    from stgtrain.cards import compile_cards, discover
    from stgtrain.envwrap import EnvWrapper

    cfg = small_cfg(intent={"name": "follow_player_v1"}, env={"mirror": True, "warmup_max": 0})
    images = compile_cards(discover(cfg["env"]["cards_dir"]))
    w = EnvWrapper(cfg, images, [stg_rl.Start("example_ring", 0, 2)], torch.device("cpu"), seed=3)
    obs = w.reset()
    assert torch.allclose(obs.target_xy, obs.player_xy), "开局即锁在自机"
    for _ in range(30):
        obs, _ = w.step(torch.full((8,), 6, dtype=torch.int64))
    assert torch.allclose(obs.target_xy, obs.player_xy), "镜像局也一致（两者同在智能体坐标系）"


def test_fixed_point_is_constant_and_configurable():
    cfg = small_cfg(intent={"name": "fixed_point_v1", "x": -30.0, "y": 400.0})
    it = INTENTS.get("fixed_point_v1")(cfg, 2, torch.device("cpu"), seed=1)
    assert it.target.tolist() == [[-30.0, 400.0], [-30.0, 400.0]]
    it.reset(torch.ones(2, dtype=torch.bool))
    assert not it.advance(1, torch.ones(2, dtype=torch.bool)).any()
    assert it.target.tolist() == [[-30.0, 400.0], [-30.0, 400.0]]


def test_under_boss_tracks_boss_x_and_falls_back():
    cfg = small_cfg(intent={"name": "under_boss_v1", "y": 384.0})
    it = INTENTS.get("under_boss_v1")(cfg, 2, torch.device("cpu"), seed=1)
    xy = torch.tensor([[[-40.0, 100.0], [60.0, 90.0]], [[10.0, 50.0], [0.0, 0.0]]])
    is_boss = torch.tensor([[False, True], [False, False]])
    mask = torch.tensor([[True, True], [True, False]])
    it.track_world(torch.zeros(2, 2), xy, is_boss, mask)
    assert it.target[0].tolist() == [60.0, 384.0], "跟 boss 的 x，y 固定在下半屏"
    assert it.target[1].tolist() == [0.0, 384.0], "没有 boss 时退回场底中央"


def test_boss_or_free_switches_with_hysteresis():
    """压力够大进自由档（目标点 = 自机），降到一半以下且待满 hold 帧才切回 boss 正下方；新局回到跟 boss。"""
    from conftest import small_cfg
    from stgtrain.registry import INTENTS

    cfg = small_cfg(intent={"name": "boss_or_free_v1", "pressure_on": 4, "pressure_hold": 3, "pressure_radius": 50.0})
    it = INTENTS.get("boss_or_free_v1")(cfg, 1, torch.device("cpu"), seed=0)
    player = torch.tensor([[30.0, 300.0]])
    boss = torch.tensor([[[-80.0, 60.0]]])

    def step(n_near):
        b = torch.zeros(1, 8, 5)
        b[0, :, 0:2] = torch.tensor([30.0, 260.0])          # 40 px 外、半径 4 ⇒ 边缘距离 36，圈内
        b[0, :, 4] = 4.0
        m = torch.zeros(1, 8, dtype=torch.bool)
        m[0, :n_near] = True
        it.track_bullets(player, b, m)
        it.track_world(player, boss, torch.ones(1, 1, dtype=torch.bool), torch.ones(1, 1, dtype=torch.bool))
        return it.target[0].tolist()

    assert step(3) == [-80.0, 384.0], "压力不够：跟 boss 正下方"
    assert step(4) == [30.0, 300.0], "压力到阈值：目标点锁自机"
    assert step(1) == [30.0, 300.0] and step(1) == [30.0, 300.0], "压力降了，但还没待满 hold 帧"
    assert step(3) == [30.0, 300.0], "待满了，但压力 3 > off 2：不切"
    assert step(2) == [-80.0, 384.0], "压力 ≤ off 且待满 hold：切回"
    step(8)
    it.reset(torch.ones(1, dtype=torch.bool))
    assert step(0) == [-80.0, 384.0], "新局从跟 boss 开始"
    assert it.switches == 3
