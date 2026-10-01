# Batch3 stagger_0102 作者交接（contract v1）

当前状态：Round3 仅针对 `laser_sp_stagger_01` 的作者修订已 `READY/FROZEN`；round0/round1/round2记录保留为历史，旧快照证据不可绑定新 SHA。`laser_sp_stagger_02` 本轮未改动，仍绑定其 Round1 四文件 SHA。

Round 0 历史记录：原作者阶段曾为 `READY/FROZEN`，其 SHA、运行与快照证据由下文原记录保留。独立审查发现重复角落站位后，这些旧快照已失效；round 1 按审查意见返工并重跑，当前状态见文末。

## laser_sp_stagger_01

目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01/`

- `main.ecl` — `022f16b4e0eab4b8fac3185ffadf0b0fd1c199d3934d87f5266e2aae207d8039`
- `meta.toml` — `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e`
- `TASK.md` — `9dcd19649c2f284f79480320500dc55abc44f9daeb02ce8de7967d8ea7621ab2`
- `machine-spec.json` — `46e860d1a79b635f56973c4b4441060a5f719da848b938a0e85d661895f704e1`

## laser_sp_stagger_02

目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_02/`

- `main.ecl` — `253445e0a839739b3fed63b86cae8f9e1d98fed77cc4ef2346e5e520a2b02bbc`
- `meta.toml` — `17f7b1694535793fd653cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948`
- `TASK.md` — `c7179aa316e00ef0000737ceffd20b10c7e4f65a33df08a6d8b808e33444603a`
- `machine-spec.json` — `07b66cc96d492a388d36099a8b4d62b1b9d0fa934443153d25f526ec69256ba5`

## 自检证据

两目录分别执行 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check <卡目录>`，结果均为 `OK`。两卡都完成 `run <卡目录> --rank R --seed S --frames 1860`，`R=0..3`、`S=1/7` 的16组矩阵全部退出0；每次运行 `task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 均存在且为0，帧1860激光数为0，段结束事件为 `PHASE_ENDED@1803`。完整输出和 check 日志在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/`；`author-selfcheck-summary.txt` 汇总机器检查。

每卡 `machine-spec.json` 含36个唯一关键帧（每rank 9项），覆盖首束预警、生效、二/三组交接、中段、末出生、fade末帧、回收和1800帧。对应 `--at F` 输出按声明核对了数量、state、width、角度和坐标区间，快照日志以 `*-rR-s1-fF.txt` 命名。另有每rank、seed1/7首组 `--at 94` 日志 `*-rR-sS-f94.txt`；两个种子的坐标各rank均不同。跨种子证据仅代表seed1/7，不覆盖所有随机组合。

时间表（rank0/1/2/3）为：首出生均94；周期112/104/90/81，组数13/14/16/18；末出生1438/1446/1444/1471；最后自然回收1750/1743/1726/1738。宽度6/8/10/12，warn90/75/60/45，active210，fade12。每组两束，峰值观测并发rank0/1为6、rank2/3为8，低于预算16；计入fade仍低于池预算20。位置由受限整数随机化，并由任务文档列出端点和间距。几何净空仅为同组线间按完整激光宽计算的下界，不是完整随机叠加下的可行性证明。

## 尚待协调者完成的门

真实玩家运动/判定参数下的轨迹与固定点站桩检查尚未执行；非作者源码审查、正式专项机器门/加载器兼容和最终纳入决定均待协调者处理。作者未证明随机全域都可躲，也未作训练收益结论。


## Round 1 修订（审查返工，contract v1）

独立审查 [`stagger-train-review.md`](stagger-train-review.md) 对旧快照要求返工：stagger_01 的 lower-left/right 基线在 8/8 rank×seed 中均为 QUALIFIED 且 SUCCESS，抵达后连续静止 1,642–1,704 帧；stagger_02 的 top-right/bottom-right 均在8/8中达到 stationary-qualified，完整局 SUCCESS 为6/8（不是8/8），显示可重复的长期固定边缘路线。问题来自旧布局的激光未覆盖实际边界。

Round1 历史状态：四文件曾 `READY/FROZEN`；该快照已由下方 Round2 修订替代。

### 当前哈希

`laser_sp_stagger_01`（`/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01/`）：

- `main.ecl` — `4c55b45c98acffe2e0d489aa11a1aa032871e3a8a1ea8b73d670c3d65ff998d7`
- `meta.toml` — `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e`
- `TASK.md` — `66b27523eb35b1dc056e88b1f9988dc896625d82b930d5097a7f69fbb2c124af`
- `machine-spec.json` — `8cfad9a28295df6c54eff547467c0c5e8b6909c693a5946c5c1d90323670b2f9`

`laser_sp_stagger_02`（`/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_02/`）：

- `main.ecl` — `b07234ecc57b0865790d6780f8a051794b193874ba76c185d965d6b50f714710`
- `meta.toml` — `17f7b1694535793fd653cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948`
- `TASK.md` — `4d1abd5618471d1ba83e3de9fd17a529e24d704a8a814c603c7f208da1319ebf`
- `machine-spec.json` — `5f2a17d3049aa9081ab5d0f1fc8280224ee7398f1d423cccdfc761fea4d67dd7`

### 修复与基础验证

保持主家族和所有rank的核心线位置/间距随机化、线宽、warn、周期与组数。每组现为两条随机核心完整长线，另加一条有完整预警期的边界长线：stagger_01 按wave奇偶在真实 y=448 底边和 y=0 顶边间交替；stagger_02 在真实 x=192 右边和 x=-192 左边间交替。边缘束每隔两组返回同一侧；每档同侧回访周期（224/208/180/162帧）小于 `warn+active`（300/285/270/255帧），所以对准实边的站角落路线会遇到可见预警和生效激光。没有给激光加瞬移/转向、子弹、人工观测或reward项，也没有把全场封死。核心 pair 的最小几何净空仍按完整判定宽计算；边缘束可与核心束靠近或重合，不将该局部数值宣称为整个并发场景的可行性证明。

三束/组使峰值并发实测 rank0/1 为9、rank2/3为12，仍低于 visible 16 / live 20 预算。first/last timing 未变：首出生94；末出生1438/1446/1444/1471；最后自然回收1750/1743/1726/1738；段事件实测 `PHASE_ENDED@1803`。metadata沿用原 train split/schema。

两卡分别重新执行 `stg-harness check <card>`，结果为 `OK`；重新跑完整 `R=0..3, S=1/7, --frames 1860` 矩阵，8次/卡全部退出0，六诊断均存在且全为0，帧1860激光数为0。每卡9关键帧/rank，共36个实际 `--at F` 快照再次核对数量、state、角度、完整width及位置范围；首出生帧94也确认新增边缘激光准确位于 y=0/448 或 x=±192。rank和seed1/7首组核心几何仍不同。证据与完整输出在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/`，摘要为 `author-selfcheck-summary.txt`。

### 仍待后续门

本轮作者没有重跑真实玩家工具；上述边界束的作用是针对被记录的固定边缘捷径，是否消除长站角路线需协调者在当前 SHA 上重跑 feasibility。独立机器 validator、实际玩家存活/站桩结果、非作者源码复审及最终纳入决定仍待协调者执行。旧 machine/feasibility/review报告只绑定 round0 SHA，不可作为本轮通过证据。作者不声称所有随机实例可躲，也不声称训练收益。


## Round 2 修订（stagger_01；修正源码确定性通带）

Round1 真实玩家及独立审查指出：即使加入交替边界线，旧核心公式仍固定限制 `y0 <= 263`。review给出确定性几何反例：rank1核心最高中心415px，加半宽4与审查测得扩张半径4.5后危险上边423.5px，边界线危险带从439.5px才开始，中间仍有16px无危险通道；rank2约余30px；rank3核心 `y0+gap <=263+120=383`，碰撞危险只到393.5px，而底边危险从437.5px开始，留下44px。该结论覆盖任意 RNG 取值，属于源式固定安全带证明。

仅修订 `laser_sp_stagger_01` 的四文件。核心先抽rank范围内 `separation`，再用 `phase=rand(5)` 和 `slot=(wave*5+phase)%wave_count`，生成 `y0=floor((448-separation)*slot/(wave_count-1))`；第二核心线中心 `y0+separation`。组数13/14/16/18都与步长5互质，所以任一完整波次周期都会访问slot0和slot n−1，核心中心分别触及0与448。每组的 joint domain 保持 `0<=y0<=448-separation`；warn/active/fade、周期、组数及交替 y=0/448 边界线保持不变。该构造取消旧式固定中间范围可推出的通带，但不证明全随机组合可躲。每rank最多12条完整长线同时存在；按 reviewer 使用的最大碰撞宽度算，总危险区纵向长度上界252px/448px，仍留空间量，不能当作跨帧路径或可执行性的证明。02未改，因为其 round1 边角捷径已经按审查要求修正；少量启发式结果不作为继续改正确场面的理由。

### 当前 `laser_sp_stagger_01` 哈希

- `main.ecl` — `8b768a5cea406bfe9f785bda211d8c30142f49d453356fcac906121f3299d4a0`
- `meta.toml` — `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e`
- `TASK.md` — `9bf1a63d23a66ea2d66bd94f2c294a1ed2f57c4f9d0a12ae7d27ac497dc8dbb3`
- `machine-spec.json` — `181909f193da7d1f0e160876e9b0708bb060f4980407352ee2a94966385fefeb`

### Round2 基础与专项机械验证

`/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01` 为 `OK`。重新运行 `R=0..3,S=1/7,--frames 1860` 全8组皆退出0；六诊断全零，完整推进到1860、phase结束 `PHASE_ENDED@1803`，末帧激光数0。每rank9个、共36个 `--at F` 关键帧重新实测并匹配数量、状态、完整width、角度及精确声明的几何范围；包括首/末出生、fade与自然回收。首出生94、末出生1471、最晚回收1750；实测峰值visible/live=12，`max_idle_gap=0`。完整输出和快照在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/`，摘要 `author-selfcheck-round2.txt`。

专项机械自检命令：`UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01 --json /tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/specialist-validate-round2.json --seeds 1 7`。结果 `MECHANICAL PASS · independent review pending (0 errors)`，报告 SHA256 `53cecfccb8090d6726b04caf2c967596b4739725ef503643d529f56d1604cfba`，`acceptance_status=mechanical_pass_independent_review_pending`。

当前文件冻结后，真实玩家可行性工具及原非作者审查员须按新四文件 SHA 重跑；Round1玩家报告只绑定上个快照。作者未重跑玩家轨迹，不声明边界/中心站位捷径已彻底消除，不声明全随机实例可解或训练收益。


## Round 3 最终修订（仅 stagger_01；slot量化边带）

独立源码审计指出，Round2 的 stratified slot 本身是离散位置：相邻基准点最大步长 rank0..3 为28/27/24/23px。按激光半宽和审计使用的 hit 半径扩张，仍有小的 quantized edge rows；因此 Round2 的“连续slot覆盖支持”说法过强。

在保留间距、相位槽、全周期遍历和边缘锚波的基础上，每波现在再抽 `jitter = rand(33)-16`，即 raw rand 半开 `[0,33)` 对应闭区间 `[-16,16]px`；先算 `base_y0=floor((448-separation)*slot/(wave_count-1))`，再加 jitter，并在建激光前 clamp 到 `[0,448-separation]`。端点附近因截断而概率偏高，TASK已说明；没有伪称均匀采样。32px抖动支持跨度大于所有相邻槽的最大取整步长，所以完整随机参数支持下的相邻位置带相接，且 clamp 保持 `y0>=0` 与 `y0+separation<=448`。由此 y=10 与 y=438进入核心线位置支持；这仅是源位置域推导，不表示每个实际回合都会在某帧打到这些行或整个实例都可躲。既有宽度、warn、active/fade、周期、wave数、3束/组、固定无敌非碰撞boss和观测预算均保留。

### 当前 stagger_01 快照 SHA256

- `main.ecl` — `250efd7ef10003fb4ef232b6c15df9d9b55520784460e4359455ed8dab8ffc90`
- `meta.toml` — `4e9917b5b0b08456daa77e0afa9eab270cf708ec29201e0c7fb4b251d9c4ba4e`
- `TASK.md` — `767c900202c5ca49c85d954237027d127935cc9acc4be951f34c56ca72d44c53`
- `machine-spec.json` — `f57ad85404b8a12c8b094e20c0cb30cb983781b6dd1b711bb92f5843666bf852`

### Round3 验证

最终快照上的 harness `check` 为 `OK`。rank0..3 × seed1/7 的8个 `run --frames 1860` 全退出0，六诊断全零，帧1860无激光，`PHASE_ENDED@1803`。每rank9项、合计36个关键帧分别采集seed1和seed7快照；数量、state、width、angle与位置范围均匹配最终machine-spec。专项命令为 `UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01 --json /tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/specialist-validate-round3.json --seeds 1 7`；结果 `MECHANICAL PASS · independent review pending (0 errors)`，报告 SHA256 `0b241dd5065f74ce873bf9d98f73e6363fdd9a2d1245de99c3bc1bd13ac0f488`，`acceptance_status=mechanical_pass_independent_review_pending`。观测流测得峰值 visible/live=12/12、max_idle_gap=0、首/末出生94/1471、最后回收1750。运行与快照日志仍在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_0102/`，本轮摘要 `author-selfcheck-round3.txt`。

`laser_sp_stagger_02` 未触碰；复核SHA仍是：main `b07234ecc57b0865790d6780f8a051794b193874ba76c185d965d6b50f714710`，meta `17f7b1694535793fd653cabc45a9cfad04ca64a9c555bdcd5a9e3209a3f48948`，TASK `4d1abd5618471d1ba83e3de9fd17a529e24d704a8a814c603c7f208da1319ebf`，spec `5f2a17d3049aa9081ab5d0f1fc8280224ee7398f1d423cccdfc761fea4d67dd7`。

此轮未运行真实玩家目标点检查，y=10/438真实物理探测及原审查员复审由协调者针对当前 stagger_01 SHA执行。机械门通过不表示玩家检查通过；不声称固定路线已消失、不声称全随机域均可躲，也不声称训练收益。若后续发现全局站桩捷径，应按协调者要求隔离该卡，不再无限轮改造。
