# 首批激光合成卡独立审查（2026-09-27）

结论：两张卡当前产物均为 **PASS（激光规格与ECL几何审查）**。这是对本报告列出哈希对应版本的结论；合成卡仍只是训练候选，不表示策略可解或玩家能躲。

审查范围包括 TASK、machine-spec、meta、main、overlay 和对应机器报告。复核结果：每卡报告均覆盖 rank 0–3、seed 1/7 共 8 次完整运行；所有运行的 exit=0、诊断字段均存在且为 0，laser 峰值均为 1。机器报告逐关键帧记录的数量、state、宽度、原点、角度和 start/end 与 machine-spec 一致；末帧无新增 color 15 激光。另独立移除 main.ecl 中唯一的 `SYNTHETIC_OVERLAY_ENTRY` 行并与底子逐字比较，两卡均完全相同。

## synth_laser_s1_b1

- **PASS。** 根 main 只增加一个 `spawn synth_overlay()` 伴生任务；overlay 不创建敌人、不读 owner / 玩家瞄准接口，也不修改底子任务。9 轮有限循环于最后一次创建后等待 210 帧返回；按首帧 123、周期 210 计算，最后一次在 1803 帧出生，任务约 2013 帧结束，早于 2100 帧段时限。预警 60、active 90、fade 12，总寿命 162 帧，周期留 48 帧空档，实测峰值 1。
- 机器关键帧观察与预期一致：帧124仍为warn，帧184/214/254为active；第一条 `(-70,80), 90°`、start=0、end=400、width=8；帧334在 `(+70,80)` 出现下一条。末帧2160没有激光。
- **受审文件 SHA-256：**

  | 文件 | SHA-256 |
  |---|---|
  | TASK.md | `8556ad75fa3b8cc9b93df5f2e023d938d3c72b56a83bde51a382854835bcaab0` |
  | machine-spec.json | `18d582f3d8c824ab2ad062a35de1b7f6a26c4f71395ac71e1a8ab40bb7c10893` |
  | meta.toml | `f171396abc4ddf856f67f708a53f14cb71dbcdc5aa36bf1d74119b87bfa02cb3` |
  | main.ecl | `4a46d0172d5558e781279beb59fa22dfc49f770344a04e1b1e458c67fd91b426` |
  | overlay.ecl | `4e2052e1347986dc7f5d36221038cb4f32e6001eb3e54577e6040f9b9135e379` |

## synth_laser_s2_b1

- **PASS。** 根 main 只增加一个 `spawn synth_overlay()` 伴生任务；overlay 不创建敌人、不读 owner / 玩家瞄准接口，也不修改底子任务。6 轮有限循环于最后一次创建后等待 210 帧返回；按首帧 123、周期 210 计算，最后一次在 1173 帧出生，任务约 1383 帧结束，早于 1500 帧段时限。预警 45、active 120、fade 12，总寿命 177 帧，周期留 33 帧空档，实测峰值 1。
- 短棒参数与真实 `lz_speed` 语义相符：`speed=2px/frame, start_len=96px`，初始 end=0，warn期间也推进；帧124 end=4，帧184/214/254 分别为 end=124/184/264、start=28/88/168，符合 `start=max(0,end-96)`。原点固定，角度90°，width=8；帧334下一条出现在 `(+80,80)`。末帧1560没有激光。
- **受审文件 SHA-256：**

  | 文件 | SHA-256 |
  |---|---|
  | TASK.md | `8cdd28a082dccf298fda1f67fbfc7f9d99e78bffe88a783d205200301d825648` |
  | machine-spec.json | `c2bfe7c9a8066a596c27145bfbd704eccab1f2054dad409783e5d225718d3fbe` |
  | meta.toml | `e2def039a11cca861dbfd4abb189140d169280b1ea5244f5308d6512f1689d15` |
  | main.ecl | `66afe4aaac7e500ee92fa587fcec6225a84a067237a66c87fa73ad9acae9a04a` |
  | overlay.ecl | `9283576a0b8d3b765b25c402ab676debc1bc1cf656ce46a15605dd0e5de2b9d4` |

## 机器报告与范围

两份机器报告中的 `file_sha256` 与上表当前文件逐项相同，且 `ok=true`、errors为空。报告使用的 harness SHA-256 为 `01ea4b6cc8f1248e67eb9e09e291f8484a7eff551b2e962c7dc2719792de7730`，`stg_rl=0.4.0`。报告验证了声明的关键帧及末帧，并记录完整运行的峰值和诊断；这不是逐帧穷举 schedule。有限轮数与出生时刻还由我对照实际 ECL 循环、TASK 及完整运行报告复核。它不证明卡可解，也不替代训练效果评估。

本审查的首版曾发现 TASK 声明颜色与 ECL 实际颜色不一致；作者已将两个 TASK 统一为机器使用的 color 15，且上述哈希确认机器报告基于修订后的文件。旧报告中的颜色差异不适用于本次 PASS 结论。
