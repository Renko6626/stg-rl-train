# Batch 2 独立审查：S5W05 / S7B1

审查者：独立 Luna reviewer（未编写以下卡片）。

审查范围：各卡当前 `TASK.md`、`machine-spec.json`、`meta.toml`、`main.ecl`、`overlay.ecl`，以及对应最终机器报告。机器报告均为 `ok=true`；本审查另外核对激光 API 的实际语义、底子还原、来源字段和报告哈希。

## synth_laser_s5_w05_v2 — PASS

脚本在 `overlay.ecl` 中只创建一条 color15 激光，`laser(..., 300px, 8px, 45, 120, 12)` 后以 `lz_start(120px)` 保留远端 180px 判定段，并以 `lz_omega` 连续旋转。预警、生效、收缩三态持续旋转符合引擎语义；机器报告关键帧的 state、start=120、end=300、width=8 与此一致，帧300后无新增激光。

随机初角和旋向各由共享 RNG 抽取；seed 1/7 的初角与后续轨迹不同。rank 0..3 仅改变 BAM 角速幅值，范围 `[40,56,80,112]` 合法。生命周期为 `45+120+12=177` 帧，出生123、最后自然回收299，早于600时限。

底子 `main.ecl` 只有一行允许的 `SYNTHETIC_OVERLAY_ENTRY`；移除该行后与 `cards/th06_s5_w05/main.ecl` 逐字一致。`source/data_kind/base_card/ranks/marks/time_limit/origin/source_ref/provenance` 与底子和契约一致，机器报告文件哈希与当前五文件一致。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `7894d02c443c23a83202577344ced5c9bd8d64d86c98eb6d4380513b87e4928f` |
| machine-spec.json | `b7df4abfbd36607046c3e320eb51640fc6a128de692b875bcdbcaa87e95fce0b` |
| main.ecl | `72d6bb9427273f8bede3bcb8b51aae818cd653bee0305887e786aa1395474e97` |
| overlay.ecl | `1135c49a071fdb4468d59f815dab5e8e5c90ec73623dd3cef695e2af28561fee` |
| meta.toml | `da96bf5063bbb3c5b8ad2f10593a5e6ff4b2e98d97e1b894def657c8dc4ad62e` |

## synth_laser_s5_w05_v3 — PASS

脚本创建一条 color15、width8、长度144px的固定方向斜段，并在有效句柄上每帧调用 `lz_origin` 沿第二个随机方向移动原点。`lz_origin` 会解除挂靠且不会改变段的 start/end；报告关键帧显示 start=0、end=144、方向角固定、原点随帧移动，符合实际 API 语义。warn=45、active=96、fade=12，帧276后已回收。

初始角、漂移角、初始 x/y 均来自共享 RNG；seed 1/7 的原点和方向均不同。移动分量是单位向量乘每帧1px，满足声明的分量上限。循环在96次更新后自然结束，句柄均以 `lz_alive` 守卫，未创建额外敌人或使用 owner 专属接口。

底子入口、逐字还原、来源隔离、继承字段和 provenance 哈希均正确；最终机器报告哈希与当前五文件一致，所有 rank/seed 运行诊断字段为0。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `6622159aa005efec7a960356631ff8a47e34306e64763d1a32bcef9540c05556` |
| machine-spec.json | `033938961df42c95a1017237070c443cad04090f2fb47fcf03fe2de56033d989` |
| main.ecl | `72d6bb9427273f8bede3bcb8b51aae818cd653bee0305887e786aa1395474e97` |
| overlay.ecl | `055ab03b0f25212b21147c8b5ec22a4bffa0eab3e98a49d91a030f81d50d4d0b` |
| meta.toml | `49936b5a27cb0c4d8623a66400e5e2bd592ed0d7d76f65fd4b3f56b65d0d8814` |

## synth_laser_s7_b1_v2 — REVISE

实现本身满足引擎语义：每轮三条 color15 短棒，`lz_speed` 将长度设为72px，warn=45、active=100、fade=12；原点和速度/角度随机化，seed 1/7 的 y、方向和端点推进均可观察，最大同时激光数为3，Extra rank4 与底子继承正确。底子入口、逐字还原、来源隔离、机器报告哈希和诊断字段均通过。

需要修订任务规格文字与辅助范围字段：`overlay.ecl` 使用 `78deg + (rand(6553) as angle)`，其中 `rand(6553)` 约覆盖0..36°，再叠加左右 ±12°，实际单条方向范围约为66..126°。TASK 当前写成中心角78..87°，`machine-spec.json` 的辅助 `angle_deg_range` 写成[54,111]；这两处都不能准确描述实际脚本。正数量关键帧使用的54..126宽范围覆盖当前报告，但不能抵消声明字段与实现不一致。建议把 TASK 中心角改为78..114°、单条方向改为66..126°，并将辅助范围同步为[66,126]，随后重跑机器验收以刷新绑定哈希。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `822201db37b372f7d79420e4cda2fdbe643d9e066d5bce836a7c4b3ed1bdb498` |
| machine-spec.json | `3421818aae2e0f6c5a268dd975740c85925194fb7898ae3056090c38602f2db7` |
| main.ecl | `1d6c5b9aa1910cf1924cd4b5c75f34d669f278bb8c4541765d7ce3631f2155b5` |
| overlay.ecl | `6058ebbe20efd81166156c65510c5e644d107926405827b7a6116aa64b857e51` |
| meta.toml | `cad2ff7cd036d5a7533304bca7677f8e92bd8c6468ce053546f1dea63329206b` |

## synth_laser_s7_b1_v3 — REVISE

实现本身满足相向水平短棒语义：左右原点分别以0°/180°沿相反方向推进，`lz_speed` 将棒长设为96px；color15、width10、warn=50、active=105、fade=12，随机 y 和2/3速度，seed 1/7 的几何及端点不同。机器关键帧显示相向方向、start/end 推进、三态和帧300空场均正确；底子还原、来源字段、哈希和诊断字段均通过。

需要修订 TASK 的时间文字矛盾：其正文写“每条自然回收约1690帧”，随后又明确写 `last_expiry_frame=1590`，而实际生命周期计算为最后出生1423加 `50+105+12=167`，即1590；machine-spec 也声明1590。应删除或改正“1690”，然后重跑机器验收以刷新任务文件哈希绑定。该问题不改变当前脚本运行几何，但会误导独立复核的回收边界判断。

当前五文件 SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `08615a11daff4bc341500322385a8a27f7e9a44531a4cc1c2db945dcd02e5e2e` |
| machine-spec.json | `a421c0158ebaea0f8f1b8144b3f69d9f2e1e2cfd008f0f5e38714e94e323d5e9` |
| main.ecl | `1d6c5b9aa1910cf1924cd4b5c75f34d669f278bb8c4541765d7ce3631f2155b5` |
| overlay.ecl | `f8f70516c0e8389b093581878899a1dcafc948933ba15ed8397ac95b03e9098e` |
| meta.toml | `9771793f16a2c82cd7e25d3e4ca8b802cfa4b5ea6140a2853a58ce1160b67ccf` |

以上结论只覆盖当前哈希；任何脚本、TASK、spec 或 metadata 修订都需要重新运行机器验收并更新审查结论。

## 复审（s7_b1_v2 / s7_b1_v3）

根代理已按上述发现修订并重新运行最终机器验收。本复审读取了当前五文件和最终机器报告，并逐项比对报告内 `file_sha256` 与磁盘 SHA256；两卡报告均 `ok=true`、`errors=[]`。

### synth_laser_s7_b1_v2 — PASS（复审）

TASK 已将中心基准角改为78°..114°，并明确单条方向覆盖66°..126°；`machine-spec.json` 的辅助 `angle_deg_range` 也已改为 `[66,126]`。这与脚本 `78deg + (rand(6553) as angle)` 加左右±12°的实际语义一致。最终机器报告仍覆盖 color15、三条短棒、warn/active/fade、seed 1/7 几何差异和无诊断错误。

当前五文件 SHA256（与最终机器报告一致）：

| 文件 | SHA256 |
|---|---|
| TASK.md | `2b0337ff1c57463363a52a3bfd2ddac43baf40db1e1760c25e719b65ae88e70c` |
| machine-spec.json | `97191a1a13e2cdea2415383e7380768411e1fdd8ea1449e36722c33ca7ffe692` |
| main.ecl | `1d6c5b9aa1910cf1924cd4b5c75f34d669f278bb8c4541765d7ce3631f2155b5` |
| overlay.ecl | `6058ebbe20efd81166156c65510c5e644d107926405827b7a6116aa64b857e51` |
| meta.toml | `cad2ff7cd036d5a7533304bca7677f8e92bd8c6468ce053546f1dea63329206b` |

### synth_laser_s7_b1_v3 — PASS（复审）

TASK 已将“约1690帧”修正为“约1590帧”，并继续明确 `last_expiry_frame=1590`。该值与最后出生帧1423加 `warn 50 + active 105 + fade 12 = 167` 的自然回收计算一致；最终机器报告和 spec 均保持1590，报告无错误。

当前五文件 SHA256（与最终机器报告一致）：

| 文件 | SHA256 |
|---|---|
| TASK.md | `9cf19886e8c9f95010c8baa5feeaf63ca5c295138c2b6af1cb983fe3f6263601` |
| machine-spec.json | `a421c0158ebaea0f8f1b8144b3f69d9f2e1e2cfd008f0f5e38714e94e323d5e9` |
| main.ecl | `1d6c5b9aa1910cf1924cd4b5c75f34d669f278bb8c4541765d7ce3631f2155b5` |
| overlay.ecl | `f8f70516c0e8389b093581878899a1dcafc948933ba15ed8397ac95b03e9098e` |
| meta.toml | `9771793f16a2c82cd7e25d3e4ca8b802cfa4b5ea6140a2853a58ce1160b67ccf` |
