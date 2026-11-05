# 东方 ECL 模型转写

将原作攻击转为 stg-engine 躲弹卡。按作品准备源材料与映射，经模型转写、自动验收、独立源语义审核和抽检后收卡。当前 TH06/NC 有批量工具，TH18 有切分指南和单攻击写审设施；多作品批量调度尚未实现。

## 从这里进入

| 工作 | 入口 | 当前范围 |
|---|---|---|
| TH06/NC 批量转写 | [TH06 操作说明](th06/README.md) | 切分、摘录、转写、验收、审核、抽检清单、收卡 |
| TH18 整关切分 / 单攻击写审 | [TH18 入口](th18/README.md) | 人工/AI切分记录、任务单准备、独立写审、共用单卡验收 |
| 合成练习卡 | [synthetic 入口](synthetic/README.md) | 设计brief或底子卡、独立写审；成品与原作共用卡库 |
| TH18 语法与机制 | [转写教材](th18/mapping.md) / [统一口径](th18/transcription-policy.md) | 本作已核语义、已批准差异、未支持机制 |
| 单卡自动验收 | [TH18 编号与规则](th18/validation.md) | `stgtranscribe.validate` 支持 TH06、TH18；预算按来源区分 |
| 目标卡试玩与出图 | [TH06 操作说明中的工具](th06/README.md#试玩) | `preview` / `play.sh` 从统一卡库发现启用卡，可按单卡预览 |
| 历史现代 ECL 导入原型 | [原型说明](../tools/th18-import-prototype/README.md) | 独立实验；有限子集代码生成，不是模型转写入口 |

TH06 契约在 `th06/contracts/`，TH18 契约在 `th18/contracts/`，合成契约在 `synthetic/contracts/`。成品统一进入 [cards/<source>/<id>](../cards/README.md)，不再新增根目录 cards-* 卡池。不要把 TH06 的坐标、色号、时序、激光规则或旧预算套到其他作品。

## 目录与归属

```text
transcribe/
  README.md                跨作品导航、工具边界与工作区约定
  th06/                    本作操作说明、配置、映射、范例、contracts/
  th18/                    本作教材、参考表、切分/验收规则、contracts/
  synthetic/               合成设计、作者/审核契约
  tools/claude-worker      现有 Sonnet 后备执行入口
  play.sh                  目标卡试玩入口
  work/                    本地工作资料与生成物，整个目录忽略
src/stgtranscribe/         现有 Python 工具（范围见下表）
tests/transcribe/          对应检查
tools/th18-import-prototype/  历史导入原型，与模型写审分开
```

| 工具 | 实际边界 |
|---|---|
| `pipeline` | TH06 批量驱动；提示词、来源路径、切分结构和状态选择仍固定 TH06 |
| `thecl`、`structure`、`split_check`、`extract`、`mapping` | TH06 文本格式、依赖/切分规则与参考摘录，不能直接解析 TH18 |
| `units` | 编号识别支持 TH06/TH18，其余闭包、来源与时限辅助仍有 TH06 规则 |
| `validate` | 目标卡编译、运行、元数据与开场安全；支持 TH06/TH18，不证明原作等价 |
| `preview` | 目标 harness 转储出图，不负责原作解析 |
| `usage`、`notes`、`density` | 已有用量、便笺、密度辅助；调用与目录仍围绕现有流程 |
| `config` | 引擎与工作区路径；引擎默认路径仍从 TH06 配置读取，可用 `STG_ENGINE_DIR` 覆盖 |

## 工作区

- `work/th18/stage01/`：当前 TH18 一面切分材料。后续单元目录按[单卡约定](th18/validation.md)建立；现有 `split.md` 的 W00/M1/C1 等为试切标签，派发前映射为最终 `th18_s…` 编号，不能直接当卡目录名。
- `work/units/`、`review/`、`split/`、`logs/`、`state.jsonl`：现有 TH06 生产记录。`sample-s*.json` 与 `notes-triaged.txt` 也属于这套记录；不随临时调研清理，不当作 TH18 的任务状态。
- `work/preview/`、`work/play/`：预览与试玩产物；弹型总览为 `work/preview/bullet-catalog.png`。
- `work/archive/th06/`：已结束的批次脚本、A/B 试验、小机制探针、历史抽检和分诊材料。保留原内容及当时路径，仅供追溯；脚本不是当前操作入口，不能原样重放整批。
- `work/th18-prototype/`：历史导入原型的镜像、轨迹与构建物。其工具仍引用这个位置，本轮不搬动。

2026-11-05 整理：TH06 操作说明移到 `th06/README.md`，三份契约从 `transcribe/contracts/` 归入 `th06/contracts/`，驱动配置同步；18 项散落历史材料归档（89 个文件，内容保留）。旧 brief 中的契约路径保留为当时记录；重派用当前 `pipeline` 生成任务单，不直接重放旧 brief。没有改变卡内容、写审状态或来源记录。

调研、下载和一次性验证结束后，结论与来源位置与版本写进正式文档。只保留有追溯用途的过程资料；仍在使用的资料按作品/关卡/单元放置，避免长期堆日期目录。`docs/investigations/` 保存研究证据，`docs/practice-cards/` 保存训练/部署实验，不再把同一份机制规则复制到各处。

## 运行与质量边界

使用项目锁定环境 `uv sync --frozen`。训练仓目前声明 `stg-rl==0.4.5`；新弹型要求 ENGINE_VER31 配套表。源码、release harness 与已安装 wheel 须分别核验，见[升级约定](../docs/agent-memory/stg-rl-wheel-sync.md)。

```bash
# 两作共用的单卡验收，目录名必须是最终单元编号
uv run --frozen python -m stgtranscribe.validate <卡目录> --json <报告路径>
# 转写相关已有检查
uv run --frozen pytest -q tests/transcribe
```

默认 worker 后端仍为 dsh-flash；Sonnet 后备入口与并发 4 约定见 [TH06 操作说明](th06/README.md#跑)。写与审分开，dsh 审核后的 Opus 抽检及逐条复核要求保留；生成抽检清单不等于完成抽检。自动验收不替代原作数值审核、动态对拍或训练效果检查。

TH18 的奖励编队独立成波、尾部隔离、掉落/表现省略按[已批准口径](th18/transcription-policy.md)处理；曲线激光仍暂缓。只有当前攻击实际涉及的机制缺口需要补证据，不以其他攻击的未知项阻塞本单元。

原作全文、摘录、素材和派生运行数据留在已忽略的 `work/` 或 renkolab `local/`。正式收卡、启动训练、提交和推送各按当前授权执行。

目录整理与模型后端分开：新任务不要求反复计算输入/参考/目标hash，也不添加冻结或签名流程。必要编译运行与独立审核保留，行为变更只补受影响检查。
