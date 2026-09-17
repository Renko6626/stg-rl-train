"""训练时的终端输出：开局概要 / 定时进度行 / 评测块 / checkpoint 行 / 收尾。

只做格式化（纯函数，好测）；打印由 train.py 负责，一律 flush——接在 `| tee` 后面时 stdout 是块缓冲。
权威数据仍是 metrics.jsonl 与 eval/*.json，这里只是给人看的。
"""
from __future__ import annotations

PROGRESS_EVERY_S = 30.0


def fmt_duration(s: float) -> str:
    s = int(round(s))
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m}:{sec:02d}"


def fmt_count(n: float) -> str:
    if n >= 1e9:
        return f"{n / 1e9:.2f}B"
    if n >= 1e6:
        return f"{n / 1e6:.1f}M"
    if n >= 1e3:
        return f"{n / 1e3:.1f}k"
    return f"{n:.0f}"


def _pct(v: float) -> str:
    return f"{v * 100:.0f}%"


def eta(done: int, remaining: int, elapsed: float) -> float | None:
    """按本次进程里已完成更新的平均耗时（含评测、存盘）外推剩余时间。"""
    return elapsed / done * remaining if done > 0 else None


class Throttle:
    """距上次放行满 interval 秒才放行；第一次必放行。"""

    def __init__(self, interval: float):
        self.interval, self.last = interval, None

    def ready(self, now: float) -> bool:
        if self.last is None or now - self.last >= self.interval:
            self.last = now
            return True
        return False


def banner(run_dir, device, n_cards: int, n_starts: int, eval_groups: int, cfg: dict, start: int) -> str:
    e, r, m = cfg["env"], cfg["run"], cfg["model"]
    total = int(r["total_updates"])
    lines = [
        "═" * 72,
        f"训练开始  {run_dir}",
        f"  设备 {device} · 卡池 {n_cards} 张 / 训练起点 {n_starts} 个 / 评测 {eval_groups} 组 · ranks {e['ranks']}",
        f"  {e['num_envs']} env × {e['threads']} 线程 · frame_skip {e['frame_skip']} · "
        f"模型 {m['name']} ({', '.join(f'{k}={v}' for k, v in m.items() if k != 'name')})",
        f"  更新 {start}→{total} · 每 {r['eval_every']} 次评测 · 每 {r['ckpt_every']} 次存 checkpoint"
        + (f" · 限时 {r['max_minutes']} 分钟" if float(r["max_minutes"]) > 0 else ""),
        "═" * 72,
    ]
    return "\n".join(lines)


def progress_line(update: int, total: int, env_steps: int, elapsed: float, eta: float | None, scalars: dict) -> str:
    width = len(str(total))
    parts = [f"[u {update:>{width}}/{total} {update / total * 100:3.0f}%] {fmt_count(env_steps)} 帧"]
    if "perf/sps" in scalars:
        parts.append(f"{fmt_count(scalars['perf/sps'])}/s")
    parts.append(f"已用 {fmt_duration(elapsed)}")
    if eta is not None:
        parts.append(f"剩 ~{fmt_duration(eta)}")
    if "ep/return" in scalars:
        parts += [f"回报 {scalars['ep/return']:.2f}", f"死 {_pct(scalars['ep/done1'])}",
                  f"跟点 {_pct(scalars['ep/in_r_frac'])}"]
    if "ppo/entropy_loss" in scalars:
        parts.append(f"熵 {scalars['ppo/entropy_loss']:.2f}")
    if "ppo/explained_variance" in scalars:
        parts.append(f"EV {scalars['ppo/explained_variance']:.2f}")
    return " · ".join(parts)


def eval_block(update: int, res: dict, is_best: bool, elapsed: float) -> str:
    o = res["overall"]
    head = f"── 评测 @ u{update} · {int(o.get('episodes', 0))} 局 · 耗时 {fmt_duration(elapsed)} "
    head += ("★ 新 best " if is_best else "")
    head = head.ljust(72, "─")
    summary = (f"  撑过 {o['survival'] * 100:.1f}% · 跟点 {o['in_r_frac'] * 100:.1f}% · "
               f"到达 {o['reach_frames_median']:.0f} 帧 · 方向 {o['dir_changes_per_s']:.1f}/s · "
               f"shift {o['shift_toggles_per_s']:.1f}/s · 贴边 {o['edge_frac'] * 100:.1f}%")
    rows = []
    names = [f"{card} {rank}" for card, per in res.get("cards", {}).items() for rank in per]
    w = max((len(n) for n in names), default=0)
    for card, per in res.get("cards", {}).items():
        for rank, v in per.items():
            rows.append(f"    {f'{card} {rank}':<{w}}   撑过 {v['survival'] * 100:3.0f}% · "
                        f"跟点 {v['in_r_frac'] * 100:3.0f}% · 均活 {v['frames_mean']:5.0f} 帧 · "
                        f"方向 {v['dir_changes_per_s']:4.1f}/s · shift {v['shift_toggles_per_s']:4.1f}/s")
    return "\n".join([head, summary, *rows])


def ckpt_line(update: int, names: list[str]) -> str:
    return f"  ✔ checkpoint u{update} → {', '.join(names)}"


def finish_line(update: int, env_steps: int, elapsed: float, best: tuple | None, stopped_early: bool) -> str:
    b = f" · best 撑过 {best[0] * 100:.1f}% / 跟点 {best[1] * 100:.1f}%" if best is not None else ""
    how = "提前停止" if stopped_early else "训练结束"
    return f"{'═' * 72}\n{how} @ u{update} · {fmt_count(env_steps)} 帧 · 用时 {fmt_duration(elapsed)}{b}"
