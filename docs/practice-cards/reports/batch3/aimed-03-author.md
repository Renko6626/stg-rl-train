# aimed_03 作者报告

状态：`READY/FROZEN`（仅作者阶段）。四文件冻结在 `/tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03/`；本报告绑定以下 SHA256：

- `main.ecl`: `353496f9017b69bdfddf49d4101cb366016259806440fe24761c01137658fcba`
- `meta.toml`: `a7009547a41fe41b7a0c9064d7675ff2cdb1f79b2fce9108877d575705033c5e`
- `TASK.md`: `a0f8de8fba326fe8b1948485c16ae71aee233d08a6f943e7a3b90ca5586debb4`
- `machine-spec.json`: `09751ff733ac8d17d855897d83e108b9bdf2c7bc957ed141d7f3f06bb4e557ac`

## 设计摘要

纯激光；一只固定无敌、`ENEMY_NO_BODY` 的 boss，phase 0 时限1800、阈值0。每组3线，同帧出生，从 x=-176 / +176、y=64 两侧原点轮流发出。中线 `off=0deg`，侧线 `off=-22deg/+14deg`；所有 `lz_aim` 在出生时调用一次，线段长度560、静止且之后冻结。阶段参数为：rank0宽6/warn90/active162/14组；rank1宽8/warn75/active174/15组；rank2宽10/warn60/active186/16组；rank3宽12/warn45/active198/19组，fade均12。开场等待为90..91帧；各档组间闭区间为99..105、90..98、82..88、72..76帧。随机来自 `rand(n)` 的整数 `[0,n)`。

最坏 clamp 对侧角距离原点约531.87px；560px线段至少留28.13px端点余量。最大并发由rank2/3的4组得12条，预警/生效峰值和含fade的存活峰值都为12。组间最大间隔小于各档warn+active，因此首预警至末回收内段空档推导为0；代码上界的最晚出生为rank1的1468，最晚回收为1729。seed1/7实测首生frame95、全矩阵末生最大frame1428、末回收最大frame1683。实际状态和几何范围列在machine-spec。

逐组直瞄线会穿过出生时自机坐标；rank3最短预警45帧。若玩家保持原位，它在预警后仍会被直瞄线覆盖。离开判定带所需中心位移为 `width/2 + player_hit_radius + hit_extra`；作者没有运行真实玩家检查器，未把该式换成动作速度保证，也未宣称所有随机实例可躲。

## 运行证据

编译命令：

```text
/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03
```

结果 `OK`，日志 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_03/check.log`。

完整矩阵均运行1860帧，退出码0：

```text
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 0 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 0 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 1 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 1 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 2 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 2 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 3 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --rank 3 --seed 7 --frames 1860
```

完整运行日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_03/final-run-r{0..3}-s{1,7}.log`。每份日志恰有一条诊断行；`task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 均存在且为0。各rank观测峰值为9/9/12/12，末帧1860激光为0，phase结束于1803。

machine-spec现有56个rank/frame关键帧（r0/r1/r2/r3分别14/16/13/13），以seed1和7快照合并得到计数、状态和几何边界。覆盖各档首生frame95及±1、实测末生±1、末次fade和精确自然回收零激光帧、frame1800空场。两seed逐档出生/回收为：r0 1418/1682、1407/1671；r1 1388/1649、1394/1655；r2 1365/1623、1356/1614；r3 1425/1680、1428/1683。实际日志在 `repair-r{rank}-s{seed}-f{frame}.log`，此前的关键帧日志在 `key-r{rank}-f{frame}.log` 与 `cross-r{rank}-s7-f{frame}.log`。

Round 1 自检使用 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_03/round1-selfcheck.json`，命令为 `UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_03 --json /tmp/sunyunbo/stg-laser-batch3/logs/aimed_03/round1-selfcheck.json`。结果 `MECHANICAL PASS · independent review pending (0 errors)`；观察首生95、末生1428、末回收1683，keyframe coverage与rank0/seed1 harness-trace对拍均无错误。报告日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_03/round1-validator.log`。本报告和四个SHA绑定此轮冻结文件。

正式专项机器门、真实自机移动 / 四边站桩检查以及非作者审查仍待协调者完成；本状态不表示正式机械验收、玩家避让通过、全部随机样本可行或训练收益成立。
