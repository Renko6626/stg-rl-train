# TH06 作者补充

通用职责、权限和交付见[作者约定](../../contracts/transcribe.md)。完整validate由执行器做一次，代码直接写card/<id>/。

适用 TH06/NC。TH18 使用[TH18规则书](../../th18/README.md)，不套用本页的坐标、弹型、时序和激光换算。

你负责**一个单元**：把 cwd 里 `source.txt` 摘录的 TH06 原文，翻成一张本引擎的 RL 卡（`.ecl` + `meta.toml`）。
保真度要求是**弹型节奏忠实**：弹数、速度、角度、时序、四档难度差异照原作换算；定点取整、判定半径可以有出入。

输入为task.md、source.txt及任务提供的unit.json/mapping-excerpt.md。摘录器添加的//@是辅助注释，原文与映射是语义依据；存在冲突时报告，不盲抄。

## 阅读范围

优先读task.md列出的相关章节。提供了mapping-excerpt.md/builtins.md就使用；未提供时直接按指令名在mapping.md和目标7-reference.md中定位有关段，不搜索不存在的文件，也不通读1500行映射。最多看一个范例的相关函数/外壳，不把全部范例作为必读。

`NAME(args)`、`at_spawn`、`at_effect`的求值时点按mapping §5，仅在本卡使用时查阅。难度前缀见§2.2，时间/跳转见§2.4，发射见§4；不为已经明确的转换重查原作VM或目标引擎实现。

## 产出

### `card/<id>/main.ecl`（单文件）

- **外壳照抄** mapping §13：波次卡用 §13.1（导演敌 + `phase_begin`），非符用 §13.2 改成 `phase_begin`，符卡用 `spell_begin`。
- `const TIME_LIMIT: int = <unit.json 的 time_limit>;`
- **所有敌人**（boss、导演敌、每只小怪）第一句 `set_invuln(65535);`。小怪还要 `spawn oob_guard();`（§6.2）。
  无敌是已批准的训练外壳要求，不在单卡任务重新论证。
- **激光**（单元里有 `laser_*` 时）：通读 mapping §14。四条最容易错：宽度写**原作值 / 2**；`laser_rotate` / `laser_offset`
  **逐帧照翻**成 `lz_rotate` / `lz_origin`（别自作主张改成 `lz_omega` / `lz_anchor`）；自机狙用 `laser(… 0bam …)` 后立刻 `lz_aim(lz, a)`；
  原点 = 敌位置 + **当时生效的** `shoot_offset`。report 的「映射」表里每条激光单独一行，写清换算后的 `len / width / warn / active / fade`。
  自检用 `--at` 看「活激光」表核 state / timer / 角度（遵循通用作者的两次上限）。
- **开场缓冲**：卡开始后 120 帧内不能有致命弹到达自机出生点 `(0, 384)` 附近。波次卡导演先 `wait(120)`；boss 段原文开场有移动 / 宣言前奏的通常够，不够就在开头补等待，并写进 report。
- `start_label` 有值时：entry sub 里该时间点之前的是登场设置，只取位置 / 出弹口 / 边界这类状态，攻击从该时间点开始。
- 弹型名常量抄进卡里（§3 表）。文件头两行注释写单元 id、卡名、原文出处。

### `card/<id>/meta.toml`

```toml
title = "<符卡名 unit.json spell_name，或「Stage N 道中 第 k 波」「Stage N boss 非符 k」>"
source = "th06"
origin = "东方红魔乡 Stage N …（写清是哪一段、原文 sub）"
source_ref = "<unit.json 的 source_ref>"
ranks = <unit.json 的 ranks>
marks = [0]
time_limit = <unit.json 的 time_limit>
original_time_limit = <unit.json 的 original_time_limit>
tags = [<从 aimed random ring spiral wall curve split stream dense fast mixed laser 里选；用了 laser() 必须带 laser>]
laser_approx = false   # 真激光也写 false；只有「原作激光、这里用弹链近似」才是 true
lower_half_blocked = <下半屏被长时间大面积封死就 true>
notes = "<一句话：近似 / 特殊处理>"
```

### `report.md`

```markdown
status: done            ← 或 blocked
## 映射
| 原文（sub:行 或 timeline 帧） | 卡里的位置 | 说明 |
<!-- 动态变换注明原配置点、快照/绑定位置、参数共享范围和效果发生帧。 -->
## 近似
- 逐条列出所有与原作不一致的地方（取整以外）
## 自检
- 必要自检命令及结果、你用 --at 核过的帧（完整validate由脚本负责）
```

**blocked**：原文用到了对照表标 skip-unit 的东西、或对照表里没有的指令、或确实表达不了（写清原因）。blocked 就不用硬写卡。

## 翻译要点（都在 mapping 里，这里是最容易错的）

- **难度前缀是粘滞的**：以 `source.txt` 行尾的 `[生效难度]` 为准（§2.2）。Stage 7（Extra）的原文没有难度前缀，**全部照转**：行尾的全难度标签 `[ENHLX]`（旧摘录写成 `[ENHL]`，同义）不代表「排除 Extra」。
- 块时间 `+N: //T` → `wait(T − 上一个 T)`；`jump` / `jump_dec` 会**重设时间**，循环体里的等待按跳转目标时间算（§2.4）。
- `call` 按值传全部变量、`ret` 恢复调用方；尾调用链翻成调度循环（§2.4）。
- 同一个 sub 里**变量名不能重复**，平行的 `for` 也不行（`k1`、`k2`…）。
- **区分 xform 路径**：旧零形参全常量模板按物理槽 ×3 占 locals，并保留 `sh_xform`/`sh_fire` 同 sub 的约束；带参/动态模板按值绑定，可在同步 helper 配置后返回开火。发射器仍是任务私有，不能跨 `async sub` 共用（§2.4、§5）。
- **动态参数默认用带参 xform**：在原 `bullet_effects` 配置点保存/绑定数值，保持原随机取样位置与共享范围；不要因参数非常量改成全局槽传参、逐弹任务或量化。确有控制流/容量限制时写出具体原因。
- **求值时点不能混用**：普通实参在绑定/单发时求值，`at_spawn` 保存每弹出生状态，`at_effect` 读取进入操作时的当前状态。ENGINE_VER30起模板体允许 `rand`，按这三个阶段抽样；保留原配置随机的共享范围。`@N` 仍只能写 u16 字面量，STEP 非阻塞（§5）。
- `bullet_*` 立即开火并写满发射参数；`shoot_disable` 期间只配置不发；`shoot_interval` 是后台自动射击（§4）。
- 角度写 `bam` 整数（照抄注释），x 坐标减 192（注释已算好）。
- 小怪镜像只取反水平速度，弹角度不镜像（§6.1）。

## 共性问题

确有会影响其他卡的映射缺口，记在report.md的未决项中，给源位置和具体疑问即可；不额外写notes.md、研究报告或自行修全局规则。报告遵循通用契约的短格式。
