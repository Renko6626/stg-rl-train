# Batch 2 独立审查：synth_laser_s5_b1_v2 / v3

审查角色：独立 Luna reviewer。审查对象不是本审查者编写的卡片。

依据：`laser-pilot-contract.md`、`2026-09-28-batch2-plan.md`、两卡当前五文件、底子 `cards/th06_s5_b1/`、以及当前机器报告 `synth_laser_s5_b1_v2.machine.json` / `synth_laser_s5_b1_v3.machine.json`。

## 结论

| 卡片 | 结论 | 机器报告 |
|---|---|---|
| `synth_laser_s5_b1_v2` | PASS | `ok=true`, `errors=[]` |
| `synth_laser_s5_b1_v3` | PASS | `ok=true`, `errors=[]` |

## 审查证据

### synth_laser_s5_b1_v2

- `overlay.ecl` 只创建 color 15 激光，`len=360`、`width=6/8/10/12`、`warn/active/fade=45/120/12`，并在每个移动写口前检查 `lz_alive`；未使用 owner 专属接口。
- 原点由每轮独立 RNG 采样：`x∈[-180,-60]`、`y∈[190,310]`。预警结束后每帧向右平移 2px，实际对应 `lz_origin`；seed 1/7 的机器关键帧显示不同起点。
- 关键帧报告覆盖 warn、active、fade、回收和下一轮出生；新增激光峰值为 1，末帧激光为 0。所有 rank/seed 运行诊断计数均为 0。
- `first_spawn_frame=123`、`last_spawn_frame=2523`、`last_expiry_frame=2700` 与 TASK/spec 一致，未超过 `time_limit=2700`。

### synth_laser_s5_b1_v3

- `overlay.ecl` 每轮创建两条 color 15 竖门，第二条在第一条后 30 帧出生；两条使用独立 RNG x 坐标，角度 90°、长度 500、宽度按 rank 分档，warn/active/fade 为 45/90/12。
- 机器关键帧确认 123/153 错峰出生、198 同时 active、270 第一条仍 active、298 第二条 fade、300 回收；seed 1/7 起点有差异。
- 生命周期结束后用 `lz_alive` 守护 `lz_cancel`；机器报告显示新增激光峰值 2、time_limit 末帧无新增激光，诊断计数均为 0。
- `first_spawn_frame=123`、`last_spawn_frame=2553`、`last_expiry_frame=2700` 与 TASK/spec 一致。

## 来源与底子隔离

- 两张卡 `main.ecl` 相对 `cards/th06_s5_b1/main.ecl` 仅新增一行标记入口：`spawn synth_overlay(); // SYNTHETIC_OVERLAY_ENTRY`。
- 两卡 `meta.origin`、`source_ref` 与底子完全一致；`source=synthetic`、`data_kind=synthetic`、`base_card`、`mutation_id` 和 provenance 均存在，底子 `main.ecl` SHA256 为 `9d2242b1badc5b15845723961268e7bb3c5666d750df2d6233422c9eb1b7a67a`。

## 当前五文件 SHA256

### synth_laser_s5_b1_v2

```text
TASK.md         992aeb0f4bb343b515a216bd7c0efb273df1ec08b94fe0e219d6f3f43ea2aba9
machine-spec    108680e65fdb14dfbdc95c542a5532dd75f1c64402a452a86c6ff58078104525
main.ecl        b6195d692358d23126a36ff9f4e1d1c486abeb582774f5e035361a5f77a8d2a1
overlay.ecl     6cbab5b78f29dc7249b70070fba92b32a2b32165e37beef35273b1573ae495b4
meta.toml       2e11599eea29e4c9f9917be7c20bc2ff6d4f90790ca1ef8fac4b4c03f831df8d
```

### synth_laser_s5_b1_v3

```text
TASK.md         53377f05b3585c44f2e9a7a4a8fe32193de84e90a7e936c237a78b88d05ee0a2
machine-spec    caaf8e37699e706afd53b19c198ef429c612dd569dbd4344cd6c51d4eb2b2c13
main.ecl        b6195d692358d23126a36ff9f4e1d1c486abeb582774f5e035361a5f77a8d2a1
overlay.ecl     275d71c51e9144300490cceab0873e345029f8d91caea7770d347e9aaaabdbb8
meta.toml       2e111cab2df39674011901e1eb8182bbf1f89095a8db132d436722f989c31bcc
```
