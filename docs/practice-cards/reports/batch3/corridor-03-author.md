# corridor_03 作者交接（contract v1）

作者阶段状态：`READY/FROZEN`（round 1）。此状态只表示卡片与基础 harness 自检完成，不表示正式机器门、真实玩家可行性、非作者审查或最终纳入通过。round 1 只澄清出生周期与实际无威胁空档的区别，不改变几何。下列 SHA 是本轮冻结快照；收到协调者返工前不再改卡片。

卡片目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_03/`

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `0bb5dbd2697b9bc271420a80178d0547e64e343f14afd8471a3b8bdfabd44a66` |
| `meta.toml` | `9edc3ebd6a18f0b0c8245b1bbae34e6fe616c8f3e3e5ab3d97acaa6baa659f59` |
| `TASK.md` | `6e938e665186a7af0aba01b06d2fe2df588d6c59cffa15022482f9cc9afb43d6` |
| `machine-spec.json` | `4fdad8aa85befa55a5270bb5a72079180faeac6b17c7ea965f987e44c66d017d` |

## 作者自检证据

- `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_03` → `OK`。
- `/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_03 --rank R --seed S --frames 1860`，`R=0..3`、`S∈{1,7}` 共 8 组，全部退出 0；六个诊断 `task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 每次各出现一次且为 0。每组均为 `PHASE_ENDED@1803`，帧 1860 激光数为 0，激光峰值为 8。
- `.venv/bin/python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_03 --json /tmp/sunyunbo/stg-laser-batch3/logs/corridor_03/specialist-validate-r1.json` → `MECHANICAL PASS · independent review pending (0 errors)`。实测边界为 visible/live 峰值 8/8、`max_idle_gap=0`、首出生 95、末出生 1481、末回收 1721；完成 8/8 运行。该报告 SHA256 为 `1555bcaf4a30ac1cac3ffa4ace6920506ebd7b9cad2c392d71a13589bd7f977c`。
- `/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_03 --rank R --seed S --frames 1860 --at F` 采集了关键帧及额外运动边界快照。`machine-spec.json` 共 44 个唯一关键帧，11 个/rank；覆盖首束预警、交接、生效移动、最大重叠、中段、末束、收缩/回收和 1800 帧。
- rank 3、seed 1 的首对边界线在帧 95 预警时法向 q 约 −134px；帧 319 到 active timer 180 时约 q=46px，角度仍为 45°，对应约 180px 连续位移。帧 320 同一对进入 fade、原点保持，核对了 active 期运动停止及自然收缩。seed 1/7 在各 rank 第二束波的几何快照不同；这只证明已采样的随机实例存在差异。
- 日志与快照：`/tmp/sunyunbo/stg-laser-batch3/logs/corridor_03/`。全时长输出为 `full-r<R>-s<S>.txt`，快照为 `at-r<R>-s<S>-f<F>.txt`，编译输出为 `check.txt`；自检汇总脚本为 `run_evidence.py`。

## 参数和范围摘要

家族为纯激光平移斜走廊。每波两条 45°、长 640px 的平行线，法向间距与方向固定；原点在 active 期沿 135° 法向以 0.72/0.80/0.90/1.00px/f 连续移动 180 帧，波次方向交替，首波方向随机。逐档 pitch 为 72/64/58/56px；计入 width 6/8/10/12px、自机半径 2.5px 和 hit_extra 2px 后，净通道为 57/47/39/35px，较冻结下限 48/40/32/28px 多 9/7/7/7px。

每波消费 `rand(49)`，单位为 px、整数闭区间 `[-24,24]`；首波偏移固定 −24px，末波固定 +24px，中间波随机。波次中点逐波从 rank 区间 `[-8,329]`、`[-8,324]`、`[0,316]`、`[8,309]`px 线性推进。实际中心路径（含 `±24px` 抖动和整段移动）保持在内区投影范围内，首末波边界扫过真实场地四角。相邻出生周期为 84/78/72/66 帧；这是发射节奏，不是空档。`max_idle_gap` 表示首个预警后到末次预警/生效结束前，完全没有 state 0/1 激光的最大内部帧数。本卡实测为 0：每档下一波预警都在前一波生效结束前出现；fade 不计可见威胁，开场和结尾不计内部空档。最长寿命下预警/生效及含 fade 峰值均为 8 条，低于 16/20 预算。

实测时序如下：

| rank | 出生周期/波数 | 首出生 | 末出生 | 最后自然回收 |
|---:|---:|---:|---:|---:|
| 0 | 84 / 17 | 95 | 1439 | 1721 |
| 1 | 78 / 18 | 95 | 1421 | 1688 |
| 2 | 72 / 20 | 95 | 1463 | 1715 |
| 3 | 66 / 22 | 95 | 1481 | 1718 |

## 待协调者完成

真实玩家动作/判定下的避让轨迹、站桩与边界检查尚未执行；seed 1/7 不能覆盖完整随机参数范围。非作者源码审查、正式专项机器门、加载器兼容和最终纳入仍待协调者完成。本报告不声称全域可躲或有训练收益。
