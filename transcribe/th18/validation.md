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

`task.md` 必须给出最终 `unit_id`、对应切分记录、可读原文和可写目录。单元编号须与卡目录名一致，`meta.toml source="th18"`；不能伪装成 TH06。验收器检查编号格式与 source，不检查整关覆盖、编号是否重复代表同一源攻击或源边界是否正确，这些仍由切分审阅负责。

## 卡目录与元数据

作者直接交付 `card/<unit_id>/main.ecl`、所需辅助 `.ecl` 和 `meta.toml`；作者说明放任务根 `report.md`。这是一份工作代码，验收和审核直接读取，不再复制out。正式收卡仍需另行安排。

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

`source_ref` 写真实源文件/行区间，多文件依赖在task/source保留定位，报告仅写必要差异。`original_time_limit` 保留原计时或注明依据的源段估计，`time_limit` 是目标外壳从开段计时点到结束的预算，包含计时期间的缓冲与尾部；两者不要求相等。代码须有字面量 `const TIME_LIMIT: int = …`，与元数据一致，不得为了旧上限截短原攻击。`laser_approx` 等字段如实填写，不因字段存在就获得新的近似许可。

沿用现有标签：`aimed/random/ring/spiral/wall/curve/split/stream/dense/fast/mixed/laser`。`curve` 标签不是曲线激光的转写许可；实际依赖曲线激光的攻击仍暂缓。

## 训练外壳

以下是独立波次的完整最小外壳。control只负责段事件，不是原作敌人，放在(0,0)并关闭体碰；真实敌在缓冲后创建，按本卡原文设置框、移动和发射。也可由真实Boss承载phase/spell，按任务指定方式组织，不必统一改已有卡。

```ecl
const TIME_LIMIT: int = 360;
const OPENING_BUFFER: int = 120;

async sub source_enemy() {
    set_invuln(65535);
    // 仅为外壳示例。转写时替换为本卡判定、运动和发弹。
    set_hitbox(12fx);
    set_hurtbox(16fx);
    wait(180);
}
async sub pattern() {
    wait(OPENING_BUFFER);
    _ = spawn_enemy(0fx, -32fx, 1000, 0, 0, 0, source_enemy);
}
async sub control() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}
sub main() {
    _ = spawn_enemy(0fx, 0fx, 1000, 0, 0, 0, control);
    loop { wait(600); }
}
```

meta的time_limit与TIME_LIMIT相同，原作时限或估计另填original_time_limit。此例时限从开段计起，120帧缓冲在段内；新任务次帧首跑还会带来启动偏移，报告实际源/卡帧关系即可，不把偏移算进原作攻击周期。帧号采用harness“第N次step之后”的口径；确需定位启动偏移时，可在角色允许的局部抽查中选一个首发点，无需逐层精算或连续扫帧。真实敌同样无敌，体碰仍按原作规则保留；示例的12/16不是所有源敌的默认映射。

按本卡完整运动、发弹和合理尾弹填写TIME_LIMIT，1–65535范围内不套旧3000/3600帧上限。源sub自然结束可使对应敌退场；控制敌保留到段结束。不要为让时限相等额外添加敌保活机制，也不要截短仍在进行的攻击。

## 执行

统一执行器自动完整验收一次。单独定位问题时可从训练仓执行：

```bash
uv run --frozen python -m stgtranscribe.validate \
  transcribe/work/th18/stage01/w01/card/th18_s1_w01 \
  --json transcribe/work/th18/stage01/w01/checks/validate.json
```

引擎位置和版本由工作包给出。新弹型要求ENGINE_VER31及以上；使用xform控制语法要求34，offscreen_keep要求35。`TH18_*` 是普通常量，所需定义要放进卡目录，验收器不会自动注入。

harness默认自机位置为`(0,384)`；推导自机狙或近身门时使用实际入口坐标。

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
| no-op 诊断 | `contract_viol` 报错，修正被吞成no-op的调用 | 相同 |

通过只说明目标程序满足这些机器检查。源语义、原作弹型/半径、入口状态、随机共享和数值锚点仍按已注入的审核说明独立核验；原作动态对拍、训练效果和自动收卡也须分别报告。此入口不启动训练，不替代现代 ECL 切分覆盖检查。
