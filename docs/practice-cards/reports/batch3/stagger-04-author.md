# laser_sp_stagger_04 作者返工报告（held-out review round 1）

任务：batch3 / contract v1，family `stagger`，split `held-out`。

状态：**READY/FROZEN（作者阶段）**。以下四文件冻结在 `/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_04/`。匹配旧 SHA 的 held-out 证据显示边缘锚线没有覆盖下半场内部；本版改为八相位斜线交接，在三个高度带按两种向下、两种向上方向重复穿行，每波从相位对应的宽半区随机抽原点，并扰动角度。相位/范围按整片空间带定义，没有使用 checker 坐标作参数。

## 冻结文件 SHA256

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `86251ae78bba2e3ab7ed72e6c94930d1024a62e3017678b64c985c7ca09d8129` |
| `meta.toml` | `40538c594942073f32839d6d4ea2c3ef7a3532122549b2a798d88a2d920d4b10` |
| `TASK.md` | `54bede6f08f25727128502ed4ea77ab7b1bb15e3d2432ae446c90c448df792d5` |
| `machine-spec.json` | `2206f524e24d1786935215b0432e3eade116f25e12396b7d1d61c577fbef30c4` |

## 作者阶段验证

- `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_04` → `OK`。
- 完整运行 8 组：`/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_04 --rank R --seed S --frames 1860`，其中 `R=0,1,2,3`、`S=1,7`。日志 `logs/stagger_04/r1e-run-rR-sS.log`。全部 1860 帧完成、`PHASE_ENDED@1803`，六诊断字段均存在且为 0；激光峰值 8（frame 310），末帧 0。
- `--at` 抽查命令形式：`/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_04 --rank R --seed S --frames F --at F`。R=0..3、S=1/7 各采 `F=93,94,166,first_active,238,310,1389,1390,last_expiry-1,last_expiry,1800`，日志 `logs/stagger_04/r1e-at-rR-fF-sS.log`。machine-spec 绑定 36 个唯一帧（每档9个），正数量快照包含完整几何/state范围，并包含自然回收与 frame 1800 零激光。首出生 frame94、末出生1390、末回收 rank0/1/2/3 分别1642/1647/1652/1657；每档首次生效帧184/169/154/139。
- 新专项机械自检：`.venv/bin/python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_04 --json /tmp/sunyunbo/stg-laser-batch3/logs/stagger_04/mechanical-r1e.json --seeds 1 7` → `MECHANICAL PASS · independent review pending (0 errors)`。JSON 中观测 max visible/live=8、max idle gap=0，出生/回收实测边界与 machine-spec 一致。
- 新 SHA 的实际运动复核：以 `--ranks 0 1 2 3 --seeds 1 7 --max-frames 1860 --baselines` 完整运行 `stgtrain.specialist_feasibility`，输出在 `logs/stagger_04/feasibility-r1e/`，88条轨迹在 `logs/stagger_04/feasibility-trajectories-r1e/`。启发式存活 8/8。指定 stationary 样本存活为：实际出生点1/8（rank1 seed7）；center-lower 1/8（rank1 seed1）；left-lower 3/8；right-lower 3/8。其余固定点统计及逐条轨迹见 JSON；这些有限样本不能推出普遍安全带，也不能证明所有随机实例可解。完整日志为 `logs/stagger_04/feasibility-r1e.log`。

## 机制与限制

每波2条平行640px静止斜线，法线间距按rank为112/96/80/68px，净空106/88/70/56px。rank width/warn/active/fade保持`6/90/150/12`、`8/75/170/12`、`10/60/190/12`、`12/45/210/12`。开场90帧，每72帧生成一波，共19波，首末出生94/1390；angle/intensity在warning出生时就确定，生效期间不跳角。随机x中心落在左/右半区的内侧宽带，y中心按八相位落在`[224,289)`、`[288,353)`、`[320,392)`、`[256,321)`，倾角在各相位基准上作`[-4551,4551)` BAM扰动（约±25°）。中心到原点的最大偏移56px，联合范围确保坐标不越场地。

本报告只绑定作者/机械/有限可执行性证据，不代表非作者源审、正式纳入或训练收益结论。held-out source review 和最终协调者判断仍待完成。
