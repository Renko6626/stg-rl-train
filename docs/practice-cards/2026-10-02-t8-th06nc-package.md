# T8四根激光模型与TH06NC mod包

2026-10-02：用户要求将T8四根激光模型和对应TH06NC mod适配并打包。用户随后明确要求保留现有平滑激光运动估计，不改为单帧差分。

## 产物

`dist/th06nc-autoplay-20261002-t8-laser-k4.zip`，6,274,203字节，11个文件。

SHA256：`af415a0ac71501ce300f593e7ca8feeed80a2c513ce266abcffc1ede0cad63a6`。旁边有`.zip.sha256`，包内有逐文件`SHA256SUMS`和`VALIDATION.json`。

默认模型`t8-laser-k4-best.onnx`，取T8 Job28a4532abf792cc4的best=u3500，917,504,000环境帧。图版本6、opset18、IR10，原始激光输入64行，图内取最近4根，激光编码器输入[B,4,14]，联合注意力序列68。包含新版`VCRUNTIME140_1.dll`、ONNX Runtime1.22.0及MIT许可证、默认INI、manifest和安装说明；不包含游戏exe或资产。

目标为TH06NC x64，绑定本地已核验的exe MD5 `b0cc28ec904e9efce2439ad857c938b5`。解压后把包目录内文件一起复制到th06nc.exe所在目录，默认手动模式、按C切换；INI默认选择T8，沿用2–6帧方向保持、0–2帧延迟、低速运动层、锚点和压力切换。

## 适配范围

- stg-agent-proto共享C的sa_model/sa_onnx支持7／8／9／11／12输入，即图版本2–6；拒绝10输入。
- 新增激光12列、mask与独立start_len，行对齐、数量钳制、warning/active压实、陈旧行清零；不在C重复Top-K几何。
- 原动作表、wire协议、游戏地址、extractor和hook机器码不变。用户明确要求保留TH06NC原8帧平滑；训练侧单帧运动与游戏平滑估计的差别在包内说明，不声称两者运动估计完全等同。
- Python逐帧对拍工具支持图版本5/6，直接读OBS中已有激光字段；不重算或改变平滑运动。
- renkolab发布脚本增加可选RELEASE_DIR，用独立T8素材目录打包，默认旧release目录仍可使用；保留各仓已有未提交改动。

## 验证证据

- `uv run --frozen python -m stgtrain.export_onnx runs/job-28a4532abf792cc4/20261002-103401-t8-laser-k4/checkpoints/best.pt --out dist --name t8-laser-k4-best`：通过，最大logits偏差2.86e-6、argmax一致。
- `make -C /data/sunyunbo/www/stg-agent-proto/c test-host`：通过。
- `make -C /data/sunyunbo/www/renkolab/mods/th06nc/autoplay/native/tests test`：策略／抽取／模型接线3项通过。
- `python /data/sunyunbo/www/renkolab/mods/th06nc/autoplay/native/check.py`：本地真实exe MD5、绑定地址、hook与代理导出等核对通过。
- `bash .../autoplay/native/build.sh`：Windows x64交叉编译通过；包内两个DLL的PE machine为0x8664。
- 真实`make test-onnx-live`分别加载T8 graph6和旧S1 graph4，在ORT1.22.0下通过；实际错误签名模型被拒绝。首次命令未指定可选BADMODEL时，Makefile传空串触发旧测试错误，已将条件修正为非空文件才运行负例，保留真实负例断言。
- 为匹配包内现有Windows ORT，验证专用Linux ORT1.22.0从官方PyPI wheel下载并核验SHA；没有替换项目依赖或升级包内运行时。下载来源记录`runs/t8-package-validation/ort122/SOURCE.json`。
- `uv run --frozen python runs/t8-package-validation/parity.py`：实际C填表+实际C ORT1.22与独立Python构造的RawObs/torch对拍，3帧全部12个输入匹配，最大logits误差6.68e-6、argmax一致，含预警／运动／伸长与无激光清零场景。结果`parity-result.json`在同目录。
- `PYTHONPATH=src <train-venv>/bin/python -m pytest -q tests/test_model_parity.py tests/test_obs.py tests/test_schema.py tests/test_c_sample_log.py`（stg-agent-proto cwd）：19 passed。
- 独立只读审查：共享C无阻塞问题；成品ZIP引用、默认模型、manifest、许可证及各文件SHA无阻塞问题。
- ZIP CRC、11个文件、默认INI指向模型、ONNX/manifest SHA和逐文件SHA全部核验通过。

没有Windows游戏内游玩验收；真实游戏日志的逐帧策略回放闸门仍需用户实机录制后执行，不能把合成世界C对拍当作实机行为验证。未提交、推送或发布Release。
