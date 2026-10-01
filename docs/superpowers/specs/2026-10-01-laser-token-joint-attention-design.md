# 下一版模型：14维激光 token 与弹／激光联合自注意力

日期：2026-10-01。

状态：用户已确认本文，并要求立即实现。2026-10-01已完成训练仓v8/v3与图版本6的ONNX适配；本地CPU、bf16 CPU更新、ONNX对拍及旧版本CPU栈检查通过。游戏部署调用方、实际GPU验证和正式训练尚未执行；未提交或推送。

## 目标与范围

让模型直接读取自机相对激光的横向位置、有限线段范围、附近观测运动、短棒伸长阶段和预警时序；在池化之前同时建模弹与激光的组合威胁。

新增 `danger_topk_v8` 和 `set_attn_v3`，保留 v7/v2 及旧 checkpoint 的运行路径。沿用 PPO、卡池、reward、意图、课程、运动层、动作表、敌人编码器和子弹密度图；不加入动作危险度、碰撞时间或未来轨迹标签。

本轮准备模型与相关验证，不申请 Magnus Job。实现完成不等于证明激光避让收益；收益需要后续对照训练。

## 现状依据

- [现有激光特征化器](../../../src/stgtrain/featurize/danger_topk_v7.py)：13维；按当前判定盒距离选16条；预警倒计时封顶120帧。
- [现有模型](../../../src/stgtrain/models/set_attn_v2.py)：弹与激光分别编码和池化后融合。T5只有弹分支的一层自注意力。
- [共享集合模块](../../../src/stgtrain/models/set_attn_v1.py)：逐条 MLP、Pre-LN 自注意力、mean/max/ctx注意力池化。
- [原始输入解码](../../../src/stgtrain/envwrap.py)：激光12列，遗漏缓冲已提供的 `start_len`。
- 引擎 `crates/stg-rl/src/encode.rs` 输出 `start_len`；名为 `omega` 的观测字段来自 `dang`，是上一帧到当前帧的总转角，包含脚本改角度，不等于未来持续旋转速率。
- 引擎 `crates/stg-core/src/world/integrate.rs`：`end += speed`，超过 `start_len` 后近端跟进。不可假定近端一直以 `speed` 前移。
- [T5配置](../../../configs/exp-t5-laser-specialist.toml)与[结果边界](../../practice-cards/2026-10-01-t5-results.md)。

## 14维激光 token 契约

所有公式先使用未归一化的像素、弧度和每帧位移。屏幕坐标 y 向下；方向沿原始射线保留，不把反向等价线段折叠。

令自机为 P、原点为 O、当前方向为 `e=(cosθ,sinθ)`，法向为 `n=(-sinθ,cosθ)`：

```text
u = dot(P - O, e)
d = dot(O - P, n)
a = start - u
b = end - u
c = clamp(0, a, b)
s_near = u + c
Q - P = c*e + d*n
```

Q 是当前有限中心线段的最近点；不以判定盒表面最近点代替它。`d` 有符号，`a/b` 也保留符号。

观测原点位移为 `ΔO=(vx,vy)`，总转角为 `δ=omega`。在当前最近点的固定射线坐标 `s_near` 上，定义观测位移：

```text
previous_direction = R(-δ) * e
ΔQ = ΔO + s_near * (e - previous_direction)
motion_t = dot(ΔQ, e)
motion_n = dot(ΔQ, n)
growth_remaining = start_len - (end - start)
```

此处不是逐帧重新求最近点后的差分，不混入自机运动或投影点沿线滑动；也不包括端点伸长。若该射线坐标上一帧不在线段范围内，ΔQ仍是支撑射线上固定坐标的运动描述，不宣称有一个实际物质点始终存在。有限旋转公式适用于观测到的大角度改写，无需用 `δ*s_near` 作小角度近似。

| 列 | 字段 | 归一化 | 含义 |
|---:|---|---|---|
| 0 | d | /192 | 自机到中心线的有符号横向位移 |
| 1 | a | /192 | 近端相对自机投影的轴向位置 |
| 2 | b | /192 | 远端相对自机投影的轴向位置 |
| 3 | cosθ | 不变 | 屏幕方向 x 分量 |
| 4 | sinθ | 不变 | 屏幕方向 y 分量 |
| 5 | half_width | /8 | 引擎实际判定半宽 |
| 6 | motion_t | /8 | 最近射线位置的轴向观测位移 |
| 7 | motion_n | /8 | 最近射线位置的法向观测位移 |
| 8 | delta_angle | ×60 | 本帧总转角，非未来角速度承诺 |
| 9 | s_near | /192 | 最近点距原点的轴向位置／旋转力臂 |
| 10 | speed | /8 | 远端推进速率 |
| 11 | growth_remaining | /192 | 距设定棒长的余量，保留负值 |
| 12 | is_warning | 0或1 | state==0 |
| 13 | time_to_active | log1p(max(t,0)/60) | 生效倒计时，不封顶120帧 |

不重复存最近点 dx/dy、距离、方位、两端世界坐标或总长度。几何与运动量不硬截断。预警沿用实际判定宽度，不使用显示时的细线宽度。生效态时序为0；收缩态不进入候选。

### 信息可恢复性与边界

除浮点舍入外，归一化前可恢复旧原始观测及 `start_len`：

```text
u = s_near - c
O - P = -u*e + d*n
start = a + u
end = b + u
start_len = growth_remaining + (b-a)
ΔO = motion_t*e + motion_n*n - s_near*(e - R(-δ)*e)
t_active = 60*expm1(time_to_active)
```

没有丢弃旋转基点。几何朝向使用cos/sin，避免0/2π接缝。零长度线段也按相同公式处理。

只恢复当前公开观测，不声称完整还原引擎隐藏状态：生效剩余寿命、未来脚本改角度、敌人之后的运动等仍不可见。`delta_angle` 和原点位移是历史观察，未来外推需由模型学习。

镜像在上游完成。镜像后 d、motion_n、delta_angle取反，cosθ取反；a、b、sinθ、motion_t、s_near、speed、growth_remaining、宽度和时序不变。

### 候选选择

v8沿用v7：非收缩态候选，按当前判定盒距离取最近K条，默认K=16。只替换token，不同时更换威胁排序或扩大K。

已知等距离且候选超过K时入选集合可能依赖行序，仍是明确的边界。本轮不承诺这种截断下的原始表排列不变性；模型在已选token集合上的排列不变性必须成立。并列规则修复单独处理，避免混入结构实验。

## 原始观测接口

推荐保留现有 `LASER_COLS` 的12列和顺序，为 `RawObs` 追加独立可选字段 `laser_start_len: Tensor | None`，形状 `[N,L]`。解码时从同一个激光字节表按同一行读取，使用同一count掩码、窄解码档位、设备和清零规则；镜像不改变长度。

- v7不依赖新字段，旧夹具、分析代码和旧ONNX输入保持有效。
- v8要求该字段存在且与激光表同形状，不用 `end-start` 冒充缺失的设定棒长。
- 在rollout CUDA图调用之前完成字节解码；v8只处理设备上的固定形状张量。
- 当前wheel已经提供该原始字段；实施时核验offset，缺失则明确报错，本设计不要求引擎机制或wheel升版。

## 模型 `set_attn_v3`

推荐替换T5现有的弹专用自注意力，而不是在其后再叠一层。两种输入各自投影，使用一层共享注意力，交流后分别池化：

```text
bullets[F_b] -> bullet MLP[F_b -> 64 -> 64] + bullet type embedding
lasers[14]  -> laser MLP [14  -> 64 -> 64] + laser type embedding
                         ↓ 拼接token与mask
              joint Pre-LN self-attention，1层，4头
                         ↓ 按原集合边界拆分
                  bullet pool      laser pool
                    192维             192维
                         ↓
与enemy pool(192)、density(64)、ctx(64)合并为704维
                         ↓
                主干704 -> 256 -> 256
                         ↓
              actor:18动作；critic:1价值
```

候选方案比较：保留弹专用层再加联合层会增加关系层深度和算力混杂；交流后把两类合成单一池化会改变主干输入和类型权重。推荐上述“替换一层、交流后分池化”，保留现有容量，直接检验联合关系建模。

具体契约：

- 子弹与激光不共享输入MLP；二者原始字段语义不同。类型嵌入是两个可学习64维向量，只存在于模型内部，不增加token输入长度。
- 联合层使用现有 `SelfAttnBlock` 的Pre-LN、残差、FFN、SDPA和有限mask；默认无dropout、无行序位置编码。
- type embedding相加后以及每个联合block之后，对padding行清零。padding不能成为有效key/value；两类全空也不出NaN。
- 交流后按子弹／激光原集合拆分，复用各自mean/max/ctx注意力池化。不存在某类型时，该类型池化严格为0。
- ctx仍只来自player/cond，enemy和density分支不改。
- v3明确使用 `joint_sa_layers`；`sa_layers=0`、`laser_sa_layers=0`。若设置旧分支层数非0则报错，避免意外叠层。允许 `joint_sa_layers=0` 做关闭联合交流的检查／对照。
- 主配置 `action_query=false`；保留现有可选动作query接口时，它读取交流后的token，不能读取旧的池化前旁路。本轮不把开启动作query作为第三项实验改动。
- 模型可按spec接受v7/v8的激光输入，用于结构对照；14维的语义由v8契约定义，不让模型猜测列含义。
- 新checkpoint使用新registry名；不以 `strict=False` 静默把旧模型权重灌入新版。正式对照从随机初始化开始。

按64弹+16激光估算，共享层注意力配对数由64²变80²，即约1.56倍；这不是全训练墙钟比。使用同一层实现并替换旧层时，参数增量主要是激光输入多一列的64个权重与两个64维type embedding，共192个；实际值实施后核验。

## ONNX与部署契约

推荐保持图版本2–5的旧输入定义不变，为v8增加图版本6：在原v7输入末尾追加 `laser_start_len: float32[L]`，与 `lasers`／`lasers_mask`严格同一行序。

- v8训练与export使用同一套激光公式；子弹路径使用现有v6导出孪生选择逻辑。
- manifest记录图版本6、新输入形状、特征化器名和模型名。导出器、例子输入、checkpoint构建与自动torch/ORT对拍必须一起支持。
- 不把全局旧版常量直接加1而导致所有旧图版本重编号。
- 部署调用方必须显式识别版本6、填入实际 `start_len`，缺字段时拒绝加载，不能用当前长度代替。对应DLL／Godot仓库变更须先读取其AGENTS/CLAUDE，并与训练侧签名同批完成。
- 如果本轮实现权限只覆盖训练仓，允许准备并验证ONNX产物，但版本6不得宣称已经可上线；必须报告部署侧仍未完成。是否扩大到部署仓由用户确认。

## 候选实验配置

准备 `configs/exp-t6-laser-joint.toml`，从T5复制训练参数，仅按下述差异更新模型／特征化器。删除旧 `laser_local` 开关；v8固定14维。

```toml
[featurize]
name = "danger_topk_v8"
frame = "static"
dt = false
k_lasers = 16

[model]
name = "set_attn_v3"
d = 64
heads = 4
trunk = 256
sa_layers = 0
laser_sa_layers = 0
joint_sa_layers = 1
action_query = false
density_fp32 = true
```

主配置是“新token+联合注意力”的组合，不把结果归因到单一因素。组件接口保留v8+v2（token对照）和v7+v3（注意力对照）的构建能力；是否训练四臂、用多少seed和预算，属于后续实验决策，本轮不自动启动。

## 验证与完成标准

按项目要求使用真实生产逻辑，补新增行为的缺口；复用现有夹具，不为每一层复制全部场景。

1. 原始解码：实际引擎buffer的 `start_len`逐值对齐，缺行清零，镜像后长度不变；旧12列不改变。
2. v8几何／运动：独立几何例子覆盖线段内投影与端点最近、有限大角度改写、短棒相同当前长度但不同设定棒长；验证可恢复原始几何及位移，不只断言向量长度。
3. v3行为：空弹／空激光／两类全空均有限；padding不影响输出；两类各自的已选token排列不改变logits/value；有实际弹和激光的输入下，联合层确实使一种token的表示依赖另一种；训练损失能到达两路编码器和联合层参数。
4. 导出：同一个真实观测的训练前向、DeployWrapper与ORT logits对拍，覆盖非零 `start_len`与非零转角；新版checkpoint加载和manifest签名匹配；旧v7导出用例仍通过。
5. 运行相关已有测试，包括envwrap、v7/v2、export、registry/smoke及新版本测试；只在有新改动或失败时扩大检查。
6. 在Magnus旧版本CPU栈（torch2.5.1/tensordict0.6.2）运行对应检查与一次小型CPU PPO冒烟，验证输入通过训练／评测／checkpoint／export，不将冒烟表现解释为学习收益。
7. CUDA图、bf16 GPU执行和吞吐必须由实际GPU验证；没有GPU时列为未验证，不因此擅自提交Job。

完成报告区分“代码／CPU／ONNX可用”“部署调用方已适配”“GPU已验证”和“训练收益已验证”。本轮没有commit/push/训练授权。

## 预期涉及的文件

- 新增：`src/stgtrain/featurize/danger_topk_v8.py`、`src/stgtrain/models/set_attn_v3.py`、候选T6配置及对应精简测试。
- 局部修改：`envwrap.py`、`registry.py`、`export_onnx.py`、现有解码／导出测试辅助和README接口说明。
- 尽量复用v1编码器和v6导出逻辑，不重构PPO或旧模型；若需要修正可复用模块，保持旧版本语义并跑对应现有检查。
- 当前已有未跟踪文件 `:memory:.ses` 与本设计无关，不删除或提交。

## 实施与验证记录（2026-10-01）

用户已确认替换弹专用层、交流后分别池化和图版本6追加输入；随后明确要求立即写新版和适配代码。实现与本设计一致。bf16下类型嵌入按激活dtype相加，避免联合序列被提升为fp32。

实测T5模型383,251参数，新版383,443参数，增加192。T6配置可从现有registry构建，激光spec为(16,14)。只读独立审查未发现实质性缺陷。

实际命令与结果：

- `uv run --frozen pytest -q tests/test_featurize_v8.py tests/test_model_v3.py tests/test_envwrap_lasers.py tests/test_featurize_v7.py tests/test_model_v2.py`：首轮52 passed。
- `uv run --frozen pytest -q tests/test_export_v8.py tests/test_export_v7.py tests/test_export_v6.py tests/test_smoke.py`：39 passed，含新版真实CPU rollout、PPO更新、评测、checkpoint及部署包装。
- `uv run --frozen pytest -q tests/test_envwrap.py tests/test_registry.py tests/test_export_onnx.py tests/test_amp.py tests/test_checkpoint.py tests/test_ppo.py`：68 passed；4项现有无CUDA／PyTree提示，CPU不能证明CUDA捕获可用。
- bf16嵌入修正后：`uv run --frozen pytest -q tests/test_model_v3.py tests/test_smoke.py -k 'v3 or v8'`：13 passed、11 deselected，包含bf16 CPU反向与新版bf16 CPU PPO冒烟。
- 修正后ONNX复核：`uv run --frozen pytest -q tests/test_export_v8.py`：2 passed，训练／包装／ORT logits和argmax一致。
- Magnus旧CPU栈解释器：`/tmp/sunyunbo/claude-1007/-data-sunyunbo-www-stg-rl-train/eeac6ecc-4642-439c-b86b-9a7d4042fb56/scratchpad/v062/bin/python`，实查torch2.5.1+cpu、tensordict0.6.2、stg_rl0.4.0。以`PYTHONPATH=src`运行`-m pytest -q tests/test_featurize_v8.py tests/test_model_v3.py tests/test_envwrap_lasers.py tests/test_smoke.py -k 'v8 or v3 or lasers'`：首轮26 passed、11 deselected；bf16修正后运行`-m pytest -q tests/test_model_v3.py tests/test_smoke.py -k 'v3 or v8'`：13 passed、11 deselected。
- `git diff --check`通过。

这些分组与复核有重复，不相加成总测试数。旧CPU venv未安装ONNX/ORT，旧栈仅验证模型／训练／包装构建；真实ONNX导出对拍来自本地锁定环境。全仓非相关检查未运行。

剩余边界：部署调用方尚未适配版本6；CUDA图、实际GPU bf16和吞吐未验证；未启动正式训练，未证明收益。候选入口为`configs/exp-t6-laser-joint.toml`，不应把候选配置当作开跑授权。
