# batch3 专项卡工具实现报告

日期：2026-10-01。范围：专项卡元数据接入、held-out 训练起点排除、独立 machine-spec v1 校验器及对应测试。未改旧 `practice_validate.py`、配置或引擎仓，也未启动卡批验收、训练或 Magnus Job。

`cards.discover()` 只对 `synthetic_kind=laser_specialist` 且 `generation_mode=standalone` 开放无底子 schema；强制校验五个 family、卡 ID 与 layout_id、train/held-out、整数 contract_version 1、ranks `[0,3]`、marks `[0]`、1800 帧时限和标签，并拒绝 `base_card`、`source_ref`、`provenance` 等伪造血缘字段。其他 synthetic 仍须有 `base_card`。`train_starts()` 无视 eval_ids 直接排除专项 held-out 卡。manifest 只为专项行添加专项标识。

新增命令接口：

```bash
.venv/bin/python -m stgtrain.specialist_validate <card-dir> --json <report.json>
.venv/bin/python -m stgtrain.specialist_validate <card-root> --all --json <reports-dir>
```

校验器拒绝 JSON 重复键与重复 `(rank, frame)`，校验严格 v1 顶层字段、逐 rank 至少六个关键帧、正数量帧完整几何声明、全局时序和并发边界；关键帧逐行校验所有激光，不按颜色筛选。运行时执行 `stg_rl.compile_dir`、引擎 `stg-harness check`、完整 `rank 0..3 × seed 1/7 × 1860 帧` harness 矩阵、六项诊断唯一且全零、时限附近段结束检查，并从 `stg_rl.VecEnv(frame_skip=1)` 原生激光表记录每帧 visible/live 数、最长空档和关键帧几何。报告绑定卡文件、harness、validator SHA、Python 和 stg_rl 版本。

验证证据：

- `.venv/bin/pytest -q tests/test_cards.py tests/test_specialist_validate.py`：**26 passed**。
- `.venv/bin/python -m stgtrain.specialist_validate --help`：CLI 参数正常。
- 临时 ECL smoke：`stg_rl.compile_dir` 成功；`/data/sunyunbo/www/stg-engine/target/release/stg-harness check <temp-dir>` 返回 `OK`。
- 小型实际 VecEnv 测量测试覆盖了连续 8 帧与从原生 laser rows 解码宽度/状态。
- 未对 batch3 卡运行完整矩阵：此工具作者任务没有指定卡目录，且协调者要求当前阶段不启动后续批量验收。以上 smoke 不代表任一卡通过。

尚未闭合的工具限制：`VecEnv` 没有玩家无敌接口，玩家死亡会自动 reset；测量器遇到 done 即停止并报告不连续，绝不把 reset 后的帧拼接进原轨迹。激光观测表按距离排序且没有稳定对象 ID，所以可直接测量首个存在帧、末次存在帧、逐帧并发、空档和关键帧，但只能将末次出生报告为“live 数量上升下界”。对此校验器显式返回错误并禁止机器 PASS；精确 `last_spawn_frame` 需要引擎提供稳定激光身份或等价逐帧 spawn 事件后再接入。完整玩家可行性和站桩检查仍归独立工具。
