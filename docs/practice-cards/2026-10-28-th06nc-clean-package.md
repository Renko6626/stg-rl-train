# TH06NC 精简发布包

2026-10-28，用户要求打包最新 AI 代打插件并配置发布，希望新包尽可能干净、简单。

## 交付

`dist/th06nc-ai-20261028.zip`：6,265,459 字节，SHA256 `977383bd88008ed903cb3ec65441e4d1a293b8e66a535c394e428e0c838ff238`。相对 10 月 22 日追敌包，23 个文件降到 6 个，ZIP 体积减少 19.8%。只保留：

- `VCRUNTIME140_1.dll`：从当前 renkolab 源码和当前 stg-agent-proto C 源码重新交叉编译。
- `onnxruntime.dll`：沿用原包的 x64 ORT 1.22.0。
- `model.onnx`：B/Shift K8 u1000 的最新 graph7 导出，2048 行弹表，同一 checkpoint 权重。
- `th06nc_autoplay.ini`：11 项配置，其余使用插件现有默认值。
- `README.txt`：安装、操作、卸载、依赖和问题反馈。
- `onnxruntime-LICENSE.txt`。

旧 T8 回退模型、源码、测试、manifest、多份历史说明和验证报告不进入玩家 ZIP。校验和与完整模型 manifest 留在 ZIP 同级的 `.zip.sha256`、`.release.json`；源码哈希与本次检查日志另存为 `.sources.json`、`.checks.log`。这些文件不需复制到游戏目录。

沿用现有代理 DLL 安装方式，需要系统 Microsoft Visual C++ 2015–2022 x64 运行库。默认 MANUAL，C 轮换模式；保留 AUTO 自由躲弹、鼠标引导、BYPASS 追敌与 Boss 优先、手动接管、自动射击和炸弹安全网、训练对应运动限制以及 8 帧激光速度平滑。不改模型架构、训练、接口或游戏钩子。

模型 SHA256：`2986d382b868ad5b802256b563a7d8ece650f91331b0fb3e65d25bd672d678cf`。
插件 SHA256：`7ba87cafa61e133ad7348b57c12bed0670485250513ac3fa452ec4604a854bd6`。
ORT SHA256：`579b636403983254346a5c1d80bd28f1519cd1e284cd204f8d4ff41f8d711559`。

## 打包入口

[package.py](../../tools/th06nc-release/package.py) 使用 Python 标准库，只打包显式指定的产物，不会扫描并混入旧模型。模板在同目录。先用 renkolab 的 `native/build.sh` 构建，再传入 DLL、模型及其 manifest、ORT 和许可。脚本核对模型 SHA、graph7 与 x64 PE，并检查归档 CRC 和逐文件字节；已有同名 ZIP 会拒绝覆盖。

本次为避免覆盖外仓已有 DLL，在 `/tmp/sunyunbo/th06nc-release-20261028/` 保存当前源码副本后使用原脚本构建。该目录仅是本次构建记录，不是后续构建必需的依赖。

```bash
python3 tools/th06nc-release/package.py \
  --dll /tmp/sunyunbo/th06nc-release-20261028/native/VCRUNTIME140_1.dll \
  --runtime ../renkolab/mods/th06nc/autoplay/release/onnx/onnxruntime.dll \
  --license ../renkolab/mods/th06nc/autoplay/release/onnx/onnxruntime-LICENSE.txt \
  --model dist/b-request-light-shift-k8-b2048-best.onnx \
  --manifest dist/b-request-light-shift-k8-b2048-best.manifest.json \
  --output dist/th06nc-ai-20261028.zip
```

后续打包时替换输入路径、模板版本日期及输出版本名；不要继续使用旧 `release.sh` 的全量模型扫描作为精简包入口。

## 本次验证与边界

- `STGAGENT=<本次源码副本> bash <副本>/native/build.sh`：Windows x64 交叉编译通过。
- 运行原 `native/check.py`，仅由 wrapper 将样本/符号读取指向 renkolab 原仓、源码/DLL/测试指向本次副本：样本、地址、序言、ABI、跳板、导出、导入及三项宿主测试全部通过，原断言未修改。
- `make -C <副本>/stg-agent-proto/c test-onnx-live SA_ONNX_TEST_LIB=<已有ORT1.22.so> SA_ONNX_TEST_MODEL=<graph7模型>`：真实 C loader 接 ORT 1.22，图版本7、右/左/上/下/原地/让弹六项现有行为检查通过。
- `.venv/bin/python` 运行 ONNX checker、12 输入签名与 manifest 对账、模型无外部权重检查、全部构建输入与原仓哈希对账：通过。
- 上述打包命令：6 文件归档 CRC、字节一致性、SHA256 检查通过。INI 对照生产初始化函数和 `load_ini` 的默认值精简，保留启用 ONNX、模型路径与安全网所需配置；未修改配置加载代码。

未完成本版 Windows 游戏内验收；不据此宣称实机躲弹效果或帧率。未提交、推送或上传公开 GitHub Release，用户尚未指定公开发布目标。原包及外仓源码/现有 DLL 保留。
