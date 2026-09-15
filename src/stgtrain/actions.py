"""动作表 v1（spec §3.2，冻结）：action_id = 方向 × 2 + slow；SHOT 恒按，BOMB 永不置位。

部署侧（th06nc / TH18 DLL）照抄本表。改动任何一项 = 新版本号 + 旧 checkpoint 作废。
"""
from __future__ import annotations

import torch
from stgagent import consts as C
from torch import Tensor

ACTION_TABLE_VERSION = 1
NUM_ACTIONS = 18
# 方向 0 不动 1 上 2 右上 3 右 4 右下 5 下 6 左下 7 左 8 左上（与 stg-rl 预热游走表 WALK_DIRS 同序）
DIR_BUTTONS: tuple[int, ...] = (
    0,
    C.BTN_UP,
    C.BTN_UP | C.BTN_RIGHT,
    C.BTN_RIGHT,
    C.BTN_DOWN | C.BTN_RIGHT,
    C.BTN_DOWN,
    C.BTN_DOWN | C.BTN_LEFT,
    C.BTN_LEFT,
    C.BTN_UP | C.BTN_LEFT,
)
MIRROR_DIR: tuple[int, ...] = (0, 1, 8, 7, 6, 5, 4, 3, 2)
DIR_MASK = C.BTN_UP | C.BTN_DOWN | C.BTN_LEFT | C.BTN_RIGHT
_KEY_BITS = 7  # UP DOWN LEFT RIGHT SHOT BOMB SLOW


def action_buttons(action_id: int) -> int:
    d, slow = divmod(int(action_id), 2)
    return DIR_BUTTONS[d] | C.BTN_SHOT | (C.BTN_SLOW if slow else 0)


def buttons_table(device) -> Tensor:
    return torch.tensor([action_buttons(a) for a in range(NUM_ACTIONS)], dtype=torch.int64, device=device)


def mirror_table(device) -> Tensor:
    return torch.tensor([MIRROR_DIR[a // 2] * 2 + a % 2 for a in range(NUM_ACTIONS)], dtype=torch.int64, device=device)


def _popcount(x: Tensor) -> Tensor:
    return sum(((x >> i) & 1) for i in range(_KEY_BITS))


def key_changes(prev: Tensor, cur: Tensor) -> tuple[Tensor, Tensor]:
    changed = prev ^ cur
    return _popcount(changed & cur), (changed & C.BTN_SLOW) != 0


def direction_changed(prev: Tensor, cur: Tensor) -> Tensor:
    return (prev & DIR_MASK) != (cur & DIR_MASK)
