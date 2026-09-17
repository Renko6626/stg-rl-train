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
