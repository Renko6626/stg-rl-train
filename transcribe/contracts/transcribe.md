# 转写契约（transcribe worker）

你负责**一个单元**：把 cwd 里 `source.txt` 摘录的 TH06 原文，翻成一张本引擎的 RL 卡（`.ecl` + `meta.toml`）。
保真度要求是**弹型节奏忠实**：弹数、速度、角度、时序、四档难度差异照原作换算；定点取整、判定半径可以有出入。

## 你能动的

- **只写** cwd 下的 `out/`（产出）和 `card/`（自检用的临时副本）。其余一律只读。
- cwd 里的输入：
  - `source.txt`：原文逐字摘录。行尾 `//@` 之后是摘录器加的注释：`[生效难度]`、`x0=…`（换算后的 x）、`a6=5.625°=1024bam`（弧度换算）、`弹型→…`。**数值照抄注释，别心算**。
  - `unit.json`：单元参数（`time_limit` 已钳好、`ranks`、`kind`、`spell_name`、`entry`/`start_label`、`examples` 范例卡路径）。
  - `mapping-excerpt.md`：对照表里本单元用到的节。
  - `feedback.md`（只在返工时有）：上一轮验收失败 / 审核发现，**逐条改掉**。

## 必读（按顺序）

1. `mapping-excerpt.md` 全文——语义只认它，别凭 ZUN 指令名猜。
2. `unit.json` 里 `examples` 指向的范例卡：`main.ecl` + `notes.md`。**照范例的写法和结构写**。
3. 我方语言：prompt 里给的 `docs/ecl-lang.md`（索引）、`docs/ecl-lang/7-reference.md`（内建签名），
   `writing-danmaku-ecl/SKILL.md` 的「跨机制的静默坑」一节。

## 产出

### `out/main.ecl`（单文件）

- **外壳照抄** mapping §13：波次卡用 §13.1（导演敌 + `phase_begin`），非符用 §13.2 改成 `phase_begin`，符卡用 `spell_begin`。
- `const TIME_LIMIT: int = <unit.json 的 time_limit>;`
- **所有敌人**（boss、导演敌、每只小怪）第一句 `set_invuln(65535);`。小怪还要 `spawn oob_guard();`（§6.2）。
- **开场缓冲**：卡开始后 120 帧内不能有致命弹到达自机出生点 `(0, 384)` 附近。波次卡导演先 `wait(120)`；boss 段原文开场有移动 / 宣言前奏的通常够，不够就在开头补等待，并写进 report。
- `start_label` 有值时：entry sub 里该时间点之前的是登场设置，只取位置 / 出弹口 / 边界这类状态，攻击从该时间点开始。
- 弹型名常量抄进卡里（§3 表）。文件头两行注释写单元 id、卡名、原文出处。

### `out/meta.toml`

```toml
title = "<符卡名 unit.json spell_name，或「Stage N 道中 第 k 波」「Stage N boss 非符 k」>"
source = "th06"
origin = "东方红魔乡 Stage N …（写清是哪一段、原文 sub）"
source_ref = "<unit.json 的 source_ref>"
ranks = <unit.json 的 ranks>
marks = [0]
time_limit = <unit.json 的 time_limit>
original_time_limit = <unit.json 的 original_time_limit>
tags = [<从 aimed random ring spiral wall curve split stream dense fast mixed 里选>]
laser_approx = false
lower_half_blocked = <下半屏被长时间大面积封死就 true>
notes = "<一句话：近似 / 特殊处理>"
```

### `out/report.md`

```markdown
status: done            ← 或 blocked
## 映射
| 原文（sub:行 或 timeline 帧） | 卡里的位置 | 说明 |
## 近似
- 逐条列出所有与原作不一致的地方（取整以外）
## 自检
- validate 输出摘要、你用 --at 核过的帧
```

**blocked**：原文用到了对照表标 skip-unit 的东西、或对照表里没有的指令、或确实表达不了（写清原因）。blocked 就不用硬写卡。

## 翻译要点（都在 mapping 里，这里是最容易错的）

- **难度前缀是粘滞的**：以 `source.txt` 行尾的 `[生效难度]` 为准（§2.2）。Stage 7 只执行 `[ENHL]` 的行。
- 块时间 `+N: //T` → `wait(T − 上一个 T)`；`jump` / `jump_dec` 会**重设时间**，循环体里的等待按跳转目标时间算（§2.4）。
- `call` 按值传全部变量、`ret` 恢复调用方；尾调用链翻成调度循环（§2.4）。
- 同一个 sub 里**变量名不能重复**，平行的 `for` 也不行（`k1`、`k2`…）。
- **xformdef 占 locals**，一个 sub 引用太多会超 64 字 → 拆成并行 `async sub`；**`sh_xform` 和 `sh_fire` 写在同一个 sub**（§2.4）。
- `bullet_*` 立即开火并写满发射参数；`shoot_disable` 期间只配置不发；`shoot_interval` 是后台自动射击（§4）。
- 角度写 `bam` 整数（照抄注释），x 坐标减 192（注释已算好）。
- 小怪镜像只取反水平速度，弹角度不镜像（§6.1）。

## 自检循环（全绿才算完成）

```bash
H=<harness>; TL=<time_limit>
$H check out
for r in <ranks 里每一档>; do $H run out --rank $r --frames $((TL + 300)); done
#   看：退出码 0、「段结束：」有帧且在 TL 附近、弹峰值 ≤ 1024
$H run out --rank 3 --frames 600 --at <你想核的帧>      # 核一轮弹的颗数 / 速度 / 角度
rm -rf card && mkdir -p card && cp -r out card/<单元 id>
cd <训练仓> && PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -m stgtranscribe.validate <cwd>/card/<单元 id>
```

`validate` 输出 `OK` 才算完成；它就是流水线收卡用的同一个验收器（编译 / 各档运行 / 卡池 lint / 段结束帧 / 开场安全）。

**卡帧对照**：`main` 在第 1 帧建 boss（或导演），boss 主任务第 2 帧跑、`spell_begin`/`phase_begin` 起的 `pattern` 第 3 帧跑。
所以 `pattern` 里 `wait(N)` 之后的开火出现在 `run --at 3+N` 附近（新弹当帧建、下一帧能看到）。

## 完成时

最后一条回复写：`status`、validate 结果一行、近似条数、你拿不准的地方。
