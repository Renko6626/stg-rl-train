"""rollout 每步的小算子录成 CUDA 图：特征化一张，reward + 逐局统计一张。

为什么：这几段在 2048 env 上每步只有几 MB 的数据，GPU 算起来是微秒级，真正花时间的是 Python 逐个发射
一两百个小核（A100 实测特征化 0.33 s + reward 0.27 s / 更新，而 512 → 2048 env 工作量 ×4、更新耗时只 +33%，
见 docs/perf-baseline.md）。录成图之后每步各只剩一次重放。

**不编译，只录图**：重放的是与 eager 相同的核，结果与 eager 一致（密度图的 scatter_add 用原子加，求和顺序
本来就不定，两边同样如此）；也省掉 torch.compile 的冷启动，不受 Magnus（torch 2.5）与 Vast（2.14）版本差影响。

录图的约束，改特征化器 / reward 项 / EpisodeTracker 时要守住：
- 不能有 CPU 同步（`.item()`、`.cpu()`、按张量值走 Python 分支）、不能新建 CPU 张量再搬上 GPU、不能用随机数；
- 输出形状只由 num_envs / bullets_cap 等配置决定；RawObs / StepInfo 哪些字段为 None 在一次训练内不能变；
- 图里不能插子阶段计时（计时要 synchronize）——所以开图时 perf 里只剩 featurize / reward 两个父阶段。
EpisodeTracker 的状态走图的输入 / 输出（`EpisodeTracker.step` 是纯函数），待 pop 的记录在图外追加。
"""
from __future__ import annotations

import dataclasses

from tensordict.nn import CudaGraphModule
from torch import Tensor

from .envwrap import RawObs, StepInfo
from .perf import maybe_phase

WARMUP = 3   # 前几次在旁路流上直接执行（让 cuBLAS 等懒初始化先发生），之后才捕获


def _pack(x) -> dict[str, Tensor]:
    """dataclass → 只含张量的 dict（CudaGraphModule 按 pytree 展开输入；None 字段不进图）。"""
    return {f.name: v for f in dataclasses.fields(x) if (v := getattr(x, f.name)) is not None}


class RolloutGraphs:
    def __init__(self, featurizer, reward_fn, tracker, graphs: bool):
        self.featurizer, self.reward_fn, self.tracker = featurizer, reward_fn, tracker
        self.graphs = bool(graphs)
        if not self.graphs:
            return

        def feat(obs: dict[str, Tensor]) -> dict[str, Tensor]:
            return featurizer(RawObs(**obs))

        def reward_track(prev: dict[str, Tensor], cur: dict[str, Tensor], info: dict[str, Tensor], state):
            p, c, i = RawObs(**prev), RawObs(**cur), StepInfo(**info)
            total, raw = reward_fn(p, c, i)
            new_state, entry = tracker.step(state, p, c, i, total, raw)
            return total, new_state, entry

        # 只用 tensordict 0.6.2（Magnus 镜像）与 0.14（Vast）共有的参数：0.6.2 没有 device，默认当前设备
        self._feat = CudaGraphModule(feat, warmup=WARMUP)
        self._reward_track = CudaGraphModule(reward_track, warmup=WARMUP)

    def matches(self, featurizer, reward_fn, tracker) -> bool:
        return self.featurizer is featurizer and self.reward_fn is reward_fn and self.tracker is tracker

    def featurize(self, obs: RawObs, timer=None) -> dict[str, Tensor]:
        if not self.graphs:
            return self.featurizer(obs, timer=timer)
        return self._feat(_pack(obs))

    def reward(self, prev: RawObs, cur: RawObs, info: StepInfo, timer=None) -> Tensor:
        """本步奖励；顺带把这一步并入逐局统计。"""
        if not self.graphs:
            with maybe_phase(timer, "reward_terms"):
                total, raw = self.reward_fn(prev, cur, info)
            with maybe_phase(timer, "episode_tracker"):
                self.tracker.update(prev, cur, info, total, raw)
            return total
        total, state, entry = self._reward_track(_pack(prev), _pack(cur), _pack(info), self.tracker.state())
        self.tracker.load_state(state)
        self.tracker.push(entry)
        return total
