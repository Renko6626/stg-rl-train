"""v6 特征化（Q1 / Q2 / R1a）与弹间自注意力的导出：部署包装 ≡ 训练路径，ONNX ≡ torch。"""
from __future__ import annotations

import pytest
import torch
from conftest import small_cfg
from test_export_onnx import ROWS_B, ROWS_E, _obs_held, _reference, _wrapper_logits

from stgtrain.export_onnx import (
    BULLET_COLS,
    ENEMY_COLS,
    GRAPH_VERSION,
    INPUT_NAMES,
    DeployWrapper,
    deploy_inputs,
    export_featurizer,
    export_graph,
    uses_held,
)
from stgtrain.registry import FEATURIZERS, load_builtins

VARIANTS = [("target", True), ("static", True), ("static", False)]


def _cfg(frame, dt, sa_layers=0, action_query=False):
    return small_cfg(featurize={"name": "danger_topk_v6", "k_bullets": 8, "k_enemies": 4, "frame": frame, "dt": dt},
                     model={"sa_layers": sa_layers, "action_query": action_query})


@pytest.mark.parametrize("frame,dt", VARIANTS)
def test_v6_export_spec_and_graph_version(frame, dt):
    cfg = _cfg(frame, dt)
    load_builtins()
    assert export_featurizer(cfg).spec() == FEATURIZERS.get("danger_topk_v6")(cfg).spec()
    assert GRAPH_VERSION + uses_held(cfg) == 4, "v6 与 v5 同签名（dir_held + slow_held），DLL 不用改"


@pytest.mark.parametrize("sa_layers", [0, 1])
@pytest.mark.parametrize("frame,dt", VARIANTS)
def test_v6_deploy_wrapper_matches_training_path(frame, dt, sa_layers):
    cfg, obs = _cfg(frame, dt, sa_layers), _obs_held()
    model, ref = _reference(cfg, obs)
    got = _wrapper_logits(cfg, model, obs, n=2)
    assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()


def test_v6_no_dt_masked_padding_cannot_be_selected():
    """无 d / t 时按距离选弹：掩码关掉的脏行离自机再近也不能入选（哨兵写法下同样成立）。"""
    cfg = _cfg("static", False, 1)
    obs = _obs_held()
    model, ref = _reference(cfg, obs)
    obs.bullets[:, -1] = torch.tensor([obs.player_xy[0, 0], obs.player_xy[0, 1], 0.0, 0.0, 9.0])
    obs.bullets_mask[:, -1] = False
    with torch.no_grad():
        ref2, _ = model(FEATURIZERS.get("danger_topk_v6")(cfg)(obs))
    got = _wrapper_logits(cfg, model, obs, n=2)
    assert torch.allclose(ref2, ref, atol=1e-5), "训练路径也不该被脏行影响"
    assert torch.allclose(got, ref, atol=1e-5)


@pytest.mark.parametrize("sa_layers", [0, 1])
@pytest.mark.parametrize("frame,dt", [("static", True), ("static", False)])
def test_v6_onnx_matches_torch(tmp_path, frame, dt, sa_layers):
    ort = pytest.importorskip("onnxruntime")
    cfg = _cfg(frame, dt, sa_layers)
    obs = _obs_held(n=2)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    path = tmp_path / "m.onnx"
    export_graph(wrap, deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2), path)
    names = list(INPUT_NAMES) + ["dir_held", "slow_held"]
    sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    assert [i.name for i in sess.get_inputs()] == names
    assert [tuple(i.shape) for i in sess.get_inputs()][:3] == [(ROWS_B, BULLET_COLS), (ROWS_B,), (ROWS_E, ENEMY_COLS)]
    for i in range(2):
        args = deploy_inputs(obs, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2)
        got = torch.from_numpy(sess.run(["logits"], {n: a.numpy() for n, a in zip(names, args)})[0])
        with torch.no_grad():
            ref = wrap(*args)
        assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()
        assert got.argmax().item() == ref.argmax().item()


def test_action_query_deploy_and_onnx_match(tmp_path):
    """R2：动作 query 策略头的常量表是 buffer，导出后与训练路径、ONNX 三者一致。"""
    ort = pytest.importorskip("onnxruntime")
    cfg, obs = _cfg("static", False, 1, True), _obs_held()
    model, ref = _reference(cfg, obs)
    got = _wrapper_logits(cfg, model, obs, n=2)
    assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    path = tmp_path / "aq.onnx"
    export_graph(wrap, deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2), path)
    names = list(INPUT_NAMES) + ["dir_held", "slow_held"]
    sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    for i in range(2):
        args = deploy_inputs(obs, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2)
        out = torch.from_numpy(sess.run(["logits"], {n: a.numpy() for n, a in zip(names, args)})[0])
        assert torch.allclose(out, ref[i], atol=1e-5), (out - ref[i]).abs().max()

