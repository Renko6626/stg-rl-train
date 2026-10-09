# TH06NC 模式调整与手动接管

2026-10-06，用户要求 AUTO 默认仅躲弹、鼠标可引导；BYPASS 改为原 AUTO 行为，并让人的手动操作始终优先。用户随后确认沿用按住鼠标左键，并保留自动射击与炸弹安全网。

## 当前行为

- AUTO 未按左键时自由躲弹，模型的目标坐标设为自机当前位置；按住左键跟随光标，松开恢复自由躲弹。
- BYPASS 使用原 AUTO 的锚点与压力切换：默认 boss 下方，压力大时临时自由躲弹；也可按住左键引导。
- 两个模式自动射击，保留既有炸弹安全网。C 仍按 MANUAL / AUTO / BYPASS 顺序切换，默认 MANUAL。
- 方向键按住即替换整组 AI 方向，同时由人的 Shift 状态决定高低速；松开方向键后 AI 恢复。单独按 Shift 也会强制低速，手动射击、炸弹始终传入。方向接管不经过 AI 运动层的保持／延迟，并清掉放弃的 AI 延迟请求。
- 模型动作历史每帧记最终执行的移动，保持时长只更新一次。相反方向键的历史归一化按原游戏 UP 优先于 DOWN、RIGHT 优先于 LEFT；输出给游戏的原始方向位保留。
- 使用游戏本帧的逻辑输入，含键位重映射和手柄；回放不接管，其余输入位保留。AI 与手动混合帧不标为纯 HUMAN，以免混入模仿学习的人类样本。

修改只在 renkolab 的 `mods/th06nc/autoplay/`：hook、内置策略、模型策略、现有测试与说明。图签名、模型输入、训练 reward、AI 运动层参数和原 8 帧激光平滑未改。

## 试玩包

`/data/sunyunbo/www/renkolab/out/th06nc-autoplay-20261006-b-shift-modes-input.zip`，7,743,643 字节、13 文件。训练仓 `dist/` 和 renkolab `mods/th06nc/autoplay/dist/` 有相同 ZIP 及 SHA 文件。

ZIP SHA256：`20130761e00ed4977383b8fd532f3b34bc03cf373d77d1ab4b538fd249efe877`。

新 Windows x64 DLL SHA256：`7278520d23bdfe0e88ea8b3fa6d34eb8397a9460ffed56515cf45d3269139fe3`。

默认仍为[带 Shift 罚分的 B/K8 u1000](2026-10-06-b-shift-th06nc-package.md)，ONNX SHA256 `e47016c892fc7b0a9667b959d6e06ee10bff4261ea805022b7b8f4e04b7bc7f1`。ORT1.22.0、两个模型及许可证沿用原包；新 DLL 已重建。旧 B/Shift 包未覆盖，SHA256 仍为 `b7aae99795d664f2dedc539306b0422a773206fce453201881e3d4d4f50a3f41`。

解压后先备份旧 DLL 与 INI，再将目录内文件一起放到 `th06nc.exe` 旁。INI 默认新 B，也可改 `model` 为随包附带的 `t8-laser-k4-best.onnx` 并重启。

## 验证与边界

- `make -C /tmp/sunyunbo/th06nc-mode-input-20261006/renkolab/mods/th06nc/autoplay/native/tests test`：三个现有测试程序通过，覆盖模式锚点／压力与真实手动混合／动作历史逻辑。
- `STGAGENT=/tmp/sunyunbo/th06nc-mode-input-20261006/stg-agent-proto XWIN_CACHE=/data/sunyunbo/.cache/cargo-xwin/xwin bash /tmp/sunyunbo/th06nc-mode-input-20261006/renkolab/mods/th06nc/autoplay/native/build.sh`：Windows x64 交叉编译通过。
- `PYTHONDONTWRITEBYTECODE=1 python3 /tmp/sunyunbo/th06nc-mode-input-20261006/audit_staged.py`：运行原有 `native/check.py`，仅将仓库／游戏样本读取路径设为真实 renkolab、代码和 DLL 仍取暂存目录；地址、序言、跳板、栈对齐、代理导出和主机测试全部通过。
- 一手 PE 复核：`WinMain` 的 `0x140045cc1` 调用 `0x14007a510` 注册 Supervisor 回调 `0x140079c70`，优先级 0，先于同 calc 链中的 Player 优先级 7。`0x140079d32` 采集输入、`0x140079d37` 刷新 INPUT_HELD，故 hook 读取的是本帧输入。相反方向优先级来自 Player 的 `0x140069072/0x140069082/0x140069092/0x1400690d3/0x140069103`。
- `python3 /tmp/sunyunbo/th06nc-mode-input-20261006/prepare_package.py`：ZIP CRC、13 文件、逐文件 SHA、默认模型来源与未改模型／ORT 哈希通过。安装前核对原源文件 SHA，安装后核对全部 10 个改动文件、新 DLL、两处镜像与旧包哈希。
- 两仓 `git diff --check` 通过。renkolab 的 `PYTHONDONTWRITEBYTECODE=1 python3 tooling/check-docs.py`：链接／地址／版本检查通过；表格检查失败，唯一问题为本次未改动的 `mods/th06nc/autoplay/release/onnx/README.md:12` 单元格 231 字符超过 200。未扩展本次工作修改该文件。

同一 B 模型此前的严格数值门仍有一帧误差 `1.335144e-5 > 1e-5`，包内保留失败记录，没有改阈值或宣称数值门通过；本次未重新导出模型。尚未进行 Windows 游戏内游玩验收。未提交、推送、发布 Release 或启动新训练。
