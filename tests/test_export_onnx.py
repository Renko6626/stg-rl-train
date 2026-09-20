"""导出器（部署设计 §4）：DeployWrapper 与训练时的 featurizer + model 等价，ONNX 与 torch 等价。

判别力说明：等价测试用的 obs 必须让两条路都真的走满 —— 有入选弹、有被 d_max 滤掉的远弹、
有 mask 关掉的脏行、focus 开、prev_action 非零、锚点离自机有距离。少任何一条，
「wrapper 把某一路特征算错/丢掉」都可能照样绿。
"""
from __future__ import annotations

import json

import pytest
import torch
from conftest import raw_obs, small_cfg

from stgtrain.export_onnx import (
    BULLET_COLS,
    ENEMY_COLS,
    GRAPH_VERSION,
    INPUT_NAMES,
    OPSET,
    DeployWrapper,
    build_deploy,
    deploy_inputs,
    export_graph,
    uses_held,
    write_manifest,
)
from stgtrain.registry import FEATURIZERS, MODELS, load_builtins

ROWS_B, ROWS_E = 16, 8


def _cfg(name="danger_topk_v3"):
    return small_cfg(featurize={"name": name, "k_bullets": 8, "k_enemies": 4})


_PLAYER = [(0.0, 384.0), (-60.0, 300.0)]
_TARGET = [(48.0, 300.0), (0.0, 420.0)]
_PREV = [5, 12]
# 近弹（会入选）、斜向迎面弹、远弹（> d_max，入选但 sel 假）、压在自机身上的静止弹
_BULLETS = [
    [(10.0, 340.0, 0.0, 2.5, 4.0), (-30.0, 300.0, 1.5, 1.5, 3.0), (170.0, 20.0, -2.0, 0.0, 8.0),
     (0.0, 383.0, 0.0, 0.0, 2.0)],
    [(-60.0, 260.0, 0.0, 3.0, 5.0), (-100.0, 340.0, 2.0, -1.0, 2.5), (150.0, 440.0, 0.0, -1.0, 6.0)],
]
# 敌行带速度（v3 的全部新意）：一只横移的 boss、一只朝自机俯冲的小怪
_ENEMIES = [
    [(20.0, 80.0, 16.0, 1.0, 2.5, 0.0), (-120.0, 40.0, 12.0, 0.0, 1.5, 3.0)],
    [(-40.0, 120.0, 24.0, 1.0, -1.0, 2.0)],
]


def _obs_held(n=2):
    o = _obs(n)
    o.dir_held = torch.tensor(_HELD[:n], dtype=torch.int64)
    return o


def _obs(n=2):
    """`n` 个 env，几何各不相同；每一路特征都有非零值，且都含被 d_max 滤掉的远弹与关掉的脏行。"""
    return raw_obs(
        n=n, cap=ROWS_B, e=ROWS_E,
        player=_PLAYER[:n], target=_TARGET[:n], prev_action=_PREV[:n],
        speed=4.5, hit_r=2.5, focus=True,
        bullets=_BULLETS[:n], enemies=_ENEMIES[:n],
    )


_HELD = [3, 1 << 20]      # 一个刚换完方向不久、一个「新局 = 很大」（图里要封顶）


def _reference(cfg, obs):
    """训练时那条路：featurizer(obs) → model → logits。"""
    load_builtins()
    feat = FEATURIZERS.get(cfg["featurize"]["name"])(cfg)
    model = MODELS.get(cfg["model"]["name"])(cfg, feat.spec())
    model.eval()
    with torch.no_grad():
        logits, _ = model(feat(obs))
    return model, logits


def _wrapper_logits(cfg, model, obs, n):
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    out = []
    with torch.no_grad():
        for i in range(n):
            out.append(wrap(*deploy_inputs(obs, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=uses_held(cfg))))
    return torch.stack(out)


FEATS = ["danger_topk_v2", "danger_topk_v3", "danger_topk_v4"]


@pytest.mark.parametrize("name", FEATS)
def test_export_featurizer_spec_matches_training_one(name):
    """导出用的特征化器只改 _topk 的哨兵写法，spec 必须逐项相同 —— 否则模型形状都对不上。"""
    cfg = _cfg(name)
    load_builtins()
    train_spec = FEATURIZERS.get(name)(cfg).spec()
    from stgtrain.export_onnx import export_featurizer

    assert export_featurizer(cfg).spec() == train_spec


def test_unknown_featurizer_is_refused():
    from stgtrain.export_onnx import export_featurizer

    with pytest.raises(ValueError, match="只支持"):
        export_featurizer(_cfg("danger_topk_v1"))


@pytest.mark.parametrize("name", FEATS)
def test_deploy_wrapper_matches_training_path(name):
    cfg, obs = _cfg(name), _obs_held()
    model, ref = _reference(cfg, obs)
    got = _wrapper_logits(cfg, model, obs, n=2)
    assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()


def test_prev_action_changes_logits():
    """变异守卫：上一步动作是 v2 的全部新意；wrapper 丢掉它时本测试必须红。"""
    cfg = _cfg()
    obs = _obs(n=1)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    args = list(deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E))
    with torch.no_grad():
        a = wrap(*args)
        args[INPUT_NAMES.index("prev_action")] = torch.tensor([7], dtype=torch.int64)
        b = wrap(*args)
    assert not torch.allclose(a, b, atol=1e-6), "换了上一步动作 logits 却没变 —— one-hot 那一路没接上"


def _logits_with_enemy_velocity_zeroed(name):
    cfg = _cfg(name)
    obs = _obs(n=1)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    args = list(deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E))
    with torch.no_grad():
        a = wrap(*args)
        e = args[INPUT_NAMES.index("enemies")].clone()
        e[:, 4:6] = 0.0
        args[INPUT_NAMES.index("enemies")] = e
        b = wrap(*args)
    return a, b


def test_enemy_velocity_changes_logits_v3():
    """变异守卫：敌人速度是 v3 的全部新意；`deploy_inputs` 或 wrapper 把那两列丢了，本测试必须红。"""
    a, b = _logits_with_enemy_velocity_zeroed("danger_topk_v3")
    assert not torch.allclose(a, b, atol=1e-6), "敌人速度清零 logits 却没变 —— vx/vy 那两列没接上"


def test_enemy_velocity_is_ignored_by_v2():
    """v2 的图也按六列签名导出（同一个 DLL 换着装），但那两列进了图不能有人读。"""
    a, b = _logits_with_enemy_velocity_zeroed("danger_topk_v2")
    assert torch.equal(a, b)


def test_dir_held_changes_logits_v4_and_is_capped():
    """变异守卫：dir_held 是 v4 的全部新意；wrapper 丢了它本测试必须红。封顶 16 ⇒ 16 与「很大」等价。"""
    cfg = _cfg("danger_topk_v4")
    obs = _obs_held(n=1)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    args = list(deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=True))
    assert len(args) == len(INPUT_NAMES) + 1
    with torch.no_grad():
        a = wrap(*args)
        args[-1] = torch.tensor([9], dtype=torch.int64)
        b = wrap(*args)
        args[-1] = torch.tensor([16], dtype=torch.int64)
        c = wrap(*args)
        args[-1] = torch.tensor([1 << 20], dtype=torch.int64)
        d = wrap(*args)
    assert not torch.allclose(a, b, atol=1e-6), "换了 dir_held logits 却没变 —— 那一维没接上"
    assert torch.equal(c, d), "封顶 16：再大也一样"


def test_masked_rows_cannot_influence_logits():
    """mask 关掉的行填垃圾也不能改结果 —— 押运哨兵（1e30）与 sel 两处。"""
    cfg = _cfg()
    obs = _obs(n=1)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    args = list(deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E))
    with torch.no_grad():
        clean = wrap(*args)
    b, bm = args[0].clone(), args[1]
    e, em = args[2].clone(), args[3]
    b[~bm] = 999.0
    e[~em] = -777.0
    args[0], args[2] = b, e
    with torch.no_grad():
        dirty = wrap(*args)
    assert torch.allclose(clean, dirty, atol=1e-6), "无效行影响了 logits"


@pytest.mark.parametrize("name", ["danger_topk_v3", "danger_topk_v4"])
def test_onnx_matches_torch(tmp_path, name):
    """v3 = 七输入（图版本 2）；v4 多一个 dir_held（图版本 3）—— 输入没被导出器剪掉是这里押的。"""
    ort = pytest.importorskip("onnxruntime")
    cfg = _cfg(name)
    held = uses_held(cfg)
    obs = _obs_held(n=2)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    path = tmp_path / "m.onnx"
    example = deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=held)
    export_graph(wrap, example, path)

    names = list(INPUT_NAMES) + (["dir_held"] if held else [])
    sess = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    assert [i.name for i in sess.get_inputs()] == names
    assert [tuple(i.shape) for i in sess.get_inputs()] == [
        (ROWS_B, BULLET_COLS), (ROWS_B,), (ROWS_E, ENEMY_COLS), (ROWS_E,), (5,), (2,), (1,)
    ] + ([(1,)] if held else [])
    for i in range(2):
        args = deploy_inputs(obs, i, bullets_rows=ROWS_B, enemies_rows=ROWS_E, with_held=held)
        feed = {n: a.numpy() for n, a in zip(names, args)}
        got = torch.from_numpy(sess.run(["logits"], feed)[0])
        with torch.no_grad():
            ref = wrap(*args)
        assert torch.allclose(got, ref, atol=1e-5), (got - ref).abs().max()
        assert got.argmax().item() == ref.argmax().item()


def test_onnx_is_single_self_contained_file(tmp_path):
    """部署侧只拖一个图文件：dynamo 导出器默认把权重甩进旁挂 .data，必须被收回图里。

    判别力：去掉 export_graph 里的 _inline_external_data，本测试立刻红（会多出 m.onnx.data）。
    """
    onnx = pytest.importorskip("onnx")
    cfg, obs = _cfg(), _obs(n=1)
    model, _ = _reference(cfg, obs)
    wrap = DeployWrapper(cfg, model, bullets_rows=ROWS_B, enemies_rows=ROWS_E).eval()
    path = tmp_path / "m.onnx"
    export_graph(wrap, deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E), path)

    assert sorted(p.name for p in tmp_path.iterdir()) == ["m.onnx"], "导出目录里除了图不该有别的文件"
    m = onnx.load(str(path), load_external_data=False)
    assert not [t.name for t in m.graph.initializer if t.data_location == onnx.TensorProto.EXTERNAL]
    assert [o.version for o in m.opset_import if not o.domain] == [OPSET]


def test_build_deploy_loads_checkpoint_weights(tmp_path):
    """从 checkpoint 造出来的 wrapper 必须真的带着那份权重（不是新初始化的）。"""
    cfg, obs = _cfg(), _obs(n=1)
    model, _ = _reference(cfg, obs)
    ck = {
        "format": 1, "action_table_version": 1, "update": 7, "env_steps": 123, "cfg": cfg,
        "model_name": cfg["model"]["name"], "featurizer_name": cfg["featurize"]["name"],
        "state": {"agent": {f"model.{k}": v for k, v in model.state_dict().items()}},
        "torch_rng": torch.get_rng_state(), "cuda_rng": None, "extra": {},
    }
    p = tmp_path / "best.pt"
    torch.save(ck, p)
    wrap, meta = build_deploy(p, bullets_rows=ROWS_B, enemies_rows=ROWS_E)
    args = deploy_inputs(obs, 0, bullets_rows=ROWS_B, enemies_rows=ROWS_E)
    with torch.no_grad():
        assert torch.allclose(wrap(*args), DeployWrapper(cfg, model, bullets_rows=ROWS_B,
                                                         enemies_rows=ROWS_E).eval()(*args), atol=1e-6)
    assert meta["update"] == 7 and meta["featurizer_name"] == "danger_topk_v3"


def test_manifest_records_provenance(tmp_path):
    onnx_path = tmp_path / "f-best.onnx"
    onnx_path.write_bytes(b"not-a-real-graph")
    ck_path = tmp_path / "best.pt"
    ck_path.write_bytes(b"ckpt")
    man = tmp_path / "manifest.json"
    write_manifest(man, checkpoint=ck_path, onnx=onnx_path,
                   meta={"update": 2000, "env_steps": 524288000, "featurizer_name": "danger_topk_v2",
                         "model_name": "set_attn_v1", "action_table_version": 1},
                   bullets_rows=640, enemies_rows=256)
    d = json.loads(man.read_text())
    assert d["graph_version"] == GRAPH_VERSION
    assert d["update"] == 2000 and d["action_table_version"] == 1
    assert d["inputs"][0] == {"name": "bullets", "dtype": "float32", "shape": [640, BULLET_COLS]}
    assert len(d["sha256"]["onnx"]) == 64 and len(d["sha256"]["checkpoint"]) == 64
    assert d["num_actions"] == 18
