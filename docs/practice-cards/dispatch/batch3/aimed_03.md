# 作者任务 aimed_03 — batch3/contract v1

cwd=/data/sunyunbo/www/stg-rl-train；main。不独占工作区，不能回退别人改动。
先读 docs/practice-cards/laser-specialist-contract.md 全文、docs/practice-cards/laser-specialist-dispatch-prompts.md 的公共约束与作者prompt，并按其引擎材料阅读。不要读batch3总布局表、未分配卡目录或留出卡规格。
只写下面分配卡的四文件main.ecl/meta.toml/TASK.md/machine-spec.json，及自己的tmp日志。共享加载器/验收器正由别人适配，你不改它们；作者就绪不等于正式验收通过。
不commit/push/训练/部署/Magnus/worktree/读密钥/再委派；引擎仓只读。禁止浏览器交互。
family=aimed。布局可在如下冻结范围内编排，具体参数由你在TASK先声明后实现；不得越界或自行换主机制：每组2..4条，长度400..640，每组含一条off=0出生直狙线，其余非零偏角绝对值8..60deg；组间隔60..110帧，单次瞄准出生冻结，不用omega/rotate追踪；总并发<=16。联合偏角/原点/预警确保贴近自机时仍有避让余量。
统一rank0..3、width6/8/10/12、warn90/75/60/45、active150..210、fade12、time_limit1800；开场90，最后出生<=1500，自然回收<=1750；全程纯激光。warn+active<=16，含fade<=20，内段最大空档90。敌人/phase骨架严格服从契约。
训练随机至少位置/角度/相位中一种，联合约束控制通道宽/速度/预警。逐档参数和最不利组合避让余量写TASK。给明确random上下界及是否含端点，int as fx数值换算，int as angle是BAM位穿透。
除核心家族外不要加无关混合机制。持续练习需覆盖下半场并排查固定角落/顶部永久站桩；不能宣称源码推导就证明可躲。
独立避让检查器由其他Luna制作，作者先做基础harness自检即可，输出READY/FROZEN(作者阶段)。无需等待工具或自造玩家测试；必须实测几何/时序，其他门未完成明示。

## laser_sp_aimed_03: 左右原点轮换瞄准
独占目录：/tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03/
metadata split=train, layout_id=laser_sp_aimed_03，其余schema按契约；不造base_card/source_ref/provenance。
具体布局目标：不同左右原点的成组出生瞄准，旧线静止；不能用已出生线持续追踪来提高难度。

验收命令：/data/sunyunbo/www/stg-engine/target/release/stg-harness check <你的卡目录>；run <目录> --rank R --seed S --frames 1860，R=0..3,S=1/7。六诊断字段必填一次且0。每rank至少6关键帧，按契约machine-spec schema实测check；run --frames F --at F只抽必要帧，避免1860次调用。首/末出生、回收以TASK推导+边界采样核对。日志保存/tmp/sunyunbo/stg-laser-batch3/logs/<task>/。
最终每卡分别报READY/FROZEN、四文件SHA256、实跑命令/结果/日志路径、时序/并发/随机范围摘要、真实玩家避让尚待协调者检查。冻结后不可自行编辑；收到root返工才改。不要长日志或训练收益断言。

主代理公共规格修正：每组必须含一条off=0出生直狙；仅非零侧线受8..60deg范围约束。预警足额，旧线冻结，不追踪；总组2..4条与并发预算不变。这是全局几何矛盾修复，不是依据留出反馈修改训练形态。
