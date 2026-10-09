# 密度图 CNN 消融与远场 Perceiver 实验计划

日期：2026-10-08。

**目标：** 测量现有策略对密度图 CNN 的依赖、关闭分支后经过训练的能力损失，以及原始远场子弹的可学习摘要是否值得替代 CNN。

**已确认路线：** 同权重关闭 CNN 诊断 → CNN/无 CNN 配对训练 → 8-latent Perceiver。Sparse attention 保留为后续候选，本轮不实现。

**状态与权限：** 用户已认可方向并要求制定实验计划。本文件是待审阅的实验设计与执行任务单，不代表训练预算已批准。本轮只写文档，不修改模型、不提交 Magnus Job、不替换部署、不 commit/push。执行时在 main 工作，保留已有未提交改动。

2026-10-08后续：用户明确要求先执行即时消融。P1已完成CPU3968局与逐局重算，见[结果](../../practice-cards/2026-10-08-density-ablation-results.md)。本次仅实现P1所需的v3分支开关、evaluate可选逐局记录和独立诊断脚本，未扩展eval_ckpt CLI或实施P2/P3；实际CPU栈为torch2.5.1+cpu/tensordict0.6.2/stg_rl0.4.2，来源checkpoint配置已成功读取并核对。后续训练预算仍待确认，无Magnus Job/部署替换/commit/push。

2026-10-08再后续：用户要求准备GPU实验。P2所需严格迁移、构图/缓存省算、u0和最终评测入口、两臂配置、冻结overlay与Job参数已就绪，见[P2准备记录](../../practice-cards/2026-10-08-density-p2-preparation.md)。未上传/提交或执行GPU验证，P3仍未实施。

2026-10-09修订：用户确认P2两臂各2000轮、按2000轮慢退火，u1000/u1500阶段诊断，固定u2000主比较；授权并行启动两个新任务，要求先提交/推送仓库。此次使用推送后的固定commit，仅传初始权重数据，不覆盖源码。以下原1000轮P2预算与固定u1000条款作为历史设计，当前P2以[u2000协议](../../practice-cards/2026-10-09-density-p2-u2000.md)为准；P3预算尚未执行。

**实现指导：** 后续按任务逐项执行；使用 `superpowers:executing-plans`，如另获明确委派授权再使用 `superpowers:subagent-driven-development`。本计划的结构契约见第 3 节，具体文件责任见第 9 节。项目测试约定优先于技能的一律新增测试要求。

## 1. 三个问题与结论边界

1. 当前训练好的策略多大程度依赖密度分支？同权重关分支回答即时依赖，下降包含输入分布突变，不能当成无 CNN 模型的上限。
2. 保留现有策略主体，经过同预算适应训练，无 CNN 是否仍明显退化？短轮配对训练回答替换后的适应能力，不代表从零学习上限。
3. 用原始远场子弹做 Perceiver 摘要是否有更好的能力/成本取舍？此比较同时改变信息表示、覆盖对象和编码器，不能单独归因于 attention 算法。

若需要作出长期架构选择，再以候选与 CNN 从零训练确认。由同一预训练 checkpoint 分出的三个训练 seed 只验证适应过程的稳定性，不是三个独立预训练模型。

## 2. 基线与必须固定的条件

### 基线权重

使用当前最新 B/Shift K8，不把 T7 旧 reward 的结果直接当同期对照：

- 文件：`runs/job-b3ef72c1ca44515d/20261006-151317-request-light-shift-k8/checkpoints/best.pt`。
- 记录的 SHA256：`8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88`。实施前重算并严格匹配。
- 来源：B/Shift 短轮实验 u1000；T7/K8 权重继承后新建优化器训练。
- 新实验继承模型权重，重新创建 optimizer、随机流、课程状态、update、env_steps、best；不用 resume。
- 以 checkpoint 内完整解析配置作为基底，保存冻结副本，不依靠未来可能变化的默认值。

### 固定条件

| 项目 | 本轮设置 |
|---|---|
| 模型主体 | v3，d=64，4头，joint_sa_layers=1，trunk=256，action_query=false |
| 近场输入 | v8，static，dt=false；子弹64、敌人8、激光8；player15、cond4 |
| 动作/决策 | 18动作，frame_skip=1 |
| 运动层 | enabled=true，hold=[2,6]，delay=[0,2]，slow=true |
| Reward | 最新 B/Shift 原配置；request，key_press=-0.001、quick_change=-0.003、shift_toggle=-0.003；其余不变 |
| 卡池/意图/课程 | 最新 B/Shift 配置原样冻结，不加卡、不调课程、不改意图比例 |
| 环境 | stg_rl 0.4.2 / ENGINE_VER24，wheel SHA 冻结并在两边核验；实施时检查实际版本 |
| 训练判定 | hit_extra=[0,2]；评测关闭额外判定半径 |
| PPO采样 | 4096环境 × 64步；8 minibatch、4 epoch；bf16，compile/CUDA图沿用 |
| 短轮训练 | 1000 updates，初始 lr=1e-4，线性退火；每250轮保存与标准评测 |
| 观测表上限 | 预期 bullets_cap=1024；以来源完整配置核验，不在本轮提 cap |

同 seed 配对不保证轨迹相同：动作改变会影响瞄准弹、死亡/reset、课程进度与后续采样。保留同一采样机制，记录每卡采样帧数与课程权重，结论解释为该训练流程下的整体效果。

## 3. 实验臂与结构契约

### A：CNN

原结构：两通道 14×12 密度图 → Conv(2,16,3,pad=1) → ReLU → Conv(16,16,3,stride=2,pad=1) → ReLU → Flatten → Linear(672,64) → ReLU。

密度图使用观测表中的全部有效子弹，含近场和远场，无法包含表外被截断的子弹。保持 density_fp32=true。

### B：无密度分支

在主干拼接位置输出形状 `[batch,64]` 的常量零向量，跳过 CNN 与密度投影；主干仍为704→256→256，actor/critic与其他分支保持相同。零输入图不能替代零输出分支，因为网络偏置可能输出非零值。

同权重诊断保留全部旧参数便于严格载入，只切换分支路径。生产候选是否物理删除闲置参数不在首轮改变；成本报告分别列总参数、参与前向/更新的参数和实际运行耗时。

短轮训练可跳过密度图构建及缓存以兑现省算收益；必须确认与“仍构图但归零输出”的行为一致。模型输入契约可以保留空占位，但不把完整密度图继续存入 PPO buffer。

### C：原始远场 Perceiver 式摘要

保留现有近场64弹+8激光联合注意力；替换全局分支，输出仍为64维。首轮固定：

- 原始子弹5维，与近场相同的归一化：相对位置2、绝对速度2、半径1。
- 远场定义为**有效子弹减去当前近场Top-64的索引集合**，不增加人为碰撞时间、危险评分或距离阈值。这里的“远场”是余集，不保证几何上都很远。
- 使用近场选择实际返回的索引生成余集，不能另做一次 Top-K 后假定并列选择相同。
- 维持来源 bullets_cap 的固定槽位和布尔mask；不做每步动态长度分配，不暗中取第二个Top-K截断远场。
- 逐弹MLP：5→64→64，ReLU；8个可学习64维latent，4头。
- 一轮 latent→子弹交叉注意力，Pre-LN、残差与64→128→64 FFN；之后一层8-latent自注意力。
- latent均值汇总→Linear(64,64)，不在末端添加ReLU；输出进入原density的64维位置。
- 初版latent不引入自机ctx条件，不与近场token额外交流；自机相对坐标已有信息，ctx仍通过主干融合。避免同时增加多条交流路径。
- 全空远场时最终分支输出严格为零；padding输入不影响输出；无dropout、无对象行序位置编码。
- 精度与主体一样使用bf16训练，FP32评测；不预设新的fp32性能开关。

这是小型 Perceiver 式摘要，不实现完整 Perceiver IO，不引入新依赖或稀疏内核。

### 初始化与公平性

- A/B共享模块逐张量复制同一来源；B的分支输出为零。
- C复制所有同名、同shape的非密度共享模块，CNN/密度投影不迁移，新分支按预先固定seed初始化。
- C最后的Linear权重/偏置初始化为零，启动时共享主体的输入与B一致；该Linear可训练，最初由输出层接收梯度，之后梯度传入摘要网络。避免随机非零摘要突然扰动旧主干。
- 为避免新模块消耗随机数改变环境起点，构造/权重迁移后统一重设训练随机流；来源权重、新模块初始化seed、训练seed分别记录。
- 对比C/B：相同的共享起点与零分支起点，区别是有无可学习远场输入；对比C/A：比较实用替换方案，包含新分支学习成本与预训练CNN优势。
- 现有 `--init-from` 严格比较model/featurize配置，不能直接承载这项迁移。新增**实验专用、白名单式**迁移入口，完整记录加载/新增/忽略的键与张量哈希；不放宽普通 `--init-from`，不用无检查的strict=false。

后续若C有收益，再做读取同样密度网格的latent attention或读取全量原始子弹的C-all以解释来源；首轮不增加这些训练臂。

## 4. 分阶段执行与预算

### P0：冻结与预检

- [ ] 冻结代码实际差异、完整配置、卡池文件/划分、checkpoint与wheel SHA，生成manifest；未提交源码可以归档，不强制commit。
- [ ] 确认留出卡没有进入训练starts；冻结批量评测组顺序、每组环境数、设备和版本。
- [ ] 通过第8节检查；准备同一批真实观测供A/B/C成本对比，不能只用全空输入。
- [ ] 在实际GPU上验证 C 的显存、compile、CUDA图和至少20个完整PPO更新；warmup/首次捕获与稳态分开记录。

Perceiver原始特征的下界：4096×64×1024×5×4字节=5 GiB，mask约0.25 GiB；旧密度图约336 MiB。该估算只含一个rollout，不含叠表、shuffle副本、latent/投影激活、optimizer、CUDA图私有池。不能因为attention配对只有8×N就认为总成本很低。

若当前4096环境设置无法运行，先报告实际峰值和瓶颈。不能单独给C减batch或减远场cap后混入原对照。改变缓存精度、microbatch、minibatch数量或采样规模需另提方案；采用后A/B/C统一条件，并重跑受影响对照。

### P1：同权重即时诊断，不训练

两种推理路径：原CNN与分支零输出。使用相同来源权重、同设备、同环境/意图seed、同批量分组，不改源checkpoint。

- 原作13张 × Hard/Lunatic × 32局 × 跟点/自由 × 2路径 = **3328局**。
- 专项5张 × Hard/Lunatic × 32局 × 自由 × 2路径 = **640局**，用于检查组合封锁风险。
- 总计3968局；默认eval seed12345，贪心，无滞回，motor开启。
- 输出总体、普通/激光、高密度子集、逐卡逐rank的差值，以及同一局配对的“原模型活/关闭后死”与逆向计数。
- 有明显退化才挑少量真实失败轨迹核查；不预先搭建大型分叉仿真平台。

P1无论退化大或小，都不单独决定是否删除CNN。

### P2：A/B单seed短轮筛查

同来源权重，新optimizer，训练seed1，各1000轮；每臂262,144,000新增帧。

u0先评测，u250/500/750/1000保存并运行标准跟点评测；u1000做第5节最终评测。u1000主比较，四点评测曲线辅助，best仅附录。

目的：验证B能否适应、实际省算有多少，并发现训练/配置问题；单seed结果不作最终架构判断。正常完成后即使B退化，也仍允许P3测试C，因为“远场信息有用”正是引入C的理由。

### P3：三臂三seed适应实验

A/B/C各train seed1、2、3，各1000轮，同初始化规则。上限**9条短轮训练**，总2,359,296,000新增帧。

P2两条可计入这9条，仅限完整manifest一致，后续增加C没有改变A/B行为、训练路径或资源协议；否则保留为先导结果，重新跑三臂。

C先做一次20-update性能预检；通过才提交1000轮。各臂用同训练帧预算，不以同墙钟代替。若C明显更慢，仍报告同帧能力与实际GPU小时，不能只报学习曲线。

P2/P3之间不根据评测结果调latent数、层数、reward、LR或挑seed。需要调参则新立实验，不覆盖这次记录。

### P4：条件性从零训练确认

仅当P3出现值得保留的候选，再单独申请预算：CNN与选出的一个候选，各seed1/2/3，从零3500轮，共6条、5,505,024,000帧。

共享模块在同seed下采用同一初始化张量，不依赖模块构造顺序。使用相同最新B/Shift reward、卡池、运动层与PPO；起始LR统一3e-4，3500轮线性退火。只比较这组同期结果，不拿历史T7当对照。

如果P3的两个替代方案都值得保留，先选主要目标下更合适的一项；不自动把确认阶段扩成三臂。

### 预算依据

| 阶段 | 训练资源预算参考 | 使用限制 |
|---|---|---|
| P1 | 无训练；评测CPU/GPU时间先测一小批再估 | 不沿用训练SPS估评测时间 |
| P2 | 两条1000轮，历史合计约2.6 GPU小时 | 含历史常规评测，不含本轮新增最终评测/排队 |
| P3 | 含P2最多9条，按旧CNN速度约11.5 GPU小时下界 | C可能显著更慢，预检后给实际预算 |
| P4 | 六条3500轮，旧T7速度参考约26.3 GPU小时 | 新reward与C成本未经测量，仅规划参考 |

历史依据：2026-10-06 A/B各76分40/41秒；T7约4.39小时/3500轮。这些不是本轮完成时间承诺，不包含排队、新增评测、归档及失败重试，不虚构当前价格。每阶段单独批准资源，不自动执行P4。

Magnus显式B2，提交前查 `magnus cluster`；CPU线程按当前实际配额/余量分配。默认最多两条并行，每条1 GPU；不能预设历史空闲资源仍在。每条先GPUCHECK，启动几分钟检查真实Python进程、日志与更新推进，监控同时处理正常完成和提前退出。

## 5. 评测协议

### 主评测与分组

- 原作：冻结 `eval/splits-laser.toml`，13卡×2rank。Hard=rank2，Lunatic=rank3。
- 专项：冻结 `eval/splits-laser-specialist.toml`；主表只用rank2/3，rank0/1作为辅助，不与原作混算。
- 主意图：自由躲弹 `follow_player_v1`，符合当前AUTO默认用途；标准跟点 `lower_half_uniform_v1` 同时报告，维持历史可比口径。
- 正式主评测motor开启；motor_off只在最终候选上诊断，不用它代替部署条件得分。
- 贪心argmax，hysteresis=0，FP32；统一设备/批量分组，不能混合CPU和GPU结果。

高密度子集在看结果前固定为以下4张原作留出卡的rank2/3：

`th06_s2_b6`、`th06_s3_w12`、`th06_s3_mb3`、`th06_s4_w16`。

来源是当前 `cards/density.json` 的历史弹量画像，冻结其SHA；不会根据哪个模型掉分再换子集。额外报告 `th06_s3_w02` 高速弹卡及 `th06_s4_b12` 水符逐卡数据；不把它们悄悄加入主高密度指标。

### 最终评测规模

P2/P3的u1000统一使用eval seed12345、23456、34567，每组32局，保持每个seed的环境批量一致；无需把episodes改成96导致批量/浮点路径变化。

每份权重：

- 原作跟点+自由：13×2×32×3×2=4992局。
- 专项自由：5×2×32×3=960局。
- 总计5952局；P3九份权重共53,568局，另有训练中标准评测。评测成本须计入提交预算。

这些评测seed提供更多环境样本，不等于更多训练seed。现有卡集已被多次研究使用，称为固定验证/留出集，不宣称它是全新未触碰的泛化测试集。

### 记录与统计

- 保存逐局记录及 `card/rank/eval_seed/env/intent/motor/train_seed/arm/update`，复用evaluate的真实episode记录；当前CLI只有汇总且无eval seed参数，需要补可选输出/覆盖，默认行为不变。
- 主指标：自由全原作撑过率、自由高密度子集撑过率；按card/rank等权，再对3个训练seed等权。相同样本数下应与episode总体一致，核对两种聚合。
- 辅助指标：普通/激光、rank2/rank3、专项家族、平均存活帧、跟点in_r_frac、Shift与方向变化/s、低速占比；不把reward改善替代生存改善。
- 配对差值以同card/rank/eval_seed/env为单位；先输出每个训练seed的差值、均值和范围。可在每个训练seed内按card/rank分层做配对bootstrap，说明其只反映评测抽样不确定性；3个训练seed不适合声称精确总体显著性。
- 主判断使用固定u1000。u250/500/750/1000的曲线与末段平均用于解释是否尚在学习，不能当四个独立训练重复。best只按原标准选择并附报，不拿各臂最好的checkpoint替代主比较。

## 6. 预先约定的判断门槛

以下是工程决策阈值，以百分点pp计，不是统计显著性的替代品。

### B：可以考虑删除CNN

- 自由原作均值相对A下降不超过2pp，高密度子集下降不超过3pp；配对评测区间仍很宽时标记“证据不足”，不能用点估计宣布等效。
- 三个训练seed没有出现共同的大幅退化；检查跟点、激光和水符，若同一card/rank在至少2/3 seed下降超过10pp，作为场景风险单列，不靠总体掩盖。
- 实际部署batch=1推理或端到端训练至少一项节省达到10%，且其余成本如实列出；若省算不足，解释为“结构可简化候选”，不声称性能优化成功。

### C：值得进入从零确认

- 自由高密度均值比A提高至少3pp，3个训练seed至少2个同方向；自由全原作不下降超过2pp，并检查上述逐卡场景风险。
- 或能力与A接近但真实推理/训练成本更优，达到B同样的省算门槛。
- 若C明显胜B却未胜A，结论为“远场摘要恢复部分信息，暂不替换CNN”，不宣布Perceiver优于CNN。
- 首轮资源容忍：固定帧数训练耗时不超过A的1.5倍、显存留足实测安全余量；batch=1推理不超过A的1.25倍。越界时先报告能力/成本结果，是否接受更高成本由用户选择。
- 若u1000仍明显上升而尚未恢复，结论为“短轮适应不足以判断”，不把增加训练时长混入首轮数据。

即时消融掉分、单seed小幅改善、某个best很高、或理论复杂度更低，都不足以触发自动部署替换。

## 7. 性能与部署边界

同GPU、同真实观测批次、同精度与compile模式测A/B/C，warmup后同步计时，至少5次重复，记录中位数和范围：

- 部署场景：FP32 batch1模型推理，以及含特征化的端到端延迟；分开报告。
- 训练场景：bf16 batch4096 rollout推理、当前minibatch32768的更新、完整PPO update、总训练墙钟、峰值allocated/reserved显存。
- 观测按有效弹数0、1–64、65–256、257–1024分桶，记录真实分布和远场mask有效量；若固定槽位计算，不能用有效弹少宣称运算量自动下降。
- 记录 `bullets_dropped`，表外截断会同时影响CNN和C；不能把C看到1024槽位称作看到了引擎中的全部子弹。

C应仅用现有PyTorch算子，保留未来ONNX可导出性。首轮进行小规模导出/ORT数值预检；不默认保持graph6兼容。原始全量弹表本已在导出图输入中，但输入shape、mask/余集构造与调用方契约仍须核查。若需改签名，后续按项目要求共同升级训练侧/部署侧GRAPH_VERSION。

本轮不改renkolab/mod、不打试玩包、不改变TH06NC八帧激光平滑、不把离线结果当作Windows实机验收。

## 8. 必要验证与失败处理

- B：开启路径复现原logits/value；关闭路径改变density输入不改变输出；同权重加载严格；agent/agent_inference使用一致分支。
- C特征：真实生产Top-64索引生成余集；有效弹≤64则全空；超过64无交叠/无遗漏；padding变化不影响输出。复用现有featurize夹具，不用源码字符串断言。
- C模型：空远场零输出；已选对象排列不影响结果；零输出初始化与B的logits/value一致；真实PPO loss可让输出层更新，随后梯度能进入latent与输入MLP。
- 初始化：加载共享张量逐项一致；未加载键只在白名单；形状/配置不兼容明确失败；不破坏现有resume/init-from。
- 评测：逐局ID可追溯、只取首局、原汇总与逐局重算一致；eval seed覆盖不改变默认结果；专项不会泄漏训练。
- 本地及torch2.5.1+cpu/tensordict0.6.2旧CPU栈跑相关已有检查；GPU严格fp32 eager/compile/CUDA图对拍与真实bf16训练预检分别报告。

复用 `tests/test_model_v3.py`、`tests/test_featurize_v8.py`、`tests/test_checkpoint.py`、`tests/test_smoke.py`、`tests/test_ppo.py`、`tests/test_export_v8.py`；新增测试只填上述关键新行为的缺口，按所属层放置，不机械跨层复制。纯计划阶段不跑训练或这些产品测试。

无NaN/全空错误、GPUcheck失败、显存溢出、逐局数据缺失或训练提前退出时，保存失败产物并停止该阶段；不删有效断言、不放宽数值阈值、不静默调参数重跑。修复后重新核验受影响的臂，所有重试保留编号与原因。

## 9. 实施任务与文件责任

本节是执行顺序，文件名是计划中的新增位置，尚未创建产品代码。

### 任务1：冻结协议与可追溯评测

- [ ] `scripts/diag/density_ablation.py`：实验manifest、同权重A/B评测，输出逐局配对记录与汇总；调用生产build_components/evaluate，避免复制环境逻辑。
- [ ] `src/stgtrain/evaluate.py`：可选逐局输出，原返回结构默认不变。
- [ ] `src/stgtrain/eval_ckpt.py`：增加可选eval seed与逐局记录开关；不混入训练配置永久修改。
- [ ] `src/stgtrain/models/set_attn_v3.py`：可选density分支开关，默认路径不变，B返回64维零向量。
- [ ] 冻结manifest至 `runs/density-ablation-20261008/`；检查来源SHA、配置、卡池和划分。P1结果写入同目录。

验收：原路径复现、关分支输入独立、3968局记录齐全、宏/微聚合与配对计数重算一致。

### 任务2：A/B训练与受控权重迁移

- [ ] `src/stgtrain/train.py` + `src/stgtrain/checkpoint.py`：实验专用严格迁移入口及来源manifest；原init-from/resume语义保持。
- [ ] `src/stgtrain/featurize/danger_topk_v8.py`：B跳过density构图/缓存的可选路径；近场各张量逐项不变。
- [ ] `configs/exp-density-cnn.toml`、`configs/exp-density-none.toml`：冻结来源配置生成A/B差异；默认1000轮seed1，seed2/3使用明确覆盖并落盘。
- [ ] `magnus/train-specialist.sh`：复用现有runner，显式 `SPECIALIST_UPDATES="500 1000"`；不能请求不存在的u2750..3500。最终逐局评测单独运行，避免把best探针当主比较。
- [ ] 相关本地/旧栈检查、GPUcheck通过后，获预算授权才提交P2。

验收：u0共享权重核验、新训练状态、1000连续更新、每臂262144000新增帧、u1000最终评测与成本产物齐全。

### 任务3：C结构与资源预检

- [ ] `src/stgtrain/featurize/danger_topk_v9.py`：原v8近场输出加固定槽位远场原始token/mask，复用同一次Top-K索引；不改变旧v8默认行为。
- [ ] `src/stgtrain/models/far_perceiver.py`：第3节8-latent摘要模块，独立于PPO/环境。
- [ ] `src/stgtrain/models/set_attn_v4.py`：复用v3主体，替换density分支；`src/stgtrain/models/__init__.py` 注册，特征化注册入口按现有项目模式。
- [ ] `configs/exp-density-perceiver.toml`：C唯一结构差异与原配置其余项冻结。
- [ ] `scripts/diag/benchmark_density_branches.py`：生产模型/真实观测的统一性能比较；明确采样、同步、warmup、显存口径。
- [ ] `src/stgtrain/export_onnx.py`：新增注册名对应的实验导出预检，先核查输入契约再决定GRAPH_VERSION；不覆盖旧模型产物。
- [ ] 本地/旧CPU栈检查后运行实际GPU20-update预检，给出三臂显存/吞吐预算；过资源门才执行P3其余训练。

验收：余集正确、全空安全、初始化与B输出一致、网络可学习、旧版本运行与GPUcheck通过、资源预算可执行。

### 任务4：三seed汇总与决策

- [ ] 执行P3，核对P2数据能否复用；并行上限和CPU配额遵守第4节。
- [ ] `scripts/diag/summarize_density_ablation.py`：固定u1000逐seed比较、学习曲线、逐卡风险、配对评测不确定性、性能/成本表；不挑最佳seed。
- [ ] 结果文档：`docs/practice-cards/2026-10-08-density-ablation-results.md`，链接manifest、逐局数据与原始日志；日期按实际完成日调整。
- [ ] 给出保留CNN、删除候选、Perceiver候选或证据不足的结论；若值得P4，单独提交预算请求。

## 10. 交付与后续

每阶段交付可复查的配置/来源、完整checkpoint、逐局评测、性能日志和失败/未验证项。最终至少有三张表：即时依赖、适应后三seed能力、能力与实际资源成本。

本次计划编写验证：`git diff --check`通过，本文件与记忆索引的本地链接存在，基线checkpoint SHA重算匹配，P1/P3/P4局数与帧数公式核对通过。尝试只读解析checkpoint配置时，本地torch在CUDA库预加载阶段长时间未返回，已中止；未因此修改环境或依赖。第2节设置根据源码、配置和既有结果记录制定，实施前仍须读取checkpoint内完整配置核对。未运行产品测试、模型评测、性能预检或训练。

首轮不实现Sparse attention。仅当原始远场信息确实有收益而Perceiver吞吐/摘要能力不理想时，再设计空间分块+全局通路对照；不默认引入FlexAttention/Triton，也不把普通mask称为省算实现。

### 依据

- [最新B/Shift配置](../../../configs/exp-request-light-shift-k8.toml)
- [短轮A/B设计与来源](../../practice-cards/2026-10-06-request-shift-short-ab.md)
- [短轮A/B结果与实际用时](../../practice-cards/2026-10-06-request-shift-short-ab-results.md)
- [最新试玩权重来源](../../practice-cards/2026-10-06-b-shift-th06nc-package.md)
- [激光阶段性能与后续候选](../../practice-cards/2026-10-02-laser-stage-summary.md)
- [旧torch栈要求](../../agent-memory/magnus-old-torch-stack.md)
- [模型主体](../../../src/stgtrain/models/set_attn_v3.py)
- [生产评测](../../../src/stgtrain/evaluate.py)
- [Perceiver原论文](https://arxiv.org/abs/2103.03206)：少量latent通过交叉注意力读取大量输入。
- [PyTorch FlexAttention说明](https://pytorch.org/blog/flexattention/)：真正利用稀疏性需考虑块稀疏执行。
