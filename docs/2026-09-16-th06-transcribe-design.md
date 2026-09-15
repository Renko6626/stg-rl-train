# TH06 ECL 批量转写流水线——设计

> 2026-09-16 brainstorming 拍板。读者：实施本流水线的会话、之后编排批量任务的会话。
> 关联：卡池写作约束 stg-engine `docs/rl-card-pool.md`；训练仓设计 `docs/2026-09-15-stg-rl-train-design.md`；
> 我方 ECL 手册 stg-engine `docs/ecl-lang.md`（索引）+ `docs/ecl-lang/`。

## 1. 目标与范围

训练仓 `cards/` 目前为空。本流水线把东方红魔乡（TH06，样本为 Steam New Classic 版）的原作 ECL
**按波次 / boss 段切分**，由 dsh（deepseek-flash）批量转写成本引擎 `.ecl` 卡，经自动验收与审核后入库。

- **单元**：小怪一波 = 一张卡；boss 的一个非符段或一张符卡 = 一张卡。
- **本轮交付** = 基础设施（工具、对照表、契约、范例、skill）+ 第 1 关端到端冒烟（§11）。
  **全作批量跑不在本轮**，由用户之后按 skill 启动。
- 不做：激光段（跳过并登记）；逐帧复刻；TH07 及以后（布局上留余地，不预先抽象）。

## 2. 已拍板的决定

| # | 决定 | 备注 |
|---|---|---|
| D1 | **保真度 = 弹型节奏忠实**：弹数、速度、角度、时序、难度分档按原作换算；允许定点取整、判定半径与贴图映射有出入 | 不做 TH06 语义参考计算器对拍 |
| D2 | **工作目录 = 训练仓 `transcribe/`**；工具是训练仓内独立包 `src/stgtranscribe/` | §4 |
| D3 | **激光段先跳过、登记**（含 `laser_*` 的单元不派活） | 全作 140 处 `laser_create`，134 处在第 4 关 |
| D4 | **原作时限 > 3000 帧的段钳到 3000**，`meta.toml` 记 `original_time_limit` | 约 20 段，集中在 Extra 与 6 面后段，最长 9000 |
| D5 | **切分也交给 dsh**：每关一个父层 dsh 产出 `split.json`，驱动脚本机械校验后再派子层 | §7.1 |
| D6 | **质量闸门 = 范例 + 自动验收 + dsh 全量审核 + opus 抽检** | §7.3、§8 |
| D7 | **转写卡入公开仓 `cards/`**：按东方二次创作规约（非商用、注明出处）处理；**解码原文永不入库** | §12 |
| D8 | **波次卡里小怪全部无敌** | 理由同 boss：难度不随模型站位变 |
| D9 | TH06 → 我方 ECL 的**对照表由主会话（Claude）逐条读 decomp 编写**，不交给 dsh | 它是整条流水线的根，§6 |

## 3. 素材与可行性事实（2026-09-16 实测）

### 3.1 原文

- 位置：renkolab `local/th06nc/decoded/ecl/ecldata{1..7}.ecl.txt`（gitignored，`thecl -g 6` 解码）。
  7 个文件（6 关 + Extra），共 18945 行、579 个 sub，每关一条 timeline。
- 符卡名：`local/th06nc/decoded/text/localization-by-language/ja.json`，键形如 `ST_ECLDATA1_SUB9_0`
  （→「月符「ムーンライトレイ」」）；`spellpractice.json` 共 131 条（约 64 张卡 × 难度）。
- 规模估计：小怪波次约 80 个 + boss 段约 95 个，**合计约 170–200 个单元**。

### 3.2 语义来源

| 需要什么 | 来源 | 可信度 |
|---|---|---|
| 指令名 | renkolab `local/vendor/truth/map/th06.eclm`（zero318），与解码文本名字一一对应 | 社区权威 |
| 参数格式 | `local/vendor/thtk/thecl/thecl06.c` 格式表（例：67–75 = `ssSSffffS`） | 可 round-trip |
| **运行时语义** | `local/vendor/th06-decomp/src/`（**CC0**）：`EclManager.cpp` 134 个 case（发弹 357–412、自动射击 428、移动 560–626、回调 685）；弹 exFlags 在 `BulletManager.cpp`；回调触发在 `EnemyManager.cpp` 346–406 | 一手源码 |
| NC 与原版的差异 | renkolab `engine/ecl/th06nc/02`：指令集逐项一致，只多 200（极坐标出弹口）/ 201（退化弹型） | 已验证 |

### 3.3 映射可行性

- 坐标：TH06 `x ∈ [0,384]` → 我方 `x − 192`；两边 y 都向下、场高 448。
- 难度：`!E/!N/!H/!L` 掩码 → `global(GVAR_RANK)` 分支（0–3），Extra 为 4。
- 弹 exFlags（`BulletManager.cpp`）与我方 xform op 的对应：
  - `0x1` 出生冲刺（16 帧内 5→0 叠加）→ `STEP_SPEED`
  - `0x10` 限时加速度向量 → `SET_GRAVITY` + `@N STOP_FX`
  - `0x20` 限时角速度 + 变速 → `SET_ANG_VEL` / `SET_ACCEL` + `@N STOP_FX`
  - `0x40` / `0x100` / `0x80` 减速到停再相对转 / 绝对转 / 瞄自机，重复 N 次 → `STEP_SPEED` + `TURN` / `SET_ANGLE` / `AIM_PLAYER` + `SET_SPEED` + `LOOP`
  - `0x400` / `0x800` 反弹 → `BOUNCE_ARM`（我方 n ≤ 3，超出即近似）
- 敌自动射击 `shoot_interval` → async 循环；`jump_dec` / 标签 → `loop` / `for`（我方无 goto）。
- boss：`life_callback_threshold/sub` + `timer_callback_threshold/sub` 串起各段，**按难度掩码分叉**
  （例：ecldata1 Sub14 的 Easy 超时回调直接结束，NHL 进下一张卡）。

### 3.4 dsh 沙箱（实测）

- worker **可读**：renkolab 原文、stg-engine 全仓（文档、release harness）。
- worker **只可写 `--cwd`**；写 cwd 以外报 `Read-only file system`。
- worker **不能派子 dsh**：dsh 启动要写 `~/.dsh/profiles/headless/cordis.yml`（EROFS），headless 拿不到提权
  ⇒ 编排只能由沙箱外的驱动脚本做。
- 预编译 `stg-engine/target/release/stg-harness` 在 worker 内可直接执行（避免并发 cargo 抢 target 锁）。

### 3.5 编译器版本一致性

`git diff rl-v0.1.0..HEAD -- crates/stg-ecl-compiler crates/stg-core crates/stg-rl` 为空：
worker 用 stg-engine HEAD 的 harness 自检，与训练仓 wheel（`rl-v0.1.0`）的编译结果一致。
`stg-harness check` 与 `stg_rl.compile_dir` 报同一套错误（`文件:行:列: 消息` + 源行 + `^`，一次报出全部错误）。
引擎升级 wheel 时重核这一条（§12）。

## 4. 目录布局

```
stg-rl-train/
  src/stgtranscribe/                 入库；标准库 + stg_rl，不加新依赖
    thecl.py        解析 thecl 文本：sub / 标签 / +时间 / 难度掩码 / 调用图 / 回调链 / 指令统计
    structure.py    生成给切分 dsh 的 structure.md
    split_check.py  split.json 机械校验
    extract.py      按 split.json 原样摘录 + 预换算注释 + unit.json + mapping 摘录
    validate.py     自动验收四层（§8）
    pipeline.py     驱动（§9）
  transcribe/
    README.md                        流程总览 + 命令
    th06/
      config.toml                    原文路径（可被环境变量 STG_TH06_SRC 覆盖）、弹型映射表、跳过规则
      mapping.md                     ★ 对照表（§6）
      examples/<id>/{main.ecl,meta.toml,notes.md}   4 张范例；原文只以「文件:行」引用
    contracts/{split,transcribe,review}.md          dsh 契约正文
    work/                            gitignore
      split/s{N}/                    父层 dsh cwd
      units/<id>/                    转写 dsh cwd
      review/<id>/                   审核 dsh cwd
      logs/<id>.<阶段>.<轮次>.log
      state.jsonl
  tests/transcribe/                  §10
  .claude/skills/th06-transcribe/SKILL.md   给 Claude 会话的编排 skill
  cards/th06_*/                      收卡目标
```

**单元 id**：`th06_s{关}_w{nn}`（小怪波）、`th06_s{关}_mb{n}`（中 boss 第 n 段）、`th06_s{关}_b{n}`（boss 第 n 段）；Extra 记 `s7`。

## 5. 流水线总览

```
0 准备（主会话）  mapping.md + 两道闸门 + 4 张范例 + harness 事件摘要（§8.1）
1 split     dsh × 7         → split.json → split_check（不过重派 ≤2）
2 extract   脚本             → units/<id>/
3 transcribe dsh × N        → out/ → validate（不过重派 ≤2，仍不过 blocked）
4 review    dsh × N         → verdict.json（fail 带发现重派转写 ≤2 轮，仍 fail needs_human）
5 sample    opus（Claude 会话）每关抽 pass 卡 ~20% + 全部 needs_human
6 collect   脚本             → cards/th06_*，按关提交（人工执行 git）
```

**第 0 步不收口（§6 两道闸门全绿、范例全过），第 1 步不开跑。**

## 6. 对照表 `transcribe/th06/mapping.md`

每条指令一节：

1. **签名**：带参数名（不写 `ssSSffffS`）。
2. **语义**：带 decomp 行号出处。例：`bullet_fan_aimed(sprite, color, count, layers, speed1, speed2, angle, spread, flags)`：
   count 颗 × layers 层，速度 speed1→speed2 逐层线性，以自机方向 + angle 为中心、按 spread 对称展开……
3. **我方写法**：一段**完整可编译**的 ```ecl 片段（含 `sub main()`，与 stg-engine `eclmeta.rs` 围栏测试同口径）。
4. **保真说明**：取整、近似、我方上限（如反弹 n ≤ 3、发射器每任务 4 槽）。
5. **处置**：`translate`（弹 / 移动 / 流程 / 变量）、`drop`（纯表现：`effect_sound`、`anm_*`、`spellcard_effect` 等）、
   `skip-unit`（`laser_*`）。

另有三张表：**弹型映射**（TH06 sprite 0–9 × 颜色 → 我方图集行 × 列，同步进 `config.toml`）、
**数值换算**（坐标、弧度 → `deg`、速度单位同为 px/帧）、**结构惯用法**（`shoot_interval`、`jump_dec`、
回调链、`call` 带参 → 我方写法）。

**两道闸门**（`tests/transcribe/`）：

1. **覆盖率**：`thecl.py` 扫 7 个文件出现的全部指令名（约 120 个），断言每个在 `mapping.md` 有条目且处置合法。
   需要本地原文，缺失即 skip。
2. **片段编译**：用 `stg_rl.compile_sources` 编译 `mapping.md` 与 `examples/` 下每个片段 / 卡。CI 必跑。

**给 worker 裁剪**：`extract.py` 统计单元实际用到的指令，只把这些条目写入 `mapping-excerpt.md`。

## 7. dsh 契约

共同约定：

- 驱动**逐个**调用 `~/.local/bin/dsh-flash --cwd <单元目录> --timeout 1800 --log <log>`
  （不用 `--batch`：它所有任务共用一个 cwd）。
- 契约正文在 `transcribe/contracts/*.md`，brief 只含单元参数 + 契约与资料的**绝对路径**。
- worker 必读我方 ECL 资料（绝对路径，不拷副本）：stg-engine `docs/ecl-lang.md`、`docs/ecl-lang/7-reference.md`、
  `.claude/skills/writing-danmaku-ecl/SKILL.md`（静默坑段）。
- 环境：`PYTHONDONTWRITEBYTECODE=1`；harness 用 release 二进制绝对路径；python 用训练仓 `.venv/bin/python`。
- 一次性 worker 无会话记忆：重派时带上 brief + 上一轮产出 + 失败 / 发现清单。

### 7.1 切分（每关一个，cwd = `work/split/s{N}/`）

**输入**：`structure.md`（`structure.py` 生成）+ 原文绝对路径。`structure.md` 含：

- timeline 按绝对帧列出的 `enemy_create`（连续同 sub 合并一行，保留时刻、坐标、血量）；
- 每个 sub 的标签：发弹指令、调用谁、`boss_set`、生命 / 时间 / 死亡回调（阈值、目标 sub，**按难度掩码拆开**）、
  `enemy_interrupt_set`、`spellcard_start`（附日文卡名）、激光、对话（`read_msg` / `wait_msg`）。

**输出** `split.json`：

```json
{ "stage": 1,
  "waves":  [{"id": "th06_s1_w01", "t_start": 100, "t_end": 1174, "tail": 300, "note": "Sub0/Sub2 两翼编队"}],
  "bosses": [{"prefix": "th06_s1_mb", "spawn_t": 1882, "phases": [
      {"n": 1, "kind": "nonspell", "entry": "Sub9", "start_label": "+160", "parallel": [],
       "ranks": [0,1,2,3], "time_limit": 1440, "hp_threshold": 500},
      {"n": 2, "kind": "spell", "entry": "Sub11", "parallel": ["Sub12"], "ranks": [2,3],
       "time_limit": 1320, "spell_key": "ST_ECLDATA1_SUB9_0"}]}],
  "excluded": [{"what": "Sub12", "reason": "laser"}] }
```

- `waves[].t_start/t_end`：该波 `enemy_create` 时刻的闭区间；`tail` = 最后一只怪出生后留给它打完的帧数。
- `phases[].start_label`：boss 开场设置与首段攻击同在一个 sub 时，攻击从哪个 `+时间` 或标签起算。
- `ranks` 必须是**连续区间**（训练仓 `cards.py` 把 `meta.ranks` 读作闭区间）；不连续就拆成两个单元。

**`split_check.py` 机械校验**：

1. 非 boss 的 `enemy_create` 恰好落入一个波次，波次互不重叠；
2. `t_end − t_start + tail ≤ 3000`；
3. 引用的 sub、标签存在；
4. 含 `spellcard_start` 的 sub 要么在某段的 `entry`/`parallel` 闭包里，要么在 `excluded`；
5. `time_limit` 等于原文对应 `timer_callback_threshold`（钳前原值）；原文该段无时间回调时，dsh 给出估计值并标
   `"time_limit_origin": "estimated"`，此时只校验 ≤ 3000；
6. `spell_key` 在 localization 中存在；
7. `ranks` 连续；
8. 激光：脚本独立判定单元闭包是否含 `laser_*`，与 `excluded` 交叉比对，不一致即报错。

不过即带错误清单重派，≤ 2 次；仍不过由主会话处理。

### 7.2 转写（每单元一个，cwd = `work/units/<id>/`）

**输入**（`extract.py` 生成）：

- `source.txt`：原文**原样摘录**（波次 = timeline 片段；boss 段 = entry / parallel sub 及其调用闭包），
  行尾附预换算注释，如 `// x=-132` `// 90.0deg` `// 自机狙`；
- `unit.json`：id、kind、`time_limit`（boss 段 = 原值钳到 3000；波次 = `t_end − t_start + tail`）、`original_time_limit`、
  `ranks`、卡名、boss 出生点、用到的指令列表；
- `mapping-excerpt.md`；同类范例卡路径。

**输出**：`out/main.ecl`、`out/meta.toml`、`out/report.md`
（逐条原文指令的映射去向、近似清单、自检命令与结果、`status: done | blocked` + 原因）。

**固定外壳**（模板写进契约，worker 只填内容）：

- **波次卡**：一只导演敌——屏外、`ENEMY_NO_BODY`、`set_invuln(65535)`——其主任务 `phase_begin(0, wave, time_limit, 0)`；
  `wave` 按 timeline 相对帧 `spawn_enemy` 小怪。**每只小怪出生即 `set_invuln(65535)`**（D8），按原脚本行动、退场。
- **boss 段卡**：boss 在该段起始位置出生，`set_invuln(65535)`；非符用 `phase_begin`，符卡用 `spell_begin`，
  `hp_threshold = 0`（无敌下不起作用）。原作回调链只用于确定段边界，不翻译。
- **开场缓冲**：原作在 120 帧内就有致命弹到达出生点 `(0,384)` 附近的，开头补等待并在 report 写明。
- `meta.toml` 按 `docs/rl-card-pool.md` §2，另加 `original_time_limit`、`source_ref = "ecldata1.ecl.txt:169-290"`。

**自检循环**：`stg-harness check out` → `stg-harness run out --rank r`（r 取 `ranks` 各档）→
`.venv/bin/python -m stgtranscribe.validate out`，全绿才算完成。

**验收不过**：驱动带 validate 输出重派，≤ 2 次；仍不过 → `blocked`。

### 7.3 审核（每卡一个，cwd = `work/review/<id>/`）

**输入**：7.2 的全部输入与产出（复制进 cwd）+ validate 结果。

**清单**：对原文每条发弹指令核对颗数、层数、速度与插值、角度与瞄准方式、弹型映射、四档差异；
时序（帧）、`jump_dec` 次数、随机范围；移动目标点与时长（换算后）；exFlags → xformdef；外壳规则；
report 声明的近似与代码是否一致。

**硬性数值锚点**：从原文**手算至少 3 轮**的期望（第 F 帧弹数 / 速度 / 角度，指定 rank），
用 `stg-harness run out --rank r --at F` 实测对照，写进 verdict。只读代码不算审过。

**输出** `verdict.json`：

```json
{ "verdict": "pass" | "fail",
  "findings": [{"severity": "critical|major|minor", "src_line": 212, "ecl_line": 40,
                "expected": "16 颗 × 3 层", "actual": "16 颗 × 1 层"}],
  "volleys":  [{"frame": 262, "rank": 2, "expected": "...", "observed": "..."}] }
```

- `pass` = 无 critical / major 且 `volleys` ≥ 3 条；minor 只登记。
- `fail` → 带 findings 重派转写，再审，≤ 2 轮；仍 fail → `needs_human`。
- severity 口径写进契约：critical = 弹幕形态错（颗数 / 层数 / 瞄准方式 / 缺段）；major = 数值偏差超出取整
  （速度、角度、时序、难度分档）；minor = 表现或可接受近似。

### 7.4 opus 抽检

- 在 Claude 会话中用 Agent tool（`model: "opus"`）执行，材料与 verdict 格式同 7.3。
- 范围：每关 pass 卡随机约 20%（至少 2 张）+ 全部 `needs_human`。
- opus 查出审核层漏掉的 **critical** → 修 `contracts/review.md` 清单，整关重审；
  只漏 major → 在 `state.jsonl` 登记漏判，按趋势决定是否收紧。

## 8. 自动验收 `validate.py`

| 层 | 查什么 | 实现 |
|---|---|---|
| 1 语法 / 类型 | 词法、语法、三型、签名、未定义名 | `stg_rl.compile_dir`（与 harness `check` 同一编译器） |
| 2 运行时 | fault、池满、弹峰值 ≤ 1024 | `stg-harness run --rank r --frames time_limit+300`，逐档；解析「峰值」「诊断」行 |
| 3 卡池 lint | boss / 导演敌 `set_invuln(65535)`；有 `phase_begin` 或 `spell_begin`；时限 ≤ 3000 且与 meta 一致；未用 `$rank`；`meta.toml` 字段与类型；目录名合规；`source`/`origin`/`source_ref` 已填；`ranks` 为连续区间 | 源码 + TOML 静态检查 |
| 4 RL 行为 | (a) 首个段结束事件帧 ∈ [120, time_limit + 60]，各档都要有；(b) 开场安全：9 方向随机游走（同 env 预热规则）前 120 帧死亡率 ≤ 10% | (a) harness `run` 事件摘要（§8.1）；(b) `stg_rl.VecEnv`，每档 32 局，看 `done` 与 `died` 列 |

阈值（(b) 的 10%、局数）为初值，§11 冒烟用 4 张范例 + 骨架卡校准后回写本节。

### 8.1 stg-engine 小改：`run` 输出段结束事件

`stg-harness run` 当前不输出事件。加一行：

```
段结束：PHASE_ENDED@1920 · SPELL_CAPTURED — · SPELL_FAILED — · STAGE_CLEARED —
```

（各类型首次出现帧，未出现记 `—`）。harness 在断层线以上，不动 `ENGINE_VER`，不影响 wheel；
在 stg-engine 另开短分支提交，附单测。release 二进制由主会话重编。
自机残机耗尽后进入 GAMEOVER，世界照常推进，不按键的 `run` 能跑满时限。

## 9. 驱动 `pipeline.py`

```
uv run python -m stgtranscribe.pipeline split      --stages 1-7
uv run python -m stgtranscribe.pipeline extract    --stages 1-7
uv run python -m stgtranscribe.pipeline transcribe --stage 1 --jobs 16
uv run python -m stgtranscribe.pipeline review     --stage 1 --jobs 16
uv run python -m stgtranscribe.pipeline sample     --stage 1        # 打印抽检清单，供 Claude 会话执行
uv run python -m stgtranscribe.pipeline status     [--stage 1]      # 状态表 / 通过率 / 重试分布 / blocked 原因
uv run python -m stgtranscribe.pipeline collect    --stage 1        # 复制进 cards/，打印建议的 git 命令，不自动提交
```

**状态机**（每单元）：

```
pending → transcribed → validated → reviewed → collected
              ↘ blocked       ↘ needs_human
excluded（split 判定跳过，含原因）
```

- 追加写 `work/state.jsonl`（`{id, state, round, reason, ts}`），同一单元以最后一行为准。
- 每个子命令只处理处于其前置状态的单元 ⇒ **中断后重跑同一命令即续跑**。
- 并发：dsh 由 `--jobs` 控制；validate 第 4 层另设信号量（默认 CPU 核数 / 2）。
- 前置检查：原文路径可读、release harness 存在且比 stg-engine HEAD 新、训练仓 `.venv` 可导入 `stg_rl`，任一不满足直接退出。

## 10. 测试（`tests/transcribe/`）

CI 上没有 ZUN 数据，分三类：

1. **合成夹具**（手写小段 thecl 格式文本，不含原作内容），CI 必跑：
   解析器（sub / 标签 / `+时间` / 难度掩码 / 回调链）、`extract` 原样性、`split_check` 每条规则一个负例、
   `validate` 第 3 层每条规则一个负例、状态机续跑。
2. **只依赖 `stg_rl`**，CI 必跑：`mapping.md` 片段编译、`examples/` 4 张卡过第 1–3 层。
3. **需要本地原文**（缺失即 skip）：解析器计数金值（ecldata1 = 38 sub、224 条 `enemy_create`、1 条 timeline）、
   摘录原样性（每行在原文逐字存在）、**对照表覆盖率**。

第 4 层与 harness 相关测试需要 release harness，缺失即 skip。

## 11. 本轮交付与完成标准

1. stg-engine：`run` 段结束事件摘要（§8.1），合入 main，release harness 重编。
2. `mapping.md` + 两道闸门全绿。
3. 4 张范例卡（取自第 1 关：小怪波、非符、符卡、带弹变换的一张），过 validate 全部四层，
   并由主会话按 7.3 清单自审（含 ≥ 3 轮 `--at` 对照）。
4. `stgtranscribe` 全部工具 + §10 测试，训练仓 CI 绿。
5. `contracts/` 三份契约 + `transcribe/README.md` + `.claude/skills/th06-transcribe/SKILL.md`
   （启动命令、看状态、`blocked`/`needs_human` 分诊、opus 抽检步骤）。
6. **端到端冒烟（第 1 关）**：dsh 真跑 split → extract → transcribe 3 个单元（波次、非符、符卡，不与范例重复）→
   validate → review → opus 抽检 1 张。把实测通过率、重试分布、单元耗时、§8 阈值校准结果回写本 spec
   新增的「实施偏差与实测」节。
7. `.gitignore` 加 `transcribe/work/`；`cards/README.md` 加转写卡出处声明。

## 12. 风险与已知限制

- **无自动保真判定**：验收四层只证明「能用」，「对不对」全靠 dsh 审核的数值锚点 + opus 抽检。
  抽检漏判率是这条流水线最该盯的指标。
- **对照表单点**：`mapping.md` 错一条会批量扩散；覆盖率闸门只保证「有条目」，不保证「条目对」。
  范例卡的主会话自审是它唯一的一手校验；抽检若发现同类错误反复出现，先回查 mapping。
- **版权**：解码原文、原文摘录只存在于 `transcribe/work/`（gitignore）与 renkolab `local/`。
  入库物只有我方 `.ecl`、`meta.toml`、对照表（描述语义，不含原文）、范例的「文件:行」引用。
- **引擎升级**：训练仓 wheel 升级时重跑 §3.5 的 diff 核查；若编译器有变，release harness 与 wheel 需同版本。
- **难度不连续**：`ranks` 不连续的段需拆单元，数量预计很少，冒烟时统计。
- **我方无对应机制**：原作 exFlags 反弹次数 > 3、`bullet_rank_influence` 等，按 mapping 标注近似，
  由 `report.md` 如实声明。
