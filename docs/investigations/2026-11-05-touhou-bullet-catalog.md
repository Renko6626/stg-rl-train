# TH06 / TH18 弹名、半径与贴图大表接入

2026-11-05。用户明确授权完整大表和运行时接入，并允许分别合成TH06、TH18的裁切图源。引擎ENGINE_VER31已接入；训练侧使用本地构建的stg-rl0.4.5，表内容hash为`7091aec34290ffd7`。未提交或推送。

## 数据与图源

新增58个按作品命名的弹型：经典TH06十型、TH18四十八型。逻辑每型16槽，旧192项保持编号、半径和图形尺寸；合计1120逻辑项，919有效、201缺色。新部分有727个有效槽，全部通过真实wheel创建与原生半径比对。

| 项目 | 位置或结果 |
|---|---|
| 唯一维护清单 | stg-engine `godot/assets/bullet/catalog.json` |
| 分作品图源 | 同目录 `source_th06.png`、`source_th18.png` |
| 离线生成器 | `godot/tools/slice_bullet_sheet.gd` |
| 图集及布局 | `godot/assets/bullets.png`、`godot/assets/bullet/atlas-layout.json` |
| 原作词表 | `godot/ecl/game/touhou-bullets.ecl` |
| Rust整数追加表 | `crates/stg-core/src/tables/touhou_appearances.rs` |
| 实际物理图集 | 1024×2560，64px格，16列40行；635个物理格 |
| 运行时表 | WorldTables格式v6，9347字节；World布局不变 |

TH06原件RGB图与独立alpha遮罩配对，TH18使用普通飞行态裁片，不取出生动画首图。小图在64格居中，不按格大小放大；旧192格逐像素与原图一致。原作缺色逻辑槽均指透明物理格192。相同RGBA图块复用，不合并逻辑弹型与半径。

原作数据证据见[TH06与NC](2026-11-05-th06nc-bullet-catalog.json)、[TH18颜色与贴图](2026-11-05-th18-bullet-textures.json)、[TH18基础尺寸](2026-11-05-th16-th18-bullet-types.json)。NC十型半径已核与经典相同；核查曾发现相对基址易混，最终以Sprite基址manager+0x608、逻辑高相对+0x1c的原生链路确认，没有采用中途的像素高误读。

## 转写用法

新卡复制所需常量，或把完整生成词表放进卡片编译目录；例如`TH06_RICE=224`、`TH18_RICE=480`。新词表直接传原作color，不沿用旧12形的8色→16色重排。TH06火弹四槽为初始动画帧别名；TH18固定色火球/音符忽略输入color，16槽共享首帧。旧卡不自动迁移。

| 例子 | 基础半径 |
|---|---:|
| TH06_RICE / TH18_RICE | 2 / 2.4 |
| TH06_BUBBLE / TH18_BUBBLE | 16 / 14 |
| TH18_BIG_YIN_YANG_R | 28 |

出生半径直接取表，无需为静态半径附加xform。弹池原字段sprite保存逻辑appearance；Godot实时、影子、倒放、消弹和harness输出时查物理图格。RL TYPE保持逻辑id，Python回放仅映射一次。`run --at`的sprite列是物理图号，不能反当原作type。

动态HITBOX/SIZE尚无通用写口；现有set_sprite/set_shape/set_color只换外观、保留出生半径的语义未改变。碰撞继续半径相加；出生减速和出生无判定按已确认取舍省略，不追求原作ANM完整复现。

## 实际验证

| 检查 | 结果 |
|---|---|
| 两次Godot图集烘焙 | PNG、布局、Rust、词表逐字节一致 |
| 全图核查 | 旧192格及新源格像素一致；919有效项非空；201缺色项透明 |
| 原生尺寸→真实wheel | 727个有效新槽全部成功出生，逻辑id和实际radius raw均匹配；无xform；缺失硬币色号3编译拒绝 |
| Rust相关包 | core/compiler/harness/Godot通过；更新版本锚点及内置词表文件数后，RL单独重跑通过 |
| fmt / clippy / verify-tables | 通过 |
| Python预览与回放 | 20通过，排除1项会启动PPO训练的既有端到端用例 |
| wheel既有冒烟 | 15通过 |
| 旧卡对照 | 两密度×三cap、每组4env×600步，全部缓冲及起点索引与0.4.4逐字节一致 |
| Godot headless编辑器 | 无脚本/Shader错误 |
| 独立只读审阅 | 无待修critical/important；已知纯表现限制保留 |

完整wheel来源、SHA256、命令与结果见[接入JSON](../practice-cards/reports/stg-rl-045-adoption.json)。pyproject、uv.lock、Magnus wheel与SHA256SUMS已同步，未提交训练Job。

新旧golden因World的tables_hash入校验和而从帧0改变，不能声称逐字节不变；两份流的SHA256已记录在接入JSON。旧行为另以固定动作观测回放核验；这覆盖已列场景，不是穷尽全部原作攻击。

随后按用户要求清理了日期命名过程目录：一次性脚本、完整日志、golden流与重复wheel已删除，正式结论、来源数据和哈希保留。弹型总览图整理至 `transcribe/work/preview/bullet-catalog.png`；可维护清单、图源和离线生成器仍在引擎正式目录。

## 边界

普通态图使用静态帧，尚未复现ANM动画、绘制anchor offset及加色混合；独立审阅确认这些offset只影响绘制顶点，不改物理位置/尺寸。原作碰撞公式、动态缩放/半径和换型刷新差异仍单列。曲线激光仍暂不做。

本轮未运行原作、Windows、GPU或跨平台确定性对拍，未启动PPO训练。后续重烘流程与运行时接口见引擎 `docs/bullet-catalog.md`。
