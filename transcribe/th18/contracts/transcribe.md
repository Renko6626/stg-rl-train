# TH18 单攻击转写契约

把任务单指定的 TH18 v1.00a 攻击转成目标引擎 ECL。只处理这个攻击及其依赖；本契约不使用 TH06 的切分器、摘录注释或状态机。

语法与转换方法见[主线教材](../mapping.md)；按本攻击查[发射模式](../aim-modes.md)、[插值](../interpolation-modes.md)、[激光](../lasers.md)及弹型/EX表。读原作后独立推导锚点，不把教学例视为该攻击的既定答案。

按[统一转写口径](../transcription-policy.md)和[敌人状态/段入口](../enemy-state.md)恢复前置状态。**曲线激光暂时不做**：实际依赖Curve的攻击写blocked、注明源位置并暂缓；不删除、不用短线近似，不能审核为pass。未选rank或确实不可达分支不因此阻塞，但须给依据。

尚未确定本攻击边界时，由主会话先按[切分指南](../splitting.md)及[切分契约](split.md)准备整关记录，再交本任务的入口、依赖和前置状态；作者不在写弹幕时自行改整关切法。

## 输入与权限

先读 cwd 的 `brief.md`、`source.txt`，再读任务单附带的 [弹型表](../bullet-types.md)、[EX 表](../ex-effects.md)、相关详细条目、内建速查和 xform 语法片段。资料可以是任务目录内副本，也可以是明确可读的引用路径。

`brief.md` 应明确最终 `unit_id`（见[编号规则](../validation.md#编号)）、版本、原作文件与入口、依赖闭包、rank、时间窗、源帧/卡帧对应、目标弹型/半径方案、已接受近似、harness 路径及可写范围。验证目录 `card/<unit_id>/` 也须明确允许写入。缺少影响本攻击的资料时写 `out/report.md` 说明缺口，不靠 TH06 规则或旧原型填空。常规难度为 0=Easy、1=Normal、2=Hard、3=Lunatic；Extra 的源难度与目标 rank 对应由任务单写明。

只写本任务 cwd 的 `out/`，如任务单允许，可另写 `card/` 临时验证目录。原作与参考只读；不要修改训练仓、引擎、其他卡或工作状态，不派子 worker。

## 转写

1. 跟踪原作调用、async 与同敌共享发射状态；跳转还会影响脚本时间，不能只翻 PC。为有限攻击重组控制流和缓存是可行手段，但须保留取值、发射、效果进入的相对时点。
2. `etSprite` 的 type/color 查本作表。记录每个实际弹型对应的我方 appearance 和判定差异；44–47 是 TH18 阴阳玉，48/49 未建立本作映射。不得统一替成 appearance 0，也不根据外观猜判定形状。
   使用ENGINE_VER31新表的 `TH18_*` 常量，附带所需词表定义，直接保留原作color；不套旧12形的换色表。出生半径直接取本型数据，列源值与目标值。当前沿用半径相加公式，未来算法选择不阻塞本次转写。新基础表不等于已有动态半径setter；出生减速和出生无判定按统一口径省略。
3. 按 609–612 的实际签名读参数，分开 id/index/async/type。短式不清 c/d/m/n；指定槽与追加槽的游标不同；SHOOT/LASER 保留相邻配对记录。SETSPRITE 会刷新默认半径，HITBOX/SIZE 的顺序不能交换。
4. 方向哨兵先分支解码，再转 BAM。ACCEL/STEP/VELTIME 的百万阈值、VEL 的 ±990、SHOOT/LASER 的高角上界不能混用；随机在配置、出生或效果进入时抽取的共享范围分别保留。
5. 带参 xform 按值绑定；`at_spawn` 保存出生值，`at_effect` 在进入操作时读当前状态。ENGINE_VER30 支持模板体 rand；STEP/WAIT_SIGNAL 停驻不重抽，LOOP 重入重抽。时长不是自动等待，`@N` 仍是字面量后置等待。
6. 普通 VELTIME 进入时固定方向，HOMING 每 tick 重读玩家；STEP 具有分段和子模式，不能直接换成一次补间。出生状态、SIZE/HITBOX、WAIT/DELAY 和同 tick 续跑的差异按 EX 条目处理。

不要套 TH06 的 x 减 192、粘滞难度前缀、半径近似或激光宽度除二规则。REACT 消费者、STEP d、完整激光消费等未解部分只在本攻击实际触及时上报；未解不等于无效果。原作随机序列和定点取整差异不自动降类，但主动量化、取中值、改共享范围须另说明。

## 产出

- `out/main.ecl`：可审查的目标源码，标出原文件/sub 与各段对应。外壳、无敌、开场缓冲和结束逻辑按任务单指定的本项目躲弹卡约定；时间平移写明。
- `out/meta.toml`：按[卡元数据](../validation.md#卡目录与元数据)填写，`source="th18"`，`source_ref` 写真实原文位置，rank、时限与源码一致。TH18 不套旧 3000 帧/1024 弹预算，不能为了验收截短或减路数。
- `out/report.md`：`status: done` 或 `blocked`；列原文位置→目标位置的映射、配置/效果取样时点、逐弹或配置共享范围、弹型/半径方案、全部近似与尚未解决的依赖。末尾给自检命令、实际输出及未验证项。

缺机制或关键语义不清时写 blocked，说明影响哪段行为及简单替代方案；不要自行接受新的省略或扩展引擎。仅涉及其他单元的共性问题可记到 `out/notes.md`。

## 自检与交接

使用任务单给出的当前 harness：

```bash
<harness> check out
<harness> run out --rank <目标rank> --frames <覆盖本段结束的帧数>
<harness> run out --rank <目标rank> --frames <F+10> --at <F>
```

先检查编译和运行诊断，再核本段结束及关键发弹/效果的数值。各目标 rank 运行一次，改动后只补受影响检查；选定锚点后最多 4 次 `--at`，避免用 dump 搜答案。日志留在任务目录，不能只写“通过”。

同步全部目标 `.ecl` 和元数据到任务单允许的 `card/<unit_id>/`，从训练仓执行：

```bash
uv run --frozen python -m stgtranscribe.validate <任务目录>/card/<unit_id> \
  --json <任务目录>/out/validate.json
```

完整自动验收须 `OK` 且未使用 `--skip-rl`，规则见[单卡验收](../validation.md#检查规则)。保留 JSON 和数值日志交独立 reviewer；修改后同步验证副本并重验。`status: done` 不代表已收卡、训练或原作等价认证。
