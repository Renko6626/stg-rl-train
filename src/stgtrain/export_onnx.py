"""导出 checkpoint 成一张 ONNX 图：**特征化 + 网络一起**，图的输入是原始表（部署设计 §4）。

为什么特征化也进图：部署侧（th06nc / TH18 DLL）因此不必用 C 复刻 topk / 密度图 / 归一化 —— 逐位一致
由「两边是同一张图」保证，C 侧只剩下填数组。设计与决策记录见 renkolab
`docs/superpowers/specs/2026-09-18-th06nc-onnx-policy-design.md`（D2）。

图签名（batch 不出现在接口上，内部 unsqueeze 成 1）：

    bullets      f32[B, 5]   x, y, vx, vy, radius
    bullets_mask bool[B]
    enemies      f32[E, 6]   x, y, hit_w, boss, vx, vy
    enemies_mask bool[E]
    player       f32[5]      x, y, hit_radius, speed, focus
    target       f32[2]      锚点
    prev_action  i64[1]      上一步动作 id，0–17
    → logits     f32[18]

**图版本 2（2026-09-20）**：`enemies` 从四列加到六列，多出来的 `vx, vy` 是 `danger_topk_v3` 要的敌人速度。
env 不导出这两个量，训练侧由 `envwrap.enemy_velocity` 按 id 差分上一帧得到；部署侧 C 端
（契约仓 `sa_model_fill` + `sa_model_track_t`）照同一口径差分后填进来 —— **差分不在图里**，图是无状态的。
v2 的 checkpoint 也按六列签名导出（那两列进了图没人读），所以同一个 DLL 能换着装 F 与 J 的图；
版本 1 的旧图（四列）新 DLL 会在建会话时拒掉。

**图版本 3（2026-09-20）**：`danger_topk_v4`（实验 N，手部运动层）多一个输入

    dir_held     i64[1]      当前方向已经**实际执行**了多少帧（新局 = 很大；图里封顶 16 再归一化）

**图版本 4（2026-09-21）**：`danger_topk_v5`（实验 N3 / M，低速键也过运动层）再多一个输入

    slow_held    i64[1]      当前低速位（按着 / 松着）已经**实际执行**了多少帧（口径同 dir_held）

只有 v4 / v5 的 checkpoint 才导出成八 / 九输入；v2 / v3 仍是七输入的版本 2（整个输入没人读的话导出器会把它剪掉，
所以没法像敌人速度那样「同一套签名、旧图不读」）。C 侧 `sa_onnx` 两种都收，并据此知道这张图是不是
在运动层下练出来的。`prev_action` 在 v4 下的含义是上一步**实际执行**的动作（运动层之后的），不是策略想按的。

用法：

    uv run --frozen python -m stgtrain.export_onnx runs/<run>/checkpoints/best.pt --out dist
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import torch
from torch import Tensor, nn

from .actions import ACTION_TABLE_VERSION, NUM_ACTIONS
from .checkpoint import load_checkpoint
from .config import from_dict
from .envwrap import RawObs
from .featurize.danger_topk_v1 import _gather, closest_approach
from .featurize.danger_topk_v2 import DangerTopKV2
from .featurize.danger_topk_v3 import DangerTopKV3
from .featurize.danger_topk_v4 import DangerTopKV4
from .featurize.danger_topk_v5 import DangerTopKV5
from .registry import FEATURIZERS, MODELS, load_builtins

GRAPH_VERSION = 2          # 七输入（v2 / v3）
GRAPH_VERSION_HELD = 3     # 八输入：多一个 dir_held（v4）。九输入（再加 slow_held，v5）= 4，即 GRAPH_VERSION + 「held 输入的个数」
BULLET_COLS = 5
ENEMY_COLS = 6
PLAYER_COLS = 5
#: dynamo 导出器的自然输出就是 18；请求 17 会让 onnxscript 的降级器抛
#: `No initializer or constant input to node found`（TopK 的 axes 那类节点降不回去），
#: 失败后它静默留在 18。没有理由跟降级器较劲 —— ORT 支持 18 已久，直接钉 18。
OPSET = 18
INPUT_NAMES = ("bullets", "bullets_mask", "enemies", "enemies_mask", "player", "target", "prev_action")
HELD_INPUT = "dir_held"
HELD_INPUTS = ("dir_held", "slow_held")     # 按这个顺序追加在七个基本输入之后；v4 用第一个，v5 两个都用
OUTPUT_NAMES = ("logits",)

#: `float("inf")` 的可导出替身。ONNX 能表达 inf，但 `torch.isfinite` 的导出不稳，
#: 而那一步检查本来就是多余的 —— 见 `DangerTopKV2Export._topk`。
SENTINEL = 1.0e30

# 训练侧每个弹池/敌池容量（th06nc 抽取器的上限）。契约仓 c/world.h 的 AP_MAX_*。
DEPLOY_BULLETS_ROWS = 640
DEPLOY_ENEMIES_ROWS = 256


class _ExportTopK:
    """特征化器的可导出孪生用的 mixin：**只重写 `_topk`**，其余计算逐行继承，杜绝两份实现漂移。

    原版 `_topk` 有两处不适合导出：

    1. `masked_fill(~mask, float("inf"))` —— 换成 `where(mask, dmin, 1e30)`。`topk(largest=False)`
       的结果不变：真实净距的量级是 1e4 以内（坐标 ≤ 1e3、半径 ≤ 1e2），1e30 一样排在所有真实值之后；
       两个哨兵之间的平局与两个 `inf` 之间的平局同样由 `topk` 按下标裁决，选出的 `idx` 逐位相同。
    2. `sel = isfinite(kval) & (kval <= d_max)` —— `isfinite` 那一项是**多余的**：哨兵
       （无论 `inf` 还是 `1e30`）都远大于 `d_max`（128），第二项已经把它判掉。所以只留第二项。

    `d_norm` 也不受影响：`clamp(1e30, -d_max, d_max) / d_max` 与 `clamp(inf, …) / d_max` 都等于 1.0。
    这两条等价性由 `tests/test_export_onnx.py::test_deploy_wrapper_matches_training_path` 押运。
    """

    def _topk(self, p: Tensor, v: Tensor, radius: Tensor, mask: Tensor, hit_r: Tensor, k: int):
        dmin, t = closest_approach(p, v, radius + hit_r[:, None], self.horizon)
        key = torch.where(mask, dmin, torch.full_like(dmin, SENTINEL))
        kval, idx = torch.topk(key, k, dim=1, largest=False)
        sel = kval <= self.d_max
        d_norm = kval.clamp(-self.d_max, self.d_max) / self.d_max
        return idx, sel, d_norm, _gather(t, idx) / self.horizon


class DangerTopKV2Export(_ExportTopK, DangerTopKV2):
    pass


class DangerTopKV3Export(_ExportTopK, DangerTopKV3):
    """v3 的敌人行再走一遍 `_topk`（带相对速度），同样落在 mixin 重写的那一份上。"""


class DangerTopKV4Export(_ExportTopK, DangerTopKV4):
    """v4 只在 player 向量后面多拼一维 dir_held，`_topk` 同样落在 mixin 上。"""


class DangerTopKV5Export(_ExportTopK, DangerTopKV5):
    """v5 再多拼一维 slow_held。"""


#: checkpoint 的特征化器名 → 可导出孪生。不在表里的一律拒绝导出。
EXPORT_FEATURIZERS = {"danger_topk_v2": DangerTopKV2Export, "danger_topk_v3": DangerTopKV3Export,
                      "danger_topk_v4": DangerTopKV4Export, "danger_topk_v5": DangerTopKV5Export}
#: 特征化器 → 要几个 held 输入（`HELD_INPUTS` 的前几个）。图版本 = GRAPH_VERSION + 这个数
HELD_FEATURIZERS = {"danger_topk_v4": 1, "danger_topk_v5": 2}


def uses_held(cfg: dict) -> int:
    """要几个 held 输入：0（v2 / v3）、1（v4：dir_held）、2（v5：dir_held + slow_held）。
    下面各处的 `with_held` 参数收的就是这个数（bool 也行：True = 1）。"""
    return HELD_FEATURIZERS.get(cfg["featurize"]["name"], 0)


def held_names(with_held: int) -> tuple[str, ...]:
    return HELD_INPUTS[:int(with_held)]


def input_names(cfg: dict) -> tuple[str, ...]:
    return INPUT_NAMES + held_names(uses_held(cfg))


def export_featurizer(cfg: dict):
    name = cfg["featurize"]["name"]
    if name not in EXPORT_FEATURIZERS:
        raise ValueError(f"本导出器只支持 {sorted(EXPORT_FEATURIZERS)}，checkpoint 是 {name!r}"
                         "（换特征化器要加一个可导出孪生；动了图签名还要 bump GRAPH_VERSION）")
    return EXPORT_FEATURIZERS[name](cfg)


class DeployWrapper(nn.Module):
    """原始表 → logits。把扁平输入摊成 `RawObs`（batch=1），交给导出用特征化器与训练好的模型。"""

    def __init__(self, cfg: dict, model: nn.Module, *, bullets_rows: int, enemies_rows: int):
        super().__init__()
        self.feat = export_featurizer(cfg)
        self.with_held = int(uses_held(cfg))
        self.model = model
        self.bullets_rows = int(bullets_rows)
        self.enemies_rows = int(enemies_rows)
        if self.bullets_rows < int(cfg["featurize"]["k_bullets"]):
            raise ValueError(f"bullets_rows({bullets_rows}) < k_bullets({cfg['featurize']['k_bullets']})")
        if self.enemies_rows < int(cfg["featurize"]["k_enemies"]):
            raise ValueError(f"enemies_rows({enemies_rows}) < k_enemies({cfg['featurize']['k_enemies']})")

    def forward(self, bullets: Tensor, bullets_mask: Tensor, enemies: Tensor, enemies_mask: Tensor,
                player: Tensor, target: Tensor, prev_action: Tensor, dir_held: Tensor | None = None,
                slow_held: Tensor | None = None) -> Tensor:
        obs = RawObs(
            player_xy=player[0:2].reshape(1, 2),
            player_hit_r=player[2:3],
            player_speed=player[3:4],
            # v1 对 focus 只做 `.to(float32)`，所以直接喂浮点 0/1，省掉图里一次 bool 往返
            player_focus=player[4:5],
            bullets=bullets.unsqueeze(0),
            bullets_mask=bullets_mask.unsqueeze(0),
            enemies=enemies.unsqueeze(0),
            enemies_mask=enemies_mask.unsqueeze(0),
            target_xy=target.reshape(1, 2),
            prev_action=prev_action,
            dir_held=dir_held if self.with_held >= 1 else None,
            slow_held=slow_held if self.with_held >= 2 else None,
        )
        logits, _ = self.model(self.feat(obs))
        return logits.reshape(NUM_ACTIONS)


def deploy_inputs(obs: RawObs, env: int, *, bullets_rows: int, enemies_rows: int,
                  with_held: bool = False) -> tuple[Tensor, ...]:
    """从训练侧 `RawObs` 取第 `env` 个 env，摊成图的七个输入。行数不足补零行 + 假掩码，超出则截断。

    `enemies` 六列全取（后两列是 `envwrap.enemy_velocity` 差分出来的速度）。摊出来的形状与 dtype 就是 `INPUT_NAMES` 的契约，
    ONNX 会话的输入校验、C 侧 `sa_model_in` 填的数组，三者必须一致。
    """
    def fit(t: Tensor, rows: int, cols: int) -> Tensor:
        out = torch.zeros(rows, cols, dtype=torch.float32)
        n = min(rows, t.shape[0])
        out[:n] = t[:n, :cols].to(torch.float32)
        return out

    def fit_mask(t: Tensor, rows: int) -> Tensor:
        out = torch.zeros(rows, dtype=torch.bool)
        n = min(rows, t.shape[0])
        out[:n] = t[:n].to(torch.bool)
        return out

    prev = obs.prev_action
    prev_id = 0 if prev is None else int(prev[env])
    def one(t: Tensor | None) -> Tensor:
        return torch.tensor([int(t[env]) if t is not None else 1 << 20], dtype=torch.int64)

    held = tuple(one(getattr(obs, name)) for name in held_names(with_held))
    return (
        fit(obs.bullets[env], bullets_rows, BULLET_COLS),
        fit_mask(obs.bullets_mask[env], bullets_rows),
        fit(obs.enemies[env], enemies_rows, ENEMY_COLS),
        fit_mask(obs.enemies_mask[env], enemies_rows),
        torch.tensor([float(obs.player_xy[env, 0]), float(obs.player_xy[env, 1]),
                      float(obs.player_hit_r[env]), float(obs.player_speed[env]),
                      float(obs.player_focus[env])], dtype=torch.float32),
        obs.target_xy[env].to(torch.float32).clone(),
        torch.tensor([prev_id], dtype=torch.int64),
    ) + held


def build_deploy(ckpt_path, *, bullets_rows: int = DEPLOY_BULLETS_ROWS,
                 enemies_rows: int = DEPLOY_ENEMIES_ROWS) -> tuple[DeployWrapper, dict]:
    """读 checkpoint，按它自带的配置重建模型并装上权重，返回 (wrapper, 元数据)。"""
    ck = load_checkpoint(ckpt_path, map_location="cpu")
    cfg = from_dict(ck["cfg"])
    if ck["featurizer_name"] != cfg["featurize"]["name"]:
        raise ValueError(f"checkpoint 自相矛盾：featurizer_name={ck['featurizer_name']!r}，"
                         f"cfg 里是 {cfg['featurize']['name']!r}")
    load_builtins()
    feat_spec = export_featurizer(cfg).spec()
    model = MODELS.get(ck["model_name"])(cfg, feat_spec)
    agent_sd = ck["state"]["agent"]
    prefix = "model."
    model_sd = {k[len(prefix):]: v for k, v in agent_sd.items() if k.startswith(prefix)}
    model.load_state_dict(model_sd)
    model.eval()
    wrap = DeployWrapper(cfg, model, bullets_rows=bullets_rows, enemies_rows=enemies_rows).eval()
    meta = {
        "update": int(ck["update"]), "env_steps": int(ck["env_steps"]),
        "featurizer_name": ck["featurizer_name"], "model_name": ck["model_name"],
        "action_table_version": int(ck["action_table_version"]),
        "featurize": dict(cfg["featurize"]), "model": dict(cfg["model"]),
        "hold_radius": float(cfg["reward"]["hold_radius"]),
        "motor": dict(cfg["motor"]), "with_held": uses_held(cfg),
        "extra": ck.get("extra", {}),
    }
    return wrap, meta


def _inline_external_data(path: Path) -> None:
    """把权重收回 `.onnx` 里。

    dynamo 导出器默认把 initializer 甩进旁挂的 `<name>.onnx.data`，而部署侧只往游戏目录拖**一个**
    图文件（设计 §7）—— 旁挂文件一旦漏拷，ORT 建会话时才会失败，而那已经是玩家机器上了。
    这里连外部数据一起读进内存、以自包含形式重写，再删掉旁挂文件，最后断言图里确实没有
    `EXTERNAL` 的 initializer 了。
    """
    import onnx

    head = onnx.load(str(path), load_external_data=False)
    sidecars = {
        Path(kv.value)
        for t in head.graph.initializer
        if t.data_location == onnx.TensorProto.EXTERNAL
        for kv in t.external_data
        if kv.key == "location"
    }
    if not sidecars:
        return
    onnx.save_model(onnx.load(str(path)), str(path), save_as_external_data=False)
    for rel in sidecars:
        f = path.parent / rel
        if f.exists():
            f.unlink()
    left = [t.name for t in onnx.load(str(path), load_external_data=False).graph.initializer
            if t.data_location == onnx.TensorProto.EXTERNAL]
    if left:
        raise RuntimeError(f"图仍有外部 initializer，收不回来：{left[:4]}…（共 {len(left)} 个）")


def export_graph(wrap: DeployWrapper, example: tuple[Tensor, ...], out_path) -> Path:
    """导出定形图，权重内联成单文件。dynamo 导出器优先，失败退回 TorchScript 路径。"""
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    names = INPUT_NAMES + held_names(len(example) - len(INPUT_NAMES))
    kw = dict(input_names=list(names), output_names=list(OUTPUT_NAMES), opset_version=OPSET)
    try:
        torch.onnx.export(wrap, example, str(out_path), dynamo=True, **kw)
    except Exception as exc:  # noqa: BLE001 —— 退回路径本身就是为了兜住任意导出器内部错误
        print(f"[export] dynamo 导出失败，退回 TorchScript 路径：{type(exc).__name__}: {exc}")
        torch.onnx.export(wrap, example, str(out_path), dynamo=False, **kw)
    _inline_external_data(out_path)
    return out_path


def _sha256(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def graph_signature(bullets_rows: int, enemies_rows: int, with_held: bool = False) -> list[dict]:
    shapes = {
        "bullets": ([bullets_rows, BULLET_COLS], "float32"),
        "bullets_mask": ([bullets_rows], "bool"),
        "enemies": ([enemies_rows, ENEMY_COLS], "float32"),
        "enemies_mask": ([enemies_rows], "bool"),
        "player": ([PLAYER_COLS], "float32"),
        "target": ([2], "float32"),
        "prev_action": ([1], "int64"),
        **{name: ([1], "int64") for name in HELD_INPUTS},
    }
    names = INPUT_NAMES + held_names(with_held)
    return [{"name": n, "dtype": shapes[n][1], "shape": shapes[n][0]} for n in names]


def write_manifest(path, *, checkpoint, onnx, meta: dict, bullets_rows: int, enemies_rows: int) -> Path:
    """出处清单：部署侧靠它确认「装的是哪一版模型」，对拍脚本靠它核签名。"""
    path = Path(path)
    with_held = int(meta.get("with_held", 0))
    payload = {
        "graph_version": GRAPH_VERSION + with_held,
        "opset": OPSET,
        "num_actions": NUM_ACTIONS,
        "action_table_version": meta.get("action_table_version", ACTION_TABLE_VERSION),
        "checkpoint": str(checkpoint),
        "onnx": Path(onnx).name,
        "update": meta.get("update"),
        "env_steps": meta.get("env_steps"),
        "featurizer_name": meta.get("featurizer_name"),
        "model_name": meta.get("model_name"),
        "featurize": meta.get("featurize"),
        "model": meta.get("model"),
        "hold_radius": meta.get("hold_radius"),
        # 这张图是在什么运动层下练出来的 —— 部署侧 DLL 要照这组参数跑同一个运动层
        "motor": meta.get("motor"),
        "eval": meta.get("extra", {}).get("eval"),
        "inputs": graph_signature(bullets_rows, enemies_rows, with_held),
        "outputs": [{"name": "logits", "dtype": "float32", "shape": [NUM_ACTIONS]}],
        "sha256": {"checkpoint": _sha256(checkpoint), "onnx": _sha256(onnx)},
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def _example_inputs(bullets_rows: int, enemies_rows: int, with_held: int = 0) -> tuple[Tensor, ...]:
    """导出用的样例输入：一颗迎面弹 + 一只敌，够让每一路都有非零值。"""
    bullets = torch.zeros(bullets_rows, BULLET_COLS)
    bullets[0] = torch.tensor([8.0, 320.0, 0.0, 3.0, 4.0])
    bmask = torch.zeros(bullets_rows, dtype=torch.bool)
    bmask[0] = True
    enemies = torch.zeros(enemies_rows, ENEMY_COLS)
    enemies[0] = torch.tensor([0.0, 96.0, 16.0, 1.0, 1.5, 2.0])
    emask = torch.zeros(enemies_rows, dtype=torch.bool)
    emask[0] = True
    player = torch.tensor([0.0, 384.0, 2.5, 4.5, 0.0])
    target = torch.tensor([0.0, 384.0])
    base = (bullets, bmask, enemies, emask, player, target, torch.zeros(1, dtype=torch.int64))
    return base + tuple(torch.tensor([v], dtype=torch.int64) for v in (3, 5)[:int(with_held)])


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="checkpoint → ONNX（特征化 + 网络一起）")
    ap.add_argument("checkpoint")
    ap.add_argument("--out", default="dist", help="产物目录（默认 dist/）")
    ap.add_argument("--name", default="best", help="产物基名（如 j-best → j-best.onnx / j-best.manifest.json）")
    ap.add_argument("--bullets-rows", type=int, default=DEPLOY_BULLETS_ROWS)
    ap.add_argument("--enemies-rows", type=int, default=DEPLOY_ENEMIES_ROWS)
    a = ap.parse_args(argv)

    wrap, meta = build_deploy(a.checkpoint, bullets_rows=a.bullets_rows, enemies_rows=a.enemies_rows)
    out_dir = Path(a.out)
    onnx_path = out_dir / f"{a.name}.onnx"
    example = _example_inputs(a.bullets_rows, a.enemies_rows, with_held=int(meta["with_held"]))
    export_graph(wrap, example, onnx_path)
    man = write_manifest(out_dir / f"{a.name}.manifest.json", checkpoint=a.checkpoint, onnx=onnx_path, meta=meta,
                         bullets_rows=a.bullets_rows, enemies_rows=a.enemies_rows)

    with torch.no_grad():
        ref = wrap(*example)
    try:
        import onnxruntime as ort
    except ImportError:
        print("[export] 没装 onnxruntime，跳过导出后自检（CI 与本地 pytest 会跑）")
    else:
        sess = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
        names = INPUT_NAMES + held_names(meta["with_held"])
        got = torch.from_numpy(sess.run(["logits"], {n: t.numpy() for n, t in zip(names, example)})[0])
        dev = (got - ref).abs().max().item()
        if dev > 1e-5 or got.argmax().item() != ref.argmax().item():
            raise SystemExit(f"导出后自检失败：logits 最大偏差 {dev:.3g}，argmax {got.argmax()} vs {ref.argmax()}")
        print(f"[export] 自检通过：logits 最大偏差 {dev:.3g}")

    print(f"[export] {onnx_path}（{onnx_path.stat().st_size / 1e6:.2f} MB）")
    print(f"[export] {man}")
    print(f"[export] update={meta['update']} env_steps={meta['env_steps']} "
          f"feat={meta['featurizer_name']} 动作表 v{meta['action_table_version']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
