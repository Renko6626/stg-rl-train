"""意图生成器 follow_player_v1：目标点每帧锁在自机身上 —— 「自由躲弹」诊断模式。

`cond` 因此恒为（距离 0、在 R 内），等价于告诉模型「你已经在点上」，不给任何位置偏好；
这个输入分布模型在正常训练里见得很多（约 73% 的帧在圈内），所以不算分布外。
评测里 `in_r_frac` / `reach_frames` 会失去意义，看撑过率、方向变化、贴边、擦弹即可。

注意：真要**训练**自由躲弹模式，`follow_shaping` 会给「移动」一个每步约 −0.01 的隐性惩罚
（本步位移相对上一步目标点 = 自机上一步位置），要么把它关掉，要么改成带「有无指令」位的混合训练。
"""
from __future__ import annotations

import torch
from torch import Tensor

from .registry import INTENTS


@INTENTS.register("follow_player_v1")
class FollowPlayer:
    def __init__(self, cfg: dict, num_envs: int, device: torch.device, seed: int):
        self.n, self.device = int(num_envs), device
        self.target = torch.zeros(self.n, 2, device=device)
        self.countdown = torch.zeros(self.n, dtype=torch.int64, device=device)

    def track(self, player_xy: Tensor) -> None:
        """由 EnvWrapper 在解码每帧时调用（未镜像的世界坐标）。"""
        self.target = player_xy.detach().clone()

    def reset_all(self) -> None:
        pass

    def reset(self, mask: Tensor) -> None:
        pass

    def advance(self, frames: int, active: Tensor) -> Tensor:
        return torch.zeros(self.n, dtype=torch.bool, device=self.device)


@INTENTS.register("fixed_point_v1")
class FixedPoint:
    """目标点固定不动（默认场底中央）——用来区分「有锚点」和「随机换锚点」各自的贡献。"""

    def __init__(self, cfg: dict, num_envs: int, device: torch.device, seed: int):
        c = cfg["intent"]
        self.n, self.device = int(num_envs), device
        xy = torch.tensor([float(c.get("x", 0.0)), float(c.get("y", 384.0))], device=device)
        self.target = xy.expand(self.n, 2).clone()
        self.countdown = torch.zeros(self.n, dtype=torch.int64, device=device)

    def reset_all(self) -> None:
        pass

    def reset(self, mask: Tensor) -> None:
        pass

    def advance(self, frames: int, active: Tensor) -> Tensor:
        return torch.zeros(self.n, dtype=torch.bool, device=self.device)
