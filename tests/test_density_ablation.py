from scripts.diag.density_ablation import pair_summary
from test_evaluate import rec


def test_specialist_summary_does_not_label_lasers_as_ordinary():
    first = dict(rec(2), pool="specialist", card="laser_sp_bars_04", rank=2, eval_seed=12345)
    second = dict(first, done=1)
    result = pair_summary([first], [second])
    assert set(result) == {"overall", "by_card_rank"}
    assert result["overall"]["delta_survival_pp"] == -100
    assert result["overall"]["cnn_survived_none_failed"] == 1
