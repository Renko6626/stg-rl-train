# TH18 首轮实现记录

2026-10-22。用户要求沿用 TH16 的接法。两项并行实现与独立原生／ABI 审阅已完成，源文件已集成到 renkolab；尚未 Windows 游戏内实跑。

## 产物与行为

- 新增 `renkolab/mods/th18.v1.00a/autoplay/` 的 11 个源码、关键行为测试、逐版本 patch 和文档文件。
- 更新 `mods/_shared/stg-ai/` 的 README、plugin.c、Makefile 三个文件；同一 x86 DLL 显式选择 TH16 或 TH18，不增加公共协议、模型输入或训练。
- 支持已核对的圆弹、普通圆形敌人体碰、直线／无限激光；TH18 的字段、宽度公式与运动按本作消费指令处理。
- 默认 MANUAL，F10 轮换 MANUAL／AUTO／BYPASS，沿用手动方向／Shift 优先和普通原生客户区鼠标引导。C 发动卡牌、D 切卡、X 炸弹保留手动。
- 特殊形状仍由暂定门交回手动，最终策略未获确认；自动炸弹未启用。不能把当前草稿称为完整代打验收。

支持样本仅 TH18 v1.00a，MD5 `9969cac756098c1da05a81de45437a70`。挂点 VA `0x45be90`，原字节 `55 8B EC 83 E4 F8`，type3、六字节完整指令窗口；输入 tick 在前，自机消费在后，商店期间原生 wrapper 跳过该 body。

草稿包：`dist/th18-autoplay-thcrap-20261022-draft.zip`，34 文件、5,818,692 字节。包含插件、图6 B/Shift K8 模型、官方 ORT1.22 x86 DLL 与声明、patch、示例配置、适配源码和独立审阅记录；不包含原作游戏文件或 thcrap 本体。TH16 旧草稿包保留。

| 文件 | SHA256 |
| --- | --- |
| ZIP | `da71d5daa9ff0335334b6a13e64ee4b57c7ee9308dce61784753aee7e41876c6` |
| 共享 DLL | `75e51ad9a4bb729b94e12d95340f49fe446498f6faf8c9d70a74e387fae08695` |
| 模型 | `e47016c892fc7b0a9667b959d6e06ee10bff4261ea805022b7b8f4e04b7bc7f1` |

## 实际验证

TH18 生产抽取／输入夹具编译命令：

```bash
cc -std=c11 -Wall -Wextra -Werror \
  -I/data/sunyunbo/www/stg-agent-proto/c \
  -I/tmp/sunyunbo/th18-autoplay-20261022/renkolab/mods/th18.v1.00a/autoplay/native \
  /tmp/sunyunbo/th18-autoplay-20261022/renkolab/mods/th18.v1.00a/autoplay/native/tests/test_extract.c \
  /tmp/sunyunbo/th18-autoplay-20261022/renkolab/mods/th18.v1.00a/autoplay/native/th18_extract.c \
  -lm -o /tmp/sunyunbo/th18-extract-test
/tmp/sunyunbo/th18-extract-test
```

结果 `TH18 extractor/input tests passed`。覆盖真实输入边沿与卡牌位保留、阶段／回放、原生弹状态、特殊形状计数、激光几何与连续回调历史。共享 native 目录执行 `make all host-check`，显式指定原 renkolab／stg-agent-proto、原 TH16 与暂存 TH18 路径；既有 `test_policy`、`test_policy_model` 和另行编译的原 TH16 抽取器夹具通过。

独立审阅发现两项中等缺陷：生成末期致死子弹实际以半速移动，部分 flags 分支只有擦弹或跳过碰撞。已按消费指令修正，更新原有夹具的直接行为断言，针对性检查与复核通过。修正后只执行受影响的 `make all`，`make -q all` 确认二进制最新。PE 检查确认 i386、两个无装饰导出及 KERNEL32／USER32／msvcrt 依赖；ORT 动态加载。

主 agent 核对 patch JSON／CRC、实际 exe 挂点原字节与 type3 窗口、14 个集成文件的 SHA、包内 CRC／逐文件 SHA。原文档检查器对六份相关 Markdown 的链接／地址／版本／表格检查通过。安装前核对共享文件基线，保留原有未提交改动与更新前备份；未提交、推送或发布。

实现、审阅及构建日志暂存 `/tmp/sunyunbo/th18-autoplay-20261022/reports/`；关键原生证据与限制已写入 renkolab 的 FIELD-NOTES／AUDIT／NEXT。

## 未验证与待办

Windows thcrap／x86 ORT 实际加载、游戏稳定性、真实模型效果与开销尚未验证。模型仍来自 TH06 转写环境；卡牌漂移／瞬移、全部原生碰撞组合、未来 EX／ECL 变化不因接口接通而得到完整预测。特殊画面变换／DPI 的鼠标换算、AI 录像正确回放也未验证。特殊形状策略、自动炸弹与独立简易安装包继续保留待办，详见[接入背景](../agent-memory/project-context.md#游戏接入)。
