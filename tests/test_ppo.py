import pytest
import stg_rl
import torch

from conftest import FIXTURES, small_cfg
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import EnvWrapper
from stgtrain.episodes import EpisodeTracker
from stgtrain.ppo import PPO, gae
from tensordict import TensorDict
from stgtrain.perf import PhaseTimer
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins
from stgtrain.reward import RewardFn

load_builtins()
CPU = torch.device("cpu")


def gae_oracle(r, v, d, nv, gamma, lam):
    """逐 env 标量写法，作为 gae 的对照实现。"""
    T, N = r.shape
    adv = torch.zeros(T, N)
    for i in range(N):
        last = 0.0
        for t in reversed(range(T)):
            code = int(d[t, i])
            v_next = float(nv[i]) if t == T - 1 else float(v[t + 1, i])
            if code == 0:
                delta = r[t, i] + gamma * v_next - v[t, i]
                last = delta + gamma * lam * last
            elif code == 3:
                last = r[t, i] + gamma * v[t, i] - v[t, i]
            else:
                last = r[t, i] - v[t, i]
            adv[t, i] = last
    return adv


def test_gae_done_codes():
    r = torch.tensor([[1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]])
    v = torch.tensor([[0.5, 0.5, 0.5, 0.5], [0.4, 0.4, 0.4, 0.4], [0.3, 0.3, 0.3, 0.3]])
    d = torch.tensor([[0, 0, 0, 0], [0, 1, 3, 0], [0, 0, 0, 2]])
    nv = torch.full((4,), 2.0)
    adv, ret = gae(r, v, d, nv, 0.9, 0.8)
    assert torch.allclose(adv, gae_oracle(r, v, d, nv, 0.9, 0.8), atol=1e-6)
    assert adv[1, 1] == pytest.approx(1.0 - 0.4), "done=1：不自举"
    assert adv[1, 2] == pytest.approx(1.0 + 0.9 * 0.4 - 0.4), "done=3：用 V(obs_t) 自举"
    assert adv[2, 3] == pytest.approx(1.0 - 0.3), "done=2：不自举，也不用 next_value"
    assert torch.allclose(ret, adv + v)


def setup(num_steps=16, ppo=None, **sections):
    cfg = small_cfg(ppo={"num_steps": num_steps, **(ppo or {})}, **sections)
    images = compile_cards(discover(FIXTURES / "cards"))
    envw = EnvWrapper(cfg, images, [stg_rl.Start("example_ring", 0, 2)], CPU, seed=4)
    feat = FEATURIZERS.get("danger_topk_v1")(cfg)
    factory = lambda: MODELS.get("set_attn_v1")(cfg, feat.spec())
    ppo = PPO(cfg, factory, CPU)
    rf = RewardFn(cfg)
    tr = EpisodeTracker(envw.n, CPU, list(rf.terms), 24.0, 16.0, 1, 300)
    return cfg, envw, feat, ppo, rf, tr


def test_rollout_and_train_step_on_cpu():
    torch.manual_seed(0)
    cfg, envw, feat, ppo, rf, tr = setup()
    assert not ppo.compile and not ppo.cudagraphs
    obs = envw.reset()
    before = [p.detach().clone() for p in ppo.agent.parameters()]
    obs, container, next_value = ppo.rollout(envw, feat, rf, tr, None, obs)
    assert container.batch_size == torch.Size([16, 8])
    assert container["feats", "bullets"].shape == (16, 8, 16, 7)
    assert next_value.shape == (8,)
    stats = ppo.train_step(container, next_value, iteration=1, num_iterations=10)
    for k in ("approx_kl", "v_loss", "pg_loss", "entropy_loss", "clipfrac", "gn", "explained_variance", "lr", "done3_frac"):
        assert k in stats
    assert all(v == v for k, v in stats.items() if k != "explained_variance"), "非 NaN"
    assert any(not torch.equal(a, b) for a, b in zip(before, ppo.agent.parameters())), "参数应被更新"
    # agent_inference 与 agent 共享数据
    for a, b in zip(ppo.agent.parameters(), ppo.agent_inference.parameters()):
        assert torch.equal(a.data, b.data)


def test_rollout_reports_reward_and_episode_stat_costs_separately():
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=2)
    timer = PhaseTimer(sync_every=1, device=CPU)
    timer.start_iteration(1)
    ppo.rollout(envw, feat, rf, tr, timer, envw.reset())
    phases = timer.pop_iteration()
    assert {"reward_s", "reward_terms_s", "episode_tracker_s", "feat_density_s"} <= phases.keys()


def test_act_greedy_and_lr_anneal():
    cfg, envw, feat, ppo, rf, tr = setup()
    f = feat(envw.reset())
    a = ppo.act(f, greedy=True)
    assert a.shape == (8,) and a.dtype == torch.int64 and ((0 <= a) & (a < 18)).all()
    assert torch.equal(a, ppo.act(f, greedy=True))
    obs, c, nv = ppo.rollout(envw, feat, rf, tr, None, envw.reset())
    stats = ppo.train_step(c, nv, iteration=6, num_iterations=10)
    assert stats["lr"] == pytest.approx(cfg["ppo"]["learning_rate"] * 0.5)


def test_rollout_graphs_only_on_cuda():
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=2)
    assert cfg["ppo"]["rollout_cudagraphs"] is True, "默认开"
    assert ppo.rollout_graphs is False, "CPU 上不录图"


def _rollout_twice(graphs: bool, timer=None):
    torch.manual_seed(0)
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=12, env={"max_frames": 10})
    ppo.rollout_graphs = graphs      # CPU 上强开：CudaGraphModule 在 CPU 上直接执行，验的是张量打包与状态传递
    obs = envw.reset()
    outs = []
    for _ in range(2):
        obs, container, next_value = ppo.rollout(envw, feat, rf, tr, timer, obs)
        outs.append((container, next_value, tr.pop_finished()))
    return outs


def test_graphed_rollout_matches_eager_path():
    eager, graphed = _rollout_twice(False), _rollout_twice(True)
    for (c0, v0, r0), (c1, v1, r1) in zip(eager, graphed):
        assert (c0 == c1).all(), "特征 / 奖励 / 动作逐位相同"
        assert torch.equal(v0, v1)
        assert r0 == r1, "逐局统计相同（跨 rollout 的 tracker 状态也接得上）"
    assert sum(len(r) for _, _, r in eager) > 0, "夹具里要有结束的局，否则统计对拍是空的"


def test_graphed_rollout_still_reports_parent_phases():
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=2)
    ppo.rollout_graphs = True
    timer = PhaseTimer(sync_every=1, device=CPU)
    timer.start_iteration(1)
    ppo.rollout(envw, feat, rf, tr, timer, envw.reset())
    phases = timer.pop_iteration()
    assert {"featurize_s", "reward_s"} <= phases.keys()


def test_gpucheck_rollout_graph_check_runs_on_cpu():
    """GPU 上才真正录图；这里只保证检查本身能跑、eager 对 eager 全部通过。"""
    from stgtrain.gpucheck import check_rollout_graphs

    cfg, envw, feat, ppo, rf, tr = setup(num_steps=2)
    images = compile_cards(discover(FIXTURES / "cards"))
    checks = check_rollout_graphs(cfg, images, [stg_rl.Start("example_ring", 0, 2)], feat, ppo, CPU)
    assert [k for k, *_ in checks] == ["rollout_feats", "rollout_reward", "rollout_tracker"]
    assert all(good for *_, good in checks)


def test_rollout_graphs_use_only_tensordict_062_api(monkeypatch):
    """Magnus 镜像装的是 tensordict 0.6.2，它的 CudaGraphModule 只收 (module, warmup, in_keys, out_keys)，
    没有 0.14 的 device 参数（Job 356819cb7a21700f 就栽在这）。用只认旧签名的替身锁住。"""
    import stgtrain.rollout_graph as rg

    class OldCudaGraphModule:
        def __init__(self, module, warmup=2, in_keys=None, out_keys=None):
            self.module = module

        def __call__(self, *args, **kwargs):
            return self.module(*args, **kwargs)

    monkeypatch.setattr(rg, "CudaGraphModule", OldCudaGraphModule)
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=2)
    ppo.rollout_graphs = True
    ppo.rollout(envw, feat, rf, tr, None, envw.reset())


def _reference_train_step(ppo, container, next_value, iteration, num_iterations):
    """改动前的 train_step（每个 minibatch 各按随机下标 gather 一次）——等价性对照。"""
    p = ppo.p
    if p["anneal_lr"]:
        frac = 1.0 - (iteration - 1.0) / num_iterations
        ppo.optimizer.param_groups[0]["lr"].copy_(frac * float(p["learning_rate"]))
    adv, ret = gae(container["rewards"], container["vals"], container["dones"], next_value,
                   float(p["gamma"]), float(p["gae_lambda"]))
    container["advantages"] = adv
    container["returns"] = ret
    flat = container.view(-1)
    mb = flat.shape[0] // int(p["num_minibatches"])
    outs = []
    for _ in range(int(p["update_epochs"])):
        for b in torch.randperm(flat.shape[0], device=ppo.device).split(mb):
            outs.append(ppo.update(flat[b], tensordict_out=TensorDict()))
    stats = {k: torch.stack([o[k] for o in outs]).float().mean().item() for k in outs[0].keys()}
    var_y = ret.var()
    stats["explained_variance"] = (
        (1.0 - (ret - container["vals"]).var() / var_y).item() if var_y.item() > 0 else float("nan")
    )
    stats["lr"] = float(ppo.optimizer.param_groups[0]["lr"])
    stats["done3_frac"] = (container["dones"] == 3).float().mean().item()
    return stats


def test_train_step_matches_per_minibatch_gather_reference():
    """每个 epoch 整表打乱一次、minibatch 取连续切片：与逐 minibatch 按随机下标 gather 逐位相同（同一个 randperm）。"""
    from tensordict import TensorDict  # noqa: F401  (reference 用)

    torch.manual_seed(0)
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=8, ppo={"update_epochs": 2, "num_minibatches": 4})
    _, container, nv = ppo.rollout(envw, feat, rf, tr, None, envw.reset())
    torch.manual_seed(0)
    cfg2, envw2, feat2, ref, rf2, tr2 = setup(num_steps=8, ppo={"update_epochs": 2, "num_minibatches": 4})
    ref.agent.load_state_dict(ppo.agent.state_dict())

    torch.manual_seed(7)
    got = ppo.train_step(container.clone(), nv.clone(), 1, 10)
    torch.manual_seed(7)
    want = _reference_train_step(ref, container.clone(), nv.clone(), 1, 10)
    assert got.keys() == want.keys()
    for k in want:
        assert got[k] == want[k] or (want[k] != want[k] and got[k] != got[k]), k
    for a, b in zip(ppo.agent.parameters(), ref.agent.parameters()):
        assert torch.equal(a, b)


def test_train_step_reports_update_subphases():
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=4)
    _, container, nv = ppo.rollout(envw, feat, rf, tr, None, envw.reset())
    timer = PhaseTimer(sync_every=1, device=CPU)
    timer.start_iteration(1)
    ppo.train_step(container, nv, 1, 10, timer=timer)
    row = timer.pop_iteration()
    assert {"update_gae_s", "update_shuffle_s", "update_minibatches_s", "update_stats_s"} <= row.keys()


def test_explained_variance_nan_when_returns_constant():
    cfg, envw, feat, ppo, rf, tr = setup(num_steps=4)
    _, container, nv = ppo.rollout(envw, feat, rf, tr, None, envw.reset())
    container["rewards"].zero_()
    container["vals"].zero_()
    container["dones"].zero_()
    stats = ppo.train_step(container, torch.zeros_like(nv), 1, 10)
    assert stats["explained_variance"] != stats["explained_variance"], "回报恒定时为 NaN"


def test_gpucheck_gae_graph_check_runs_on_cpu():
    from stgtrain.gpucheck import check_gae_graph

    cfg, envw, feat, ppo, rf, tr = setup(num_steps=4)
    _, container, nv = ppo.rollout(envw, feat, rf, tr, None, envw.reset())
    name, *_, good = check_gae_graph(ppo, container, nv)
    assert name == "gae_graph" and good
