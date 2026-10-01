# batch3 sweep_0102 round 1 作者修订记录

规格：`laser-specialist-contract v1`。两卡作者状态：`READY/FROZEN`，仅代表本轮编译、harness与专项机械trace自检通过。协调者仍需对新SHA重跑玩家/站桩门和独立源码审查。

## `laser_sp_sweep_01` — 上侧单原点扫扇

四文件最终SHA256：

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `b00ad03e6261076e201c80d287abefd639aacc68c905b6e656d81ae9ad762af0` |
| `meta.toml` | `0a984142ede50eda6e4f879df038306f15979bca6aded0035d659b3168feb9ef` |
| `TASK.md` | `aa252a3d0ed11ea6c70fd144b5473e33392fb618e38310d5bab52a3ee87aa2dd` |
| `machine-spec.json` | `90c3da8062e924571b96d075234ccbe71f41983b7ceeb9a3470ef04d0d07134a` |

编译命令 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_01` 返回 `OK`，日志 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/laser_sp_sweep_01-check-round1-final.log`。rank0..3 × seed1/7 的16帧矩阵中本卡8次完整运行均exit 0；六诊断各自唯一且为0，峰值可见/live均12条，1860帧末无激光。日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/laser_sp_sweep_01-r<R>-s<S>-round1-final.log`。

中心相位现从整圈 `[0,65536) BAM` 随机起始，每组加18°，20组完整环行一周；相邻中心间隔18°，三线扇宽24°，不存在持续的方位角向空档。单束omega按rank为28/32/40/48 BAM/frame，出生时写入并从warn开始连续转动。角度范围经过结构性调整，改动针对完整角度空间，不针对审查报告中的某个静止坐标。

`specialist_validate` 机械门通过，报告 `/tmp/sunyunbo/stg-laser-batch3/selfcheck-round1/laser_sp_sweep_01.machine.json`，SHA256 `aaf997205d2f7bf5079c5a1d1ddbf46332be09e002090f6d40a624fa05830d81`。该trace矩阵实测 first/last spawn=94/1462、last expiry=1729、max visible/live=12/12、内部max idle gap=0；最后可见帧rank0..3为1710/1710/1711/1716，frame1800关键帧计数为0。关键帧日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/key-laser_sp_sweep_01-r<R>-s<S>-f<F>-round1.log`，覆盖首末出生、warn/active/fade、运动与交接、精确expiry空场和frame1800空场。

实测几何联合假设采用fast/slow=4.5/2.0px/frame、hit_extra=[2,2]（完整玩家半径4.5px）、motor hold=[2,6]、delay=[0,2]；warn内理想直线移动上界rank0..3为fast 405/337.5/270/202.5px、slow 180/150/120/90px。640px全线端点切向速率为1.72/1.96/2.45/2.95px/frame；可玩区域内最远原点距离约476px，末端速率约1.28/1.46/1.83/2.19px/frame。上述量是范围估算，不是生存保证。

旧快照的玩家报告记录rank0/seed1在 `(-128,80)`、`(128,80)` 静止成功1604、1589帧，rank0/seed7在 `(-128,80)` 静止成功1539帧；旧启发式成功2/8。证据绑定旧 `main.ecl` SHA `f27ce719…`，不代表当前修订快照。需由协调者按新SHA重跑固定点及邻域静止检查；启发式失败仍不证明不可解。

## `laser_sp_sweep_02` — 左右原点交接

四文件最终SHA256：

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `5905e8cd75cef0038471681050fb18986d531ce4014de09623ccb1826416be98` |
| `meta.toml` | `d1af770e2843037420b5b0e14ecea82ccd3febfc49d18741687f4e5a8535b141` |
| `TASK.md` | `da5c82b555ee336f57b8f3f3a5805c2feb7cda5eea30d320fc37bb64be3b53dc` |
| `machine-spec.json` | `956bf5bce941797df037fa5496c2669727c2e8659cd18ef3f2cd4aab51bf6688` |

编译命令 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_02` 返回 `OK`，日志 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/laser_sp_sweep_02-check-round1-final.log`。rank0..3 × seed1/7的8次完整运行均exit 0；六诊断各唯一且为0，峰值可见/live均8条，1860帧末无激光。完整日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/laser_sp_sweep_02-r<R>-s<S>-round1-final.log`。

随机整圈phase每波前进18°，左右交替且右侧加180°；每组角抖动为闭区间`[-546,546] BAM`，原点y为整数闭区间`[96,352]`。omega左侧固定正、右侧固定负，rank0..3为34/40/48/56 BAM/frame；rank0长度520px，其他rank640px。每侧同侧中心间距36°，随机抖动下最大跨度42°；两线夹角16°，active角向覆盖范围分别约45.7°/54.2°/66.1°/80.6°，结构上环行完整方位角空间且相邻active范围重叠。

`specialist_validate` 机械门通过，报告 `/tmp/sunyunbo/stg-laser-batch3/selfcheck-round1/laser_sp_sweep_02.machine.json`，SHA256 `50ad6615779b79695dec8aff2378370b9da76e0fc307cc9be51f73cbd52af5e1`。trace实测 first/last spawn=94/1462、last expiry=1729、max visible/live=8/8、内部max idle gap=0；最后可见帧rank0..3为1710/1710/1711/1716，frame1800关键帧计数为0。关键帧日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_0102-author/key-laser_sp_sweep_02-r<R>-s<S>-f<F>-round1.log`，覆盖状态边界、左右接力、运动、多波交叠、首末生、fade、精确回收和时限快照。

运动核对使用fast/slow=4.5/2.0px/frame、hit_extra=[2,2]（完整玩家半径4.5px）、hold=[2,6]、delay=[0,2]。warn内fast/slow理想路程上界rank0..3为405/337.5/270/202.5px、180/150/120/90px。全线端点切向速率为1.70/2.45/2.95/3.44px/frame；活动区最远源点距离约515px，rank0的520px线仍达该距离。局部channel余量只是几何截面，不证明整局可躲。

旧快照rank0/seed7在`(-192,0)`静止成功1483帧，旧启发式成功3/8、静止基线成功2例；证据绑定旧 `main.ecl` SHA `8f43bb58…`。新的phase使每侧依序扫过整圈方向，不是针对该坐标加线。协调者应在新SHA重跑top-left和相邻边点静止检查；旧单例结果不说明所有随机局可解或不可解。

两卡boss均固定`(0,64)`、无敌、设置`ENEMY_NO_BODY`，只用激光并由1800帧`phase_begin`管理。正式玩家可行性、站桩结果和非作者完整源码/几何审查针对本轮最终SHA仍待协调者完成。
