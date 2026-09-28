# Batch 2 独立审查：Stage 3 boss 非符 1

审查对象：`synth_laser_s3_b1_v2`、`synth_laser_s3_b1_v3`。依据为试产契约、各卡当前 TASK/spec/meta/main/overlay、完整机器报告及当前文件内容。两份机器报告均为 `ok=true`，覆盖 rank 0–3 × seed 1/7，诊断字段全为 0。

## synth_laser_s3_b1_v2 — REVISE

脚本和机器结果本身符合激光约束：`overlay.ecl:1-42` 只创建 color 15 的两条 width=8、warn=45/active=120/fade=12 竖直激光；`lz_origin` 更新发生在 `lz_alive` 守卫之后，未调用 `$self`、`aim_player`、`spawn_enemy` 或 `set_invuln`。机器关键帧确认首轮帧123出生、帧168进入生效，左右原点在帧184/216靠拢、帧248回到初始位置；峰值2，末帧1860为0。seed 1/7 的首轮原点/间距不同，颜色、宽度、方向、长度均符合 spec。main 唯一入口为 `main.ecl:93`；删除标记行后与 `cards/th06_s3_b1/main.ecl` 逐字一致。meta 的 synthetic/data_kind/base_card/mutation_id、原始 origin/source_ref、继承字段、laser 标签和 provenance SHA 均匹配，底子未与留出区间冲突。

需要返修的是任务规格与实际脚本不一致：`TASK.md:7` 写“每210帧一轮，共8轮”，但 `overlay.ecl:10` 的 `0..7` 实际执行7轮，且机器关键帧/实测出生为 123、323、523、723、923、1123、1323（间隔200），最后一轮在约1522帧回收；`machine-spec.json` 已按实际写为 7 轮的最后出生帧1323、回收帧1500附近。请只同步 TASK 的轮数、周期和最后一轮描述后重跑机器验收。

当前五文件 SHA256：

```text
TASK.md         5ba6a216478b2fb1ab8076eaecbabc563ad93b25ba62c85263eebb9807c6303f
machine-spec    eb2d96dfeef90515648cbaef9dd4376753d55e82a8f4c83de3b85e48ee78a52c
main.ecl        31ed943fc65f1b9a43245cbb7a3784256a879b5b516014782a56b3fb659f7682
overlay.ecl     2005062a70a311436725a3360e40d7a1c132e3dd2aa0ab3fab1a9623ec969988
meta.toml       0bce8702dcb6c9a82ffce0f510a333c95cd183a0fb68d3c683ca273ed076d17b
```

## synth_laser_s3_b1_v3 — REVISE

脚本和机器结果本身符合激光约束：`overlay.ecl:3-16` 每轮创建一条 color 15、width=8、方向0°、长度280、warn=60/active=90/fade=12 的水平激光；预警后延迟，再在 `lz_alive` 守卫下用 `lz_origin` 每帧平移。机器关键帧确认帧183出生、帧243/259/300 的 x 为 -70/10/215，帧351回收；峰值1，末帧1860为0。seed 1/7 的随机 y 不同，且没有 owner 接口或额外敌人。main 唯一入口为 `main.ecl:93`；去标记后与 `cards/th06_s3_b1/main.ecl` 逐字一致。meta 的 synthetic/data_kind/base_card/mutation_id、原始 origin/source_ref、继承字段、laser 标签和 provenance SHA 均匹配，来源区间隔离通过。

需要返修的是任务规格与实际脚本不一致：`TASK.md:7` 写“每轮间隔300帧，共6轮”，但 `overlay.ecl:5` 的 `0..5` 实际执行5轮，且机器关键帧/实测出生为183、383、583、783、983（间隔200）；最后一轮约1160帧回收。`machine-spec.json` 已按实际写为最后出生983、回收1160。请只同步 TASK 的轮数、周期和最后一轮描述后重跑机器验收。

当前五文件 SHA256：

```text
TASK.md         6ceebc86d4b2a315937ebf93a303bdc4a98f668fd1b75b20887290312af03cd5
machine-spec    44673a2c5413bff97cbfd2e5d7d18e19d40c256b7311f4b49dff801e9a5e9201
main.ecl        31ed943fc65f1b9a43245cbb7a3784256a879b5b516014782a56b3fb659f7682
overlay.ecl     0205b6c0bcde0b824807851a889b340f82e3fe97e12f13540c9ced98463a42b2
meta.toml       12d77e98e2f8730e4df9ac22eaefd0e95195021c5eac9b6cca917e41d8214e26
```

两卡均为 `REVISE`，原因仅为 TASK 的轮数/周期陈述与实际脚本及已通过机器报告不一致；未修改卡片、共享工具或其他报告。

## 复审（修订后）

作者已只修订两张卡的 TASK 轮数、周期和末轮描述，并由根代理重新生成机器报告。复核结果：两项发现均已解决，当前脚本实际循环与 TASK/spec 一致；没有发现新的激光语义、时序、来源或原作保留问题。

- `synth_laser_s3_b1_v2` — **PASS**。TASK 现在明确每200帧、7轮、末轮帧1323出生并约1500帧回收；与 `overlay.ecl:10` 的 `0..7`、machine-spec 的 `last_spawn_frame=1323` / `last_expiry_frame=1500` 及完整报告一致。机器报告 `ok=true`，当前五文件 SHA 与报告 `file_sha256` 全部一致。机器报告 SHA256：`6c0fe87e2157464f4666283c6d127f616aba6a86ef93558e38de374a603da3db`。

  ```text
  TASK.md         55aaeb6c7ae156dda63babd2cd5e44773fe25ec17843c5879cf60c31b159acbb
  machine-spec    eb2d96dfeef90515648cbaef9dd4376753d55e82a8f4c83de3b85e48ee78a52c
  main.ecl        31ed943fc65f1b9a43245cbb7a3784256a879b5b516014782a56b3fb659f7682
  overlay.ecl     2005062a70a311436725a3360e40d7a1c132e3dd2aa0ab3fab1a9623ec969988
  meta.toml       0bce8702dcb6c9a82ffce0f510a333c95cd183a0fb68d3c683ca273ed076d17b
  ```

- `synth_laser_s3_b1_v3` — **PASS**。TASK 现在明确每200帧、5轮、末轮帧983出生并约1160帧回收；与 `overlay.ecl:5` 的 `0..5`、machine-spec 的 `last_spawn_frame=983` / `last_expiry_frame=1160` 及完整报告一致。机器报告 `ok=true`，当前五文件 SHA 与报告 `file_sha256` 全部一致。机器报告 SHA256：`d44cf6047464551163786005288efc7b735dd88d5333f52681f60b5c399ad16a`。

  ```text
  TASK.md         5ba9cac186e2e69cec8f4044aada294f6f366d980d642a2d420cb8c3945ba7c9
  machine-spec    44673a2c5413bff97cbfd2e5d7d18e19d40c256b7311f4b49dff801e9a5e9201
  main.ecl        31ed943fc65f1b9a43245cbb7a3784256a879b5b516014782a56b3fb659f7682
  overlay.ecl     0205b6c0bcde0b824807851a889b340f82e3fe97e12f13540c9ced98463a42b2
  meta.toml       12d77e98e2f8730e4df9ac22eaefd0e95195021c5eac9b6cca917e41d8214e26
  ```

复审结论：两卡均由 `REVISE` 更新为 `PASS`；旧发现历史保留在上文。
