from pathlib import Path

import pytest

from stgtrain.config import deep_merge, from_dict

FIXTURES = Path(__file__).parent / "fixtures"


def small_cfg(**sections) -> dict:
    """CPU 小配置：8 env、小模型、指向夹具卡。关键字参数按 section 深合并覆盖。"""
    base = {
        "run": {"device": "cpu", "total_updates": 3, "ckpt_every": 2, "eval_every": 3, "torch_threads": 2},
        "env": {"cards_dir": str(FIXTURES / "cards"), "eval_splits": str(FIXTURES / "eval_splits.toml"),
                "num_envs": 8, "threads": 2, "bullets_cap": 256},
        "featurize": {"k_bullets": 16},
        "model": {"d": 16, "heads": 2, "trunk": 32},
        "ppo": {"num_steps": 16, "num_minibatches": 2, "update_epochs": 1, "compile": False, "cudagraphs": False},
        "eval": {"episodes": 4},
        "log": {"tensorboard": False},
        "bench": {"seconds": 0.5, "num_envs": [8]},
    }
    return from_dict(deep_merge(base, sections))


@pytest.fixture
def cfg():
    return small_cfg()
