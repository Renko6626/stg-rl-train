# 2026-09-27 激光变异试产复盘与批量化展望

本轮范围是10张已有训练底子上的合成激光变异，不是训练效果实验。10张已经通过机械验收；独立审查及当前哈希的最终状态以[验收汇总](reports/acceptance-summary.json)为准。机械与规格合格不等于已证明可躲或训练收益。没有启动训练、提交Magnus、修改并发配置、提交或推送。

## 产物与证据

- [清单与复跑入口](README.md)：2张固定pilot、8张有真实几何随机化的变异，覆盖静止预警、沿射线飞行短棒、omega斜扫、origin平移通道、原点瞄准、水平线下移、旋转短段、V射线和随机棒列。
- [机器报告](reports/)记录各声明rank × seeds1/7，共70次完整harness运行，以及规格关键帧、首末出生帧、段末回收和实际文件SHA。原Extra源卡的rank4是既有特殊值；常规映射仍为0=Easy、1=Normal、2=Hard、3=Lunatic。
- [原作清单](reports/original-manifest.json)保存166张原卡的文件哈希。原cards/未变，旧激光划分下rank2的153个训练起点保持；合成卡单独cards-synthetic/，只有显式配置才合并。
- [编写契约](laser-pilot-contract.md)、[工具独立审查](reports/tool-review.md)、[pilot审查](reports/pilot-review.md)、[后续卡审查](reports/batch-review.md)、[交叉审查](reports/tail-review.md)分别保留作者规范、机器门与另一Luna的判断。

来源管理采用source='th06'兼容加载为data_kind='original'，合成卡显式source='synthetic'/data_kind='synthetic'；未知来源保持unknown。base_card和provenance记录底子、原source_ref和逐ECL文件哈希。新run env.json.cards保存card_id→data_kind/source/base_card/mutation_id映射，starts保留旧格式。标签用于分析，不进入策略观测。

## 本轮确认的机制与数据边界

原main仅加一行带标记的根伴生任务入口，新增逻辑集中overlay.ecl；删标记行必须逐字恢复底子。采用根任务直接调用激光API，避免额外敌人进入敌人token或改变boss_or_free等意图目标。没有增加人为几何答案或reward罚款。随机overlay消费共享世界RNG：底子发弹代码不变，但其后续随机序列可能改变，不能声称同seed的原弹逐帧完全一致。

底子排除所有eval/splits-laser.toml留出及同源source_ref区间，交集包括共享helper和端点。最初考虑的s3_b2因共享原作helper区间276–288被保守换成s3_b1。只加强新增合成卡的血缘筛选，不重写原作历史训练划分。

stg_rl 0.4.0已经从实际dang/dx/dy导出脚本rotate/origin和挂靠运动；无须为旧设计稿的“脚本运动缺失”前提升级引擎。harness激光表的omega是配置BAM/帧，RL观测omega是实际角差的弧度/帧；不能从前者为0推断后者没运动。width是完整判定宽度，半宽width/2；lz_speed先令end=start，再推进射线段，近端达到棒长后也会移动。

## 写、验、独立审、返工的实际收益

先用两张固定pilot走通编译、真实运行、机械报告、另一Luna审查和哈希绑定，再扩随机/运动组合，避免把共同接口误解复制到全部卡。作者A写前8张，作者B独立审；后期B写最后2张，A独立审，任何卡的作者与审查者均不同。Sol负责工具/集成，Astra负责判断与交付。

本轮实际捕获并修复了：同一sub内for变量重复声明；将90帧active的状态时间套在120帧active的卡上；忘记短棒随rank速度推进start；TASK颜色和脚本不一致；把次轮出生423误写424；把到中心线的70px距离称为判定区净空（最高width12时实际64px）。编译门、规格关键帧和独立审查各抓到不同问题，不能互相替代。

还有一次协调者误报：把angle cast的位穿透规则误套到int as fx，要求改变正确的随机坐标。独立审查查手册及实测整数像素坐标后撤回该建议。正确规则是int as fx数值转换×65536，fx as int向零截断；int/angle间cast才是位穿透。以后疑点先用权威手册或最小探针确认，再要求作者修改。

语法能编译、run退出0都不等于合格。harness对task fault返回非零，但坏句柄/钳制、池满和缓冲溢出未必改变退出码。本轮显式要求诊断字段存在、无重复且task_faults/contract_viol/pool_full/hits_ovf/events_ovf/reqs_dropped全部0；reqs_dropped也按严格0处理。

早期曾读到作者尚在编辑的中间态，造成重复编译/返工消息。改为作者先compile、解析meta/spec、手算时间并声明READY/FROZEN，集成才取快照。机器与审查报告绑定实际TASK/spec/meta/main/overlay SHA，改一处后旧pass失效。文修也要更新SHA和报告；不能拿旧报告替新卡背书。

本轮手工协调也有明显开销：长上下文里混合写作与审查、重复设计确认、作者/审查者等待、多个细小反馈往返、主代理和执行者状态同步。将写与审分成小批流水、明确目录所有权和只报ready/机器通过/审查通过三个计数，比持续重述计划更有效。未可靠记录逐卡tokens和wall time，不补造成本或吞吐数字。

## 当前验收工具的四项局限

这四项是下一批批量化前的硬化工作，不冒充本轮已实现的通用强门。独立审查对当前10卡逐卡确认：

1. 正数量关键帧的状态/几何规格足够完整；工具尚未强制所有必需字段，完整性目前由review保证。
2. 当前10份JSON没有重复键/重复frame；主代理另用拒绝重复键的object_pairs_hook复核。通用validator仍用普通json.loads，自动拒绝重复键/重复frame待补。
3. 机器的最终回收采样在time_limit+60，源码审查确认本轮新增激光在time_limit前自然回收；尚未把所有卡的tl时刻直接回收门通用化。
4. 当前metadata均有laser标签、明确合成title，origin/source_ref与底子/provenance一致；工具未把全部展示/来源字段一致性变成自动门。

规格采样不是逐帧穷举，没有验证策略可解性；几何净空也不等于真实弹激光组合必有逃生路线。原作转写的现有后端、Opus抽检与逐条复核要求不因合成试产改变。

## 批量化展望（尚未实现）

先加持久化任务表，不先追求一次派出很多LLM。CSV/JSONL或轻量数据库均可，字段至少包括card_id/base_card/recipe_version、writer/reviewer身份、状态、attempt、文件哈希、工具/依赖版本、机器/审查报告路径、错误分类、起止时间和费用。建议状态：queued → writing → machine_failed/reviewing → revise → accepted/blocked。每个card_id使用独立目录，重试幂等；没有绑定当前hash的双门通过不得accepted。

writer与reviewer是两次独立Luna任务，可复用有限工作池，但同卡作者不能审自己。每卡/每批使用最小上下文，spawn时fork_turns='none'，只传冻结契约、任务规格、文件路径和验收命令；显式记录model与reasoning_effort，避免继承主代理的大上下文或错误模型。复用槽位/客户端不等于无限复用长对话。原作不变部分靠已审核底子hash和摘要复用，review仍检查实际overlay及组合影响。编译与harness属于普通进程池，不占LLM槽；按实际cgroup配额限制进程并行。review输出结构化发现：严重度、类型（编译/参数/时序/几何/来源/规格/基础设施）、证据、文件行号、建议和需要复验范围。单卡最多3轮返工；基础设施中断与脚本错误分开重试，达到上限明确blocked与原因。扩并发时保留READY/FROZEN、hash、机器和独立review门。

从这10张扩到可控较大批次，先观察每卡成本、耗时、验收率、返工率和形态覆盖，不只计产量。持续重复的错误应反馈到技能/契约和自动门。当前跨仓原创skill未改，本仓契约补激光入口与坑；后续更新技能要保留正确单位和状态语义。

数据覆盖有价值仍需训练证明：固定模型/reward/运动层和总环境帧预算，A原训练数据、B提高现有激光卡采样、C加入合成变异；B/C尽量匹配实际激光可见帧比例，继续用相同留出和逐卡×rank×意图评测，区分重复采样收益与形态覆盖收益。此文没有实施新调度器、改并发配置或启动A/B/C。

## 并发与CSV Agent Jobs：日期和入口不能混淆

2026-09-27本session注入的总槽位是4，包含root；Sol协调占1，余2个Luna可同时工作。这是会话观察，不是产品普遍硬上限。主代理核验本机CLI为0.157.1，配置未显式设置agents并发；runtime仍有自身会话上限，修改本机配置不保证改变本会话。

官方本地配置agents.max_concurrent_threads_per_session限制同时打开的子线程，不含root；agents.max_threads是旧别名。应在未来入口验证实际生效，并保留配额与验收门。来源（2026-09-27复核）：[配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)、[Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)。

官方Responses Multi-agent使用max_concurrent_subagents，限制整棵子树同时活跃的子代理、不含root，默认3；文档没有固定参数上限。这是未来可验证的另一入口，不是当前CLI会话自动可调。来源（2026-09-27复核）：[Responses Multi-agent](https://developers.openai.com/api/docs/guides/responses-multi-agent)。

用户可能记得CSV Agent Jobs。主代理本机二进制检查发现agent_jobs/agent_job_items表相关残留（CSV输入/输出/重试状态）；官方sqlite_home描述也提到agent jobs。但本session未暴露对应工具，本机CLI未找到spawn_agents_on_csv函数名，不能声称当前可用、已验证可提高并发或可直接转用。它是待确认能力，不能当作当前生产依赖。官方说明只支持状态库用途这项事实：[sqlite_home配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)。
