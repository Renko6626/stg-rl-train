# 项目背景

这里只保存理解项目所需的背景；工作约定见根目录 [AGENTS.md](../../AGENTS.md)，当前研究安排见[下一步](../next-steps.md)。

## 仓库分工

| 仓库 | 职责 |
| --- | --- |
| `stg-rl-train`（本仓） | PPO 训练、评测、ONNX 导出，以及弹幕转写的生产资料和卡池 |
| `/data/sunyunbo/www/stg-engine` | 实际弹幕模拟、碰撞、实体池、我方 ECL 编译器及 Python `stg_rl` wheel |
| `/data/sunyunbo/www/stg-agent-proto` | 游戏侧世界快照、模型输入及控制等共用协议／C 实现 |
| `/data/sunyunbo/www/renkolab` | 各作原生行为研究、现有 Ghidra 工程、游戏适配器及共享插件 |

## 东方与 ECL

- TH06／TH16／TH18 是不同作品，TH06NC 是 TH06 的重制实现，不能直接当作原版二进制。不同作品的 opcode、变量、弹型、结构体偏移和碰撞行为不能凭同名套用。
- 原作 ECL 是控制敌机、弹幕、时序等行为的脚本／虚拟机系统。我们把原作攻击转写成 **stg-engine 自己的 ECL 语言**，两者语法与执行模型不同，不要求逐指令对应。
- 判断可转写性要分别看原作行为、当前引擎能力、转写工具覆盖及现有卡是否实际采用。工具不支持某 opcode，不等于引擎无法通过整段重写实现。
- 道中段、Boss 非符、符卡都可成为独立训练段。单段固定难度、敌人无敌的躲弹外壳会改变原作压力；玩家可击杀敌人或提前击破符卡时，不能直接把此处生存率当作玩家难度。
- 卡牌源别、难度、季节及启用状态以本作指南和 metadata 为准。作者稿、机器校验、独立审核、正式收卡是不同阶段；试测过的草稿仍可能未收录。

## 游戏接入

TH16／TH18 已确认的路线是 thcrap 加载共享 x86 AI 插件，由逐版本 patch 提供地址和挂点，复用快照、ONNX 与运动层。源码在 renkolab 的 `mods/_shared/stg-ai/`、`mods/th16.v1.00a/autoplay/`、`mods/th18.v1.00a/autoplay/`；TH06NC 的 x64 适配器在 `mods/th06nc/autoplay/native/`。

TH18 自包含包选择封装现有 thcrap，游戏文件由用户自备。独立代理 DLL 仍只是后续需求；特殊几何、自动炸弹和新增协议范围不能因打包而视为已确认。TH16 季节释放和 TH18 卡牌使用／切换保留手动。构建入口、现行包说明及未验证项见[打包说明](../../tools/th18-portable/README.md)；历史决定与实施见 [TH16 计划](../superpowers/plans/2026-10-22-th16-adaptation.md)、[TH18 计划](../superpowers/plans/2026-10-22-th18-adaptation.md)和[自包含包记录](../practice-cards/2026-10-22-th18-portable.md)。

实验权重与游戏包模型分别查各自配置／manifest，不按日期推断“最新模型就是部署模型”。游戏编译、主机对拍和 Windows 实机表现也须分开记录。
