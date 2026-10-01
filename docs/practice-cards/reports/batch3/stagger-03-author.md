# laser_sp_stagger_03 作者阶段报告

**状态：READY/FROZEN（仅作者阶段）**。四文件已冻结于 `/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_03/`。真实玩家避让/站桩检查与非作者完整脚本审查尚未完成；此状态不表示正式验收、全随机实例可解或训练收益。

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `738c7fcf2f5434229363fb67596b11da50c473f73021d1152eb4acfa40076c8c` |
| `meta.toml` | `9feee67b761abb3e48653bbb6b48fdf8365c2c5d25a775b791b439789a318f2e` |
| `TASK.md` | `9c7927b36d2cf12c1d6be7f4096048ad52e280bdd64c70bf79948bb5788329f4` |
| `machine-spec.json` | `fca3873924935837dbbb56a00154a19e42b33e530518912618d9a05e65afc9e9` |

`stg-harness` SHA256：`01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`。

## 作者阶段证据

- 编译：`/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_03`，退出码 0，`OK`；输出保存在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_03/frozen_check.log`。
- 完整矩阵：rank 0..3 × seed 1/7，各运行 `--frames 1860`，8/8 退出码 0。每份日志恰有一行诊断，`task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 均存在且为 0；观测激光峰值 12，frame 1860 激光数 0。日志在 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_03/frozen_run_r{0..3}_s{1,7}.log`。
- 关键帧：最终快照按两个种子实测，machine-spec 有 44 个唯一 `(rank,frame)` 条目、每 rank 11 个；覆盖首生前/首生、warn 到 active 边界、frame 290/780 的三组交叠、末组出生前后、最后 fade 和自然回收、frame 1800。正数量项都列出 states 与实测 x/y/angle/width/start/end 范围；JSON 无重复键或重复 rank/frame。日志路径模式为 `/tmp/sunyunbo/stg-laser-batch3/logs/stagger_03/frozen_at_r{0..3}_s{1,7}_f<frame>.log`。
- 时序和峰值：首条 frame 94（frame 93 为 0 条）；每 98 帧一组，共 15 组，末组 frame 1466（frame 1465 为 8 条，1466 为 12 条）；自然回收 rank0..3 分别为 1718/1723/1728/1733，最后回收时限不晚于 1733；非符段结束事件为 frame 1803。最大可见/存活实测 12，预算为 16/20。
- 随机化证据：seed1 与 seed7 同 rank 的 frame94 垂直组 x 坐标分别为 `[-163,-67,29,125]` 与 `[-137,-41,55,151]`，角度/颜色相同，证实位置随种子变化。随机端点和联合约束见冻结 `TASK.md`；两个种子不代表全随机范围。

## 尚未覆盖

作者只做基础 harness 自检。交点处真实可达路线、动作映射与方向 hold/delay 的逐帧影响、边界附近的存活及长时间站桩结果，均待独立避让检查器验证；无全范围可解或训练收益结论。作者阶段不替代非作者审查及协调者最终决定。
