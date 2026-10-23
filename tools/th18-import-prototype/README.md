# TH18 导入原型

2026-10-23。独立的现代 ECL 前端，现可把原始指令转换为可校对的我方 `.ecl` 源码，再通过现有编译器交给 stg-core 执行。简单控制流恢复为 `if`／`for`／`while`，其余保留标签和 goto。第一版的直接字节码后端仍保留，供原型对照；没有在运行期另写一个 ZUN VM。

这是原型验证，未接正式卡池、训练入口或部署插件。本轮只在 stg-engine 编译前端添加普通标签／goto，不改 VM、World、opcode 或 syscall；TH06 解析器和训练依赖保持原样。训练用 wheel 尚未重建，生成源码由本地 Rust 编译器验证。

## 范围与结论

- **解析**：固定使用 `thecl -r -x -j -d 18`，不加载 eclmap。保留数值 opcode、参数类型及引用、跳转标签、时间、难度、文件地址。`-j` 避免转义后的 CP932 字节损坏日文字符串。
- **二进制补充**：从原文件核对指令头，读取 `+0xc` 的低字节作为指令完成后的栈消费字节数。`[-1]` 是 peek，不在每次取参时弹栈。
- **严格转换**：只允许已实现的整数控制流、栈与整数脚本时间子集。单入口、无参、无调用／async，最大 24 个源局部变量字；不支持项明确拒绝。
- **实验转换**：源浮点与玩法指令必须显式 `--demo`。镜像中的 `approximations` 列出差异。这些产物不能作为保真训练卡。
- **执行**：独立 Rust runner 调用真实 `World::new_game` / `step`，读取公共视图；fault、contract violation、pool full 任一非零均失败。零输入保留引擎真实碰撞／死亡，不把玩家设为无敌。

原型读取现有引擎的 opcode/syscall 常量，并在镜像中记录 `ENGINE_VER`。这是本机实验的连接方式，不是已确定的跨版本产物格式。

## 实测结果

22 份 TH18 二进制全部成功解析并核对头部：**798 个真实子程序定义、22,721 条指令、1,761 个标签**。此前调查的 838 包含非 raw 输出额外生成的 40 条前向声明，不能当成定义数。

真实样本为 `st04.ecl::GirlD01_at2`。只导入这一子程序，发射源固定为 `(0,100)`；其父敌人的移动和异步调度没有导入。观察实际创建的弹句柄与出生帧，结果如下：

| rank | 难度 | 轮数 | 每轮弹数 | 间隔帧 | 共观察到的出生弹数 |
|---|---|---:|---:|---:|---:|
| 0 | Easy | 10 | 20 | 60 | 200 |
| 1 | Normal | 20 | 40 | 30 | 800 |
| 2 | Hard | 20 | 55 | 30 | 1100 |
| 3 | Lunatic | 20 | 65 | 30 | 1300 |

四档 fault、contract violation 和池满计数均为 0。目标引擎中角速度为每帧 -109 BAM，持续 120 次积分后停止转向；Normal 同 seed 重跑的逐帧输出及世界 checksum 完全一致。该结论仅涉及目标运行的确定性，不是与 TH18 原作的逐帧对拍。

源码路径扩展后，9 个控制流微程序的结构化／goto 两种输出逐帧行为一致；真实样本四档发射与曲率检查通过，Normal 源码两种输出还与旧直接字节码后端的可观察结果一致。生成源码时发现并修复了随机角度小数部分转 fx 的溢出，保留了严格对拍标准。

手写微程序验证了：

- 跳转设时钟到 7 后，时间 10 的指令再等 3 帧执行。
- `wait(4)` 减小时钟后，较早时间标签的下一条指令仍可同帧执行。
- 表达式栈跨帧保留，0.75 与 0.25 在第 5 帧求和为 1（实验浮点模式）。
- 后缀自减压旧值，循环次数与末值符合独立预期。
- 先时间门控再难度过滤。
- 未支持的原生函数指令 637 被拒绝。

还保留了一个**已知数值差异**：`0.999999f` 原生转 int 为 0；Q16.16 量化后为 1，会改变条件分支。严格模式拒绝源浮点，实验模式明确记录这类风险。可精确表示的 0.5 条件用例通过，不能推广为任意浮点分支等价。

## 复现

从训练仓根目录执行，要求相邻目录有当前 stg-engine 和 renkolab 的本地素材／thecl。Rust 依赖使用现有离线缓存。

```bash
CARGO_TARGET_DIR="$PWD/transcribe/work/th18-prototype/target" cargo build --offline --manifest-path tools/th18-import-prototype/runner/Cargo.toml
python tools/th18-import-prototype/verify.py
```

源码路径的验证执行 `python tools/th18-import-prototype/verify_source.py`；只检查控制流可加 `--synthetic-only`。它会分别生成结构化与保留 goto 的源码，并通过 runner 实际编译这些文件，比较时序、局部观测和弹幕行为。

生成便于校对的源码：

```bash
python tools/th18-import-prototype/emit_source.py ../renkolab/local/th18.v1.00a/dat/st04.ecl --sub GirlD01_at2 --rank 1 --demo --output transcribe/work/th18-prototype/girl-r1.generated.ecl
```

默认尝试简单结构恢复；`--no-structured` 保留逐条跳转，便于交叉核对。生成文件包含源子程序、文件／指令偏移、难度、时间和近似说明，变量与源局部偏移对应。暂未折叠全部表达式栈和重复时间门，结果仍偏指令级。

runner 使用以下配置执行源码（`ecl` 路径相对于 JSON 文件所在目录）：

```json
{"ecl":"girl-r1.generated.ecl","frames":610,"seed":1,"watch_globals":[16,17,19,64,65]}
```

源码模式与 `code`／`subs`／`entries` 字节码表互斥，不能隐藏另一份执行内容。源码和直接字节码的 locals 布局不同，两者比较可观察结果；只有同一路径的确定性复跑才比较完整世界 checksum。

`verify.py` 会编译手写微程序并运行真实 VM，然后检查上述真实样本四档结果及一次确定性复跑。合成用例故意包含下降的时间标签，thecl 会提示 `illegal timer change`，仍产出该指令序列；解析后核对二进制并断言真实目标执行结果。没有启动原作游戏。

单独生成与运行样本：

```bash
python tools/th18-import-prototype/compile.py ../renkolab/local/th18.v1.00a/dat/st04.ecl --sub GirlD01_at2 --rank 1 --demo --frames 610 --output transcribe/work/th18-prototype/girl-r1.json
transcribe/work/th18-prototype/target/debug/th18-prototype-runner transcribe/work/th18-prototype/girl-r1.json > transcribe/work/th18-prototype/girl-r1.trace.jsonl
```

`verification.json`、派生镜像和轨迹全部位于已忽略的 `transcribe/work/th18-prototype/`；原作文本只在解码进程内使用，未复制进源码或 fixtures。

主要文件：`parser.py` 负责独立解析；`compile.py` 做静态栈形状分析和直接发码；`emit_source.py` 输出源码并识别有限结构；`runner/` 编译源码或加载目标镜像；`verify.py`／`verify_source.py` 分别检查两条路径。`fixtures/raw-synthetic.ecl` 为手写解析样本。

## 标签与简单结构恢复

我方语言现在支持 `name:` 和 `goto name;`。**仅建议用于自动导入／兼容，常规手写优先用结构化语法。** 标签只在 sub 顶层，跳转只在同一 sub；含标签／goto 时顶层局部声明必须置于可执行语句前。不能跳入嵌套作用域，也不能与同 sub 的 mark 混用。完整规则见 stg-engine `docs/ecl-lang/2-tasks.md`。

当前自动识别的模式：

- 前向条件分支及闭合的直线 then／else，恢复为 if／else。
- 有已证明非负常量初值、无循环体改写计数器的后缀自减循环，恢复为 for；保留检查时序、旧值语义和退出时的最后一次自减。
- 单一回边、直线条件与循环体的条件循环，恢复为 while。

有外部跳入内部、未确认的计数初值或其他复杂边时，保留 goto。此处不追求通用反编译器。普通 goto 只改变 PC，**不会重设 `$frame` 或脚本时间**；原作带时钟跳转由下节的显式代码处理。

## 时间和栈的转换

每个入口保存 `base = target_frame - source_time`，当前源时间为 `target_frame - base`。每条指令先按其原始时间门控，再检查已选择难度。跳转会同时修改 base 和 PC；wait 只增加 base，下一条指令决定是否需要暂停。这使同一条跳转的时间语义不依赖前驱路径。

引擎原有 `$frame` 是全局帧，`$self_age` 是任务龄，`wait(n)` 是相对等待；没有原生可重设的 ZUN 脚本时钟。本轮复用局部变量，不新增时钟 API 或 VM 状态。例如原作跳到时间为 10 的标签、并设置当前脚本时间为 7，可生成：

```ecl
sub main() {
    var clock_base: int = $frame;
    var due: int = 0;
    clock_base = $frame - 7;
    goto target;
target:
    due = 10 - ($frame - clock_base);
    if due > 0 { wait(due); }
}
```

这一降低只覆盖当前原型的单 sub、固定逻辑步速。不能据此声称调用／async 的时钟恢复、外部冻结或原作 gameSpeed 已经兼容。

源表达式栈通过控制流数据流分析得到各指令的入栈形状，分配到目标 locals，所以跨帧等待不会丢值。形状冲突或栈下溢会被拒绝。目标操作数栈只用于执行当前降低后的计算。暂未实现调用帧、跨任务状态和动态入口参数。

原生依据来自本机 TH18 v1.00a：

- `0x48b700`：跳转写 `ctx.time` 并改变指令偏移；13／14 在 `0x48b6cc`／`0x48b697` 判断条件。
- `0x48b727`／`0x48b748`：整数／浮点 wait 减时钟；本原型只实现整数 wait。
- `0x48c8ac`：自减写新值、压旧值。
- `0x48d4f0`／`0x48d5a0`：参数引用读取；`0x48d232` 从头部 `+0xc` 低字节统一收栈。

## 玩法近似及下一步

`--demo` 中的真实样本存在以下明确差异：

1. **EX2 出生状态省略。** 原生会 `pos -= 4*v`，随后有半速运动、至少 8 tick 的碰撞门，并由弹种 ANM 的 I0 控制转态。EX8 在此状态期间不推进，转态 tick 还可能同时发生半步与整步运动。原型直接进入普通运动，不能拿其轨迹、避让空间或开场安全性当作原作。
2. **原生 RANDRAD 替换为目标 PCG32。** 当前用 `[0,2π)` 随机旋转；同 seed 只保证目标内部复现，不匹配原生随机流。
3. **弹型／半径替换为目标 appearance 0。** 没有完成 TH18 弹型几何映射。
4. **源 f32 转 Q16.16、弧度转 BAM。** 除轨迹累积误差外，算术、比较、转整与分支边界也可能变化。
5. **发射源固定。** 不代表整只原作敌人的行为；未支持多层速度插值、跨任务共享发射器或一般 EX 通道。

本例 EX8 的原生依据已核到 `0x425f1a` 的配置和 `0x42416c` 的消费：active 状态先更新角度／速度，再积分位置，timer 0…119 共更新 120 次。etAim2 的单层环形语义也已核对。上述依据不消除 EX2、浮点和发射源差异。

下一步应先决定数值保真目标，并补齐出生状态这个实际机制，再扩大转换支持集。曲线激光、完整调用／async、训练数据发布仍是后续工作；本原型没有决定正式导入器的模块边界与存储格式。
