# 动态xform参数的代码核查与候选路线

日期：2026-11-03。用户要求检查代码并评估解决办法，同时确认TH06NC是否受影响。本轮只读引擎/原作及既有卡，未实施新接口、修改卡或训练。技术路线待用户选择，本文不是已批准的设计规格。

**后续状态更新**：同日用户告知引擎已完成更新，复查main提交`85c042e`确认ENGINE_VER28已交付按值参数与三阶段求值，实际World净增44KiB。本文保留更新前的代码调查与备选路线，192KiB为当时方案估算，不能作为现行实现的内存账。当前实现、性能与训练接入状态见[现行能力与证据入口](../agent-memory/evidence-map.md#引擎与转写)。

## 代码已确认的事实

当前引擎HEAD为`d2bc2dab418167064de43356d4e8698e159f7ebf`、`ENGINE_VER27`，分支`codex/core-module-cleanup`，只有既有忽略构建目录；训练仓仍在main。没有切分支或改引擎文件。

| 层 | 当前限制/行为 | 代码 |
|---|---|---|
| 语法 | `xformdef NAME`没有类型形参；`@wait`仅接受0..65535整数字面量 | [ast.rs:65](/data/sunyunbo/www/stg-engine/crates/stg-ecl-compiler/src/lang/ast.rs:65)、[parse.rs:307](/data/sunyunbo/www/stg-engine/crates/stg-ecl-compiler/src/lang/parse.rs:307) |
| 参数编译 | 对每个槽参数调用`const_eval::evaluate`，失败明确报“xformdef槽参数必须是编译期常量” | [codegen.rs:143](/data/sunyunbo/www/stg-engine/crates/stg-ecl-compiler/src/lang/codegen.rs:143) |
| 模板暂存 | 模板在sub入口写入locals；同sub按模板名称复用区域；同步兄弟sub可复用locals | [codegen.rs:188](/data/sunyunbo/www/stg-engine/crates/stg-ecl-compiler/src/lang/codegen.rs:188)、[slots.rs:21](/data/sunyunbo/www/stg-engine/crates/stg-ecl-compiler/src/lang/slots.rs:21) |
| 单发 | 每次fire从当前locals解包wait/op/args，随后复制到该弹独立变换段 | [bullet.rs:113](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/syscall/bullet.rs:113)、[world.rs:347](/data/sunyunbo/www/stg-engine/crates/stg-core/src/world.rs:347) |
| 发射器绑定 | sh_xform仅保存off/cnt；sh_fire才解包，整波使用同一份配置 | [shooter.rs:154](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/syscall/shooter.rs:154)、[shooter.rs:232](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/syscall/shooter.rs:232) |

因此，常量限制是源码前端的主动限制；底层已有每次建弹复制当前参数的能力。开放动态参数需要语法、类型检查、使用处求值与配置所有权设计，不能只删掉常量检查。

源码也显示一个配置引用生命周期风险：helper A在自己的locals暂存并绑定模板后返回，兄弟helper B可以复用该区域；之后caller开火会读取被复用的数据。未来若同一模板用不同参数绑定到两个发射器，按现有模板名复用区域也会互相覆盖。这里是静态可构造的路径，本轮没有运行最小复现，不能宣称已定位到现有卡发生该故障。

## TH06NC确实需要动态参数与两步快照

TH06在执行bullet_effects时立即解析变量，把值写入敌人的bulletProps；发弹再将已保存值复制给每颗弹，后续运动读弹自身字段。见 [EclManager.cpp:413](/data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/EclManager.cpp:413)、[BulletManager.cpp:316](/data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/BulletManager.cpp:316)。

本轮还只读核了NC本作导出，避免仅凭TH06继承推断：

- `renkolab/local/th06nc/state/data/functions.jsonl:223`，NC `EclManager__RunEcl` `0x140022060`，case0x52将配置写入敌字段。
- 同文件`:91`，`BulletManager__SpawnBulletPattern` `0x14000f870`，将已配置参数复制到逐弹运动字段。
- 同文件`:93`，`BulletManager__OnUpdate` `0x140010870`，后续消费弹自身字段。

这两个取值时点不能合并。实际`s7_mb3`摘录先把随机F0送入bullet_effects，随后改写F0再发弹；若发弹时重新读F0就错。见 [摘录:162](/data/sunyunbo/www/stg-rl-train/transcribe/work/units/th06_s7_mb3/source.txt:162)。延迟瞄准等op在执行时读世界、负恢复速度捕获每弹初速等语义也须保留，不把所有值统一提前求一次。

## 旧卡已有实际影响

子代理清点166张原作卡：81张含xformdef，15张实际挂弹任务。结合原作摘录与实际采用分支，12张涉及这类动态bullet_effects参数，主要采用10张弹任务、2张固定/粗化参数。这不是12张都错误，也不是其余卡没有其他近似。

| 卡 | 当前处理 | 证据 |
|---|---|---|
| `th06_s4_b16` | 连续共享随机转角被分为±22.5°、±67.5°四档 | [main.ecl:13](/data/sunyunbo/www/stg-rl-train/cards/th06_s4_b16/main.ecl:13) |
| `th06_s7_b12` | 随机加速度取固定0.02/0.0185；历史报告记峰值263、任务池256，因此选中值 | [main.ecl:7](/data/sunyunbo/www/stg-rl-train/cards/th06_s7_b12/main.ecl:7)、[历史报告:34](/data/sunyunbo/www/stg-rl-train/transcribe/work/units/th06_s7_b12/card/th06_s7_b12/report.md:34) |
| `th06_s6_mb1` | 原作每一发内共享随机转角，转写成每颗弹独立抽角，扇形相对结构改变 | [main.ecl:11](/data/sunyunbo/www/stg-rl-train/cards/th06_s6_mb1/main.ecl:11)、[历史报告:17](/data/sunyunbo/www/stg-rl-train/transcribe/work/units/th06_s6_mb1/card/th06_s6_mb1/report.md:17) |

星弓案例修正了前一轮“没有实际峰值超过256的已知样本”这一过宽表述：本轮已找到历史记录，说明动态参数限制确实迫使旧卡选过固定值。但这是历史运行依据，本轮没有重新测该卡峰值或验证263颗均需长驻任务。

八张采用全局传参的旧卡均先读入local，同槽重写间隔6..70帧；没有找到这批现存卡相邻帧覆盖的正例。应记录已查到的近似，不凭理论风险宣布旧卡全部无效。`s4_b17`元数据的“两次随机合并”已落后于当前八任务实现，也不能继续算作现存近似。

## 两条候选技术路线

### A：参数化模板，发射器持有绑定快照（推荐）

示意语法，尚未实施或冻结：

```text
xformdef TURN(delta: angle, final_speed: fx) {
    @40 step_speed(0fx, 40);
    turn(delta);
    set_speed(final_speed);
}

sh_xform(0, TURN(saved_angle, 1.4fx));
sh_fire(0);
```

语义建议：

- 每次实例化的实参按顺序只求值一次。模板使用类型形参、全局常量与纯表达式，不隐式捕获某个helper的locals。
- fire调用处实例化，立即复制给弹。
- sh_xform在绑定时实例化并复制到发射器配置；sh_fire只读取这份快照，不重新读参数变量。一波所有弹使用相同参数；逐弹不同由脚本显式逐颗实例化。
- 后续重绑定不改变已有弹。旧无参模板名称作为兼容写法保留。
- 参数计算仍走已有定点/角度算术；弹运动解释器和16物理槽结构继续复用。STEP的扩展scratch保持逐弹独立。
- 动态等待等原始宽值必须在打包前处理合法范围；常量坏参编译报错，动态坏参依现有P4约定制定no-op+计数等规则，不能先截断为u16再校验。

这条路线能自然表达原作的配置快照，也避免两发射器绑定同模板、helper返回后locals复用造成参数串用。若采用每任务每发射器16槽的固定快照数组，配置主体增量为256×4×16×12=196608字节，即每World约192KiB；4096环境约增加768MiB，未含具体实现的元数据/对齐差别。需要纳入save/checksum/copy/reset与ENGINE_VER评审。性能影响尚未实测。

### B：仅在发射处即时实例化动态模板

直接fire及“带模板的发射器开火”入口在同一个调用点求值、暂存并立即复制，不保存跨调用的动态模板引用。LLM需要在原bullet_effects配置点用普通变量保存值，在发射时显式传入。

优点是可减少或避免新增World配置状态；代价是不能直接提供A的持久动态绑定语义，还要明确新发射入口如何覆盖本次变换而不污染旧绑定。现有静态sh_xform跨helper持久引用的边界也不会因此自动消失。这是可选的较小范围方案，不能在未定义调用语义前承诺全部只改前端。

两条路线均无需为了动态数值重建通用EX VM。运行时按索引增删操作的builder、更多槽、反弹次数/反弹后变速、出生状态和全场弹关联是独立能力，未纳入本轮候选实现。

## 本轮验证与待确认

本轮读取当前编译器、运行时、NC本作反编译导出、旧卡源码与历史报告；三名既有代理分别核编译器、运行时和TH06NC。本轮未改产品代码、未执行Rust测试、未跑原作/训练或新原生对拍，也未重测历史峰值。报告只检查证据路径、JSON材料与文档格式。

下一步需用户选择公开模板接口与配置所有权路线；A涉及World状态存储与版本，B涉及发射接口和使用限制，均按工作约定先确认。确认后再写完整设计、实施计划和相关行为测试，不在这轮自行扩大到全部旧卡迁移。
