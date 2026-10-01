# corridor_04 作者交接报告

任务/规格：batch3 / `laser_sp_corridor_04` / corridor family / held-out / specialist contract v1。

状态：**READY/FROZEN（作者阶段）**。下列四个暂存卡文件已冻结；正式专项机器门、独立审查、真实玩家避让/站桩检查、加载器兼容与协调者纳入决定仍待完成。未声称全随机实例可解或训练收益。

## 冻结文件与 SHA256

- `main.ecl` — `962ce277cee16c66bd4bac128487ba29a8e74f1d4fcbb5aa8ed805b7d2b715dc`
- `meta.toml` — `eba3687b90de76c7447c1056d013a1d317d84761d4f0861fdde902edaec4a1db`
- `TASK.md` — `b3d88c406e52b77577d825127f55c37d8b73e73db481faf57877ec1fce07908a`
- `machine-spec.json` — `c06818521bf9e7948275e8be0c53b39a8fa9761b08db7fa0d8dfdd825b69f652`

卡目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04/`。

## 运行证据

最终编译：

```bash
/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04
```

结果 `OK`，日志：`/tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/check-final.log`。

完整矩阵共 8 条命令，全部退出码 0：

```bash
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 0 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 0 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 1 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 1 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 2 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 2 --seed 7 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 3 --seed 1 --frames 1860
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --rank 3 --seed 7 --frames 1860
```

Each summary contains exactly one copy of all six diagnostics (`task_faults`, `contract_viol`, `pool_full`, `hits_ovf`, `events_ovf`, `reqs_dropped`), all zero. Peak was 4 live lasers; frame 1860 had 0 lasers and the fixed target remained. Phase ended at frame 1803. Per-run logs are `/tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/run-r{0..3}-s{1,7}.log`.

`--at` snapshots were run for every machine-spec keyframe for both seed 1 and seed 7: 44 frames per seed, 88 rank/frame/seed snapshots total. They are saved under `/tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/` (`edge-*`, `key-*`, `r1-*`, and `frame-*` logs). A separate parser compared every sampled count, state set, and geometry value with its declared key-frame bounds; all 88 matched. This includes each rank's last-fade frame (`expiry−1`) with two positive-geometry state-2 lines, the exact expiry frame with count 0, and F1800 with count 0. Seed 1 and seed 7 produced different inward center offsets while remaining within the declared `[0,24]` px range.

`machine-spec.json` and `meta.toml` parsed successfully; machine keys are unique with eleven `(rank, frame)` entries per rank. The new single-card self-check command completed with `MECHANICAL PASS` and 0 errors:

```bash
UV_CACHE_DIR=/tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_corridor_04 --json /tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/specialist-selfcheck.json
```

Its report and log are `/tmp/sunyunbo/stg-laser-batch3/logs/corridor-04-author/specialist-selfcheck.json` and `specialist-selfcheck.log`. The report records 8 complete runs (ranks 0–3 × seeds 1/7), keyframe coverage with no errors, observed max visible/live count 4, first/last spawn F95/F1445, and last expiry F1727. Independent review remains pending; this self-check is not that review.

## 参数与边界摘要

| rank | width | warn/active/fade | centerline spacing | net corridor | speed | active travel | measured last expiry |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 6 px | 90/180/12 f | 70 px | 64 px | 0.40 px/f | 72 px | F1727 |
| 1 | 8 px | 75/180/12 f | 64 px | 56 px | 0.60 px/f | 108 px | F1712 |
| 2 | 10 px | 60/180/12 f | 50 px | 40 px | 0.85 px/f | 153 px | F1697 |
| 3 | 12 px | 45/180/12 f | 44 px | 32 px | 1.00 px/f | 180 px | F1682 |

Two parallel boundaries per group. Direction cycle is top-horizontal, left-vertical, bottom-horizontal, right-vertical. Each group moves inward only after warning; perpendicular safe strips intersect during handoff. Center displacement is discrete uniform `rand(25)` converted numerically to fx: integer `[0,24]` inclusive, inward from the selected edge. Ten groups spawn at F95, 245, 395, 545, 695, 845, 995, 1145, 1295, 1445. The six-count diagnostics and sampled geometry support the author-stage timing and pool bounds; player dodgeability and long-term edge/corner standing are still pending the coordinator's independent gate.
