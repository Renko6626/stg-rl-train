# TH18 自包含启动包

沿用现有 thcrap x86 和共享 AI 插件，提供原生启动器及离线打包；游戏文件须自行准备。当前 `th18-ai-probe-20261022-r5.zip` 的世界快照和ONNX原始子弹表均为2048行，不在适配层排序，只保留图内TopK；同一checkpoint重导出为graph7，无需重训。保留激光状态、解冻首帧、子弹入口、Boss优先追敌和诊断探针。本批修复尚未 Windows 实机验收。

r5诊断包使用 `build_probe.py`，显式传入新DLL、graph7模型／manifest、两仓源码和导出器路径。包内模型使用启动器原有文件名，manifest和`provenance.json`记录真实graph7、2048输入及checkpoint哈希；启动器无需替换。普通旧包的构建命令保留在下文作为历史入口，不能用于覆盖当前r5。

将整个 `TH18-AI/` 解压到可写的短目录（如 `D:\TH18-AI`），双击 `TH18-AI.exe`，首次选择自己的 TH18 v1.00a 原版程序。后续直接双击启动。重新选择游戏可删除包内 `game-path.txt`，或将游戏程序拖到启动器上。只有 `dependencies.json` 中 SHA256 匹配的游戏版本可启动。

默认 MANUAL，F10 依次切换 MANUAL／AUTO／BYPASS；方向键或 Shift 手动输入优先，C／D／X 保持手动，自动炸弹关闭。遇到矩形弹等当前未支持的形状时暂时交回手动，最终处理方案待确认。完整操作说明在包内 `使用说明.txt`。

AI 接管时生成的游戏录像不能保证正确回放，请不要依赖录像复现 AI 操作。

推荐 Windows 10 22H2／Windows 11。包内含 ONNX Runtime 1.22 x86、VC++ 14.51.36247 minimum 的 11 个 x86 DLL、DirectX June 2010 的 d3dx9_43／xinput1_3，以及 thcrap 2026-09-04 的 x86 原生加载依赖。无需 Python、开发工具、管理员权限、联网或另装系统运行库。ORT 的 DXCore 依赖由现代 Windows 系统提供。

启动器在包内写 `game-path.txt` 和 `thcrap/config/ai.js`，向每个 patch 的 `config.breakpoints.stg_ai_tick` 写入绝对模型／ORT 路径。它启动包内加载器，以 thcrap 为工作目录，并将完整配置路径作为命令行参数传入；游戏由加载器在自己的目录启动。包内模型／DLL 搜索路径随子进程继承。中文和空格路径可用；本启动器将模型／ORT 路径限制在 255 个 UTF-8 字节内，过深路径会提示移动到较短目录。启动器不覆盖游戏文件；现有插件在游戏目录追加 `stg-ai.log`。

r2 修正了首包的配置参数错误：thcrap 将不含反斜杠的相对参数当作配置名称，会把 `config/ai.js` 拼成 `config\config/ai.js`。现在传绝对路径，不需要修改全局 `config.js` 来加载 `ai.js`。

构建机需要 Python 3.9+、`cabextract`。编译启动器另需 Make、支持 x86 Windows 的 MinGW 编译器；`TOOLCHAIN` 可指定 Makefile 使用的 llvm-mingw 根目录，`WINCC` 可覆盖编译器路径。示例：

```bash
make -C tools/th18-portable check all OUT=/path/to/TH18-AI.exe
python3 tools/th18-portable/build.py \
  --cache /path/to/verified-inputs \
  --adapter dist/th18-autoplay-thcrap-20261022-draft.zip \
  --launcher /path/to/TH18-AI.exe \
  --output dist/th18-ai-portable-20261022.zip
```

先按 `dependencies.json` 的文件名准备官方输入归档和许可缓存。构建不会下载或安装依赖；每次都验证全部输入 SHA256，在临时目录从原始归档提取所需文件，不信任缓存中的预解压 DLL。微软签名 CAB 的附加签名数据可能触发 cabextract 的 `extra bytes at end of file` 警告；提取成功仍以命令退出码和后续闭包检查为准。

ZIP 只有一个 `TH18-AI/` 根目录。`model/` 放固定 graph6 B/Shift K8 模型，`runtime/` 放 ORT、VC++ 和 DirectX DLL。`thcrap/` 保留 AI 所需原生加载器、依赖和 patch；保留必需的空 `bin/update.json`、`config/games.js` 和可写日志目录。补充精确 SHA256 的 `versions.js` 和 `th18.js`，重算 patch 文件 CRC；原始 patch.js 和 hook 不变。启动配置在运行时生成，不预埋本机绝对路径。在线更新器、配置向导、.NET、64 位插件和 base_tsa 不随包提供。

`licenses/` 保留 ORT、thcrap、jansson、win32_utf8、zlib-ng 以及微软 VC++／DirectX 声明。`source/` 包含本目录构建工具、原适配器源码、文档、来源和审阅记录；其中适配器原始 README 描述的是旧草稿包布局，实际操作以根目录 `使用说明.txt` 为准。包中没有游戏 exe、素材、存档或 Ghidra 工程。

构建检查每个 EXE／DLL 均为 x86 PE32，并检查普通及延迟导入闭包；只允许包内 DLL 和 Windows 10／11 系统 DLL／API sets。`provenance.json` 记录固定依赖清单、实际二进制 SHA256 和导入项；`SHA256SUMS` 覆盖除自身以外的全部普通文件，ZIP 的 `.sha256` 旁文件覆盖完整归档。写包后重新核对 CRC、清单和逐文件字节。相同输入使用固定时间戳生成相同 ZIP。

这些检查没有执行 Windows DLL 加载、文件选择窗口、游戏注入或 AI 实际控制。相关实机验收仍待用户在 Windows 完成。
