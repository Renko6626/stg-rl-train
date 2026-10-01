# 从零激光专项卡契约 v1（batch3，2026-10-01）

本轮授权：20张原创专项卡，五家族各四个独立布局；每家族01/02/03为train、04为held-out。主代理冻结本契约，作者只见自己分配的布局。暂存 `/tmp/sunyunbo/stg-laser-batch3/<card_id>/`；通过完整验收后进入 `cards-laser-specialist/`，不修改历史卡池或训练配置。留出不纳入训练起点。没有训练收益或全部随机实例可解的预先保证。

## 全局约束

- 留在main，不commit/push，不建worktree/分支，不部署/训练/提交Magnus；引擎仓只读，不读密钥，不再委派。共享工作区不覆盖其他作者文件。
- 纯激光，无普通子弹；一只固定、无敌、非碰撞boss `(0,64)`，统一以 `phase_begin` 管理1800帧段，`wait_spell`后保持存活。`spawn_enemy` 签名为 x/y/hp/drop_table/score/sprite/task，并无flags参数；boss_task必须调用 `set_enemy_flag(ENEMY_NO_BODY,1)` 明确关闭体碰，不创建额外敌人。Boss是明确的跟点目标，跟点冲突不靠修改reward解决。
- rank=0/1/2/3对应Easy/Normal/Hard/Lunatic；逐档width=6/8/10/12px；warn=90/75/60/45帧；active允许150..210帧、fade=12帧。家族运动速度/重叠强度须逐档在TASK声明，不能把较难档只换颜色。
- 开场90帧后开始；最后出生不晚于1500，最后自然回收不晚于1750；段结束约1800帧。除开场/收尾外，家族波次应反复交接，最长无预警或生效激光空档不超过90帧。
- 预警+生效并发最多16，含收缩池占用最多20；宽度完整判定宽，长度/near/far不超过640。仅沿射线合法前向短棒，不使用负速触发钳制。普通瞬移或生效中无预警跳角不能作为压力来源。
- 当前观测预警倒计时最多120帧，无消退倒计时；不得要求预知未来随机或剩余寿命。离线检查轨迹不进入观测/reward。允许正确避让后停住，不能长期在固定角落绕过全部练习。
- 随机化至少影响原点/方向/通道/相位之一，有确切单位与区间；联合约束而非独立乱抽。按最坏运动距离/预警时间给余量；用真实运动验证时必须使用实际速度、hit_extra与动作限制，并明示覆盖边界。
- 作者先编译、全部rank×seed1/7完整1860帧运行，诊断六字段存在、无重复且全零。关键帧核实际几何和边界；绝不以退出码0代替门。模型独立审查必须读完整实际脚本。每次文件变化使旧报告失效。
- 大型日志/截图在tmp；不启动浏览器交互。所有最终文件SHA256冻结，review必须是非作者。

## 文件与metadata

每卡四文件 `main.ecl`、`meta.toml`、`TASK.md`、`machine-spec.json`。根/共享工具不归作者。metadata 必须有：

```toml
title = "原创激光专项卡名"
source = "synthetic"
data_kind = "synthetic"
synthetic_kind = "laser_specialist"
generation_mode = "standalone"
family = "<stagger|corridor|sweep|aimed|bars>"
layout_id = "<card_id>"
split = "<train|held-out>"
contract_version = 1
ranks = [0, 3]
marks = [0]
time_limit = 1800
tags = ["laser", "specialist"]
```

不得有base_card/source_ref/mutation_id/原作provenance；standalone显式schema例外仅限此类卡。正式加载器须校验这个例外，仍拒绝缺底子的普通synthetic。train_starts无论eval_ids如何都排除split=held-out专项卡。

## machine-spec v1

严格JSON，禁止重复键/重复(rank,frame)。以下键必填，值为实测与独立推导一致的最终声明：

```json
{
  "schema_version": 1,
  "max_visible_lasers": 16,
  "max_live_lasers": 20,
  "first_spawn_frame": 93,
  "last_spawn_frame": 1500,
  "last_expiry_frame": 1750,
  "max_idle_gap": 90,
  "key_frames": [
    {"rank": 0, "frame": 94, "count_min": 1, "count_max": 4,
     "states": [0], "width_min": 6, "width_max": 6,
     "x_min": -192, "x_max": 192, "y_min": 0, "y_max": 448,
     "angle_min": 0, "angle_max": 360,
     "start_min": 0, "start_max": 0, "end_min": 1, "end_max": 640}
  ]
}
```

上面的数值只是schema例子，不能直接复制当实际规格。首/末出生、自然回收等统一跨rank时须覆盖实际最早/最晚值，TASK列逐rank时序。关键帧每rank至少6个，覆盖预警、生效、波次交接、运动、末轮与时限；有激光的项必须列states及所有几何字段（x/y/angle/width/start/end的min/max）。count_max=0允许只给rank/frame/count_min/count_max。范围需足以检出该帧机制错误，不能一律填全场/全部状态。几何角度按harness归一化度数，wrap区间用合理关键帧避开或报告工具需求。

## 验收工具与状态

工具适配任务实现 `python -m stgtrain.specialist_validate <root> --all --json <reports>`，从零卡专用，不放宽旧overlay工具。报告包含逐rank×seed、关键帧、实测并发/时序/空档、文件/harness/tool SHA。真实玩家避让检查由单独工具执行，记录轨迹、动作、判定/运动限制、存活和站桩结果；工具尚未齐时只能作者就绪，不能正式通过。单例成功不代表全部随机实例可躲；未成功是候选检查器局限或卡需调整的信号，不单凭启发式失败宣判不可解。

先把作者产物按快照机器检查，再非作者审查、返工（最多三轮）。最终逐卡同时记录mechanical/review/feasibility状态，未满足本轮完整门的产物留暂存并列出缺口，不以批量数量掩盖失败。

## 2026-10-01 执行澄清（不改变v1 schema）

真实玩家位置clamp为x[-192,192]/y[0,448]，依据引擎world/player.rs；四边永久安全带检查必须覆盖此范围。corridor任务中的内区[-176176]/[16432]描述通道中心及场内可达空间，不能当作激光边界限制；允许联合中心/半gap让激光边界扫到真实边缘，但规定净宽与连续可达空间仍须满足，不得把通道整体挤出场或在生效期跳位置。此澄清已传全部相关作者，训练/留出均只共享引擎约束。

逐组封位公共修正：每组包含1条off=0出生时直狙，其余非零偏角8..60deg；原brief全部偏角非零会使远处静止自机永远不被命中，与避站桩目标矛盾。总组2..4条，预警与出生后冻结规则不变；joint时空余量仍需验收。这是主代理规格修复，所有aimed作者均收到，不使用留出结果调参。

敌人接口纠正：先前spawn flags=1的说明错误，实际第4参数是drop_table、第6参数是sprite。非体碰必须使用 `set_enemy_flag(ENEMY_NO_BODY,1)`，`set_hitbox(0)` 仍保留自机半径，不能代替禁用体碰。依据官方引擎7-reference.md第102/114行；此公共纠正不改变任务意图。
