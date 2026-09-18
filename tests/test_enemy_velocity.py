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
