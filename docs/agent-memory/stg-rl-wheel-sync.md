---
name: stg-rl-wheel-sync
description: 升 stg_rl 版本要同时改 pyproject/uv.lock 与 magnus/wheels（+SHA256SUMS），两边哈希须相同
metadata:
  type: project
---

stg_rl（stg-engine 的 `rl-v*` Release wheel）有两个消费点：本机 `pyproject.toml` + `uv.lock`，以及 Magnus 用的
`magnus/wheels/*.whl` + `SHA256SUMS`（`magnus/bootstrap.sh` 装它）。**只改一边就会本机与 Magnus 跑不同引擎**。

**Why:** 2026-09-25 发现 pyproject 已被另一会话（转录，`470d1eb`）切到 0.3.0，而 Magnus 仍是 0.2.0——Q1…R2 在 Magnus 上是 0.2.0、
本机诊断是 0.3.0。卡池没变所以结论无碍，但下一次未必。S 批起统一 0.4.0。
**How to apply:** 升版时：`gh release download` 进 magnus/wheels、删旧 whl、重写 SHA256SUMS、改 pyproject URL、`uv lock && uv sync --frozen`，
核对 uv.lock 里的 sha256 与 magnus/wheels 一致；引擎版本变了就同批重跑对照（如 r1c-e04）。见 [magnus-old-torch-stack](magnus-old-torch-stack.md)。

2026-10-06：本地 `tool.uv.sources` 已直接引用 `magnus/wheels`，两端消费同一文件；当前为0.4.2，来源与验证见[接入记录](../practice-cards/2026-10-06-adapter-update-and-next-ab.md)。没有上游 Release 时可从经核对的源码快照构建，记录基准提交及补丁来源，勿将旧的 `gh release download` 当成必要发布操作。下一轮两臂同用新版；旧版结果保留原版本标识。

2026-11-03：用户授权后接入0.4.3，来源为引擎main `07058f3086811a8326307cad2e9423024adc531d`、ENGINE_VER29（动态xform与单值STEP）。沿用导出源码快照构建，只在快照内将Python包装版本从0.4.1改为0.4.3，不改引擎工作区；`build_info().git_sha=unknown`，提交身份与归档哈希见[来源及验证记录](../practice-cards/reports/stg-rl-043-adoption.json)。四处已同步且本地环境安装新版，Magnus消费文件已替换但未提交Job；两密度×三cap固定动作回放的全部缓冲与起点索引和0.4.2逐字节一致。旧卡未迁移；转写skill/契约/mapping随后已按用户要求同步，并刷新本机单元输入，见[核查结论](ecl-capability-audit.md)。未发布上游Release、未提交或推送。

2026-11-04：用户确认xform三阶段rand后接入0.4.4/ENGINE_VER30，基线仍为07058f3，叠加本轮已审阅的引擎源码补丁（随后提交为`2f24d8628231126b01f3025b065117c9013a4934`）；构建快照只另改包装版本。四处同步、本机安装，Python3.12/3.11真实取样检查通过，六组密度回放与0.4.3逐字节一致。精确base/patch/archive/wheel哈希及命令见[0.4.4接入记录](../practice-cards/reports/stg-rl-044-adoption.json)。用户随后授权阶段性提交并推送main；交付记录见Git历史，未发布上游Release或训练。

2026-11-05：用户授权TH06/TH18弹型大表完整运行时接入，升级0.4.5/ENGINE_VER31，表hash7091aec34290ffd7。按2f24d86工作区补丁及新增数据导出快照构建，只在快照改Python包装版本；四处同步、本机安装。727新有效槽实际出生半径核对、15项wheel冒烟、20项预览/回放检查通过；六组旧密度回放全部缓冲与0.4.4逐字节一致，旧卡未迁移。来源与限制见[0.4.5接入记录](../practice-cards/reports/stg-rl-045-adoption.json)，未训练/提交/推送。
