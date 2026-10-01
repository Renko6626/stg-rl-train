# Batch3 bars_0102 作者交接（contract v1）

作者阶段状态：两卡均为 `READY/FROZEN`。两卡均通过当前专项机械 validator；bars_02 保持原源码快照且源审查为 `pass (source scope)`，bars_01 针对源审查发现修订后等待原审查者复核。作者冻结只绑定下列 SHA，不代表真实玩家可行性或训练价值通过。

## laser_sp_bars_01

目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_bars_01/`

- `main.ecl` — `39e458a758e74583b82a1a4ec797f3db11bbb6c5ed19e8cc590f1f7d44445754`
- `meta.toml` — `81f70a504d000e7515c88513c980e50d9f2d59eddfb82754722e7b85db01a58b`
- `TASK.md` — `17c78b801294d42d256c1f38d413ae1a070bd9047775cb7084915c181d278b7a`
- `machine-spec.json` — `6af2cc438adccb872362ae04035e83989f0d8e6f838b63ebf7ee6a9c5bc2549b`

## laser_sp_bars_02

目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_bars_02/`

- `main.ecl` — `3a5e41944bbd13992d00b37553e30a00c2f38f69d32fdde2244f7cddd635ee90`
- `meta.toml` — `d27e673d16fdb6eb99d5627e9d890d913dc0040af0a3ef8658bbdef9a7951d59`
- `TASK.md` — `79baa5137c4eaa7eb1b6afea17178fc7e97d6fd658f4ff88ca18404755c74ae0`
- `machine-spec.json` — `0c84b34439b2ea49d83deea9094894dfda2b49f51e41be94f18b93435e085982`

## 作者自检证据

bars_01 round2新快照已执行 `stg-harness check` 和 `run --rank R --seed S --frames 1860`，`R=0..3`、`S=1/7` 八组均完成。`bars_02`四文件未变，保留前轮匹配当前SHA的八组完整运行。总计16组的六项诊断均为0；两卡均在1803帧发出`PHASE_ENDED`，帧1860激光数为0。观测峰值bars_01为16条（到达16的可见/生效预算、live仍低于20），bars_02为8条。运行日志与`--at`快照位于 `/tmp/sunyunbo/stg-laser-batch3/logs/bars_0102/`，按卡/rank/seed/frame命名。

两卡分别执行 `UV_CACHE_DIR=/tmp/sunyunbo/stg-laser-batch3/logs/bars_0102/uv-cache uv run python -m stgtrain.specialist_validate <卡目录> --json <报告路径>`，均为 `MECHANICAL PASS`、0 errors。报告为 `/tmp/sunyunbo/stg-laser-batch3/logs/bars_0102/specialist-bars01.json` 和 `specialist-bars02.json`；独立语义审查仍待完成。

bars_01 machine spec有60个唯一关键帧（每rank15项、seed1/7各采），额外覆盖第三轮底层lane到达左/右边界的位置；bars_02规格保留52个唯一关键帧（每rank13项）。两卡均覆盖开场、预警/生效边界、移动中、交接、中段、末轮、fade、回收与1800帧。全程首出生95、末出生1423、最晚回收1735；每83帧出生一组，warn90/75/60/45，active210，fade12。width为6/8/10/12px；bars_01每轮四根、正合成速率0.8/1.1/1.5/2.0斜向下平移，bars_02左右对流速度1.0/1.1/1.5/2.0。两卡预警静止；near=0、far=随机长度80..120px全程不变。细节见各自`TASK.md`与`machine-spec.json`。

跨 seed 首束坐标和长度有差异，证明声明的 RNG 被实际消费；两个种子不覆盖全部随机范围。有限棒不会同帧封闭整条通道。`max_idle_gap=0` 指开场和收尾之外，warn/active并集内部没有空档；组间出生间隔为83帧。

## Train 源质量复核

本轮审查先指出旧bars_01快照有固定x=96纵向安全带（协调者旧基线39/80成功）；round1斜向三层仍留下低rank左下角路径。round2将每组扩为四根短棒，并在四轮周期中把四个x lane分别与四个y strata作全笛卡尔配对：每条外lane都会重复配到底部y∈[372,396]层，80px最短段出生就跨过y=448，active首步水平位移仅0.64px（rank0），保有命中余量；同一配对周期也遍历顶部、中间和下方条带。最不利y sweep核心区间在TASK中逐层列出并彼此相交，说明按整个schedule端点推导的空间支撑，不是给某个baseline坐标加一根特例。当前已重跑新SHA的八组full matrix、60个关键帧和专项机械validator；升级后的真实固定位置基线仍待协调者复测。

bars_02未改源码：它已获本轮源审查 `pass (source scope)`，每四轮的y=0/448行与左右有限棒结构覆盖四角，其他行由轮换和随机抖动覆盖场地。协调者报告该卡基线17/80次静止成功；本作者不据局部有限条带的静止样例扩机制，也未复跑该基线。本结论保留审查者限定，只说明当前源码未发现广泛固定安全带，不说明所有行/随机实例均可解。

## 尚待协调者完成的门

bars_01新快照的独立源码复审、真实自机动作/判定下的可行轨迹、固定位置/边角站桩复测和加载器/纳入门仍待协调者完成。bars_02源级复审已通过但仍需保留全局可行性/站桩限制。坐标覆盖推导与harness几何快照不证明所有随机实例可躲，也不构成训练收益结论。
