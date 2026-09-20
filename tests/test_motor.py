"""手部运动层（实验 N）：策略说「想按哪个方向」，实际按出去的由 MotorLayer 决定。

判别力说明：每条规则都要有「刚好放行」与「刚好挡住」两侧；随机量要押范围**且**押散布
（只押范围的话，退化成恒取下界的实现照样绿——而「确定性最短保持」正是设计明确否掉的方案）。
"""
from __future__ import annotations

import stg_rl
import torch

from conftest import FIXTURES, small_cfg
from stgtrain import actions
from stgtrain.cards import compile_cards, discover
from stgtrain.envwrap import DIR_HOLD_NEVER, EnvWrapper, MotorLayer
from stgtrain.registry import load_builtins

load_builtins()
CPU = torch.device("cpu")
IMAGES = compile_cards(discover(FIXTURES / "cards"))


def layer(n=1, hold=(3, 3), delay=(0, 0), seed=1):
    cfg = small_cfg(motor={"enabled": True, "hold": list(hold), "delay": list(delay)})
    return MotorLayer(cfg, n, CPU, seed)


class Hand:
    """替 envwrap 记账的最小替身：上一步执行的动作 + 当前方向已执行帧数。"""

    def __init__(self, m: MotorLayer):
        self.m, self.n = m, m.n
        self.prev = torch.zeros(self.n, dtype=torch.int64)
        self.held = torch.full((self.n,), DIR_HOLD_NEVER, dtype=torch.int64)

    def step(self, want) -> torch.Tensor:
        want = torch.as_tensor(want, dtype=torch.int64).expand(self.n).clone()
        out = self.m.apply(want, self.prev, self.held)
        changed = (out // 2) != (self.prev // 2)
        self.held = torch.where(changed, torch.ones_like(self.held), self.held + 1)
        self.prev = out
        return out


def dirs(h: Hand, wants) -> list[int]:
    return [int(h.step(w * 2)[0]) // 2 for w in wants]


def test_first_change_of_an_episode_is_free():
    assert dirs(Hand(layer(hold=(5, 5))), [3]) == [3]


def test_min_hold_blocks_until_segment_is_long_enough():
    # hold=3：换到 3 之后这一段要执行满 3 帧；第 2、3 帧想换被挡，第 4 帧放行
    assert dirs(Hand(layer(hold=(3, 3))), [3, 7, 7, 7, 7]) == [3, 3, 3, 7, 7]


def test_stopping_is_a_direction_change_too():
    """1 帧点按 = 按下 → 下一帧松开。松开也得等：这正是要去掉的那个能力。"""
    assert dirs(Hand(layer(hold=(4, 4))), [3, 0, 0, 0, 0]) == [3, 3, 3, 3, 0]


def test_wanting_the_current_direction_again_changes_nothing():
    h = Hand(layer(hold=(3, 3)))
    assert dirs(h, [3, 7, 3, 3, 3, 3]) == [3, 3, 3, 3, 3, 3]   # 中途想换又反悔：一直是 3，没有迟到的变向


def test_slow_bit_passes_straight_through():
    h = Hand(layer(hold=(5, 5)))
    got = [int(h.step(a)[0]) for a in (6, 7, 6, 15)]   # 方向 3：低速关 / 开 / 关；然后想换到方向 7 且低速
    assert got == [6, 7, 6, 7], "方向被锁在 3，低速位照策略给的走"


def test_hold_is_random_within_range_and_actually_spreads():
    h = Hand(layer(n=512, hold=(2, 6), seed=3))
    h.step(3 * 2)                                   # 全体换到方向 3，各自抽一个 L
    freed_at = torch.zeros(512, dtype=torch.int64)
    for t in range(1, 10):                          # 此后一直想换到 7，看各自第几帧放行
        out = h.step(7 * 2) // 2
        freed_at = torch.where((out == 7) & (freed_at == 0), torch.full_like(freed_at, t), freed_at)
    seg_len = freed_at                              # 方向 3 执行了 t 帧后放行 ⇒ 段长 = t
    assert int(seg_len.min()) == 2 and int(seg_len.max()) == 6, "段长必须落在 [2, 6] 且两端都取得到"
    assert all(int((seg_len == k).sum()) > 40 for k in range(2, 7)), "五个取值都要有相当的份额（均匀 ≈ 102）"


def test_delay_postpones_the_change():
    assert dirs(Hand(layer(hold=(0, 0), delay=(2, 2))), [3, 3, 3, 3]) == [0, 0, 3, 3]


def test_changing_your_mind_redraws_the_delay():
    # t0 想 3（延迟 2）；t1 改想 7 → 重新计 2 帧；所以 7 在 t3 生效，3 从未出现
    assert dirs(Hand(layer(hold=(0, 0), delay=(2, 2))), [3, 7, 7, 7, 7]) == [0, 0, 0, 7, 7]


def test_withdrawing_the_request_cancels_it():
    # 想 3 一帧就反悔回「不动」：请求撤销；之后再想 3 要重新等满 2 帧
    assert dirs(Hand(layer(hold=(0, 0), delay=(2, 2))), [3, 0, 3, 3, 3]) == [0, 0, 0, 0, 3]


def test_delay_and_hold_must_both_be_satisfied():
    # hold=4、delay=1：换到 3（t1 生效），随后想 7：延迟 1 帧早就过了，但要等 3 这一段执行满 4 帧
    assert dirs(Hand(layer(hold=(4, 4), delay=(1, 1))), [3, 3, 7, 7, 7, 7, 7]) == [0, 3, 3, 3, 3, 7, 7]


def test_reset_clears_lock_and_pending_per_env():
    h = Hand(layer(n=2, hold=(9, 9), delay=(0, 0)))
    h.step(3 * 2)
    h.m.reset(torch.tensor([True, False]))
    h.prev[0], h.held[0] = 0, DIR_HOLD_NEVER          # envwrap 在新局也会这样清
    out = h.step(7 * 2) // 2
    assert out.tolist() == [7, 3], "新局第一下不受限；没结束的那个 env 仍被锁着"


def test_same_seed_same_draws():
    a, b = Hand(layer(n=64, hold=(2, 6), delay=(0, 2), seed=5)), Hand(layer(n=64, hold=(2, 6), delay=(0, 2), seed=5))
    g = torch.Generator().manual_seed(0)
    for _ in range(200):
        want = torch.randint(0, actions.NUM_ACTIONS, (64,), generator=g)
        assert torch.equal(a.step(want), b.step(want))


# ---------------- 接进 EnvWrapper ----------------

def ring(motor=None, seed=1):
    cfg = small_cfg(env={"mirror": False}, **({"motor": motor} if motor else {}))
    return EnvWrapper(cfg, IMAGES, [stg_rl.Start("example_ring", 0, 2)], CPU, seed=seed)


def test_disabled_layer_is_a_no_op():
    w = ring()
    w.reset()
    a = torch.tensor([6, 14, 0, 3, 6, 14, 0, 3])
    obs, info = w.step(a)
    assert w.motor is None and torch.equal(obs.prev_action, a) and not info.overridden.any()
    moved = a // 2 != 0
    assert (obs.dir_held[moved] == 1).all(), "刚换完方向：已执行 1 帧"
    assert (obs.dir_held[~moved] > 1000).all(), "开局一直没动：没发生过变向，保持帧数仍是「很大」"


def test_wrapper_executes_the_layer_output_everywhere():
    """prev_action / buttons / dir_held / overridden 全按**实际执行的**算 —— 不然模型看到的是一个它没做过的动作。"""
    w = ring(motor={"enabled": True, "hold": [3, 3], "delay": [0, 0]})
    w.reset()
    n = w.n
    right, left = torch.full((n,), 3 * 2), torch.full((n,), 7 * 2)
    obs, info = w.step(right)                                   # 第一下放行
    assert torch.equal(obs.prev_action, right) and not info.overridden.any()
    for k in (2, 3):                                            # 想换左，被锁：执行的仍是右
        obs, info = w.step(left)
        assert torch.equal(obs.prev_action, right) and info.overridden.all()
        assert torch.equal(info.buttons & actions.DIR_MASK, torch.full((n,), actions.DIR_BUTTONS[3]))
        assert torch.equal(obs.dir_held, torch.full((n,), k))
    obs, info = w.step(left)                                    # 右执行满 3 帧 → 放行
    assert torch.equal(obs.prev_action, left) and not info.overridden.any()
    assert torch.equal(obs.dir_held, torch.ones(n, dtype=torch.int64))


def test_no_executed_movement_segment_is_shorter_than_hold_lo():
    """端到端不变量：随机乱按 600 帧，按出去的每一段方向（跨局的除外）都不短于 hold 下界。"""
    w = ring(motor={"enabled": True, "hold": [2, 6], "delay": [0, 2]}, seed=9)
    w.reset()
    g = torch.Generator().manual_seed(1)
    prev_dir = torch.zeros(w.n, dtype=torch.int64)
    run = torch.full((w.n,), 99, dtype=torch.int64)
    shortest, overridden = 99, 0
    for _ in range(600):
        obs, info = w.step(torch.randint(0, actions.NUM_ACTIONS, (w.n,), generator=g))
        cur = obs.prev_action // 2
        ended = info.done != 0
        changed = (cur != prev_dir) & ~ended
        if changed.any():
            shortest = min(shortest, int(run[changed].min()))
        run = torch.where(changed | ended, torch.where(ended, torch.full_like(run, 99), torch.ones_like(run)), run + 1)
        prev_dir = torch.where(ended, torch.zeros_like(cur), cur)
        overridden += int(info.overridden.sum())
    assert shortest >= 2, f"出现了 {shortest} 帧的段"
    assert overridden > 600, "乱按的策略应当大部分时候被运动层否决"


# ---------------- 基于计数器的随机数 ----------------

def test_counter_draw_is_order_independent_and_matches_golden():
    """值只由 (seed, env, step, stream) 决定：分块怎么切、先算哪块都一样。黄金值与契约仓 c/tests/test_motor.c 共用 ——
    两边各写各的实现，押同一组数，C 与 Python 才算逐位同源。"""
    from stgtrain.envwrap import counter_draw

    ids = torch.arange(4)
    whole = counter_draw(12345, ids, 0, 16, 0, 2, 6)
    parts = torch.cat([counter_draw(12345, ids, 8, 8, 0, 2, 6), counter_draw(12345, ids, 0, 8, 0, 2, 6)])
    assert torch.equal(whole, torch.cat([parts[8:], parts[:8]]))
    assert whole.min() >= 2 and whole.max() <= 6
    assert not torch.equal(whole, counter_draw(12345, ids, 0, 16, 1, 2, 6)), "两路（hold / delay）不能同值"
    assert not torch.equal(whole[:, 0], whole[:, 1]), "不同 env 不能同值"
    assert torch.equal(counter_draw(1, ids, 0, 4, 0, 5, 5), torch.full((4, 4), 5))
    zero = torch.zeros(1, dtype=torch.int64)
    assert counter_draw(12345, zero, 0, 12, 0, 2, 6)[:, 0].tolist() == [2, 3, 4, 6, 4, 2, 6, 5, 6, 6, 4, 6]
    assert counter_draw(12345, zero, 0, 12, 1, 0, 2)[:, 0].tolist() == [2, 1, 2, 2, 0, 0, 0, 2, 2, 1, 2, 0]


def test_env_ids_make_batched_layer_reproduce_separate_layers():
    """批量评测的前提：把两组各 8 个 env 并成一批（env 编号各自 0..7），与两组分开跑逐位相同。"""
    cfg = small_cfg(motor={"enabled": True, "hold": [2, 6], "delay": [0, 2]})
    a, b = MotorLayer(cfg, 8, CPU, seed=5), MotorLayer(cfg, 8, CPU, seed=5)
    both = MotorLayer(cfg, 16, CPU, seed=5, env_ids=torch.arange(16) % 8)
    ha, hb, hboth = Hand(a), Hand(b), Hand(both)
    g = torch.Generator().manual_seed(3)
    for _ in range(150):
        wa, wb = (torch.randint(0, actions.NUM_ACTIONS, (8,), generator=g) for _ in range(2))
        out = torch.cat([ha.step(wa), hb.step(wb)])
        assert torch.equal(hboth.step(torch.cat([wa, wb])), out)
