# batch3 连续机械轨迹工具实现报告

日期：2026-10-01。范围：`tools/laser_trace/`、专项 validator/tests 与本目录机器报告。未修改练习卡或 `/data/sunyunbo/www/stg-engine`，没有提交或推送。

## Round 1 修订

独立审查的两个可绕过问题已修复。每次验收都会运行 `cargo build --offline --release`；trace 源、Cargo manifest/lock、相关引擎 crate 源与 manifest、workspace lock/toolchain 组成 source fingerprint。原子 sidecar 同时绑定 source fingerprint、可执行文件 SHA、Cargo/Rust 版本和引擎身份。fingerprint 或可执行文件 SHA 不匹配时先清理隔离的 trace Cargo target，再构建；构建期间源指纹变化、报告前后 source/binary 变化、或 sidecar SHA 不匹配都会拒绝验收。`--seeds` 必须包含契约种子 1 和 7，可附加其它非负、不重复种子；只传 `--seeds 1` 已实测退出码 1。

关键帧现在按冻结 v1 的用途作结构和轨迹检查：各 rank 分别需要有激光的 warn、active、fade 快照，warn/active 须是不同帧；必须覆盖实测首波和末波出生边界、中段、末次 handle 回收后的精确空场帧以及 frame 1800 零激光终帧。若轨迹实际有多波重叠或单束运动，还要求至少一个快照覆盖对应的实测帧。负例证明每 rank 六个任意零激光帧不能通过。

几何检查接受 harness 归一化角度 `[0,360]`、混合激光状态，以及超出玩家移动边界但处于引擎坐标域内的原点，例如 x=-320、y=-96。起点/终点约束在契约 `[0,640]`，原点约束在引擎 `[-4096,4096]`，宽度约束为 rank 对应值。为避免把合法的整场随机布局误判为无意义范围，只在单个快照的 x/y、角度、start/end 同时覆盖各自完整合法域时判定其完全无约束。

**验收状态明确只是机械门。** 对完整随机取值域而言，有限 seed 矩阵无法证明作者给出的每个坐标/几何区间足以捕捉所有机制错误；因此报告中的 `acceptance_status` 是 `mechanical_pass_independent_review_pending`，CLI 显示“MECHANICAL PASS · independent review pending”。这里保留非作者语义审查，由其检查实际脚本与声明范围。审查意见若要求更严格的几何紧度门，需由协调者根据具体字段和机制判断；本工具没有用任意范围宽度阈值拒绝合法全场随机几何。

## 实现与来源身份

Rust 命令：

```bash
CARGO_TARGET_DIR=/tmp/sunyunbo/stg-laser-batch3/trace-target cargo build --offline --release --manifest-path tools/laser_trace/Cargo.toml
```

`laser-trace CARD --rank RANK --seed SEED --frames FRAMES` 以 path dependency 链接 `stg-core`/`stg-ecl-compiler`，按 harness 顺序执行 `compile_units → World::new_game → InputFrame::empty → step`。每帧 JSONL 记录全部激光的真实 `(pool index,generation)`、状态、宽度、原点、归一角度、start/end/speed/omega、handle born/expiry 转换、六项诊断、弹/敌计数、自机状态和公开段结束事件。raw World death 后持续 step，不使用 VecEnv autoreset。validator 每 rank/seed 启动一次 trace，并以 harness 单帧表对拍 rank0/seed1 的所有声明关键帧，打印值容差 0.011。

最终 executable SHA256：`669f316844e5527e261345d939e08e44de59ebff4d1374d53c2c81470beb5a82`。build sidecar source fingerprint：`dd267e137118483efb2cced40094b539dcd2cce23ee25021f068535c819d9c35`。

报告记录引擎 commit `5dfc08d45f8f0c359c301de94d6fe7bb399df889`；core/compiler/derive source SHA256 依次为 `dcb97316b86c3177d3cfe8cd548648f963e4323374e686336ce27d26337feda6`、`3dfaf21fccf2296c7ea2bba2e2eeac5a53f3904d0f7f1c5689569d783792c787`、`8df365b4eefb4ff92e63cb20ab8c0f51a0ba28d8d29f48eaa34c9021c16f40db`；相关已跟踪源码 diff 为空。报告把已安装 `stg_rl` build info 与此 path-dependency 编译身份分开记录，不声称两者同版。

## 验证结果

- `cargo fmt --manifest-path tools/laser_trace/Cargo.toml -- --check`：通过。
- `.venv/bin/pytest -q tests/test_cards.py tests/test_specialist_validate.py`：**36 passed**。新增测试覆盖 fingerprint 对工具/引擎源码变化的响应、sidecar 必须同时匹配 source/binary SHA、不可信缓存清理重建、仅 seed 1 不能满足矩阵、六个零激光帧拒绝，以及完整域 vacuity 检出但保留合法全场可达范围。
- `.venv/bin/python -m stgtrain.specialist_validate ... --seeds 1`：**FAIL，退出码 1**，原因是缺 seed 7。
- 当前暂存的 stagger01、02、03 均完成 4 ranks × seeds 1/7 × 1860 帧以及 harness 检查；每卡机器报告为 **MECHANICAL PASS · independent review pending**，rank0/seed1 所有声明关键帧与 harness 对拍无误。六项诊断全零。
- stagger01/02 实测跨矩阵 first/last spawn `94/1471`、last expiry `1750`；stagger03 为 `94/1466`、`1733`。三卡各自 visible/live peak 都为 `12/12`、内部 idle gap 为 `0`；声明并发预算均为上界且满足。

逐卡机器证据：

- [stagger01 machine report](laser_sp_stagger_01.machine.json)
- [stagger02 machine report](laser_sp_stagger_02.machine.json)
- [stagger03 machine report](laser_sp_stagger_03.machine.json)

机械报告不代表玩家可躲、TASK质量、全部随机值可解或训练收益。真实玩家检查和非作者完整源码/几何语义审查仍待完成。
