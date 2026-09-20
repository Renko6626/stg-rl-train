import torch

from conftest import mirror_obs, raw_obs, small_cfg
from stgtrain.registry import FEATURIZERS, load_builtins

load_builtins()


def feats(**sections):
    return FEATURIZERS.get("danger_topk_v2")(small_cfg(featurize={"name": "danger_topk_v2"}, **sections))


def test_v2_is_v1_plus_prev_action_onehot():
    v1 = FEATURIZERS.get("danger_topk_v1")(small_cfg())
    v2 = feats()
    assert v2.spec()["player"] == (13,) and {k: s for k, s in v2.spec().items() if k != "player"} == \
        {k: s for k, s in v1.spec().items() if k != "player"}
    o = raw_obs(n=3, bullets=[[(10.0, 300.0, 0.0, 1.0, 2.0)]] * 3, prev_action=[0, 7, 12])
    a, b = v1(o), v2(o)
    for k in a:
        if k != "player":
            assert torch.equal(a[k], b[k]), k
    assert torch.equal(b["player"][:, :3], a["player"])
    tail = b["player"][:, 3:]
    # 动作 id = 方向 × 2 + slow：0 → 方向 0；7 → 方向 3 + slow；12 → 方向 6
    assert tail[0].tolist() == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    assert tail[1].tolist() == [0, 0, 0, 1, 0, 0, 0, 0, 0, 1]
    assert tail[2].tolist() == [0, 0, 0, 0, 0, 0, 1, 0, 0, 0]


def test_v2_missing_prev_action_is_still():
    o = raw_obs(n=2)
    o.prev_action = None
    assert feats()(o)["player"][:, 3:].tolist() == [[1] + [0] * 9] * 2


def test_v2_mirror_maps_prev_direction():
    o = raw_obs(n=1, player=(30.0, 380.0), prev_action=[6])  # 方向 3 = 右
    m = feats()(mirror_obs(o))["player"][0, 3:]
    assert m.tolist() == [0, 0, 0, 0, 0, 0, 0, 1, 0, 0], "镜像后应为方向 7 = 左"


def test_v4_appends_normalised_dir_held():
    """v4 = v3 + 「当前方向已执行几帧」：封顶 16、归一化到 [0, 1]；缺席（旧调用方）按「早就可以换了」= 1。"""
    from stgtrain.featurize.danger_topk_v4 import HELD_CAP

    cfg = small_cfg(featurize={"name": "danger_topk_v4", "k_bullets": 8, "k_enemies": 4})
    v3 = FEATURIZERS.get("danger_topk_v3")(cfg)
    v4 = FEATURIZERS.get("danger_topk_v4")(cfg)
    assert v4.spec()["player"] == (v3.spec()["player"][0] + 1,)
    obs = raw_obs(n=3)
    obs.dir_held = torch.tensor([1, 8, 1 << 20])
    out3, out4 = v3(obs), v4(obs)
    assert torch.equal(out4["player"][:, :-1], out3["player"]), "前 13 维与 v3 逐位相同"
    assert torch.allclose(out4["player"][:, -1], torch.tensor([1 / HELD_CAP, 8 / HELD_CAP, 1.0]))
    obs.dir_held = None
    assert torch.equal(v4(obs)["player"][:, -1], torch.ones(3))


def test_v5_appends_normalised_slow_held():
    from stgtrain.featurize.danger_topk_v4 import HELD_CAP

    cfg = small_cfg(featurize={"name": "danger_topk_v5", "k_bullets": 8, "k_enemies": 4})
    v4, v5 = FEATURIZERS.get("danger_topk_v4")(cfg), FEATURIZERS.get("danger_topk_v5")(cfg)
    assert v5.spec()["player"] == (v4.spec()["player"][0] + 1,)
    obs = raw_obs(n=3)
    obs.dir_held = torch.tensor([2, 5, 9])
    obs.slow_held = torch.tensor([1, 8, 1 << 20])
    assert torch.equal(v5(obs)["player"][:, :-1], v4(obs)["player"]), "前 14 维与 v4 逐位相同"
    assert torch.allclose(v5(obs)["player"][:, -1], torch.tensor([1 / HELD_CAP, 8 / HELD_CAP, 1.0]))
    obs.slow_held = None
    assert torch.equal(v5(obs)["player"][:, -1], torch.ones(3))
