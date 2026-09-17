---
name: th06-transcribe
description: Use when running, monitoring, or triaging the TH06 ECL → RL card batch transcription pipeline in stg-rl-train (dsh split / transcribe / review workers, opus sampling, collecting cards), or when a transcribed card, mapping.md entry, or worker contract needs fixing.
---

# TH06 批量转写：编排与分诊

流水线本体在 `src/stgtranscribe/`，说明在 `transcribe/README.md`，设计在 `docs/2026-09-16-th06-transcribe-design.md`。
这份 skill 讲**主会话**要做的事：启动、盯状态、分诊、opus 抽检、收卡。

## 分工（不要越位）

| 谁 | 做什么 |
|---|---|
| dsh-flash worker | 切分 / 转写 / 审核，按 `transcribe/contracts/*.md`，只写自己的 cwd |
| `pipeline.py` | 派活、机械校验、摘录、验收、状态机 |
| 主会话（你） | 启动命令、分诊 `blocked` / `needs_human`、opus 抽检、修对照表与契约、提交 |

worker **派不了子 worker**（dsh 要写 `~/.dsh`，沙箱只读）。所有派发都走 `pipeline.py`。

## 启动前自检

```bash
uv run --frozen pytest -q tests/transcribe          # 对照表覆盖率 + 片段编译 + 范例卡四层验收
ls $STG_ENGINE_DIR/target/release/stg-harness        # 引擎改过就重编：cargo build --release -p stg-harness
```

训练仓 wheel 升级时先核 `git diff rl-vX..HEAD -- crates/stg-ecl-compiler crates/stg-core crates/stg-rl`
（spec §3.5）：编译器变了，harness 与 wheel 要同版本。

## 标准顺序（一关一关推）

```bash
P="uv run python -m stgtranscribe.pipeline"
$P split --stages 1-7          # 可以一次全关
$P extract --stages 1-7
$P transcribe --stage N --jobs 16
$P review --stage N --jobs 16
$P transcribe --stage N        # 处理 revise
$P review --stage N
$P status --stage N
$P sample --stage N            # → work/sample-sN.json
# opus 抽检（见下）
$P collect --stage N           # 然后 git add cards/ && git commit
```

后台跑用 `run_in_background`；日志在 `transcribe/work/logs/<id>.<阶段>.<轮次>.log`。

## 分诊

`status` 列出所有没走完的单元。

- **split_fail**：读 `work/split/sN/feedback.md`。同一类错误反复出现 → 契约 `split.md` 没讲清，改契约后 `split --stages N --force`。
  切分本身有歧义（编队怎么分）时，主会话可以直接改 `split.json` 再跑 `split_check`。
- **blocked**：读 `work/units/<id>/out/report.md`（worker 说为什么）和 `feedback.md`（验收错误）。
  - 真做不到（skip-unit 漏判、引擎缺机制）→ `pipeline.record(id, "excluded", reason=…)`，并回头修 `config.toml [skip]` 或 split。
  - 对照表缺条目 / 写错 → 改 `mapping.md`（改完跑 `pytest tests/transcribe`），再 `record(id, "pending")` 重派。
  - worker 能力问题 → `record(id, "pending")` 重派一次；还不行就主会话手转。
- **needs_human**：读 `work/review/<id>/verdict.json` 与 `work/units/<id>/feedback.md`。判断是转写错还是审核错；
  转写错且模式明确 → 主会话直接改 `work/units/<id>/out/`，跑 `validate`，`record(id, "reviewed")`。

`record` 用法：`uv run python -c "from stgtranscribe import pipeline as p; p.record('th06_s1_w03', 'pending')"`。

## opus 抽检

`sample` 选出每关 pass 卡约 20%（至少 2 张）+ 全部 `needs_human`。对每张：

1. Agent tool 派子代理，**显式 `model: "opus"`**，prompt：读 `transcribe/contracts/review.md` 按契约审
   `transcribe/work/units/<id>/`（卡在 `out/`，原文 `source.txt`），结论写回复里（它不能写 cwd 以外时就写回复）。
2. 对比 dsh 的 `work/review/<id>/verdict.json`：
   - opus 找到 dsh 漏掉的 **critical** → 改 `contracts/review.md` 的清单（把漏掉的那类显式写进去），这一关**全部重审**：
     把该关 `reviewed` 的单元 `record(id, "validated")` 后重跑 `review`。
   - 只漏 **major** → 记到 `work/sample-sN.json` 的 `misses`，看趋势；同类漏两次以上照 critical 处理。
   - opus 发现的问题本身 → 该卡 `record(id, "revise")`，把发现追加到 `work/units/<id>/feedback.md`。
3. 抽检结论（漏判率、改了什么）写进设计文档「实施偏差与实测」节。

## 常见坑

- **角度心算翻倍**：π/32 = 1024bam，不是 2048。worker 被要求照抄 `source.txt` 注释；审核发现角度整体差 2 倍就是这个。
- **粘滞难度前缀**：`!L shoot_disable();` 之后的行都是 L-only，直到下一个前缀。
- **locals 超 64**：xformdef 按物理槽 × 3 字算进引用它的 sub；拆并行任务。
- **自动射击停火守卫用 `>`**：原作设定帧当帧就 tick，首发在第 `n−1` 帧；我方 `wait(n)` 统一晚 1 帧，`first > until` 才停（对照表 §4.3）。
  2026-09-16 曾误改成 `>=`，审核若再提「until 帧多打一轮」，先核这条。改对照表后要**刷新所有单元的 `mapping-excerpt.md`**（`extract` 不覆盖已往下走的单元）。
- **弹峰值超 1024**：先看是不是 TH06 的 640 弹池在压画面（我方池 8192，屏内弹数照样超）。做法见设计 §13.4 第 2 条：
  离线复现 640 池（`work/units/th06_s3_w12/pool640/poolsim.py`，要临时放开 harness `AT_DUMP_LIMIT`）→ 拟合「某类弹 `$frame ≥ N` 的轮次不发」→
  返工派 dsh 实现 → 主会话用同一脚本复核曲线误差。不要随手抽稀颗数，也不要只收窄 ranks 了事。
- **一台机器只跑一个 `pipeline` 进程**：两个进程同秒起 dsh 会撞 `~/.dsh` 配置（`config file must be a top-level array`），并发靠 `--jobs`。
- `validate` 要求**目录名 = 卡 id**，所以 pipeline 把 `out/` 拷到 `card/<id>/` 再验。
- 别提交 `transcribe/work/`（含原文摘录，gitignore 已挡）。
