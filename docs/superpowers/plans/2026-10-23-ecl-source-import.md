# ECL 标签跳转与可读源码导入

> 执行按 superpowers:subagent-driven-development 分工；不提交、不推送，不创建分支或 worktree。用户已在本会话确认添加标签／goto，并要求尽量映射简单分支与 for／while。

**Goal:** 让已支持的 TH18 原型能够生成可校对、经我方编译器运行的 ECL 源码。

**Architecture:** 在 stg-engine 现有语言前端添加普通标签和 goto，复用现有 JMP/JZ。训练仓原型增加源码输出，优先识别简单结构；ZUN 时钟沿用已验证的局部 base 与 `$frame` 降低，不修改 VM 状态。

**Tech Stack:** 现有 Rust 编译器、Python 原型和独立 Rust runner；不引入新依赖。

**Spec:** 本会话用户选择；原型背景见 tools/th18-import-prototype/README.md。

## Global Constraints

- goto 在文档中显著注明为兼容／自动导入用途，不推荐常规手写，优先结构化语法；不为此另建编译 warning 系统。
- 第一版标签只在 sub 顶层声明，跳转只在同一 sub；禁止跳入嵌套作用域。含标签／goto 的 sub 顶层局部声明放在可执行控制流前，避免跳过初始化。
- 不改变旧程序字节码与运行语义，不新增 opcode/syscall/World 字段；评估 ENGINE_VER 无需 bump 的依据并核对 golden。
- 只恢复能确认形状的简单分支／计数循环／条件循环；其他情况保留标签跳转，不做全功能反编译器。
- 源浮点和玩法近似继续要求显式 demo，不增加 EX2／曲线激光支持，不接正式卡池或训练，不重建 wheel。
- 原作及派生产物只放 transcribe/work；既有未提交修改保持原样。
- `$frame` 是世界帧，不等于原生脚本时钟。该降低沿用单 sub、固定逻辑步速范围；调用／async、冻结／变速精确兼容另议。

## Tasks

- [x] 引擎编译器支持 `label:`、`goto label;`，包括解析、作用域与初始化边界、代码生成、相关 AST 消费者和简短文档。
- [x] 在训练仓原型输出可读 `.ecl`：源位置、近似说明、变量、时钟门控、简单结构恢复与 goto 回退。
- [x] runner 能编译并执行生成的 `.ecl`，沿用真实引擎和既有观测；实现方式由内部复用决定，不改正式加载入口。
- [x] 用真实运行验证标签前后跳、条件分支、跨 wait 循环；对照原型已知时序，验证 if／for／while 映射与回退。仅新增填补上述关键行为缺口的简短测试。
- [x] 运行编译器已有测试、相关原型验证、TH06 转写既有检查，以及改动前后 golden 对比；文档记录结果和边界。

## Review Focus

前跳不能跳过局部初始化；标签不可跨 sub／进入嵌套块；恢复循环必须保留自减旧值、退出末值及等待时序；ZUN 跳转时钟重设和普通 goto 分清；源码必须是实际执行输入，不能运行另一份隐藏字节码。

## 执行结果

- `cargo test -p stg-ecl-compiler`：336 unit、1 integration、1 doctest 通过；新增 mark 测试改为真实启动观察 BGM 后，单独重跑该项通过。
- `cargo clippy -p stg-ecl-compiler --all-targets -- -D warnings`、相关 Rust 格式检查、`cargo test -p stg-harness every_ecl_fenced_example_in_doc_compiles` 通过。
- 改前／后 golden `cmp` 为 0，SHA256 同为 `599e53fd102fbbfcb398822e920cd3aec4cd2cfea1fea8b56ebf17af1ebdda86`。只改编译语法，ENGINE_VER 保持 24。
- 独立 runner 的 `cargo build --offline --manifest-path tools/th18-import-prototype/runner/Cargo.toml` 通过；新增的依赖只是现有本机 `stg-ecl-compiler` crate。
- `python tools/th18-import-prototype/verify_source.py --synthetic-only`：9 个微程序，结构化与 goto 路径逐帧行为一致，独立时序和值断言通过。
- 同模块 `real_sample()` 单独运行：四档发射轮数／弹数／间隔与 120 帧曲率检查通过；Normal 结构化源码、goto 源码和旧直接字节码后端的逐帧可观察结果一致。修复了 RANDRAD 小数部分直接 `as fx` 溢出，改为 256 进制两段转换，未放宽对拍。
- `uv run --frozen pytest -q tests/transcribe`：98 passed。原型 Python 语法检查、diff whitespace 检查通过。
- 未运行训练、原作游戏、跨平台验证或全 workspace 测试，未升级 wheel，未提交或推送。数值与 EX2 等原型近似仍然有效。
