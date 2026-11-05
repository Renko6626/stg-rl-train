# TH18 单元编号与单卡验收

`stgtranscribe.validate` 已支持 TH06 与 TH18。TH18 沿用现有卡目录、`meta.toml` 和 JSON 验收报告；切分记录仍用 [split.md](splitting.md)，没有接入旧 TH06 批量状态机。

## 编号

| 单元 | 格式 | 编号依据 |
|---|---|---|
| 道中波次 | `th18_s1_w01`、`w02`… | 按已确认切分的出场顺序，击破速度奖励波也独立编号 |
| 中 Boss 攻击 | `th18_s1_mb1`、`mb2`… | 非符和符卡合在一起按实战顺序编号 |
| 关底 Boss 攻击 | `th18_s1_b1`、`b2`… | 非符和符卡合在一起按实战顺序编号 |

`s1`–`s6` 是普通六关，`s7` 是 Extra；难度另写 `ranks`，编号中的序号也不是原作 spell ID、sub 名或 EX 编号。工具接受一至两位序号，派发时统一从 1 开始，道中使用两位。整关审阅确认后再固定编号；已派发或已收卡的单元不因后来补漏而自动重排。

同一攻击的难度版本通常共用一个编号，代码按 rank 分支，元数据列实际支持的连续区间。确需拆成多张卡时分配不同序号，并在切分表记录各自对应的原作入口与难度；不要给不连续区间补上不存在的难度。Extra 的源难度到目标 rank 由任务单明确，不根据 `s7` 自动推断。

`brief.md` 必须给出最终 `unit_id`、对应切分记录、可读原文和可写目录。单元编号须与卡目录名一致，`meta.toml source="th18"`；不能伪装成 TH06。验收器检查编号格式与 source，不检查整关覆盖、编号是否重复代表同一源攻击或源边界是否正确，这些仍由切分审阅负责。

## 卡目录与元数据

作者继续交付 `out/main.ecl`、所需词表/辅助 `.ecl`、`out/meta.toml` 和 `out/report.md`。在任务单允许的 `card/<unit_id>/` 建立验证副本，复制全部 `.ecl` 与元数据；更新或删除源文件后同步该副本，避免残留旧程序。正式收卡仍需另行安排。

下面是字段格式示例，标题、原文位置、rank 和时限必须换成本次任务的真实值：

```toml
title = "Stage 1 道中 第 1 波"
source = "th18"
origin = "TH18 v1.00a Stage 1，道中波次；具体入口见任务单"
source_ref = "st01.ecl.txt:100-180"
ranks = [0, 3]
marks = [0]
time_limit = 3500
original_time_limit = 3200
tags = ["aimed", "stream"]
laser_approx = false
lower_half_blocked = false
notes = "源/卡帧换算、尾部预留和已接受差异见 report.md"
```

`source_ref` 写真实源文件/行区间，多文件依赖在报告中逐一列出。`original_time_limit` 保留原计时或注明依据的源段估计，`time_limit` 是目标外壳从开段计时点到结束的预算，包含计时期间的缓冲与尾部；两者不要求相等。代码须有字面量 `const TIME_LIMIT: int = …`，与元数据一致，不得为了旧上限截短原攻击。`laser_approx` 等字段如实填写，不因字段存在就获得新的近似许可。

沿用现有标签：`aimed/random/ring/spiral/wall/curve/split/stream/dense/fast/mixed/laser`。`curve` 标签不是曲线激光的转写许可；实际依赖曲线激光的攻击仍暂缓。

## 执行

先按任务单同步验证目录，再从训练仓执行：

```bash
uv run --frozen python -m stgtranscribe.validate \
  transcribe/work/th18/stage01/w01/card/th18_s1_w01 \
  --json transcribe/work/th18/stage01/w01/out/validate.json
```

路径示范采用稳定的关卡/单元目录，不要求预先存在。引擎位置由 `STG_ENGINE_DIR` 或现有配置确定，使用其 release harness。新弹型要求同批 ENGINE_VER31 表及配套 wheel；`TH18_*` 是普通常量，所需定义要放进卡目录，验收器不会自动注入。

退出码：0=自动检查通过，1=验收有错误，2=命令用法错误。报告沿用 `card/errors/warnings/runs/opening_death_rate/ok`；`runs` 按 rank 记录退出码、弹数峰值、诊断与段结束帧。`--skip-rl` 只供定位问题，会跳过开场安全，不能把这一结果当作完整自动验收。

## 检查规则

| 项目 | TH18 | TH06 现有规则 |
|---|---|---|
| 编号 / source | `th18_s…` / `th18`，两者须一致 | `th06_s…` / `th06`，两者须一致 |
| 目标时限 | 1–65535 帧；上限来自引擎 u16 计时字段 | 1–3000 帧 |
| 弹数峰值 | 报告实测值，不以 1024 拒收或要求减路数 | 超过 1024 报错 |
| 实体池耗尽 | `pool_full` 报错，实际发射已丢失 | 相同 |
| 运行 | 每个声明 rank 跑到 `time_limit+300`；编译或运行失败报错 | 相同 |
| 段结束 | 须有 `phase_begin/spell_begin`；最早结束事件在卡帧 `[120,time_limit+60]` | 相同 |
| 训练外壳 | 须有 `set_invuln(65535)`、`marks=[0]`；难度用 `global(GVAR_RANK)` | 相同 |
| 开场安全 | 各 rank 的 32 局自机随机移动，前 120 帧死亡率不得超过 10% | 相同 |
| no-op 诊断 | `contract_viol` 保留为警告，审核时逐项解释 | 相同 |

通过只说明目标程序满足这些机器检查。源语义、原作弹型/半径、入口状态、随机共享和数值锚点仍按[审核契约](contracts/review.md)独立核验；原作动态对拍、训练效果和自动收卡也须分别报告。此入口不启动训练，不替代现代 ECL 切分覆盖检查。
