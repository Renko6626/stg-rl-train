import pytest
import torch

from conftest import FIXTURES, small_cfg
from stgtrain.cards import compile_cards, discover, load_splits
from stgtrain.evaluate import evaluate, score, summarize_eval
from stgtrain.ppo import PPO
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

load_builtins()


def rec(done, frames=100, reach=50.0, in_r=0.5):
    return {"env": 0, "done": done, "frames": frames, "return": 1.0, "steps": frames, "in_r_frac": in_r,
            "edge_frac": 0.0, "shift_toggles_per_s": 1.0, "dir_changes_per_s": 2.0, "reach_frames": reach,
            "key_presses_per_s": 3.0, "graze_per_s": 1.0, "close4_frac": 0.1, "close12_frac": 0.3, "dir_changes_in_r": 0, "secs_in_r": 0.0, "dir_changes_out_r": 0, "secs_out_r": 0.0,
            "quick_frac": 0.2, "dir_changes_near": 4, "secs_near": 1.0, "dir_changes_far": 2, "secs_far": 4.0}


def test_summarize_eval_and_score():
    s = summarize_eval([rec(2, reach=10.0), rec(1, reach=30.0, in_r=0.1), rec(2, reach=300.0), rec(3)])
    assert (s["graze_per_s"], s["close4_frac"], s["close12_frac"]) == pytest.approx((1.0, 0.1, 0.3))
    assert s["episodes"] == 4 and s["survival"] == 0.5 and s["death"] == 0.25 and s["timeout"] == 0.25
    assert s["reach_frames_median"] == pytest.approx(40.0)
    assert s["in_r_frac"] == pytest.approx((0.5 + 0.1 + 0.5 + 0.5) / 4)
    # 临危 / 平时的变向率按总时长合并：4 局各 4 次 / 1 秒 与 2 次 / 4 秒
    assert s["dir_changes_near_per_s"] == pytest.approx(4.0) and s["dir_changes_far_per_s"] == pytest.approx(0.5)
    assert s["quick_frac"] == pytest.approx(0.2)
    assert summarize_eval([]) == {"episodes": 0.0}
    assert score({"survival": 0.5, "in_r_frac": 0.9}) > score({"survival": 0.4, "in_r_frac": 1.0})


def test_evaluate_calm_card_counts_exact_episodes():
    cfg = small_cfg()
    device = torch.device("cpu")
    images = compile_cards(discover(FIXTURES / "cards"))
    specs = load_splits(FIXTURES / "eval_splits.toml", cfg["eval"]["episodes"])
    feat = FEATURIZERS.get("danger_topk_v1")(cfg)
    ppo = PPO(cfg, lambda: MODELS.get("set_attn_v1")(cfg, feat.spec()), device)
    # 固定「一直按下」：测的是评测管线，不是策略（未训练的网络可能撞上 boss 本体）
    ppo.act = lambda feats, greedy: torch.full((feats["player"].shape[0],), 10, dtype=torch.int64)
    res = evaluate(cfg, ppo, feat, images, specs, device)
    r2 = res["cards"]["example_calm"]["r2"]
    assert r2["episodes"] == 4 and r2["survival"] == 1.0
    # 静场卡脚本段在引擎第 303 帧结束；env 预热（warmup_max=120，且不占 ep_frames）会先吃掉最多 120 帧，
    # 所以每局 183..303 帧、均值约 222。阈值放宽到 150 仍能抓住评测管线提前截断的 bug。
    assert r2["frames_mean"] > 150
    assert res["overall"]["episodes"] == 4


def test_summarize_pools_radius_split_rates():
    a = {**rec(2), "key_presses_per_s": 4.0, "dir_changes_in_r": 6, "secs_in_r": 1.0, "dir_changes_out_r": 1, "secs_out_r": 2.0}
    b = {**rec(2), "key_presses_per_s": 2.0, "dir_changes_in_r": 0, "secs_in_r": 0.0, "dir_changes_out_r": 3, "secs_out_r": 2.0}
    s = summarize_eval([a, b])
    assert s["key_presses_per_s"] == pytest.approx(3.0)
    assert s["dir_changes_in_r_per_s"] == pytest.approx(6 / 1.0), "按总时长合并，不对各局比率取平均"
    assert s["dir_changes_out_r_per_s"] == pytest.approx(4 / 4.0)
    assert summarize_eval([b])["dir_changes_in_r_per_s"] == 0.0, "点内时长为 0 时记 0"


def test_hysteresis_keeps_prev_action_unless_margin_exceeds_tau():
    import torch

    from stgtrain.evaluate import hysteresis_action

    logits = torch.tensor([[0.0, 1.0, 0.5],    # 最优 1，上一步 2：差 0.5
                           [0.0, 1.0, 0.5],
                           [3.0, 1.0, 0.0],    # 最优 0，上一步 2：差 3.0
                           [0.0, 2.0, 0.0]])   # 上一步就是最优
    prev = torch.tensor([2, 2, 2, 1])
    assert hysteresis_action(logits, prev, 0.0).tolist() == [1, 1, 0, 1], "τ = 0 等价 argmax"
    assert hysteresis_action(logits, prev, 0.6).tolist() == [2, 2, 0, 1]
    assert hysteresis_action(logits, prev, 5.0).tolist() == [2, 2, 2, 1]


def test_eval_intent_is_pinned_and_does_not_mutate_the_training_cfg():
    """训练意图换成混合档时，评测仍走 eval.intent 那一档——尺子不跟着实验变。"""
    from stgtrain.evaluate import eval_cfg
    cfg = {"intent": {"name": "mixed_v1", "mix": {"follow": 1.0}}, "eval": {"intent": "lower_half_uniform_v1"}}
    out = eval_cfg(cfg)
    assert out["intent"]["name"] == "lower_half_uniform_v1"
    assert cfg["intent"]["name"] == "mixed_v1", "不得就地改调用方的配置"
    same = {"intent": {"name": "lower_half_uniform_v1"}, "eval": {"intent": ""}}
    assert eval_cfg(same) is same, "空串 = 跟训练一致，直接返回原配置"
