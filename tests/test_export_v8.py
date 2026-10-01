"""图版本6：新输入对齐，真实训练前向/包装/ORT一致。"""
import json

import pytest
import torch

from conftest import small_cfg
from stgtrain.export_onnx import (DeployWrapper, _example_inputs, build_deploy, deploy_inputs,
                                  export_graph, graph_version, input_names, write_manifest)
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins
from test_export_v7 import ROWS_B, ROWS_E, ROWS_L, _obs


def inputs(o, i):
    return deploy_inputs(o, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=2,
                         with_lasers=True, lasers_rows=ROWS_L, with_start_len=True)


def build():
    load_builtins()
    cfg = small_cfg(featurize={"name": "danger_topk_v8", "k_bullets": 8, "k_enemies": 4,
                                "k_lasers": 6, "frame": "static", "dt": False},
                    model={"name": "set_attn_v3", "joint_sa_layers": 1})
    o = _obs()
    o.laser_start_len = torch.arange(o.lasers.shape[1], dtype=torch.float32)[None].expand(2, -1)*7 + 160
    feat = FEATURIZERS.get("danger_topk_v8")(cfg)
    torch.manual_seed(8)
    net = MODELS.get("set_attn_v3")(cfg, feat.spec()).eval()
    return cfg, o, feat, net


def test_training_wrapper_and_onnx_match_with_aligned_start_len(tmp_path):
    ort = pytest.importorskip("onnxruntime")
    cfg, o, feat, net = build()
    wrap = DeployWrapper(cfg, net, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    ref = net(feat(o))[0]
    path = export_graph(wrap, inputs(o, 0), tmp_path/"v8.onnx")
    sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    names = input_names(cfg)
    assert [x.name for x in sess.get_inputs()] == list(names)
    assert sess.get_inputs()[-1].shape == [ROWS_L]
    for i in range(2):
        args = inputs(o, i)
        torch.testing.assert_close(wrap(*args), ref[i], atol=1e-5, rtol=1e-5)
        got = torch.from_numpy(sess.run(["logits"], {n: a.numpy() for n, a in zip(names, args)})[0])
        torch.testing.assert_close(got, ref[i], atol=1e-5, rtol=1e-5)
        assert got.argmax() == ref[i].argmax()
    # 行置换时，长度输入必须和原表一起移动。
    args = list(inputs(o, 0))
    perm = torch.arange(ROWS_L-1, -1, -1)
    args[-3:] = [a[perm] for a in args[-3:]]
    torch.testing.assert_close(wrap(*args), ref[0], atol=1e-5, rtol=1e-5)


def test_checkpoint_manifest_and_example_inputs(tmp_path):
    cfg, o, _, net = build()
    ck = {"format": 1, "action_table_version": 1, "update": 7, "env_steps": 123,
          "cfg": cfg, "model_name": "set_attn_v3", "featurizer_name": "danger_topk_v8",
          "state": {"agent": {f"model.{k}": v for k, v in net.state_dict().items()}},
          "torch_rng": torch.get_rng_state(), "cuda_rng": None, "extra": {}}
    cp = tmp_path/"best.pt"
    torch.save(ck, cp)
    wrap, meta = build_deploy(cp, bullets_rows=ROWS_B, enemies_rows=ROWS_E)
    assert meta["with_start_len"] and graph_version(2, True, True) == 6
    examples = _example_inputs(ROWS_B, ROWS_E, 2, True, ROWS_L, True)
    assert examples[-1][0] == 400 and torch.isfinite(wrap(*examples)).all()
    onnx = tmp_path/"stub.onnx"
    onnx.write_bytes(b"manifest-only")
    manifest = write_manifest(tmp_path/"m.json", checkpoint=cp, onnx=onnx, meta=meta,
                              bullets_rows=ROWS_B, enemies_rows=ROWS_E, lasers_rows=ROWS_L)
    data = json.loads(manifest.read_text())
    assert data["graph_version"] == 6
    assert data["inputs"][-1] == {"name": "laser_start_len", "dtype": "float32", "shape": [ROWS_L]}
    o.laser_start_len = None
    with pytest.raises(ValueError, match="laser_start_len"):
        inputs(o, 0)
