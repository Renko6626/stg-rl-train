# TH16 首轮实现记录

2026-10-22。用户明确要求派发子代理实施。[已确认路线](../agent-memory/project-context.md#游戏接入)为 thcrap 加载共享 x86 AI 插件，逐版本 patch 保存 TH16 地址／预期字节。独立安装包留待后续，不启动训练。

## 当前产物

原 renkolab 中仅新增 16 个源码／文档／patch 文件，既有未提交修改保留：

- `mods/_shared/stg-ai/`：共享能力插件源码、构建入口和说明。
- `mods/th16.v1.00a/autoplay/`：纯 C 抽取器、输入注入、关键行为测试、逐版本 patch、TARGET、FIELD-NOTES、AUDIT、NEXT。

直接编译既有 TH06NC 纯 C 控制代码和 `stg-agent-proto` 的 canonical model／motor／ORT 源文件，没有修改或复制另一份算法。当前默认 MANUAL，F10 轮换；C 季节释放保留原生手动输入。普通三种原生分辨率的鼠标引导已有指令与最终合成脚本依据，特殊画面变换仍未验证。

已准备本地审阅草稿 `dist/th16-autoplay-thcrap-20261022-draft.zip`，30 文件、5,808,606 字节。包含 x86 插件、图6 B/Shift K8 模型、官方 ORT1.22 x86 运行时、许可证声明、thcrap patch、示例配置、新增源码及限制说明；不含游戏 exe、资产、Ghidra 工程或 thcrap 本体。

- ZIP SHA256：`889dfcd5ed51fbc670e88080c1031820dc834786e366e2442fb56ce137351079`。
- 插件 SHA256：`8814331d638e114c7dbed5057a6d241786b64e294e82c569d242f173306da445`。
- 模型 SHA256：`e47016c892fc7b0a9667b959d6e06ee10bff4261ea805022b7b8f4e04b7bc7f1`。
- ORT DLL SHA256：`f898b430bb6130b8c1394f98ea1c6f4134752919cf96601da27537a8b9458fdb`。

## 验证与修正

子代理实际执行的相关检查：

```bash
cc -std=c11 -Wall -Wextra -Werror \
  -I/tmp/sunyunbo/th16-autoplay-20261022/renkolab/mods/th16.v1.00a/autoplay/native \
  -I/data/sunyunbo/www/stg-agent-proto/c \
  /tmp/sunyunbo/th16-autoplay-20261022/renkolab/mods/th16.v1.00a/autoplay/native/extract.c \
  /tmp/sunyunbo/th16-autoplay-20261022/renkolab/mods/th16.v1.00a/autoplay/native/tests/test_extract.c \
  -lm -o /tmp/sunyunbo/th16-autoplay-20261022/test_extract
/tmp/sunyunbo/th16-autoplay-20261022/test_extract
```

结果 `TH16 extractor/input tests passed`。测试调用真实生产抽取与输入逻辑，覆盖原生输入边沿／方向优先级／季节位保留、阶段门、生成中致死子弹、几何／形状报告、容量计数及慢速历史；没有新建大型验证框架。

在暂存共享插件 `native/` 中执行：

```bash
make host-check RENKOLAB=/data/sunyunbo/www/renkolab STGAGENT=/data/sunyunbo/www/stg-agent-proto
make RENKOLAB=/data/sunyunbo/www/renkolab STGAGENT=/data/sunyunbo/www/stg-agent-proto
```

既有 `test_policy`、`test_policy_model` 通过；x86 DLL 构建无警告。PE 检查确认 Intel80386、两个无装饰导出和预期静态依赖；官方 ORT DLL 也核实为 x86，仍需要 Windows 上的 VC++ x86 运行时。

独立审阅发现一个中等缺陷：原生缩放计时器会在 dt=0.5 时重复整数帧，导致运动层与激光历史反复清空。改为使用已有逐次自机回调计数，保留原有生命周期复位；针对性回归、DLL 重建和独立复核通过，没有引入新计时／恢复机制。原生 hook 字节、完整指令边界、type3 浮点状态保存、cdecl 回调与输入写入范围均有地址级审阅依据。

主 agent 核对了复制后的 16 个文件哈希、patch 原字节／type3／六字节窗口，以及草稿包 CRC 和逐文件 SHA。使用 renkolab 原有文档检查函数检查新增的 6 份 Markdown，链接／地址／版本／表格均通过。未重复无关训练测试或运行全仓训练。

## 仍待确认／验证

- 用户尚未回答首版对矩形弹、曲线／未知激光及特殊敌人几何的处理范围。临时交回手动门并非已批准的最终发布策略；不能静默忽略后宣称完整适配。
- 自动炸弹预测器与 TH16 原生几何尚未对齐，暂未接入，炸弹保留手动。原有安全网需求未取消。
- 容量超过模型原始输入表时如何处理仍需明确；当前只报告丢失计数，不宣称完整观察。
- 未在 Windows 启动 TH16、thcrap 或 x86 ORT，未实测躲弹效果／开销／鼠标／暂停菜单；模型为 TH06 转写环境权重，跨作泛化尚无结果。
- AI 注入晚于原生录像记录，暂不支持正确保存 AI 回放；回放输入不接管。

因此当前产物是可审阅、可构建的实验草稿，不是完整验收或正式发布。未提交、推送、发布 Release 或启动训练。
