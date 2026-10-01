# aimed_04 作者交接报告

状态：**READY/FROZEN（作者阶段，仅作者自检）**。布局 `laser_sp_aimed_04`，契约 v1，split `held-out`。四个卡片文件已冻结；收到协调者返工要求前不再修改。

## 文件 SHA256

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `c466b5f6d096b3e04dfa852aa8bb8ad964bb686983fbc3fbb125d27e595124b7` |
| `meta.toml` | `b4bd074c8f84f8432d1577984f68c9233a1817cb6149d5179d650c442751cf29` |
| `TASK.md` | `0168cf6664eaf862ce25eacdfef0188307a288b670afe37d0d97733b31506bad` |
| `machine-spec.json` | `b24744cd2b2b612c3776d278b159c01e3a3f8574855b1762e00fda8d423a02b9` |

## 自检证据

- `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_04`：`OK`，输出保存在 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_04/check-final.log`。
- Round 2 补充 `--at 1800` 时限快照：rank0..3 × seed1/7 全部为 0 条激光，且六项诊断计数全为 0，日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_04/terminal-r{0..3}-s{1,7}-f1800.log`。逐 rank 末句柄收缩/回收边界也已双 seed 快照核对，日志为 `lifecycle-r*-s*-f*.log`。
- 项目专项 validator 自检：`UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_04 --json /tmp/sunyunbo/stg-laser-batch3/logs/aimed_04/round2-selfcheck.json`，结果 `MECHANICAL PASS · independent review pending (0 errors)`。该结果绑定本报告上方 SHA；协调者正式门和非作者独立审查仍待执行。
- 完整运行 `/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_aimed_04 --rank R --seed S --frames 1860`，`R=0..3`、`S=1/7` 共 8 组，全部退出码 0。每组都完整报告 `task_faults / contract_viol / pool_full / hits_ovf / events_ovf / reqs_dropped` 且六项全为 0。峰值激光 12 条；帧 1860 激光数为 0；段事件 `PHASE_ENDED@1803`。逐组日志为 `/tmp/sunyunbo/stg-laser-batch3/logs/aimed_04/r{0..3}-s{1,7}.log`。
- `--at` 关键帧对所有 rank、seed1/7 抽样了 94、139、184、334、1477、1478、1490；并在各 rank 最后句柄回收前后、1749/1750、1800 检查了收缩与空场边界。结果保存在同目录的 `at-r*-s*-f*.log`、`edge-r*-s*-f*.log`、`recheck-r*-s*-f*.log`、`lifecycle-r*-s*-f*.log` 与 `terminal-r*-s*-f1800.log`。machine spec 每个 rank 有 10 或 11 个唯一帧，包含出生预警、预警/生效边界、波次交接、并发峰值、实测末出生边界、逐 rank 最后收缩/回收和 1800 帧终点；正数量行列出 states 与完整几何字段。严格 JSON 解析、无重复键、`(rank,frame)` 唯一、元数据 split/layout 和正数量字段检查均通过。
- 跨矩阵观察到首次出生帧 94。协调者的独立逐帧 handle 追踪确定最后出生帧为 1478（seed7，各 rank）；harness 已追加 `--at` 帧 1477/1478 邻帧采样。逐 rank seed7 的末收缩/自然回收边界为 r0 1729/1730、r1 1734/1735、r2 1739/1740、r3 1744/1745；帧1800两种子各rank均为零激光。组间隔按 `72+rand(19)` 为 72..90 帧，单组 3 条、最坏 4 组重叠，测得峰值 12；`max_idle_gap=90`。
- 随机覆盖：`rand(3)` 选择首原点 `[-184,0,184]` 三处之一后轮转；另一个 `rand(3)` 选择侧线偏角 `{8°,16°,24°}`，左右对称。seed1 首组从 x=0 发出，角度 66°/90°/114°；seed7 首组从 x=184 发出，角度 100.55°/116.55°/132.56°，已实测位置和方向随机差异。激光出生后 speed/omega 均为 0，角度冻结。

## 尚未覆盖

没有运行真实移动自机的避让轨迹，也没有做固定角落/顶部的站桩生存测量。TASK 中的线带余量与角落评估是几何推导；真实动作速度、判定半径、各出生/偏角实例下的存活及站桩结果仍待协调者独立检查。本报告不代表专项机器门、独立审查、完整随机范围可解或训练收益通过。

Harness SHA256：`01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`。
