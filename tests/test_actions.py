import torch
from stgagent import consts as C

from stgtrain import actions as A


def swap_lr(b: int) -> int:
    l, r = bool(b & C.BTN_LEFT), bool(b & C.BTN_RIGHT)
    b &= ~(C.BTN_LEFT | C.BTN_RIGHT)
    return b | (C.BTN_RIGHT if l else 0) | (C.BTN_LEFT if r else 0)


def test_table_contents():
    assert A.NUM_ACTIONS == 18 and A.ACTION_TABLE_VERSION == 1
    assert A.action_buttons(0) == C.BTN_SHOT
    assert A.action_buttons(1) == C.BTN_SHOT | C.BTN_SLOW
    assert A.action_buttons(2) == C.BTN_UP | C.BTN_SHOT
    assert A.action_buttons(6) == C.BTN_RIGHT | C.BTN_SHOT
    assert A.action_buttons(17) == C.BTN_UP | C.BTN_LEFT | C.BTN_SHOT | C.BTN_SLOW
    all_b = [A.action_buttons(a) for a in range(18)]
    assert len(set(all_b)) == 18
    assert all(b & C.BTN_SHOT and not b & C.BTN_BOMB for b in all_b)


def test_tensor_tables_match_python():
    bt, mt = A.buttons_table("cpu"), A.mirror_table("cpu")
    assert bt.tolist() == [A.action_buttons(a) for a in range(18)]
    assert torch.equal(mt[mt], torch.arange(18)), "镜像两次回到原样"
    for a in range(18):
        assert A.action_buttons(int(mt[a])) == swap_lr(A.action_buttons(a)), a


def test_key_changes_and_direction():
    prev = torch.tensor([C.BTN_UP | C.BTN_SHOT, C.BTN_SHOT | C.BTN_SLOW, C.BTN_SHOT])
    cur = torch.tensor([C.BTN_UP | C.BTN_RIGHT | C.BTN_SHOT | C.BTN_SLOW, C.BTN_SHOT, C.BTN_SHOT])
    presses, toggled = A.key_changes(prev, cur)
    assert presses.tolist() == [2, 0, 0]
    assert toggled.tolist() == [True, True, False]
    assert A.direction_changed(prev, cur).tolist() == [True, False, False]
