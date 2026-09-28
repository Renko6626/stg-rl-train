# Batch 2 independent Luna review: s4_b1 v2/v3

审查对象：`synth_laser_s4_b1_v2`、`synth_laser_s4_b1_v3`。审查依据为 `laser-pilot-contract.md`、两卡实际五文件、对应完整机器报告，以及当前文件 SHA256。作者未参与本审查。

## synth_laser_s4_b1_v2 — REVISE

机器门通过：`docs/practice-cards/reports/synth_laser_s4_b1_v2.machine.json` 报告 `ok=true`、`errors=[]`，rank 0–3 × seed 1/7 共 8 次运行通过；新增激光为 color 15，诊断计数均为 0，`last_expiry_frame=1920 <= time_limit=2400`。

脚本与契约核对通过：`overlay.ecl` 只创建一条有限激光，使用随机原点和 `lz_aim(lz, offset)`；未调用 `$self`、`aim_player()`、`spawn_enemy()`、`set_invuln()`；原点范围为 x[-100,100]、y[70,170]，宽度 6/8/10/12，warn/active/fade=60/45/12。报告关键帧显示 seed 1/7 原点与角度不同，且 124/184/214/228/240/254/364 的 geometry、状态、颜色与 machine-spec 一致。

发现一处规格文字不一致：`TASK.md:14` 写明帧 184 为 `state 0`，但实际机器报告及 `machine-spec.json:4` 均为 `state 1`（warn=60，出生帧123，帧184已进入 active）。建议把 TASK.md 的 `state 0` 改为 `state 1`；不修正前不冻结。

来源隔离通过：去除唯一 `SYNTHETIC_OVERLAY_ENTRY` 后，`main.ecl` 与 `cards/th06_s4_b1/main.ecl` 逐字一致；meta 的 `origin/source_ref` 与底子一致，provenance base main SHA 为 `a7b865ea947ddecfb64cae496130280295530aac3f6b5bd658d44349d7d1cd17`。

当前五文件 SHA256：

```text
TASK.md         a61ed3a479a842d49fc251f894854d459213fc92e787fd0b1c05e5f12f6e07ab
machine-spec    6ab95f8698c515cc82abcd2725e2ed90c9858cf63f84c904ddf9db55f457c6c7
main.ecl        17e880d54f187528084db6c937229b4387c0bfa60336d6ff7a9d5e75b54ad900
overlay.ecl     6976b7c7402ed38bb19490da858ec6578e4e80834fccd42b7e0b0b3631ee7013
meta.toml       a27a91d60c57d8028be6678c665a84acf75217135c07c59ddedc4b7478ba1f6e
```

## synth_laser_s4_b1_v3 — PASS

机器门通过：`docs/practice-cards/reports/synth_laser_s4_b1_v3.machine.json` 报告 `ok=true`、`errors=[]`，rank 0–3 × seed 1/7 共 8 次运行通过；新增激光为 color 15，诊断计数均为 0，`last_expiry_frame=1905 <= time_limit=2400`。

脚本与契约核对通过：`overlay.ecl` 使用随机原点/角度、`lz_omega(lz, 96bam)` 连续旋转，并在每次 `lz_origin` 前使用 `lz_alive`；未调用 owner 专属接口或创建额外敌人。原点移动为 `(x,y)` → `(x+32,y)` → `(x+32,y+24)` → `(x,y+24)`，范围与 machine-spec 一致；报告关键帧显示 seed 1/7 起点和角度不同，active/fade/回收时序、start/end、width、omega 与声明一致。

来源隔离通过：去除唯一 `SYNTHETIC_OVERLAY_ENTRY` 后，`main.ecl` 与 `cards/th06_s4_b1/main.ecl` 逐字一致；meta 的 `origin/source_ref` 与底子一致，provenance base main SHA 为 `a7b865ea947ddecfb64cae496130280295530aac3f6b5bd658d44349d7d1cd17`。

当前五文件 SHA256：

```text
TASK.md         1688f08d314e25dd0fb3098ff27656c27558ef33872455435acdb4b670715d77
machine-spec    f6a869f179748a6e9e31b7ca993e9403b6bfa5355203c8c28d75d6bfa6aa720e
main.ecl        17e880d54f187528084db6c937229b4387c0bfa60336d6ff7a9d5e75b54ad900
overlay.ecl     4a9a449f8c64d334313f5574b6631bbfdb58a7d4cfbb9ad74d7640188b66f783
meta.toml       6ea5e10819ac640af1725b77874ae59483506407738098245e5975b052dba0b4
```

## v2 复审 — PASS

作者已将 `TASK.md:14` 的帧184状态从 `state 0` 修正为 `state 1`。该修订与 `machine-spec.json`、实际机器关键帧及 `warn=60` 的计时一致，原 REVISE 发现已解决。

最终机器报告 `synth_laser_s4_b1_v2.machine.json` 为 `ok=true`、`errors=[]`；报告中的 `file_sha256` 与当前五文件逐一一致：

```text
TASK.md         fdc1430c918afff537964a7afd8d5d197623682905a174f5d451a9b42828b024
machine-spec    6ab95f8698c515cc82abcd2725e2ed90c9858cf63f84c904ddf9db55f457c6c7
main.ecl        17e880d54f187528084db6c937229b4387c0bfa60336d6ff7a9d5e75b54ad900
overlay.ecl     6976b7c7402ed38bb19490da858ec6578e4e80834fccd42b7e0b0b3631ee7013
meta.toml       a27a91d60c57d8028be6678c665a84acf75217135c07c59ddedc4b7478ba1f6e
```

v2 现为 `PASS`；v3 原 `PASS` 结论保持不变。
