# TH18 子弹链入口修复

2026-10-22，用户 Windows 探针日志显示 ORT 推理和鼠标引导执行正常，但子弹节点、world 子弹数、实际模型子弹 mask 全部为0，过滤计数也为0。

TH18 v1.00a 原生 tick 在 `0x424c7e` 从 manager+0xc0 读取首节点；manager+0xbc 是内嵌哨兵的空 content。取消圆域子弹的独立消费者也读取 +0xc0。源码此前误读 +0xbc，测试夹具同样写错入口，导致未发现空输入。生产修复仅为首节点偏移改为 +0xc0；模型、控制、过滤及激光逻辑沿用原实现。

修正现有夹具，使用空哨兵与两个16字节原生链节点。旧实现先失败；修复后断言 world 和 probe 节点数为2，再调用真实 `sa_model_fill` 检查两行 mask 与独立给定的位置、速度、半径。保留现有过滤检查。

验证：

- 在 renkolab 使用 `gcc -std=c11 -O2 -Wall -Wextra -Werror -pedantic` 编译 `native/tests/test_extract.c`、`native/th18_extract.c` 和 canonical `sa_model.c`，运行成功：`TH18 extractor/input tests passed`。
- 使用原共享 Makefile 的 `make all`，显式指定 canonical `RENKOLAB`、`STGAGENT`、`TH16_NATIVE`、`TH18_NATIVE`；严格 x86 编译通过，PE32导出和依赖检查通过。
- `python3 tools/th18-portable/build_probe.py --base dist/th18-ai-portable-20261022-r2.zip --dll /tmp/sunyunbo/th18-bullet-head-fix-20261022/runtime/stg_ai.dll --source /data/sunyunbo/www/renkolab --output dist/th18-ai-probe-20261022-r2.zip` 成功；22个 x86 二进制依赖闭包及全部文件校验通过。

修正版包：`dist/th18-ai-probe-20261022-r2.zip`，8,184,622字节、72文件。

ZIP SHA256：`9c4a6eea37350a0f247be39a7e62f2760839124a1abc728fd76476a684db6cf3`。

DLL SHA256：`4d514b9a062c116d4554d95dc9482d7fa718f72decff50f7a0e653628d9aa162`。

共享插件、模型、ORT、加载器、启动器及 hook 地址／预期字节／type3 沿用此前诊断包。包保留 `probe:1`，日志标签仍为 `probe1`，版本以包名与哈希区分。

尚未在 Windows 实机运行修正版。下一次进入有普通圆弹的场景，应确认 `bullet_nodes`、world 子弹数与实际输入子弹 mask 均出现非零值；如仍不躲，再依据这些日志检查后续链路。已知 Infinite 激光状态口径问题仍未修复，不包含在本次范围。未训练、提交、推送或发布。
