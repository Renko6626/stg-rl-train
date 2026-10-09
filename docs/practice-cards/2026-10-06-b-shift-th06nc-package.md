# 带 Shift 罚分的 B/K8 Windows 试玩包

用户在查看短轮A/B结果后授权打包最新B。2026-10-06完成，使用独立名称，未覆盖旧B3500包。

## 产物

`/data/sunyunbo/www/renkolab/out/th06nc-autoplay-20261006-b-request-light-shift-k8.zip`，7,761,361字节、13文件。训练仓`dist/`与renkolab的`mods/th06nc/autoplay/dist/`有同字节镜像及SHA文件。

ZIP SHA256：`b7aae99795d664f2dedc539306b0422a773206fce453201881e3d4d4f50a3f41`。

默认模型`b-request-light-shift-k8-best.onnx`，来源新Job `b3ef72c1ca44515d`的u1000 best.pt，新增262144000帧；checkpoint SHA256 `8b3824871e18ca4a5fd052e758ef13833a0303d856513ebe58e6d604f0a19c88`，ONNX SHA256 `e47016c892fc7b0a9667b959d6e06ee10bff4261ea805022b7b8f4e04b7bc7f1`。T7 u3500仅继承权重，新optimizer；request key_press=-0.001/quick_change=-0.003/shift_toggle=-0.003。

保持player15/v8/v3/K8/graph6，复用原x64插件与ORT1.22.0，不改native、运动层或8帧激光运动平滑。包内附旧T8四根模型回退；旧B ZIP哈希仍为`152852bc135834226f3f28ac114e8ce0d208f57dcbcd499fc8fa1b61bc4f74b1`。

将解压目录内文件一起复制到th06nc.exe所在目录，先备份原插件与INI。默认手动，按C切换MANUAL/AUTO/BYPASS。INI默认新B；改model为`t8-laser-k4-best.onnx`并重启即可回退。

## 本次验证与边界

- `uv run --frozen python -m stgtrain.export_onnx runs/job-b3ef72c1ca44515d/20261006-151317-request-light-shift-k8/checkpoints/best.pt --out dist --name b-request-light-shift-k8-best`：导出自检通过，最大logits误差4.29e-6。
- 既有native `test_policy_model`通过。真实ORT1.22 `make test-onnx-live`使用新模型，原六项锚点/让弹行为断言及错误签名拒绝全部通过；没有删除或改动断言。旧B曾失败的立即让弹用例这次通过。
- `uv run --frozen python runs/new-b-shift-th06nc-package-validation/parity.py`：严格数值检查失败，一帧最大绝对误差1.335144e-5，超过原1e-5阈值，失败日志保留。独立完整三帧诊断中全部12个输入及argmax一致，误差依次9.05991e-6/1.33514e-5/2.86102e-6，没有放宽阈值或把严格门标成通过。
- `uv run --frozen python runs/new-b-shift-th06nc-package-validation/verify_package.py`：CRC、逐文件SHA、默认INI、新checkpoint与ONNX来源、自包含graph6/opset18/IR10、DLL x64、镜像一致通过。主agent另独立核验ZIP、13文件、逐文件SHA、默认新B/u1000、三处镜像及旧包未覆盖。

包内README、MODEL-SOURCE和VALIDATION记录完整来源、数值边界及[水符代价](2026-10-06-request-shift-short-ab-results.md)。尚未进行Windows游戏内游玩验收，不把仿真Shift改善当作实机已修复。

素材在`dist/b-request-light-shift-k8-release-assets/`，日志和脚本在`runs/new-b-shift-th06nc-package-validation/`。未提交、推送、发布Release、启动训练或操作游戏UI。
