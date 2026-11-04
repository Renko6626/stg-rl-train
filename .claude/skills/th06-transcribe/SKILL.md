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
| 主会话（你） | 启动命令、分诊 `blocked` / `needs_human`、opus 抽检、修对照表与契约；提交和推送分别取得用户授权 |

worker **派不了子 worker**（dsh 要写 `~/.dsh`，沙箱只读）。所有派发都走 `pipeline.py`。

## 启动前自检

```bash
uv run --frozen python -c 'import stg_rl; print(stg_rl.build_info())'
uv run --frozen pytest -q tests/transcribe          # 对照表覆盖率 + 片段编译 + 范例卡四层验收
```

用 `stgtranscribe.config.harness_bin()` 确认 release harness 路径；引擎改过就重编，不能只检查文件存在。
2026-11-04 训练基线为 `stg-rl==0.4.4`、ENGINE_VER30，来源与哈希见
`docs/practice-cards/reports/stg-rl-044-adoption.json`；动态 xform 从 ENGINE_VER28 起支持，模板体 rand 从30起支持。
源码 HEAD、已构建 harness 和已安装 wheel 要分别核对。升级依赖按
`docs/agent-memory/stg-rl-wheel-sync.md` 同步四处，不能只重编 harness；旧 spec §3.5 的版本号是历史记录。

## 动态 xform 转写口径

- 以 mapping §5 的求值表和完整例子为准。原 `bullet_effects` 配置点保存参数；同一配置发出的弹共享配置值，直到重配。
- 运行期角度/速度/加速度用 `NAME(args)` 按值传入，保留随机取样位置；新卡不再因“参数非常量”改用任务、全局槽或量化。
- 模板体允许 rand：未标记时绑定抽一次、同配置共享，`at_spawn` 每弹出生抽一次，`at_effect` 每次操作进入抽一次；STEP/等待中保持。仍按原作取样位置选择阶段，`@N` 仍是字面量后置等待。
- 旧零形参全常量路径仍占 locals，并保留同 sub 配置/开火约束；带参/动态绑定可经同步 helper，发射器仍为任务私有。
- 新能力不解除 8 逻辑缓存、16 物理槽、256 总任务槽等独立限制。旧卡迁移要逐卡核原文、效果时序和随机共享，文档更新不代表旧卡已还原。

## 刷新已有单元输入

修改 mapping 或引擎签名后，**派发前刷新本次目标单元**。`extract` 跳过已进入后续状态的单元，重跑它不会刷新这些输入。
`builtins.md` 只收签名，动态 xform 的额外语法保留在 mapping §5，避免要求 worker 整篇读引擎手册。
以下从仓库根目录执行，`ids` 填实际目标；仅更新两份派生文档：

```bash
uv run --frozen python - <<'PY'
import json
from stgtranscribe import config, mapping
from stgtranscribe.extract import builtins_cheatsheet

ids = ["th06_s4_b16"]  # 换成本次准备转写/返工/复审的单元
text = (config.TH06_DIR / "mapping.md").read_text()
ref = config.engine_dir() / "docs/ecl-lang/7-reference.md"
cheat = builtins_cheatsheet(ref)
for uid in ids:
    d = config.WORK_DIR / "units" / uid
    unit = json.loads((d / "unit.json").read_text())
    (d / "mapping-excerpt.md").write_text(mapping.excerpt(text, set(unit["used_instructions"])))
    (d / "builtins.md").write_text(cheat)
    print(uid)
PY
```

旧 `work/review/<id>/` 保留当时的资料与 verdict；重新 `review` 时流水线会从单元目录复制新输入。
刷新资料不改变卡内容、状态、验收结果或抽检结论；需要返工的卡另按下文分诊，不能据此直接标记 reviewed。

## 标准顺序（一关一关推）

```bash
P="uv run --frozen python -m stgtranscribe.pipeline"
$P split --stages 1-7          # 可以一次全关
$P extract --stages 1-7
$P transcribe --stage N --jobs 16
$P review --stage N --jobs 16
$P transcribe --stage N        # 处理 revise
$P review --stage N
$P status --stage N
$P sample --stage N            # → work/sample-sN.json
# opus 抽检（见下）
$P collect --stage N           # 收卡后核对改动；仅在用户授权后提交，推送另需授权
```

默认后端仍是 dsh-flash；如按已有约定切换 `transcribe/tools/claude-worker`，用 Sonnet、`--jobs 4`，不要照上例开 16 路。
后台启动后按 `docs/agent-memory/verify-background-launch.md` 核实实际 worker 与日志；日志在 `transcribe/work/logs/`，以实际文件名为准。

## 便笺分诊（每批跑完必做）

worker 撞上「可能影响别的单元」的问题会写 `notes.md`（判据、格式见契约）。每批结束后：

```bash
$P notes            # 只列未分诊的，按影响面排序（疑似全池 → 疑似同关 → 只此单元）
$P notes --mark     # 处理完把这批标记掉
```

处置：证据成立且影响面大 → 改 `mapping.md` / 契约，按改动运行相关既有检查，并按上文刷新受影响的待派发单元；
必要时把已入库的卡打回返工。属引擎缺机制 → 先记录证据与候选处理，不自行扩展引擎功能；
只此单元 → 确认已写进 report/verdict 即可。**1–3 关那批的三个批量扩散问题（§4.3 停火守卫、640 弹池、
出生特效降速）都是撞了一次却影响全池，当时没有这条通道，全靠事后抽检才发现。**

## 用量账

```bash
$P usage [--stage N] [--since 2026-09-18]   # 步数 / 计费输入估算 / 推理占比 / 最贵 5 次
```

成本 ≈ 步数 × 平均上下文（每步重发整段），所以省钱先砍步数与上下文，不要合并单元
（合并只会让后面的步背上前面的痕迹，N 个单元合跑约 N 倍差）。

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

1. 在提供 Opus 的 Claude 环境使用 Agent tool，**显式 `model: "opus"`**，prompt：读 `transcribe/contracts/review.md` 按契约审
   `transcribe/work/units/<id>/`（卡在 `out/`，原文 `source.txt`），结论写回复里（它不能写 cwd 以外时就写回复）。
   当前环境没有 Opus 时保留待抽检清单并说明，不能换一个模型后宣称已完成 Opus 抽检。
2. 对比 dsh 的 `work/review/<id>/verdict.json`：
   - opus 找到 dsh 漏掉的 **critical** → 改 `contracts/review.md` 的清单（把漏掉的那类显式写进去），这一关**全部重审**：
     把该关 `reviewed` 的单元 `record(id, "validated")` 后重跑 `review`。
   - 只漏 **major** → 记到 `work/sample-sN.json` 的 `misses`，看趋势；同类漏两次以上照 critical 处理。
   - opus 发现的问题本身 → 该卡 `record(id, "revise")`，把发现追加到 `work/units/<id>/feedback.md`。
3. 抽检结论（漏判率、改了什么）写进设计文档「实施偏差与实测」节。

## 常见坑

- **角度心算翻倍**：π/32 = 1024bam，不是 2048。worker 被要求照抄 `source.txt` 注释；审核发现角度整体差 2 倍就是这个。
- **粘滞难度前缀**：`!L shoot_disable();` 之后的行都是 L-only，直到下一个前缀。
- **locals 超 64**：先区分旧常量 xform 的 staging 与新按值绑定。旧路径按物理槽 ×3 占 locals；动态模板另核捕获/物理槽预算，不为绕过旧限制无条件拆并行任务。
- **自动射击停火守卫用 `>`**：原作设定帧当帧就 tick，首发在第 `n−1` 帧；我方 `wait(n)` 统一晚 1 帧，`first > until` 才停（对照表 §4.3）。
  2026-09-16 曾误改成 `>=`，审核若再提「until 帧多打一轮」，先核这条。改对照表后按上文刷新受影响的待派发单元。
- **弹峰值超 1024**：先看是不是 TH06 的 640 弹池在压画面（我方池 8192，屏内弹数照样超）。做法见设计 §13.4 第 2 条：
  离线复现 640 池（`work/units/th06_s3_w12/pool640/poolsim.py`，要临时放开 harness `AT_DUMP_LIMIT`）→ 拟合「某类弹 `$frame ≥ N` 的轮次不发」→
  返工派 dsh 实现 → 主会话用同一脚本复核曲线误差。不要随手抽稀颗数，也不要只收窄 ranks 了事。
- **激光卡（2026-09-25 起可转）**：规则在 mapping §14，引擎侧口径在 stg-engine spec `2026-09-25-laser-pool-design.md` §9.1。
  1–2 关早先按 `skip: "laser"` 切过的单元（s1_mb2、s1_b3、s2_b4）要重切：`split --stages 1,2 --force` 后 `extract`，
  否则 `split_check` 会报「标了 skip 但机械检查没发现」。第 4 关（帕秋莉）从没切过。`ex_ins_12 / 14`（在激光上 / 沿激光发弹）用激光读口 `lz_x/lz_y/lz_angle/lz_near/lz_far` 转（mapping §14.4）。
  **前提**：训练仓的 `stg-rl` wheel ≥ 0.3.0（rl-v0.2.0 的编译器不认 `laser()` / 激光读口），release harness 也要重编。
- **一台机器只跑一个 `pipeline` 进程**：两个进程同秒起 dsh 会撞 `~/.dsh` 配置（`config file must be a top-level array`），并发靠 `--jobs`。
- `validate` 要求**目录名 = 卡 id**，所以 pipeline 把 `out/` 拷到 `card/<id>/` 再验。
- 别提交 `transcribe/work/`（含原文摘录，gitignore 已挡）。
