import pytest
import torch

from conftest import raw_obs, small_cfg
from stgtrain.perf import PhaseTimer
from stgtrain.registry import FEATURIZERS, load_builtins

load_builtins()


@pytest.mark.parametrize("name", [f"danger_topk_v{i}" for i in range(1, 6)])
def test_timed_featurizer_preserves_outputs_and_reports_subphases(name):
    cfg = small_cfg(featurize={"name": name})
    f = FEATURIZERS.get(name)(cfg)
    obs = raw_obs(n=2,
                  bullets=[[(10.0, 300.0, 0.0, 1.0, 2.0)]],
                  enemies=[[(0.0, 200.0, 10.0, 0.0, 1.0, 0.0)]])
    plain = f(obs)

    timer = PhaseTimer(sync_every=1, device=torch.device("cpu"))
    timer.start_iteration(1)
    timed = f(obs, timer=timer)
    phases = timer.pop_iteration()

    assert plain.keys() == timed.keys()
    assert all(torch.equal(plain[key], timed[key]) for key in plain)
    assert {"feat_bullets_s", "feat_enemies_static_s", "feat_density_s"} <= phases.keys()
    if name in ("danger_topk_v3", "danger_topk_v4", "danger_topk_v5"):
        assert "feat_enemies_motion_s" in phases
