# TH06 ECL 批量转写

把东方红魔乡（TH06，th06nc 解码）的原作 ECL 按**波次 / boss 段**切开，用 dsh（deepseek-flash）批量转写成 `cards/` 下的 RL 卡。
设计：[`docs/2026-09-16-th06-transcribe-design.md`](../docs/2026-09-16-th06-transcribe-design.md)。

## 目录

```
transcribe/
  th06/config.toml        原文路径（环境变量可覆盖）、跳过规则、弹型映射
  th06/mapping.md         ★ TH06 → 我方 .ecl 对照表（逐条读 th06-decomp 写的，语义唯一依据）
  th06/examples/          4 张手转范例卡（波次 / 中 boss 非符 / boss 非符 / 符卡），每张带 notes.md
  contracts/              dsh worker 契约：split.md / transcribe.md / review.md
  work/                   gitignore：原文摘录、worker 工作目录、日志、state.jsonl
src/stgtranscribe/        工具：thecl 解析 / 结构摘要 / 切分校验 / 摘录 / 验收 / 流水线
```

## 前置

- 本机有 renkolab 的 th06nc 解码原文（`STG_TH06_SRC`，默认见 `th06/config.toml`）。
- stg-engine 里 `cargo build --release -p stg-harness`（`STG_ENGINE_DIR`）。
- `~/.local/bin/dsh-flash`（`STG_DSH_BIN`）。
- `uv sync --frozen`。

## 跑

```bash
uv run python -m stgtranscribe.pipeline split      --stages 1-7            # 每关一个 dsh 切分 → 机械校验
uv run python -m stgtranscribe.pipeline extract    --stages 1-7            # 原样摘录单元
uv run python -m stgtranscribe.pipeline transcribe --stage 1 --jobs 16     # 转写 → 自动验收（失败带报告重派 ≤2）
uv run python -m stgtranscribe.pipeline review     --stage 1 --jobs 16     # 审核（fail 带发现返工 ≤2 轮）
uv run python -m stgtranscribe.pipeline transcribe --stage 1               # 处理返工（state = revise）
uv run python -m stgtranscribe.pipeline review     --stage 1
uv run python -m stgtranscribe.pipeline sample     --stage 1               # 生成 opus 抽检清单（在 Claude 会话里做）
uv run python -m stgtranscribe.pipeline status     --stage 1
uv run python -m stgtranscribe.pipeline collect    --stage 1               # 收进 cards/，按提示提交
```

中断后重跑同一命令即续跑。编排与分诊的完整步骤见 `.claude/skills/th06-transcribe/SKILL.md`。

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
uv run python -m stgtranscribe.preview                                   # cards/ 全部卡 × 卡内各档，每档一张 8 帧拼图（45 张卡约 5 秒）
uv run python -m stgtranscribe.preview cards/th06_s3_w12 --ranks 2-3 --gif   # 指定卡 / 档，另出 GIF（20 fps，每个约 6–10 MB）
uv run python -m stgtranscribe.preview --serve                           # 静态页 127.0.0.1:8612，远程 ssh -L 8612:localhost:8612 <机器>
```

产物在 `work/preview/<卡 id>/`（`sheet_r<档>.png`、`anim_r<档>.gif`）+ `work/preview/index.html`。
拼图取「第一颗弹到最后一颗弹」时间窗均匀 8 帧，弹数峰值帧标题栏标红；贴图用 stg-engine `godot/assets/bullets.png`
（原作弹片切的，产物别提交）。自机停在场底中心不动，自机狙都瞄这个点；harness `--at` 每帧最多列 1024 颗弹。

## 手动工具

```bash
uv run python -m stgtranscribe.split_check <关> <split.json>     # 切分自检
uv run python -m stgtranscribe.validate <卡目录>                 # 四层验收（目录名必须是卡 id）
uv run pytest -q tests/transcribe                                # 对照表覆盖率 + 片段编译 + 工具测试
```

## 版权

原文摘录只在 `work/`（gitignore）与 renkolab `local/`。入库的只有我方 `.ecl`、`meta.toml`、对照表与范例说明。
