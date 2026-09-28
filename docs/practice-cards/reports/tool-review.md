# 合成卡验收工具交叉审查

审查者：Luna reviewer（非 `cards.py` / `train.py` / `practice_validate.py` 作者 Sol）  
范围：只读审查 `src/stgtrain/cards.py`、`src/stgtrain/train.py`、`src/stgtrain/practice_validate.py` 及 `tests/test_cards.py`、`tests/test_practice_validate.py`、`tests/test_config.py`；未修改产品代码，未运行测试。

## 通用硬化建议

以下是验收器对未来输入的 fail-open 边界，不表示当前10张卡因此未通过。已交叉抽查的s6_b1/s7_b1分别有完整正数量帧几何规格、无重复JSON键/帧、末条激光在time_limit内回收、并保留合约metadata；两卡机器报告与当前文件hash一致。其余卡是否满足这些边界由对应独立卡审报告确认。

1. **建议硬化 — 正数量关键帧可以省略几何/状态字段。** `practice_validate.validate()` 只要求 `key_frames` 非空、最大条数和颜色存在（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:59)）；`frame_errors()` 只遍历规格中实际出现的键（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:27)）。因此规格 `{"frame":124,"count":1}` 可接受任意状态、宽度、位置、方向和端点，只剩通用宽度/合法段检查。后续可要求每条 `count>0` 的关键帧声明状态、width、x/y/angle、start/end 的精确值或有效 min/max 区间；`count=0` 帧才可省几何。

2. **建议硬化 — JSON 重复键会被静默覆盖。** `json.loads()` 默认接受诸如 `{"count":1,"count":2}` 的重复字段，后一个值覆盖前一个（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:52)）。这会让机器规格本身的重复字段逃过“重复字段即失败”的审计口径。后续可用 `object_pairs_hook` 拒绝重复键，并检查 `key_frames` 中是否有重复帧；当前s6_b1/s7_b1文件已单独确认无重复。

3. **建议硬化 — 末条激光只在 `time_limit+60` 抽查回收。** 出生窗口目前只验证 `last_spawn_frame < last_spawn_before <= time_limit`（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:113)），终态只在 `time_limit+60` 检查没有合成激光（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:171)）。若最后一条越过段时限、但在额外60帧内自然回收，它仍会通过。后续可声明/计算 `last_expiry_frame` 并要求不超过 `time_limit`。当前s6_b1/s7_b1源码计算的最后自然回收分别是2445/1560，均早于各自时限。

4. **建议硬化 — 合约要求继承的部分 metadata 未被机器闸门检查。** 验收只比较 ranks、marks、time_limit、original_time_limit（[practice_validate.py](/data/sunyunbo/www/stg-rl-train/src/stgtrain/practice_validate.py:97)），没有要求 title/origin/source_ref 等底卡字段保留，也没有确认 `tags` 含 `laser`。后续可扩大 metadata 比对范围。当前s6_b1/s7_b1的tags含laser，origin/source_ref与底卡一致，provenance source与SHA吻合，title均明确synthetic。

## 未发现的问题

- `discover()` 对旧配置的字符串 `cards_dir` 保持原有单目录行为；T0/T1 配置仍指向 `cards`。T2 的 TOML 列表映射为 list，发现流程逐目录合并并拒绝重复 ID。训练起点与 `data_kind` 分离，`train.py` 只把来源清单写进 `env.json`，没有将标签作为策略输入。
- held-out 检查对合成卡沿 `base_card` 向上追溯，并比较底子 `source_ref` 与 held-out 区间；另有直接底卡 ID 排除。端点重叠被 `source_ranges_overlap()` 正确视为冲突。
- 逐文件底子 SHA、删除入口行的逐字恢复和唯一入口检查均有实现；诊断字段重复/缺失/非零会失败；两 seed 抽样会比较合成激光几何签名。

## 现有测试覆盖

`test_cards.py` 覆盖显式多目录、重复卡 ID、来源标记、原作池留出兼容和基础同源过滤；`test_practice_validate.py` 覆盖诊断字段缺失/重复/非零、源区间端点和少量关键帧比较；`test_config.py` 覆盖 list `cards_dir` 的 TOML round-trip。没有看到覆盖机器规格必需几何字段、JSON 重复键、末条回收截止或合约 metadata 继承的测试。
