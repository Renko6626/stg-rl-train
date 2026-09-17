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
        "log": {"tensorboard": False, "perf_sync_every": 1},
        "bench": {"seconds": 0.5, "num_envs": [8]},
    }
    return from_dict(deep_merge(base, sections))


@pytest.fixture
def cfg():
    return small_cfg()


import torch

from stgtrain.envwrap import RawObs


def _per_env(v, n):
    return [tuple(x) for x in v] if isinstance(v, list) else [tuple(v)] * n


def raw_obs(n=2, cap=16, e=8, player=(0.0, 384.0), target=(0.0, 300.0), speed=4.0, hit_r=2.0,
            bullets=None, enemies=None, focus=False, prev_action=0) -> RawObs:
    """手搓 RawObs。bullets / enemies：按 env 给行列表，弹行 (x, y, vx, vy, r)、敌行 (x, y, r, is_boss)。"""
    b = torch.zeros(n, cap, 5)
    bm = torch.zeros(n, cap, dtype=torch.bool)
    for i, rows in enumerate(bullets or []):
        for j, row in enumerate(rows):
            b[i, j] = torch.tensor(row, dtype=torch.float32)
            bm[i, j] = True
    en = torch.zeros(n, e, 4)
    em = torch.zeros(n, e, dtype=torch.bool)
    for i, rows in enumerate(enemies or []):
        for j, row in enumerate(rows):
            en[i, j] = torch.tensor(row, dtype=torch.float32)
            em[i, j] = True
    return RawObs(
        player_xy=torch.tensor(_per_env(player, n), dtype=torch.float32),
        player_hit_r=torch.full((n,), float(hit_r)),
        player_speed=torch.full((n,), float(speed)),
        player_focus=torch.full((n,), bool(focus)),
        bullets=b, bullets_mask=bm, enemies=en, enemies_mask=em,
        target_xy=torch.tensor(_per_env(target, n), dtype=torch.float32),
        prev_action=torch.tensor(prev_action if isinstance(prev_action, list) else [prev_action] * n, dtype=torch.int64),
    )


def mirror_obs(o: RawObs) -> RawObs:
    """把 RawObs 左右镜像（x 类量取反），用于镜像一致性测试。"""
    def neg_col(t, cols):
        t = t.clone()
        for c in cols:
            t[..., c] = -t[..., c]
        return t

    return RawObs(
        player_xy=neg_col(o.player_xy, [0]), player_hit_r=o.player_hit_r, player_speed=o.player_speed,
        player_focus=o.player_focus, bullets=neg_col(o.bullets, [0, 2]), bullets_mask=o.bullets_mask,
        enemies=neg_col(o.enemies, [0]), enemies_mask=o.enemies_mask, target_xy=neg_col(o.target_xy, [0]),
        prev_action=None if o.prev_action is None else _mirror_actions(o.prev_action),
    )


def _mirror_actions(a):
    from stgtrain import actions

    return actions.mirror_table(a.device)[a]


from stgagent import consts as C

from stgtrain.envwrap import StepInfo


def step_info(n=2, done=None, refreshed=None, buttons=None, prev_buttons=None, ep_frames=100) -> StepInfo:
    def i64(v, default):
        return torch.tensor(v, dtype=torch.int64) if v is not None else torch.full((n,), default, dtype=torch.int64)

    return StepInfo(
        done=i64(done, 0),
        events=torch.zeros(n, 8, dtype=torch.int64),
        ep_frames=torch.full((n,), ep_frames, dtype=torch.int64),
        refreshed=torch.tensor(refreshed, dtype=torch.bool) if refreshed is not None else torch.zeros(n, dtype=torch.bool),
        buttons=i64(buttons, C.BTN_SHOT),
        prev_buttons=i64(prev_buttons, C.BTN_SHOT),
    )
