# Batch3 sweep_03 作者交接（contract v1）

作者阶段状态：`READY/FROZEN`。这只表示作者产物和基础 harness 自检已完成，不代表正式机器门、真实玩家可执行性或独立源码审查通过。卡片四文件按下列 SHA 冻结；返工须由协调者解冻。

卡片目录：`/tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03/`。

| 文件 | SHA256 |
|---|---|
| `main.ecl` | `da34d47f01f40d933c7d23b7f9fb9d307ebca7555bcda7ae22c2c8fe88c2a995` |
| `meta.toml` | `14c97048d361f54bcb622c3e4c455da8b6a99dc97fa69d942441cfdd90ec1327` |
| `TASK.md` | `77bc69dd32ec4c74b24516962479d876ea80d963d33171119df2b95d0259078a` |
| `machine-spec.json` | `6081ea3653e91fb7459f53459089dabbcb72e777dcab24e8a2d066dfb513c7b1` |

## 作者自检证据

执行 `/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03`，结果 `OK`。

完成 rank 0..3 × seed 1/7 共8次完整运行：

```text
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03 --rank R --seed S --frames 1860
```

8次均退出0；每次 `task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped` 字段各出现一次且全为0；帧1860无激光，段结束为 `PHASE_ENDED@1803`。最大同时激光数实测4，峰值帧359；清理relay子任务后任务峰值为7。

machine-spec 有40个唯一关键帧（每rank 10个），覆盖首出生、预警末/生效首、次束交接、三束与峰值并发、末出生、最后fade、精确自然回收帧和1800帧时限。所有有激光关键帧均按最终 ECL 实际运行了 `--at F`；首帧与峰值帧另以seed7抽查，seed1/7在原点和角度上有差异。Round 1 补入每档末句柄回收后第一帧的空场样本（r0/r1/r2/r3：1727/1712/1697/1682）；最后fade样本保留在各自回收帧前一帧。seed1和seed7均已实测这些fade/空场帧，fade各显示1条state 2，后续第一帧显示0条。快照命令：

```text
/data/sunyunbo/www/stg-engine/target/release/stg-harness run /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03 --rank R --seed S --frames 1860 --at F
```

JSON 唯一键/必填几何字段/关键帧数量及快照字段范围自检通过。完整输出、快照和作者日志位于 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_03/`，矩阵日志为 `run-rR-sS.txt`，快照日志为 `at-rR-sS-fF.txt`。

按协调者要求复跑专项机器 validator：`UV_CACHE_DIR=/tmp/sunyunbo/uv-cache uv run --frozen python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03 --json /tmp/sunyunbo/stg-laser-batch3/logs/sweep_03/machine-r1-after.json`。结果 `MECHANICAL PASS · independent review pending`，0 errors；报告测得各rank/seed的last expiry为1727/1712/1697/1682，keyframe coverage errors为空。此前 validator 的4项失败都由每rank缺少“精确回收后首个零激光帧”引起；补齐后通过。validator报告和Round 1边界日志均在上述专属日志目录。

## 布局和时序

两侧源在活动场中段交替出生，方向相反地连续旋转；预警时 omega 为0，只在 warn 结束后设置真实 `lz_omega`。左源 omega 为正、右源为负；未对生效中已有射线调用 rotate 或改角。开场 `wait(90)` 后首束实测帧95，之后每88帧发一束，共16束，末束帧1415。按rank 0/1/2/3 的 width/warn/active/fade 为 6/90/210/12、8/75/210/12、10/60/210/12、12/45/210/12。末束最后仍活帧分别为1726/1711/1696/1681，下一帧自然回收；最晚回收帧1727。内部相邻active窗口重叠122帧，无内部空档，收尾距1800最多73帧。`max_visible_lasers=16`、`max_live_lasers=20` 为预算；实测峰值均4。

原点随机范围为左 `x∈[-168,-160]`、右 `x∈[160,168]`、`y∈[192,256]`，端点均包含；初角按30°起始、45°分区并分别偏置∓10°，再加 raw BAM `[-2731,2729]` 的均匀整数相位抖动（左闭右开）。每条长度450px；对 side-origin 到最远角距离的几何上界约441.7px，rank3端点最大切向速度按完整450px计算为3.45px/frame。角速度绝对值按rank为20/40/60/80 BAM/frame。几何可达范围与角速度余量是作者计算，不是整段可躲证明。

## 尚待完成的门

协调者补充状态：非作者源码审查通过。真实玩家启发式有限样本完成7/8；其中rank0–2/seed7和rank0–3/seed1完成，rank3/seed7未完成。rank0/seed7有两个静止整段生存样本：实际出生点 `(-13.8587,448)` 生存1746帧，左上角 `(-192,0)` 生存1483帧。这些是两个有限样本中的具体绕过，不证明连续安全带，也不证明全随机实例可解；同样不能据此宣称不存在其他固定安全点。协调者决定不根据这两个孤立坐标样本做坐标专属几何调参。来源审查依据见 [sweep-train-review.md](sweep-train-review.md)。

Round 2 将TASK中的角落覆盖描述改为明确的有限结论：450px射线长度在声明的原点范围内能够到达场角，但不保证某一seed的active角度轨迹实际经过每个角、中心或顶部位置。ECL、metadata和machine-spec均未修改；移动样本、两个静止样本及其限制已保留。上一轮冻结的TASK SHA为 `da91f58ed270a2b22fc3e5be9b4dc1bab7c460d0cd01d68746b0ce8651bbf545`，本轮仅修订TASK并更新本报告。新TASK SHA下执行 `./.venv/bin/python -m stgtrain.specialist_validate /tmp/sunyunbo/stg-laser-batch3/laser_sp_sweep_03 --json /tmp/sunyunbo/stg-laser-batch3/logs/sweep_03/machine-r2-doc-correction.json`，结果 `MECHANICAL PASS · independent review pending`，0 errors。报告位于 `/tmp/sunyunbo/stg-laser-batch3/logs/sweep_03/machine-r2-doc-correction.json`。本轮之后需协调者把最终矩阵/审查报告重新绑定到新TASK SHA；专项机器/加载器兼容和最终纳入决定仍由协调者完成。seed 1/7 不覆盖所有随机组合；没有作全随机实例可解或训练收益断言。
