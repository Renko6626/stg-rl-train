# s6_b1 / s7_b1 独立交叉审查

审查者：Luna reviewer（与这两张卡的作者不同）。  
结论：**两张均 PASS**。我逐项核对 TASK、machine-spec、完整 main/overlay、metadata 和 Sol 机器报告，并检查报告里的所有已声明rank、seed及关键帧。没有修改卡片文件。

## synth_laser_s6_b1 — PASS

- TASK与脚本一致：共原点的向下V形双线，center由 `rand(161)-80` 抽取，开半角由15°加BAM随机量形成15°..35°，两线朝角为90°±开半角；rank 0..3宽度为6/6.5/7/8。60/90/12三段周期、每240帧重发，循环10次。第一条第123帧生，第二条第363帧生，最后一组第2283帧生；162帧后在2445回收，早于2700时限。
- 每个正数量关键帧都明确了count、state、width范围、x/y、angle范围与start/end；fade第273帧及回收第285帧也有规格。JSON没有重复键，`key_frames`没有重复帧。
- main仅含一条标记的 `spawn synth_overlay()`；去除该行后与底卡main逐字一致。底卡ECL SHA与provenance一致，source范围不与留出卡重叠。overlay只新增两条color15激光，不调用owner接口、不新增敌人；随机center/angle会使seed1与seed7的实测几何不同。
- metadata的source/data_kind/base_card/mutation_id、tags、origin/source_ref、ranks/time_limit和provenance均正确。底卡来源及文件哈希匹配。
- 机器报告状态为PASS，当前文件SHA与报告绑定值相同；8个运行覆盖rank0..3 × seed1/7，均exit 0、峰值新增2、6项诊断均为0。报告关键帧逐条符合spec，段末无color15激光。

文件SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `bf88c87b2399d913fed7e7500d031fddfcf5c86b49c52876b95ca22349829f35` |
| machine-spec.json | `276956a2977086ef09aa24392960903cf8b91dd8bb6b766865cfef78b8557d54` |
| main.ecl | `d937d1370de0f4396d62b3b2167cf882929975db5621bf269e0042bdc87f6c07` |
| meta.toml | `2ee8240f358b8ab29ac6d9f0447596c36d5bc4e365017e5d584f4130f3b6c4e8` |
| overlay.ecl | `d7397debdf2416006a9c9c3ffc7c6936bc2f0ecefc1ea16218e3897c44cae3c3` |
| machine report | `e6a218fc42a7e87da55c58cde90c7f89000f12e61080d8da732489bc9059144e` |

## synth_laser_s7_b1 — PASS

- TASK与脚本一致：Extra rank4 only，每轮一条短棒；origin x由`rand(201)-100`取[-100,100]，y=80，方向由60°加BAM随机量取60°..120°，速度按共享RNG取2或3px/frame，start_len=96。45/120/12时长、每210帧重发7轮。第一条第123帧生、最后一条第1383帧生、在1560回收，早于1800时限。
- 每个正数量关键帧都明确count、state、width、x/y/angle范围和start/end范围；末条fade第288帧、回收第300帧均有规格。JSON没有重复键，`key_frames`没有重复帧。
- main仅含一条标记的 `spawn synth_overlay()`；去除该行后与底卡main逐字一致。底卡ECL SHA与provenance一致，source范围不与留出卡重叠。overlay只新增color15短棒，不调用owner接口、不创建敌人；seed1/7实测origin/角度/速度不同。
- metadata保留Extra rank4、marks与time_limit；tags含laser，origin/source_ref和provenance与底卡一致。
- 机器报告状态为PASS，当前文件SHA与报告绑定值相同；运行覆盖rank4 × seed1/7，均exit 0、峰值新增1、6项诊断均为0。短棒的start/end按96px棒长推进，关键帧逐项落在spec范围；段末没有color15激光。

文件SHA256：

| 文件 | SHA256 |
|---|---|
| TASK.md | `52f7ecf34583b33ee34b8cab6840ad0e42f10b952f2b66b6d0d7d50f480c47ac` |
| machine-spec.json | `078ee17c6b783d8617d6dabb5344c4a3921e31a19901f77ad5bf8c437dac9a3a` |
| main.ecl | `1d6c5b9aa1910cf1924cd4b5c75f34d669f278bb8c4541765d7ce3631f2155b5` |
| meta.toml | `93181ad72a5860167153c05a81e66be2bfe65856b4a0ef116250c31209d732f2` |
| overlay.ecl | `ba357950ff369652a3577b0260428194e8a1ec7a286184d548caa56eb25547b8` |
| machine report | `680ce5317488db630b0e542af4d8ad27e8a07ed757d2fa32c6f359a4909cf9ac` |

## 限制

这次只独立审了s6_b1和s7_b1。通用验收器增强建议见 [tool-review.md](tool-review.md)；本轮两张卡自身的规格、血缘、参数、诊断和自然回收均满足当前契约。机器/脚本审查不证明策略可解或训练有收益。
