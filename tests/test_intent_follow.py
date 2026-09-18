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
