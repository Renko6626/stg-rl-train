"""起点难度采样（实验 H）：按每个起点的死亡率调采样权重——不会的多练。

env 侧本来就留了口子：`VecEnv::step` 在自动 reset **之前**把 `start_index` 写进缓冲（所以 `done != 0`
那一步读到的是刚结束那局的起点），`set_start_weights` 从 Rust 一路暴露到 Python，下一次 reset 生效。
这里只做训练侧的账：把结束的局归到起点，维护死亡率的 EMA，隔一段时间重算一次权重。

口径（`[curriculum]`）：

    w_i ∝ clamp(fail_i, floor, ceil) ** alpha        再归一化到均值 1，最后钳进 [w_lo, w_hi]

`fail_i` 是起点 i 的死亡率 EMA（done==1 占比；撑过与超时都算没死）。两级钳位缺一不可：

- `floor/ceil` 防止 0 或 1 把权重推到极端；
- `w_lo/w_hi` 是**相对均匀权重**的上下限，挡住经典病——近乎必死的卡（如 `th06_s5_b9` rank 3
  一屏 731 颗弹）会稳定拿最高死亡率，没有上限就会把采样吸干，而模型从里面学不到东西。

样本不足（`min_episodes`）的起点权重保持 1，避免开局几十局的噪声直接定生死。
"""
from __future__ import annotations

import numpy as np


class Curriculum:
    def __init__(self, n_starts: int, cfg: dict):
        self.n = int(n_starts)
        self.enabled = bool(cfg["enabled"])
        self.decay = float(cfg["ema_decay"])
        self.alpha = float(cfg["alpha"])
        self.floor, self.ceil = float(cfg["fail_floor"]), float(cfg["fail_ceil"])
        self.w_lo, self.w_hi = float(cfg["w_lo"]), float(cfg["w_hi"])
        self.interval = int(cfg["interval"])
        self.min_episodes = int(cfg["min_episodes"])
        self.fail = np.full(self.n, 0.5, dtype=np.float64)
        self.seen = np.zeros(self.n, dtype=np.int64)

    def observe(self, records: list[dict]) -> None:
        """吃一轮 rollout 结束的局；`record["start"]` 是起点下标，`done == 1` 为死亡。"""
        for r in records:
            i = int(r.get("start", -1))
            if not 0 <= i < self.n:
                continue
            x = 1.0 if int(r["done"]) == 1 else 0.0
            self.fail[i] += (1.0 - self.decay) * (x - self.fail[i])
            self.seen[i] += 1

    def weights(self) -> list[float]:
        w = np.ones(self.n, dtype=np.float64)
        ready = self.seen >= self.min_episodes
        if ready.any():
            raw = np.clip(self.fail[ready], self.floor, self.ceil) ** self.alpha
            w[ready] = np.clip(raw / raw.mean(), self.w_lo, self.w_hi)
        return w.tolist()

    def due(self, update: int) -> bool:
        return self.enabled and update % self.interval == 0

    def stats(self) -> dict[str, float]:
        w = np.asarray(self.weights())
        ready = self.seen >= self.min_episodes
        return {
            "curr/fail_mean": float(self.fail.mean()),
            "curr/fail_max": float(self.fail.max()),
            "curr/fail_min": float(self.fail.min()),
            "curr/w_max": float(w.max()),
            "curr/w_min": float(w.min()),
            "curr/ready_frac": float(ready.mean()),
        }
