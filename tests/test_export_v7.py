"""v7（激光）导出：图版本 5、部署包装 ≡ 训练路径、ONNX ≡ torch、行序无关。"""
from __future__ import annotations

import json

import pytest
import torch
from conftest import small_cfg
from test_export_onnx import ROWS_B, ROWS_E, _obs_held, _reference
from test_featurize_v7 import laser, random_lasers, with_lasers

from stgtrain.envwrap import LASER_COLS
from stgtrain.export_onnx import (
    INPUT_NAMES,
    DeployWrapper,
    _example_inputs,
    build_deploy,
    deploy_inputs,
    export_featurizer,
    export_graph,
    graph_version,
    input_names,
    uses_held,
    uses_lasers,
    write_manifest,
)
from stgtrain.registry import FEATURIZERS, load_builtins

ROWS_L = 32


def _cfg(sa_layers=1, action_query=False, laser_local=False, laser_sa_layers=0):
    return small_cfg(featurize={"name": "danger_topk_v7", "k_bullets": 8, "k_enemies": 4, "k_lasers": 6,
                                "frame": "static", "dt": False, "laser_local": laser_local},
                     model={"name": "set_attn_v2", "sa_layers": sa_layers, "action_query": action_query,
                            "laser_sa_layers": laser_sa_layers})


def _obs(n=2):
    o = random_lasers(_obs_held(n), seed=11, per_env=20)
    # 一条压在自机身上的生效激光、一条收缩态、一条预警：三种都得在图里走一遍
    for i in range(n):
        px, py = o.player_xy[i].tolist()
        o.lasers[i, 20] = torch.tensor(laser(x=px + 3.0, y=py - 200.0, deg=90.0))
        o.lasers[i, 21] = torch.tensor(laser(x=px - 5.0, y=py - 100.0, deg=80.0, state=2.0))
        o.lasers[i, 22] = torch.tensor(laser(x=px, y=py - 50.0, deg=100.0, state=0.0, t_active=12.0))
        o.lasers_mask[i, 20:23] = True
    return o


def _args(obs, i, rows_l=ROWS_L):
    return deploy_inputs(obs, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2, with_lasers=True,
                         lasers_rows=rows_l)


def _wrap(cfg, model):
    return DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()


def test_graph_version_and_input_names():
    cfg = _cfg()
    assert uses_held(cfg) == 2 and uses_lasers(cfg)
    assert graph_version(2, True) == 5
    assert input_names(cfg) == INPUT_NAMES + ("dir_held", "slow_held", "lasers", "lasers_mask")
    load_builtins()
    assert export_featurizer(cfg).spec() == FEATURIZERS.get("danger_topk_v7")(cfg).spec()


@pytest.mark.parametrize("model", [dict(), dict(action_query=True), dict(laser_local=True, laser_sa_layers=1)])
def test_deploy_wrapper_matches_training_path(model):
    cfg, obs = _cfg(**model), _obs()
    net, ref = _reference(cfg, obs)
    wrap = _wrap(cfg, net)
    with torch.no_grad():
        got = torch.stack([wrap(*_args(obs, i)) for i in range(2)])
    assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()


def test_row_order_does_not_matter_for_deploy():
    """DLL 按什么顺序填激光表都一样：图里按几何重选。"""
    cfg, obs = _cfg(), _obs()
    net, _ = _reference(cfg, obs)
    wrap = _wrap(cfg, net)
    args = list(_args(obs, 0))
    perm = torch.randperm(ROWS_L, generator=torch.Generator().manual_seed(4))
    shuffled = args[:-2] + [args[-2][perm], args[-1][perm]]
    with torch.no_grad():
        assert torch.allclose(wrap(*args), wrap(*shuffled), atol=1e-5)


def test_lasers_change_deploy_logits():
    cfg, obs = _cfg(), _obs(n=1)
    net, _ = _reference(cfg, obs)
    wrap = _wrap(cfg, net)
    args = list(_args(obs, 0))
    empty = args[:-1] + [torch.zeros_like(args[-1])]
    with torch.no_grad():
        assert not torch.allclose(wrap(*args), wrap(*empty))


def test_onnx_matches_torch(tmp_path):
    ort = pytest.importorskip("onnxruntime")
    cfg, obs = _cfg(action_query=True, laser_sa_layers=1), _obs()
    net, _ = _reference(cfg, obs)
    wrap = _wrap(cfg, net)
    path = tmp_path / "v7.onnx"
    export_graph(wrap, _args(obs, 0), path)
    names = list(input_names(cfg))
    sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    assert [i.name for i in sess.get_inputs()] == names
    shapes = {i.name: tuple(i.shape) for i in sess.get_inputs()}
    assert shapes["lasers"] == (ROWS_L, len(LASER_COLS)) and shapes["lasers_mask"] == (ROWS_L,)
    for i in range(2):
        args = _args(obs, i)
        got = torch.from_numpy(sess.run(["logits"], {n: a.numpy() for n, a in zip(names, args)})[0])
        with torch.no_grad():
            ref = wrap(*args)
        assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()
        assert got.argmax().item() == ref.argmax().item()


def test_example_inputs_cover_lasers():
    ex = _example_inputs(ROWS_B, ROWS_E, with_held=2, with_lasers=True, lasers_rows=ROWS_L)
    assert len(ex) == len(INPUT_NAMES) + 4
    assert ex[-2].shape == (ROWS_L, len(LASER_COLS)) and ex[-1].sum() == 1


def test_build_deploy_and_manifest(tmp_path):
    cfg, obs = _cfg(), _obs(n=1)
    net, _ = _reference(cfg, obs)
    ck = {
        "format": 1, "action_table_version": 1, "update": 7, "env_steps": 123, "cfg": cfg,
        "model_name": "set_attn_v2", "featurizer_name": "danger_topk_v7",
        "state": {"agent": {f"model.{k}": v for k, v in net.state_dict().items()}},
        "torch_rng": torch.get_rng_state(), "cuda_rng": None, "extra": {},
    }
    p = tmp_path / "best.pt"
    torch.save(ck, p)
    wrap, meta = build_deploy(p, bullets_rows=ROWS_B, enemies_rows=ROWS_E)
    assert meta["with_held"] == 2 and meta["with_lasers"] is True
    with torch.no_grad():
        assert torch.allclose(wrap(*_args(obs, 0)), _wrap(cfg, net)(*_args(obs, 0)), atol=1e-6)
    onnx_path = tmp_path / "t.onnx"
    onnx_path.write_bytes(b"x")
    man = write_manifest(tmp_path / "m.json", checkpoint=p, onnx=onnx_path, meta=meta,
                         bullets_rows=640, enemies_rows=256, lasers_rows=64)
    d = json.loads(man.read_text())
    assert d["graph_version"] == 5
    assert [i["name"] for i in d["inputs"]][-4:] == ["dir_held", "slow_held", "lasers", "lasers_mask"]
    assert d["inputs"][-2] == {"name": "lasers", "dtype": "float32", "shape": [64, len(LASER_COLS)]}


def test_no_lasers_on_card_is_fine():
    cfg = _cfg()
    obs = with_lasers(_obs_held(2), [[], []])
    net, ref = _reference(cfg, obs)
    with torch.no_grad():
        got = torch.stack([_wrap(cfg, net)(*_args(obs, i)) for i in range(2)])
    assert torch.isfinite(got).all() and torch.allclose(got, ref, atol=1e-5)
