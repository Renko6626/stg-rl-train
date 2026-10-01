# corridor_0102 作者返工交接 — round 1

状态：`READY/FROZEN`（作者阶段；正式接受待协调者重跑与非作者复审）。本报告与卡文件对应 contract v1 新SHA。旧作者、机器、可行性和源码审查结果全部失效，不作为本快照的通过证据。

## 本轮修复

两卡的warning阶段现在保持初始原点静止；warn结束后active第一步才开始逐帧`lz_origin`平移，active和fade期间连续运动。起始轨迹先朝对应边界移动，再反射穿过中心区。C01的右/左组active轨迹扫过`x=192/-192`附近并通过中区；C02的上/下组active轨迹扫过`y=0/448`附近并通过中线。所有运动仍是两条平行线围成的可行走廊，没有普通子弹、观测改造、reward塑形或预测未来。

净空现在分两种数值报告。每侧有效自机半径按实际feasibility参数`hit_radius=2.5px + hit_extra=2px = 4.5px`，所以玩家中心净空`C = 束边净距g − 9px`。束边g的rank最小值为60/52/44/40px，得到玩家中心净空51/43/35/31px，高于冻结下限48/40/32/28px。每波抽`q∈{0,…,8}`联合设束边间距和速度，抽中心位移`j`分别为C01 `[0,24]px`、C02 `[0,4]px`；两端包含。速度随rank为1.10..1.14、1.12..1.16、1.14..1.18、1.16..1.20px/frame，q步进0.005；warning不移动，rank active分别160/162/180/208帧，fade12。TASK给出了最不利q/j下的路径余量与具体hit-radius核算，并明确这些只是几何推导。

Machine-spec增加每rank在最后激光消失帧的`count=0`关键帧及frame1800零激光终帧。新轨迹实测末波出生frame1485；各rank最后active转fade帧为1735/1722/1725/1738；最后仍有激光的帧为1746/1733/1736/1749；自然回收帧为1747/1734/1737/1750。

## 机器、轨迹和玩家基线

- 两张卡的`stg-harness check`均为`OK`。日志：`/tmp/sunyunbo/stg-laser-batch3/logs/corridor-0102/round1-laser_sp_corridor_01-check.log`、`round1-laser_sp_corridor_02-check.log`。
- rank0..3 × seed1/7 × 1860帧共16个harness完整运行全部退出0；每个结果均唯一包含`task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped`，六项全零。激光峰值8，末帧1860无激光。日志模式：`round1-<card>-r<R>-s<S>-full.log`，目录同上。
- 机器关键帧覆盖frame92/93首出生边界、各rank首active、handoff、frame900中段、1484/1485末出生边界、末波last-active/fade、每rank实际自然回收零激光帧及frame1800终帧。`machine-spec.json`的几何范围由轨迹限制、半间距公式、完整width及轨迹span解析式推导；两种seed的数量/状态/几何均落在声明范围内。
- 两次新版工具自检均为`MECHANICAL PASS · independent review pending (0 errors)`：C01报告 `/tmp/sunyunbo/stg-laser-batch3/round1-machine/laser_sp_corridor_01`；C02报告 `/tmp/sunyunbo/stg-laser-batch3/round1-machine/laser_sp_corridor_02`。正式机器矩阵由协调者最终重跑。
- 对当前两个卡SHA，各跑一次完整`specialist_feasibility --ranks 0 1 2 3 --seeds 1 7 --max-frames 1860 --baselines`，每卡88条试验。C01 heuristic成功0/8，C02 0/8；这只是启发式结果，不表示不可解。更关键的是，两卡各自所有72个固定目标静止试验均在完成全段前死亡，实际spawn静止基线也均为0/8存活；涵盖本次声明rank和seed下的左右/顶/底/角及内侧固定点。报告：`/tmp/sunyunbo/stg-laser-batch3/round1-feasibility/laser_sp_corridor_01/laser_sp_corridor_01.json`、`/tmp/sunyunbo/stg-laser-batch3/round1-feasibility/laser_sp_corridor_02/laser_sp_corridor_02.json`，stdout索引及日志在各自目录和`logs/corridor-0102/round1-*-feasibility.log`。

有限种子和固定目标检查不能证明全部随机取值都可解，也不代表训练收益。仍需非作者读完整新源码/新machine-spec复核，协调者按最终SHA重跑正式机器门；返工后结果不得继承旧快照PASS。

## 冻结文件SHA256

| 卡片 | 文件 | SHA256 |
|---|---|---|
| laser_sp_corridor_01 | main.ecl | `2a06fc8d99f64c3329eb00936343beb0fb5d711c20acf026bdddc69fad1799c2` |
| laser_sp_corridor_01 | meta.toml | `280d374d49c280f24d8dee35b07c9a057d4f70eccce82504ca33038b709d207c` |
| laser_sp_corridor_01 | TASK.md | `4f074081c324a28fac0da27d84fb5ff6cb66ca28d80c432f7bd253d279c95251` |
| laser_sp_corridor_01 | machine-spec.json | `8540bea6e26a75084499a3845a965c3e15b2eaf422930fb754c99545d5e80099` |
| laser_sp_corridor_02 | main.ecl | `6933461772b57146dcda295946ead8683b0f80f6f44f7cd8968f5440a4c1448b` |
| laser_sp_corridor_02 | meta.toml | `ba0b492eaae3766d92253d461a72eff5ade589fe1fe52228b743b74ae46c9cf5` |
| laser_sp_corridor_02 | TASK.md | `bbfcd143c05b53b8e81161c9b90c5db0217c8eb017628ad7322ce71f4ed4e10b` |
| laser_sp_corridor_02 | machine-spec.json | `f15ef0b2ed11951dd7b2ae64d9aef29f4a43a599681a0178f132ef5db0572a0b` |
