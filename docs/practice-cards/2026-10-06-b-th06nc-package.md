# 实验B/K8与TH06NC Windows试玩包

2026-10-06：按用户要求，将刚训练完成的B模型装入既有TH06NC包。默认选择B，并保留旧T8模型供回退。没有修改模型输入、运动层、激光平滑或shift逻辑。

## 产物与使用

- `dist/th06nc-autoplay-20261006-b-request-reward-k8.zip`，7,758,699字节，13个文件。
- SHA256：`152852bc135834226f3f28ac114e8ce0d208f57dcbcd499fc8fa1b61bc4f74b1`。旁边有`.zip.sha256`，包内有逐文件`SHA256SUMS`和`VALIDATION.json`。
- 同字节副本位于renkolab仓库的`out/th06nc-autoplay-20261006-b-request-reward-k8.zip`和`mods/th06nc/autoplay/dist/th06nc-autoplay-20261006-b-request-reward-k8.zip`。

将包目录内文件一起复制到`th06nc.exe`所在目录，先备份旧插件和INI。默认手动，按C切换MANUAL/AUTO/BYPASS。默认`model = b-request-reward-k8-best.onnx`；把该项改为`t8-laser-k4-best.onnx`后重启即可回退旧T8。包中没有游戏exe或资产。

目标TH06NC x64，绑定exe MD5仍为`b0cc28ec904e9efce2439ad857c938b5`。插件DLL、ORT1.22.0、许可证和T8回退模型均与旧T8成品包逐字节一致。保留既有8帧激光运动平滑、方向保持2–6帧、延迟0–2帧、低速运动层、锚点和压力切换；除默认模型名称外，所有INI配置值与旧T8包一致。

## 模型来源

唯一B checkpoint：`runs/job-3c0392a2052fb68e/20261004-204129-request-reward-k8/checkpoints/best.pt`，SHA256 `c9456b4d2a8a37c2fa7c79851d1a172ddc77151dc0487c7adc800d3cb764bb59`。

真实checkpoint核验为u3500、917,504,000帧、seed1、`reward.action_source=request`、`danger_topk_v8`、`set_attn_v3`、player15、8根激光。ONNX SHA256 `0bf5fcfe5b0bc137f7438bb39f9ce998bb6a2d9d11cfc88c491f6a404361d933`，graph6/opset18/IR10，12个输入、原始激光64行、激光token `[8,14]`、联合序列72。没有请求历史输入或图签名变化。

训练使用base commit `4a3bc4a35ca57d4fd114cca227206fed658a84a0`和四文件源码覆盖归档，归档SHA256 `745b4dc08c91a2a4b4ab7dc7a945fb953dd6e9b35bea7be3aec2157af170161e`；base commit本身不含B修改。完整来源见包内MODEL-SOURCE和VALIDATION。

B在仿真中动作更平滑，原作激光主评测末四次通过率为73.44%，历史T7为90.36%，见[结果记录](2026-10-05-request-reward-results.md)。这是实验模型的已观察取舍，不能据此保证真实游戏表现，也不能宣称shift问题已经修复。

## 本次实际验证

- `uv run --frozen python -m stgtrain.export_onnx runs/job-3c0392a2052fb68e/20261004-204129-request-reward-k8/checkpoints/best.pt --out dist --name b-request-reward-k8-best`：通过，真实torch/ORT导出自检最大logits偏差3.81e-6。
- `uv run --frozen python runs/b-th06nc-package-validation/parity.py`：复用T8验证工具与Linux ORT1.22.0，真实C填表/C ORT对独立Python观测/torch三帧全部12输入一致，最大logits偏差5.72205e-6，argmax一致，覆盖预警/运动/伸长及无激光清零。
- `make -C /data/sunyunbo/www/renkolab/mods/th06nc/autoplay/native/tests build/test_policy_model`，随后执行该目录`build/test_policy_model`：通过，`test_policy_model ok`。
- `make -C /data/sunyunbo/www/stg-agent-proto/c test-onnx-live SA_ONNX_TEST_LIB=/data/sunyunbo/www/stg-rl-train/runs/t8-package-validation/ort122/libonnxruntime.so.1.22.0 SA_ONNX_TEST_MODEL=/data/sunyunbo/www/stg-rl-train/dist/b-request-reward-k8-best.onnx SA_ONNX_TEST_BADMODEL=/data/sunyunbo/www/stg-rl-train/runs/t8-package-validation/wrong-signature.onnx`：**行为检查失败**，见下节；不能报告整体通过。
- `uv run --frozen python runs/b-th06nc-package-validation/bad_signature.py`：直接调用真实C加载错误签名模型，正确拒绝。
- 将上述live命令的MODEL改为`t8-laser-k4-best.onnx`：通过六项行为检查和错误签名拒绝。
- `RELEASE_DIR=/data/sunyunbo/www/stg-rl-train/dist/b-th06nc-release-assets bash runs/b-th06nc-package-validation/package.sh`：按既有release.sh独立素材布局和复制/ZIP步骤出包；复用旧DLL，未执行release.sh强制重建段，未修改该脚本或native源码。
- `uv run --frozen python runs/b-th06nc-package-validation/verify_package.py`：ZIP CRC、13文件、12项逐文件SHA、B checkpoint/ONNX/manifest来源与签名、自包含ONNX检查、默认INI、旧T8回退字节一致、两DLL PE machine `0x8664`、三处ZIP镜像一致全部通过。

临时脚本、原始日志及JSON结果在`runs/b-th06nc-package-validation/`。没有新增永久测试，也没有因换权重重建DLL或重跑无关测试。

## 未通过的行为检查与验收边界

既有`test_onnx.c:220`要求自机正上方80像素的直落弹出现时立即移动。B在真实C/ORT1.22加载后选择方向0，触发断言；此前的原地/右/左/上/下锚点五项已通过。

独立运行`stop_fixture.py`重建该场景：B的torch和ORT都argmax=1（低速原地），偏差4.76837e-6。`t8_stop_fixture.py`对同场景得到旧T8两端argmax=7（向右低速），偏差2.65241e-6，且旧T8完整live行为检查通过。证据支持这是B权重自身的当帧选择，不能据此判断后续轨迹是否死亡或概括所有弹幕表现。未删除或放宽原断言，未更改权重来让检查变绿。

包内README/VALIDATION已明确这条失败、仿真生存取舍和shift未修。本次仅交付用户授权的试玩包；没有Windows游戏内交互验收或实机日志逐帧回放，没有训练、提交、推送、GitHub Release或部署。
