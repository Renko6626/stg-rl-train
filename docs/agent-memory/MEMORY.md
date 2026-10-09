# 项目记忆索引

2026-09-26 从 `~/.claude/projects/-data-sunyunbo-www-stg-rl-train/memory/` 迁入：10 条记忆及本索引。

每次开始任务先读本索引，再读相关条目。用户反馈继续适用；机器资源、软件版本、余额和运行状态是记录时的观察，执行前以当前环境核验。条目保留 Claude 来源元数据用于追溯，它不是 Codex 专有配置。

- [直接在 main 上提交](commit-directly-on-main.md) — stg-rl-train 不开功能分支，提交/推送都走 main
- [Astra 委派代码执行工作](astra-delegates-code-work.md) — 改代码与大量代码库阅读优先交给子代理；类似任务优先 Sol / medium，主代理负责判断与审查
- [Luna 练习卡生产与试产经验](luna-practice-card-workflow.md) — 用户优先低成本扩卡；独立写审、READY/FROZEN+SHA、来源隔离、严格机器门及批量化边界
- [租的训练机只有 24 核 CPU 配额](rented-box-cpu-quota.md) — nproc 的 255 是宿主机的；并行两条会被 cgroup 节流，下一轮开跑前要先确认
- [Magnus 是旧 torch 栈](magnus-old-torch-stack.md) — torch 2.5.1 / tensordict 0.6.2；提交 Job 前先在同版本 venv 跑测试
- [Magnus 用 B2 优先级](magnus-job-type-b2.md) — 提交 Job 一律 --job-type B2，不用 A2（用户要求礼貌）
- [Magnus 节点 CPU 是瓶颈](magnus-cluster-cpu-bound.md) — 6×A100 只配 112 核；提交前 magnus cluster 看 cpu_free；kill 要 -f
- [rank 从 0 开始](rank-is-zero-based.md) — r2 = Hard、r3 = Lunatic（0 Easy · 1 Normal · 2 Hard · 3 Lunatic）
- [少构造、改真实机制](prefer-real-mechanics-over-shaping.md) — 不喂构造特征、不用罚款塑形；改环境 / 直接改引擎
- [激光编码器审阅与新版（2026-10-01）](laser-encoder-review.md) — 后续用户确认并实现v8的14维token与v3联合SA、图版本6；CPU/ONNX与旧CPU栈通过；T6已完成GPU验收与训练；TH06NC graph6已打包、未实机验收；Top-K并列边界仍保留
- [激光专项练习方向（2026-09-30）](../practice-cards/2026-09-30-laser-specialist-design.md) — 用户认可激光成为绝对主体、持续提供避让练习；已落档设计，尚未制卡或训练，具体参数与采样待定
- [专项卡派发模板（2026-10-01）](../practice-cards/laser-specialist-dispatch-prompts.md) — 从零专项卡的冻结任务单和写审/返工 prompt；执行后补骨架、单卡自检和源码安全带检查要求
- [第三批专项卡结果（2026-10-01）](../practice-cards/2026-10-01-batch3-results.md) — 20张生成、机器20/20、17有限样本候选（12训练/5留出）、3 NOT_PROVEN隔离；部分rank未获完成轨迹，不代表训练收益，未训练/提交
- [T5专项混合训练（2026-10-01）](../practice-cards/2026-10-01-t5-experiment.md) — 快照889a9d3，Job4aba4850f7ba4dff已完成3500updates并取回；12张专项训练、5张另测
- [T5阶段性结果与结构实验交接（2026-10-01）](../practice-cards/2026-10-01-t5-results.md) — 主激光评测小幅改善、专项泛化未学稳；用户怀疑模型结构，下一会话做结构实验，具体方案未定；取回码数字长度不可写死
- [T6联合注意力训练（2026-10-01）](../practice-cards/2026-10-01-t6-experiment.md) — Job cec000c4981cc5af已完成3500轮并取回；GPU对拍PASS；原作激光56.90→80.73%、专项18.95→54.34%，普通卡−3.63pp；单seed组合改动；后续TH06NC部署见T8包
- [T7／T8激光数量训练对照（2026-10-02）](../practice-cards/2026-10-02-t7-t8-experiment.md) — T7 retry1与T8均完整3500轮：8根原作激光90.36%、普通91.88%、SPS+2.2%；4根原作86.33%、SPS+4.8%；纯专项都约42.9%；T7混合组未补测
- [T8模型与TH06NC包（2026-10-02）](../practice-cards/2026-10-02-t8-th06nc-package.md) — graph6共享C／mod适配并打包；保留用户要求的8帧激光平滑；C/ORT1.22与Windows x64构建通过，未实机验证；ZIP在dist，未发布
- [激光模型阶段小结与后续候选（2026-10-02）](../practice-cards/2026-10-02-laser-stage-summary.md) — 统一T5–T8结果，原作／混合／专项与部署口径分开；建议补T7混合／实机、同批profile、子弹K对照；路线未选定、未占新编号
- [后台任务要确认真在跑](verify-background-launch.md) — env 变量写在 taskset 前；ps 看 python 进程；监视要盯提前退出
- [T7控制诊断实验1／2（2026-10-03）](../practice-cards/2026-10-03-t7-control-diagnostics.md) — 实验1完成1664局：跟点请求／执行8.28／4.86次变向每秒，自由3.41／2.00；请求短段约47.5%，执行约5%；实验2失败轨迹待执行，不授权新训练或动作空间改造
- [T8推理间隔消融（2026-10-03）](../practice-cards/2026-10-03-t8-inference-interval.md) — 五档合计4160局：AUTO1/2/3/4/6为94.47/94.95/90.87/91.11/82.45%，自由94.71/91.59/93.03/89.66/83.89%；AUTO激光3帧起明显下降，6帧普通也受损；建议AUTO2帧、自由1帧，未改mod或训练
- [待执行：两帧决策PPO训练（2026-10-03）](../practice-cards/2026-10-03-two-frame-training-candidate.md) — 用户要求仅记录、之后进行；一次采样跨两帧，运动层／reward逐帧、PPO只记一次，成本估算约1.45倍非实测；方案／预算待确认，未开跑
- [请求动作惩罚 A/B：准备 B（2026-10-03）](../superpowers/specs/2026-10-03-request-reward-b-design.md) — 用户确认T7的8根激光，明确否决请求／执行分开的模型输入；保留player15维/v8/v3/图6，只把动作惩罚移到原始请求；内部记录仅供reward，已实现并经本地／旧CPU栈检查，旧Job e1438561397ddfdb被用户中止；2026-10-04按原快照重开Job 3c0392a2052fb68e（B2），已完成3500轮并取回：关层变向14.78→3.54/s，普通91.88→88.16%、激光90.36→73.44%，见[结果](../practice-cards/2026-10-05-request-reward-results.md)；未提交／推送
- [T8静止反复切shift（2026-10-06）](../practice-cards/2026-10-06-idle-shift-diagnostic.md) — 用户实机报告原T8四根模型不动时反复松按低速键；旧离线AUTO/自由持续不动段约3.22次翻转/s；quick_change只管方向、shift_toggle=0；未改输入/惩罚或启动训练；B试玩打包与此问题分开
- [B/K8 Windows试玩包（2026-10-06）](../practice-cards/2026-10-06-b-th06nc-package.md) — renkolab/out已有ZIP，默认B并附旧T8回退，图6/8帧平滑不变，shift未修；数值对拍通过，80px直落弹立即移动行为断言失败，已标注；未实机／提交／推送／Release
- [stg_rl 升版两边同步](stg-rl-wheel-sync.md) — pyproject/uv.lock 与 magnus/wheels+SHA256SUMS 必须同一版
- [适配层排序优化与下一轮候选（2026-10-06）](../practice-cards/2026-10-06-adapter-update-and-next-ab.md) — 已接入等价排序优化的0.4.2 wheel，ENGINE_VER24；本地/Magnus同哈希，低弹/超cap回放一致；平台当时6GPU/108CPU空闲；后续较轻请求惩罚与额外Shift罚分短轮配对已提交，见下条
- [请求惩罚与Shift短轮A/B（2026-10-06）](../practice-cards/2026-10-06-request-shift-short-ab.md) — 用户确认运动层不动、并行两种惩罚；同T7/K8权重新建优化器1000轮；Job9436bd073b636c2b/b3ef72c1ca44515d均完成取回，训练各76分40/41秒；Shift自由2.76→0.32/s、关层4.08→0.84/s，四卡持续静止3.03→0.12/s；水符均值85.16→76.95%、末轮90.62→75%，见[结果](../practice-cards/2026-10-06-request-shift-short-ab-results.md)；未替换部署/启动后续训练/提交/推送
- [带Shift罚分B/K8 Windows试玩包（2026-10-06）](../practice-cards/2026-10-06-b-shift-th06nc-package.md) — 用户随后授权新B/u1000打包；renkolab/out已有request-light-shift-k8 ZIP，默认新B+旧T8回退、运动层与8帧平滑不变；行为六项通过，严格三帧数值门一帧1.34e-5>1e-5但输入/动作一致，已标注；旧包未覆盖，未实机/提交/推送/Release
- [TH06NC模式与手动优先（2026-10-06）](../practice-cards/2026-10-06-th06nc-modes-manual-input.md) — 用户确认AUTO默认自由躲弹、按住左键引导，BYPASS沿用旧AUTO锚点/压力；两者保留自动射击与炸弹安全网；方向键立即接管全组移动/Shift状态，历史记最终动作；renkolab源码及新B/Shift模式包已更新，三项主机测试/交叉编译/入口导出检查通过，未实机/提交/推送
- [密度图CNN消融与Perceiver计划（2026-10-08）](../superpowers/plans/2026-10-08-density-ablation-perceiver.md) — 用户认可同权重关CNN→配对训练→8-latent远场摘要；随后授权P1，CPU3968局完成：原作自由−1.44pp、跟点−2.64pp，专项自由−5.94pp，高密度自由持平/跟点+2.34pp；空图CNN有非零常量响应，不能把即时损失全归因于远场信息，见[结果](../practice-cards/2026-10-08-density-ablation-results.md)；P2/P3未启动、预算待确认，Sparse attention暂缓
- [密度CNN配对适应P2准备（2026-10-08）](../practice-cards/2026-10-08-density-p2-preparation.md) — 用户授权准备GPU实验；两臂seed1/1000轮、真实最新B权重严格迁移、B跳过构图/缓存、u0与u1000三eval seed逐局评测、B2/1GPU32CPU参数和647文件快照已就绪；本地/旧CPU栈及真实源权重预检通过，CUDA验收待Job启动；未上传/提交/训练/推送，Perceiver未实施
- [CNN配对适应u2000（2026-10-09）](../practice-cards/2026-10-09-density-p2-u2000.md) — 用户确认统一2000轮慢退火、并行两个新B2任务，并明确要求阶段性提交/推送后启动；固定u2000为主比较、u1000/u1500阶段诊断；按推送commit运行，仅传初始化数据，提交和启动证据见条目
- [转写 worker 可换 Sonnet](transcribe-claude-worker-fallback.md) — DeepSeek 没余额就 STG_DSH_BIN=claude-worker；并发 4；dsh 审核必须配 opus 抽检

## 迁移说明

- 迁移时仓库内没有 `CLAUDE.md` / `claude.md` 或既有 `AGENTS.md`。根目录的 [AGENTS.md](../../AGENTS.md) 根据这些记忆、README 和现有配置整理为 Codex 项目入口。
- 用户级 `~/.claude/CLAUDE.md` 和父目录 `~/www/CLAUDE.md` 是机器与跨项目说明，本次没有修改或整体复制到本项目；原 Claude 记忆和 `.claude/` 均保留。
- 将原有 `[[条目名]]` 交叉引用改为相对 Markdown 链接。跨仓库引擎规范改为优先读取适用的 `AGENTS.md`，同时保留尚未迁移的 `CLAUDE.md` 入口。
- `rented-box-cpu-quota.md` 中 2026-09-21 的“未提交”已补充仓库核验结果；没有把旧待办当作刚刚执行过的操作。
- `claude-worker`、Sonnet 和 Opus 是现有流水线的真实工具与历史约定，保留原名；本次没有把它们机械替换成 Codex，也没有迁移 `.claude/skills/` 或改动流水线程序。
- Codex 的标准项目入口与加载时机依据 [OpenAI 官方 AGENTS.md 文档](https://developers.openai.com/codex/guides/agents-md/)；`docs/agent-memory/` 是本仓库通过根指引要求读取的普通文档目录。
