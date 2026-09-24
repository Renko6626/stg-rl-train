"""敌人速度：env 不导出敌人 vx/vy，按 enemies.id 匹配上一帧差分；特征化 v3 用它算最近接近。"""
import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.envwrap import enemy_velocity
from stgtrain.registry import FEATURIZERS, load_builtins

load_builtins()


def test_enemy_velocity_matches_by_id():
    prev_ids = torch.tensor([[7, 9, 0]])
    prev_xy = torch.tensor([[[0.0, 0.0], [10.0, 10.0], [0.0, 0.0]]])
    cur_ids = torch.tensor([[9, 7, 5]])                 # 换了槽位 + 来了个新敌 5
    cur_xy = torch.tensor([[[10.0, 16.0], [2.0, 0.0], [50.0, 50.0]]])
    v = enemy_velocity(prev_ids, prev_xy, cur_ids, cur_xy, frame_skip=2, valid=torch.ones(1, dtype=torch.bool))
    assert v[0, 0].tolist() == [0.0, 3.0], "敌 9：(10,10)→(10,16) 两帧 ⇒ 每帧 (0,3)"
    assert v[0, 1].tolist() == [1.0, 0.0], "敌 7：(0,0)→(2,0) 两帧 ⇒ 每帧 (1,0)"
    assert v[0, 2].tolist() == [0.0, 0.0], "新出现的敌：速度记 0"


def test_enemy_velocity_zero_after_episode_reset():
    prev_ids, cur_ids = torch.tensor([[3]]), torch.tensor([[3]])
    prev_xy, cur_xy = torch.tensor([[[0.0, 0.0]]]), torch.tensor([[[9.0, 9.0]]])
    v = enemy_velocity(prev_ids, prev_xy, cur_ids, cur_xy, 1, valid=torch.zeros(1, dtype=torch.bool))
    assert v.abs().sum() == 0, "新局第一步不能拿上一局的坐标差分"


def test_v3_uses_enemy_velocity_in_closest_approach():
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


def test_teleport_is_not_read_as_velocity():
    """`move_to(0, …)` 让敌人当帧跳过去（咲夜时停压平后每轮一次，最远 112px）——
    差分会读成上百 px/帧，归一化后是十几倍的离群值。单帧位移超阈值的一律记 0。"""
    ids = torch.tensor([[7, 9]], dtype=torch.int64)
    prev = torch.tensor([[[0.0, 0.0], [10.0, 10.0]]])
    cur = torch.tensor([[[3.0, 4.0], [122.0, 10.0]]])          # 7 号正常走，9 号瞬移 112px
    v = enemy_velocity(ids, prev, ids, cur, 1, torch.tensor([True]))
    assert v[0, 0].tolist() == [3.0, 4.0]
    assert v[0, 1].tolist() == [0.0, 0.0]


def test_threshold_scales_with_frame_skip():
    ids = torch.tensor([[1]], dtype=torch.int64)
    prev, cur = torch.tensor([[[0.0, 0.0]]]), torch.tensor([[[24.0, 0.0]]])
    # frame_skip=1 时 24px 一帧算瞬移；frame_skip=2 时是每帧 12px，仍在阈值内
    assert enemy_velocity(ids, prev, ids, cur, 1, torch.tensor([True]))[0, 0].tolist() == [0.0, 0.0]
    assert enemy_velocity(ids, prev, ids, cur, 2, torch.tensor([True]))[0, 0].tolist() == [12.0, 0.0]


# ---- 按池槽号直接寻址（2026-09-24）：id = (generation << 16) | 池槽号，槽号 < ENEMIES_CAP ----

def test_slot_table_matches_pairwise_reference():
    import stg_rl
    from stgtrain.envwrap import enemy_slot_table, enemy_velocity_by_slot

    g = torch.Generator().manual_seed(0)
    n, e = 3, 40
    slots = torch.stack([torch.randperm(stg_rl.ENEMIES_CAP, generator=g)[:e] for _ in range(n)])
    gen = torch.randint(1, 5, (n, e), generator=g)
    prev_ids = (gen << 16) | slots
    prev_xy = torch.rand(n, e, 2, generator=g) * 100
    keep = torch.rand(n, e, generator=g) < 0.7                       # 三成死掉 / 换代
    cur_ids = torch.where(keep, prev_ids, ((gen + 1) << 16) | slots)  # 同槽复用、代数不同 = 另一只敌
    perm = torch.stack([torch.randperm(e, generator=g) for _ in range(n)])
    cur_ids = torch.gather(cur_ids, 1, perm)                         # 顺序打乱
    cur_xy = torch.gather(prev_xy, 1, perm.unsqueeze(-1).expand(-1, -1, 2)) + torch.rand(n, e, 2, generator=g)
    valid = torch.tensor([True, True, False])
    ref = enemy_velocity(prev_ids, prev_xy, cur_ids, cur_xy, 1, valid)
    ids_t, xy_t = enemy_slot_table(prev_ids, prev_xy)
    got = enemy_velocity_by_slot(ids_t, xy_t, cur_ids, cur_xy, 1, valid)
    assert torch.equal(got, ref)
    assert (got[:2].abs().sum(-1) > 0).any() and (got[:2].abs().sum(-1) == 0).any(), "两种情况都要覆盖到"


def test_slot_out_of_range_degrades_to_no_match():
    """万一引擎改了打包方式、槽号超出 ENEMIES_CAP：不越界、不崩，按没对上处理（速度 0）。"""
    from stgtrain.envwrap import enemy_slot_table, enemy_velocity_by_slot

    ids = torch.tensor([[(1 << 16) | 300]])
    xy = torch.tensor([[[0.0, 0.0]]])
    ids_t, xy_t = enemy_slot_table(ids, xy)
    v = enemy_velocity_by_slot(ids_t, xy_t, ids, xy + 1.0, 1, torch.ones(1, dtype=torch.bool))
    assert v.abs().sum() == 0
