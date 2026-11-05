# TH06 ECL 批量转写

把东方红魔乡（TH06，th06nc 解码）的原作 ECL 按**波次 / boss 段**切开，用 dsh（deepseek-flash）批量转写成 `cards/th06/` 下的 RL 卡。
设计：[`docs/2026-09-16-th06-transcribe-design.md`](../../docs/2026-09-16-th06-transcribe-design.md)。

高版本整关切分先读[切分指南](../th18/splitting.md)（TH18已核实例）；TH18 单攻击工作先读[双语法转写教材](../th18/mapping.md)，再按[专用入口](../th18/README.md)查表；[专用 skill](../../.claude/skills/th18-transcribe/SKILL.md)与写审契约负责派发和交付。单卡 `validate` 已按 [TH18 编号与验收规则](../th18/validation.md)接通；本页的批量命令、摘录器和切分检查仍只用于 TH06/NC。

## 目录

以下路径均相对仓库根目录；跨作品入口与工作区规则见[总览](../README.md)。

`work/` 是临时工作区。调研、下载、构建和一次性验证结束后，结论与来源位置/版本写入正式文档，过程目录及时清理，避免在根目录长期堆积日期命名文件夹。历史报告中的日期路径表示当时的执行位置，不保证临时脚本和日志一直保留。

仍需使用的产物按用途放置：TH18 Stage01切分资料在 `work/th18/stage01/`，弹型总览在 `work/preview/bullet-catalog.png`。流水线的 `units/`、`review/`、`split/`、`logs/` 和 `state.jsonl` 单独管理，不随调研目录一起删除。

```
transcribe/
  th06/config.toml        原文路径（环境变量可覆盖）、跳过规则、弹型映射
  th06/mapping.md         ★ TH06 → 我方 .ecl 对照表（逐条读 th06-decomp 写的，语义唯一依据）
  th06/examples/          4 张手转范例卡（波次 / 中 boss 非符 / boss 非符 / 符卡），每张带 notes.md
  th06/contracts/         dsh worker 契约：split.md / transcribe.md / review.md
  work/                   gitignore：原文摘录、worker 工作目录、日志、state.jsonl
src/stgtranscribe/        工具：thecl 解析 / 结构摘要 / 切分校验 / 摘录 / 验收 / 流水线
```

## 前置

- 本机有 renkolab 的 th06nc 解码原文（`STG_TH06_SRC`，默认见 `th06/config.toml`）。
- stg-engine 里 `cargo build --release -p stg-harness`（`STG_ENGINE_DIR`）。
- `~/.local/bin/dsh-flash`（`STG_DSH_BIN`）。
- `uv sync --frozen`。

## 当前转写口径（2026-11-05）

训练仓使用 `stg-rl==0.4.5`、ENGINE_VER31。新表追加按作品命名的TH06十型/TH18四十八型；旧192项保留，出生半径直接取本型数据。TH18新词表与色号见[弹型表](../th18/bullet-types.md)，本页旧TH06批量配置和已生成卡仍使用旧别名，不自动迁移。
带参 xform 从 ENGINE_VER28 起支持，单值 STEP 扩展从29起支持，模板体 rand 从30起支持；
引擎源码、release harness 和 Python wheel 是三个需分别核对的状态，升级方法见
[`stg-rl-wheel-sync.md`](../../docs/agent-memory/stg-rl-wheel-sync.md)，本次来源与验证见
[`stg-rl-045-adoption.json`](../../docs/practice-cards/reports/stg-rl-045-adoption.json)与[大表接入记录](../../docs/investigations/2026-11-05-touhou-bullet-catalog.md)。

运行期变换参数优先按 mapping §5 转成 `NAME(args)`，在原 `bullet_effects` 配置点保存值，保留随机取样位置与共享范围。
模板体 rand 按原求值标记选择绑定、每弹出生或操作进入时抽样；配置随机仍保持共享，STEP/等待中不重抽。
`at_spawn` 保存每弹出生状态，`at_effect` 在进入操作时读取当前状态；`@N` 仍是字面量后置等待。
旧卡的量化/取中值/逐弹任务不会随 wheel 或文档更新自动还原。当前契约针对 TH06/NC，不能直接套到其他作品的 EX 语义。

修改对照表后，派发前按 [skill 的刷新步骤](../../.claude/skills/th06-transcribe/SKILL.md#刷新已有单元输入)
更新目标单元的 `mapping-excerpt.md` / `builtins.md`；`extract` 不覆盖已进入后续状态的单元。
速查表只含内建签名，xform 的额外语法直接查摘录 §5。旧审核目录保留原记录，新一轮审核会复制刷新后的输入。

## 跑

```bash
uv run --frozen python -m stgtranscribe.pipeline split      --stages 1-7            # 每关一个 dsh 切分 → 机械校验
uv run --frozen python -m stgtranscribe.pipeline extract    --stages 1-7            # 原样摘录单元
uv run --frozen python -m stgtranscribe.pipeline transcribe --stage 1 --jobs 16     # 转写 → 自动验收（失败带报告重派 ≤2）
uv run --frozen python -m stgtranscribe.pipeline review     --stage 1 --jobs 16     # 审核（fail 带发现返工 ≤2 轮）
uv run --frozen python -m stgtranscribe.pipeline transcribe --stage 1               # 处理返工（state = revise）
uv run --frozen python -m stgtranscribe.pipeline review     --stage 1
uv run --frozen python -m stgtranscribe.pipeline sample     --stage 1               # 生成 opus 抽检清单（在 Claude 会话里做）
uv run --frozen python -m stgtranscribe.pipeline status     --stage 1
uv run --frozen python -m stgtranscribe.pipeline collect    --stage 1               # 收进 cards/th06/；提交、推送分别需用户授权
```

中断后重跑同一命令即续跑。编排与分诊的完整步骤见 `.claude/skills/th06-transcribe/SKILL.md`。
默认后端为 dsh-flash；按既有约定换 Sonnet 时，在仓库根目录设置 `STG_DSH_BIN="$PWD/transcribe/tools/claude-worker"`、`STG_CLAUDE_MODEL=sonnet`，
并将并发降为 `--jobs 4`。dsh 审核后的 Opus 抽检与逐条复核仍须完成，不能把生成抽检清单视为已抽检。

## 单元状态

```
pending → validated → reviewed → collected
   ↘ blocked   ↘ revise（回 transcribe）/ needs_human
excluded（切分判定跳过：不可转 ex_ins / 对话；激光 2026-09-25 起可转，见 mapping §14）
```

## 试玩

```bash
transcribe/play.sh                  # 列出可试玩的卡（范例 / 流水线已验收 / cards 已收）
transcribe/play.sh 3 [rank]         # 后台起 viewer（端口 PLAY_PORT，默认 8611），换卡再跑一次后刷新浏览器
transcribe/play.sh status | stop
```

远程机器先开隧道 `ssh -L 8611:localhost:8611 <机器>`，浏览器开 `http://localhost:8611`。
操作：方向键 · Z 射击 · Shift 低速；别按 X（训练用的机体 1 没有保命手段）。

## 出图（弹幕预览 PNG / GIF）

```bash
uv run --frozen python -m stgtranscribe.preview cards/th06                        # TH06卡 × 卡内各档，每档一张8帧拼图
uv run --frozen python -m stgtranscribe.preview cards/th06/th06_s3_w12 --ranks 2-3 --gif   # 指定卡 / 档，另出 GIF（20 fps，每个约 6–10 MB）
uv run --frozen python -m stgtranscribe.preview --serve                           # 静态页 127.0.0.1:8612，远程 ssh -L 8612:localhost:8612 <机器>
```

产物在 `work/preview/<卡 id>/`（`sheet_r<档>.png`、`anim_r<档>.gif`）+ `work/preview/index.html`。
拼图取「第一颗弹到最后一颗弹」时间窗均匀 8 帧，弹数峰值帧标题栏标红；贴图用 stg-engine `godot/assets/bullets.png`
（原作弹片切的，产物别提交）。自机停在场底中心不动，自机狙都瞄这个点；harness `--at` 每帧最多列 1024 颗弹。

## 手动工具

```bash
uv run --frozen python -m stgtranscribe.split_check <关> <split.json>     # 切分自检
uv run --frozen python -m stgtranscribe.validate <卡目录>                 # 四层验收（目录名必须是卡 id）
uv run --frozen pytest -q tests/transcribe                                # 对照表覆盖率 + 片段编译 + 工具测试
```

## 版权

原文摘录只在 `work/`（gitignore）与 renkolab `local/`。入库的只有我方 `.ecl`、`meta.toml`、对照表与范例说明。
