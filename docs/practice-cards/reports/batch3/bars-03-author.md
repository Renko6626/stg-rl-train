# laser_sp_bars_03 作者返工记录（Round 2）

**状态：READY/FROZEN（作者阶段）**。最终四文件快照通过专项机械门。validator 的 `acceptance_status` 为 `mechanical_pass_independent_review_pending`；源审查和真实玩家可行性/固定位置基线仍由协调者复核。卡片冻结，后续修改须由协调者解冻。

| 文件 | SHA-256 |
|---|---|
| `main.ecl` | `d4bd04fcdf5e4454a74fa7b11a8ff2e9e61d934db19959458dcec3101ebcf94f` |
| `meta.toml` | `562093f086ed4b808d729a576ed012f33cf7ac51011d67b6e7f9872d7176e805` |
| `TASK.md` | `537a3c968e6a05ad56b7efbf7e93d04e39187654129d6dafcc0fad51a47c8e7c` |
| `machine-spec.json` | `8012636eff19d8b86f0930b5f0987848fda95b8fde4c8fa94a6b2f88a113bfb2` |

Round 2 扩大了所有四向对角线的法向 lane 支持。每波的 lane centers 是 `[32,128,256,384]px`，每对仍错开64px；四种入射方向的 base intercept 集合覆盖 player field 相关的 `[-192,640]`，相邻中心最大间距64px。每对共用 `n∈[-24,24]px` 的闭区间法向位移，随机支持带宽跨过相邻 intercept 带；不会把一条随机偏移独立加到 pair member 而缩窄 gap。中心 `(0,224)` 和左上 `(0,0)` 都有确定性 lane/intercept 支持，外缘线在 Easy 总扫过最小272px，可到达从边界到中心的271.53px路径。没有以单独一条坐标补丁线覆盖审查点。

机械验证和源码几何证据：

- Harness `check` 返回 `OK`；rank0–3 × seed1/7 的 8 次 `--frames 1860` 全部退出0，六诊断全零。峰值visible/live为 `8/8, 7/7, 6/6, 6/6`；内部空档为0。
- 使用引擎同版 `laser-trace` 对八条无输入完整轨迹扫描全部1860帧。active有限段到中心 `(0,224)` 的最小线距 rank0–3 × seed1/7 分别为 `2.828/2.828`、`2.828/2.828`、`2.828/2.828`、`2.828/2.828` px；到左上 `(0,0)` 分别为 `3.533/0.707`、`3.533/0.707`、`3.534/0.707`、`3.536/0.707` px。对应碰撞 reach（激光半宽 + 玩家半径）为5.5/6.5/7.5/8.5px。中心/左上交会发生帧因各 group 的法向随机值而不同；这是两个种子实际几何证据，不代表所有实例可解，也不替代真实玩家基线。
- `machine-spec.json` 对每 rank 有16个关键帧，覆盖首波、交接、warn/active边界、中心与边角交会样本、峰值/中段、末波、fade、最后 handle 精确回收和frame1800空场；范围合并 seed1/7 快照。
- `.venv/bin/python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_bars_03 --json /tmp/sunyunbo/stg-laser-batch3/logs/bars_03/specialist-validate-r2.json`：**MECHANICAL PASS · independent review pending (0 errors)**。报告SHA-256：`58ac6fe5fc8d18126043b591363be6613573c8ac25f002c51d8aeca1cbcbf9df`；其 `file_sha256` 与上表一致，rank0/seed1的16个关键帧与 harness 对拍无错误。

实测首/末出生为帧95/1397，末 handle 回收帧1709，内部无 state0/1 空档0；所有值在契约预算内。真实玩家可行性、固定位置站桩门与非作者语义复审未由作者运行或代替。机械采样不是全部随机值可解证明，也没有训练收益结论。
