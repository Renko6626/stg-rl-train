# 三作 BYPASS 追敌，Boss 优先

2026-10-22，用户确认：“都改成所有敌人都追，但有boss优先boss”。范围为 TH06NC、TH16、TH18 部署侧 BYPASS；训练意图、模型及图6签名不变。

共享模型策略及 TH06NC builtin 均优先选择第一个可碰撞 Boss，没有时选第一个可碰撞普通敌人；同类沿用原池／链顺序，无目标回底部中央。横向跟随敌人，纵向保持既有站位。AUTO 自由躲弹、鼠标引导、压力切自由、手动接管、运动层及各作炸弹配置沿用原规则。保留旧 `under_boss` 配置名，避免旧 INI 失效。

TH06NC 原生 Boss 身份改读 enemy+0xbd 的0x08位，不再将默认槽下标0当作 Boss；字段依据见下文。TH16／TH18 抽取代码本轮未改，TH18 包保留此前首节点+0xc0修复。

## TH06NC 字段依据

旧抽取器用 `i32(enemy+0x230)>=0` 标记 Boss，但该字段在普通敌人中默认为 0，导致旧 BYPASS 也会追小怪。TH06NC 原生 reset `0x140035f50` 清零管理器与敌机模板；模板清零调用 `0x140035f77`、大小 `0x10b0`，后续赋值未覆盖 `+0x230`，spawn `0x14003611e` 至 `0x140036138` 复制完整模板。opcode101 在 `0x140027215` 写的是 BYTE，不能解释成这里的 i32 Boss 编号。

真正 Boss 位为 `enemy+0xbd` 的 `0x08`：原生 `0x14002720b` 设置、`0x140027236` 清除，消费者亦测试该位。因此不能只读共享选择器里的 `boss` 条件就推断各作实际追敌范围。此次修正身份字段，同时按用户要求显式追踪所有可碰撞敌人、Boss 优先，避免修标签时丢掉小怪跟随。

## 验证


- 在 TH06NC `native/tests/` 执行 `make build/test_policy build/test_policy_model STGAGENT=/data/sunyunbo/www/stg-agent-proto`，随后运行两程序，均通过。复用现有用例检查小怪跟随、后排 Boss 优先、同类池序、不可碰撞排除及无目标回中。
- `gcc -std=c99 -Wall -Wextra -Werror -pedantic` 编译真实 TH06NC 提取器及现有夹具并运行通过；普通敌人默认槽0仍为普通，设置／清除 Boss 位时身份正确更新。
- 共享 `make all` 严格 x86 编译和 TH06NC `build.sh` x64交叉编译通过；精确导出／导入检查通过。新 x86 DLL：`06d874ef8c2edd8db1fd16dd90921ad370eeb2073a5b80ee4956221eb1710aff`；新 x64 DLL：`4d86c7484bb65d13096a6bcc9cbf7a3b4f65487c8b5dc0f01e7c681f5cc0beca`。
- 因修改 TH06NC header，运行原有 `native/check.py`，仅由 wrapper 将仓库和样本读取路径指向原仓、新源码和 DLL 保持 staging；样本／序言／ABI／代理／导出／导入及三项宿主检查全部通过。checker与断言未改。
- TH18 使用 `tools/th18-portable/build_probe.py` 基于固定 normal r2 包生成新 r3，22个 x86 二进制依赖闭包及归档校验通过。其他两包更新脚本随包附于 `source/package_other_games.py`；模型与 ORT 字节、TH16 patch/config均与旧包一致。

交付均在 `dist/`，旧包保留：

| 包 | 字节 | SHA256 |
| --- | ---: | --- |
| th18-ai-probe-20261022-r3.zip | 8222459 | f109e39a7dea898c59e343c6e46a6f54d717c3f774ec53c4ad78d64da7a59186 |
| th06nc-autoplay-20261022-enemy-follow.zip | 7816329 | 8afa284ac4f5d26ac78a5103ae7b1e8e182c9d56cfe44c5706a46a61ad026959 |
| th16-autoplay-thcrap-20261022-enemy-follow-draft.zip | 5880501 | 21062bbe1767e08ee0b3bc11cc28c5097ae6aff04921fe11003826e52e11d8a5 |

TH18 为完整自包含包，双击启动器，F10切模式；TH06NC 备份后把根目录文件放游戏旁，C切模式；TH16仍为原 thcrap 接入草稿，非自包含启动器。三者均不含游戏文件。未实机验收本次追敌规则，未提交、推送、训练或发布。
