# MIT License
#
# Copyright (c) 2024 LeanRL developers
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
"""PPO —— 以 LeanRL leanrl/ppo_atari_envpool_torchcompile.py 为底本（MIT，许可见上）。

与底本的差异只有：envpool → EnvWrapper + 特征化器 + RewardFn（本仓胶水）；CNN Agent → 模型注册表；
GAE 按 stg_rl 的 done 码处理（spec §5）；日志 / checkpoint 由 train.py 负责。
rollout / loss / 更新 / compile + CudaGraphModule 的用法照抄底本。
"""
from __future__ import annotations

import os

os.environ.setdefault("TORCHDYNAMO_INLINE_INBUILT_NN_MODULES", "1")

from typing import Callable, Mapping  # noqa: E402

import torch  # noqa: E402
import torch.nn as nn  # noqa: E402
import torch.optim as optim  # noqa: E402
from tensordict import TensorDict, from_module  # noqa: E402
from tensordict.nn import CudaGraphModule, TensorDictModule  # noqa: E402
from torch import Tensor  # noqa: E402
from torch.distributions.categorical import Categorical, Distribution  # noqa: E402

from .perf import maybe_phase  # noqa: E402
from .rollout_graph import RolloutGraphs  # noqa: E402

Distribution.set_default_validate_args(False)

# 底本的临时修补（pytorch#138080，PR 未合入）：torch 2.14 的 Categorical.logits/probs 仍是
# lazy_property，其 __get__ 每次读取都 setattr 进实例字典，会让 torch.compile / CUDA 图图裂。
# 底本直接把它换成只读 property；但 Categorical.__init__ 会对 self.logits / self.probs 赋值，
# 只读 property 会抛 “property has no setter”。这里补 setter（写实例字典）并让读取优先实例字典：
# 既去掉 lazy_property 读取时的 setattr，又不破坏构造。将来 torch 去掉 lazy_property（没有 .wrapped）自动跳过。
class _CategoricalParam:
    def __init__(self, wrapped, name: str):
        self.wrapped, self.name = wrapped, name

    def __get__(self, obj, objtype=None):
        if obj is None:
            return self
        if self.name in obj.__dict__:
            return obj.__dict__[self.name]
        return self.wrapped(obj)

    def __set__(self, obj, value):
        obj.__dict__[self.name] = value


for _name in ("logits", "probs"):
    _attr = Categorical.__dict__.get(_name)
    if hasattr(_attr, "wrapped"):
        setattr(Categorical, _name, _CategoricalParam(_attr.wrapped, _name))

torch.set_float32_matmul_precision("high")


class Agent(nn.Module):
    """`amp_device` 非 None 时，模型前向包进该设备的 bf16 autocast，输出转回 fp32（分布、损失都在 fp32 里算）。"""

    def __init__(self, model: nn.Module, amp_device: str | None = None):
        super().__init__()
        self.model = model
        self.amp_device = amp_device

    def _forward(self, feats):
        if self.amp_device is None:
            return self.model(feats)
        with torch.autocast(self.amp_device, dtype=torch.bfloat16):
            logits, value = self.model(feats)
        return logits.float(), value.float()

    def get_value(self, feats):
        return self._forward(feats)[1]

    def get_action_and_value(self, feats, action=None):
        logits, value = self._forward(feats)
        probs = Categorical(logits=logits)
        if action is None:
            action = probs.sample()
        return action, probs.log_prob(action), probs.entropy(), value


def gae(rewards: Tensor, values: Tensor, dones: Tensor, next_value: Tensor, gamma: float, lam: float):
    """dones[t] 是第 t 步动作产生的 done 码；done ≠ 0 时 obs[t+1] 已是新局首帧，故任何 done 都切断优势回传。
    done ∈ {1, 2}：终止，不自举。done == 3：超时截断，缺末帧观测，用 V(obs_t) 近似自举（spec §5）。"""
    nonterminal = (dones == 0).to(rewards.dtype)
    truncated = (dones == 3).to(rewards.dtype)
    lastgaelam = torch.zeros_like(next_value)
    next_v = next_value
    advantages = []
    for t in range(rewards.shape[0] - 1, -1, -1):
        boot = nonterminal[t] * next_v + truncated[t] * values[t]
        delta = rewards[t] + gamma * boot - values[t]
        lastgaelam = delta + gamma * lam * nonterminal[t] * lastgaelam
        advantages.append(lastgaelam)
        next_v = values[t]
    adv = torch.stack(list(reversed(advantages)))
    return adv, adv + values


class PPO:
    def __init__(self, cfg: dict, model_factory: Callable[[], nn.Module], device: torch.device):
        self.p = cfg["ppo"]
        self.device = device
        self.num_steps = int(self.p["num_steps"])
        amp_device = device.type if self.p["amp"] == "bf16" else None
        self.agent = Agent(model_factory(), amp_device).to(device)
        # 底本：推理用一份共享参数数据、但不带梯度的副本。tensordict 0.14 的 to_module 默认
        # preserve_module_state=True，会保留参数原有的 requires_grad=True，于是 rollout 的
        # vals/logprobs 会带上 rollout 图，第二次 minibatch backward 就报「图已释放」；显式关掉。
        self.agent_inference = Agent(model_factory(), amp_device).to(device)
        from_module(self.agent).data.to_module(self.agent_inference)
        self.agent_inference.requires_grad_(False)

        on_cuda = device.type == "cuda"
        self.compile = bool(self.p["compile"]) and on_cuda
        self.cudagraphs = bool(self.p["cudagraphs"]) and on_cuda
        self.rollout_graphs = bool(self.p["rollout_cudagraphs"]) and on_cuda
        self._rollout_fns: RolloutGraphs | None = None
        self.optimizer = optim.Adam(
            self.agent.parameters(), lr=torch.tensor(float(self.p["learning_rate"]), device=device), eps=1e-5,
            capturable=self.cudagraphs and not self.compile,
        )

        policy = self.agent_inference.get_action_and_value
        update = TensorDictModule(
            self._update,
            in_keys=["feats", "actions", "logprobs", "advantages", "returns", "vals"],
            out_keys=["approx_kl", "v_loss", "pg_loss", "entropy_loss", "old_approx_kl", "clipfrac", "gn"],
        )
        if self.compile:
            mode = "reduce-overhead" if not self.cudagraphs else None
            policy = torch.compile(policy, mode=mode)
            update = torch.compile(update, mode=mode)
        if self.cudagraphs:
            policy = CudaGraphModule(policy, warmup=20)
            update = CudaGraphModule(update, warmup=20)
        self.policy, self.update = policy, update
        # GAE 是 num_steps 步的 Python 循环（约 600 个小核）；录成一张图，与 eager 同一批核、结果相同
        self._gae = CudaGraphModule(gae, warmup=2) if self.cudagraphs else gae

    def _update(self, feats, actions, logprobs, advantages, returns, vals):
        p = self.p
        self.optimizer.zero_grad()
        _, newlogprob, entropy, newvalue = self.agent.get_action_and_value(feats, actions)
        logratio = newlogprob - logprobs
        ratio = logratio.exp()

        with torch.no_grad():
            old_approx_kl = (-logratio).mean()
            approx_kl = ((ratio - 1) - logratio).mean()
            clipfrac = ((ratio - 1.0).abs() > p["clip_coef"]).float().mean()

        if p["norm_adv"]:
            advantages = (advantages - advantages.mean()) / (advantages.std() + 1e-8)

        pg_loss1 = -advantages * ratio
        pg_loss2 = -advantages * torch.clamp(ratio, 1 - p["clip_coef"], 1 + p["clip_coef"])
        pg_loss = torch.max(pg_loss1, pg_loss2).mean()

        newvalue = newvalue.view(-1)
        if p["clip_vloss"]:
            v_loss_unclipped = (newvalue - returns) ** 2
            v_clipped = vals + torch.clamp(newvalue - vals, -p["clip_coef"], p["clip_coef"])
            v_loss_clipped = (v_clipped - returns) ** 2
            v_loss = 0.5 * torch.max(v_loss_unclipped, v_loss_clipped).mean()
        else:
            v_loss = 0.5 * ((newvalue - returns) ** 2).mean()

        entropy_loss = entropy.mean()
        loss = pg_loss - p["ent_coef"] * entropy_loss + v_loss * p["vf_coef"]
        loss.backward()
        gn = nn.utils.clip_grad_norm_(self.agent.parameters(), p["max_grad_norm"])
        self.optimizer.step()
        return approx_kl, v_loss.detach(), pg_loss.detach(), entropy_loss.detach(), old_approx_kl, clipfrac, gn

    def _rollout_graphs(self, featurizer, reward_fn, tracker) -> RolloutGraphs:
        # 图按这三个对象录：换了任何一个（如 gpucheck 另建 tracker）就重建，不复用旧图
        fns = self._rollout_fns
        if fns is None or not fns.matches(featurizer, reward_fn, tracker) or fns.graphs != self.rollout_graphs:
            fns = self._rollout_fns = RolloutGraphs(featurizer, reward_fn, tracker, self.rollout_graphs)
        return fns

    def rollout(self, envw, featurizer, reward_fn, tracker, timer, obs):
        n = envw.n
        fns = self._rollout_graphs(featurizer, reward_fn, tracker)
        ts = []
        for _ in range(self.num_steps):
            with maybe_phase(timer, "featurize"):
                feats = TensorDict(fns.featurize(obs, timer), batch_size=[n])
            with maybe_phase(timer, "policy"):
                torch.compiler.cudagraph_mark_step_begin()
                action, logprob, _, value = self.policy(feats)
            next_obs, info = envw.step(action, timer)
            with maybe_phase(timer, "reward"):
                reward = fns.reward(obs, next_obs, info, timer)
            ts.append(TensorDict._new_unsafe(
                feats=feats, vals=value.flatten(), actions=action, logprobs=logprob, rewards=reward,
                dones=info.done, batch_size=(n,),
            ))
            obs = next_obs
        container = torch.stack(ts, 0)
        with maybe_phase(timer, "featurize"):
            next_feats = TensorDict(fns.featurize(obs, timer), batch_size=[n])
        with torch.no_grad():
            next_value = self.agent_inference.get_value(next_feats)
        return obs, container, next_value

    def train_step(self, container, next_value, iteration: int, num_iterations: int, timer=None) -> dict[str, float]:
        p = self.p
        if p["anneal_lr"]:
            frac = 1.0 - (iteration - 1.0) / num_iterations
            self.optimizer.param_groups[0]["lr"].copy_(frac * float(p["learning_rate"]))
        with maybe_phase(timer, "update_gae"):
            adv, ret = self._gae(container["rewards"], container["vals"], container["dones"], next_value,
                                 float(p["gamma"]), float(p["gae_lambda"]))
            container["advantages"] = adv
            container["returns"] = ret
        flat = container.view(-1)
        n = flat.shape[0]
        mb = n // int(p["num_minibatches"])
        outs = []
        for _ in range(int(p["update_epochs"])):
            # 每个 epoch 整表按随机排列 gather 一次，minibatch 取连续切片：与逐 minibatch 按
            # perm[i*mb:(i+1)*mb] 各 gather 一次逐位相同，但每个键只 gather 一次而不是 num_minibatches 次
            with maybe_phase(timer, "update_shuffle"):
                shuffled = flat[torch.randperm(n, device=self.device)]
            with maybe_phase(timer, "update_minibatches"):
                for start in range(0, n, mb):
                    torch.compiler.cudagraph_mark_step_begin()
                    outs.append(self.update(shuffled[start:start + mb], tensordict_out=TensorDict()))
        with maybe_phase(timer, "update_stats"):
            # 全部统计量先在设备上算好、拼成一个张量，只同步一次（原来是十来次 .item()）
            keys = list(outs[0].keys())
            means = [torch.stack([o[k] for o in outs]).float().mean() for k in keys]
            var_y = ret.var()
            ev = torch.where(var_y > 0, 1.0 - (ret - container["vals"]).var() / var_y,
                             torch.full_like(var_y, float("nan")))
            done3 = (container["dones"] == 3).float().mean()
            lr = self.optimizer.param_groups[0]["lr"]
            values = torch.stack([*means, ev.float(), done3, torch.as_tensor(lr, device=ev.device).float()]).tolist()
        stats = dict(zip([*keys, "explained_variance", "done3_frac", "lr"], values))
        return stats

    @torch.no_grad()
    def act(self, feats: Mapping[str, Tensor], greedy: bool) -> Tensor:
        logits, _ = self.agent_inference.model(feats)
        return logits.argmax(-1) if greedy else Categorical(logits=logits).sample()

    def state_dict(self) -> dict:
        return {"agent": self.agent.state_dict(), "optimizer": self.optimizer.state_dict()}

    def load_state_dict(self, sd: dict) -> None:
        self.agent.load_state_dict(sd["agent"])
        # Optimizer.load_state_dict 会深拷贝 param_groups，换掉 lr 张量对象；CUDA 图在捕获时
        # 已引用原张量，train_step 的 lr.copy_() 退火会作用在旧张量上而静默失效。
        # 先留原张量引用，载入后把值搬回来并装回 param_group，保住身份。
        lr_t = self.optimizer.param_groups[0]["lr"]
        self.optimizer.load_state_dict(sd["optimizer"])
        lr_t.copy_(torch.as_tensor(self.optimizer.param_groups[0]["lr"], device=lr_t.device))
        self.optimizer.param_groups[0]["lr"] = lr_t
        from_module(self.agent).data.to_module(self.agent_inference)
        self.agent_inference.requires_grad_(False)
