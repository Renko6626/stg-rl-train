"""checkpoint 存 / 读（spec §5）：自描述（注册名 + 完整配置 + 动作表版本），原子写。"""
from __future__ import annotations

import os
from pathlib import Path

import torch

from .actions import ACTION_TABLE_VERSION

FORMAT = 1


def save_checkpoint(path, *, ppo, update: int, env_steps: int, cfg: dict, extra: dict | None = None) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "format": FORMAT, "action_table_version": ACTION_TABLE_VERSION,
        "update": int(update), "env_steps": int(env_steps), "cfg": cfg,
        "model_name": cfg["model"]["name"], "featurizer_name": cfg["featurize"]["name"],
        "state": ppo.state_dict(),
        "torch_rng": torch.get_rng_state(),
        "cuda_rng": torch.cuda.get_rng_state_all() if torch.cuda.is_available() else None,
        "extra": extra or {},
    }
    tmp = path.with_name(path.name + ".tmp")
    torch.save(payload, tmp)
    os.replace(tmp, path)


def load_checkpoint(path, map_location="cpu") -> dict:
    ck = torch.load(path, map_location=map_location, weights_only=False)
    if ck.get("format") != FORMAT:
        raise ValueError(f"checkpoint 格式 {ck.get('format')} ≠ {FORMAT}")
    if ck.get("action_table_version") != ACTION_TABLE_VERSION:
        raise ValueError(f"checkpoint 的动作表版本 {ck.get('action_table_version')} ≠ 当前 {ACTION_TABLE_VERSION}")
    return ck


def restore_rng(ck: dict) -> None:
    # 续训时 checkpoint 按 map_location=device 读入，RNG 状态须搬回 CPU ByteTensor 才能 set
    torch.set_rng_state(ck["torch_rng"].cpu())
    if ck.get("cuda_rng") is not None and torch.cuda.is_available():
        torch.cuda.set_rng_state_all([s.cpu() for s in ck["cuda_rng"]])
