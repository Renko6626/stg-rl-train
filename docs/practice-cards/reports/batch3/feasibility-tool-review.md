# 激光专项卡可行性工具独立审查

审查结论：**REVISE**。工具确实用真实 `EnvWrapper` 执行动作，并在首次非零 `done` 后停下；检查器只看当前观测，不读 ECL 或未来随机脚本。当前核心风险是路径评分重复扩张激光判定宽度；固定点基线和 rank 报告还有两项证据/字段问题。本文不评估任何 batch3 卡片的可解性。

## 审查快照

依据专项契约 v1 与 dispatch prompt；审查期间代码及文档只读。SHA256：

- `src/stgtrain/specialist_feasibility.py`: `ac3f7ff8c56f9957fc9077b413a72fefa7939271d449957da8d87dab606d1b7e`
- `tests/test_specialist_feasibility.py`: `45c3bc6ad66910fe9bd97f4646c79b970d0f7effe085ba036ac3dc52a5c1df75`
- 作者说明 `docs/practice-cards/reports/batch3/feasibility-author.md`: `286201e014b7b59948430bdcd08feb62343a533dd0d5cf87cec5e5de6b3584e2`
- 冻结契约 `docs/practice-cards/laser-specialist-contract.md`（写报告时观察）: `d385e87e44931a2e4d608014952d4349f281404b1f47e91ed0a5936224faa987`
- 派发 prompt `docs/practice-cards/laser-specialist-dispatch-prompts.md`: `7fa71abcb5d5d67e4d920bc07e1ccac0a00b5c76e3bcd8e37661dd9606eb119c`

作者说明文件是工具使用说明，没有附任何 batch3 可行性 JSON 或逐卡报告 SHA。因此这次能审实现和报告生成逻辑，不能核对真实卡片的 report/card snapshot 是否一致。

## 发现

### F1 — 高：激光半宽被重复计入避碰距离

- 位置：`src/stgtrain/specialist_feasibility.py:59-69, 101-103`
- 证据：`point_to_laser_sq()` 把玩家点投影到包含 `half_h` 的旋转矩形，返回到矩形的欧氏距离。随后 `score_path_clearance()` 又从该距离扣 `row[half_h]`，等价于把矩形半宽再外扩一次。一个玩家点位于激光端点外、离矩形 3px，玩家半径 2px、激光半宽 4px 时，真实净空应为 1px，当前评分为 -3px。
- 违反/影响：动作选择把可碰撞区估得比引擎判定更宽，可能偏向远离并发激光的路径，或错判启发式失败；因此可行性结果对声明的真实判定几何不准确。
- 最小修正：保留矩形距离计算，净空只减实际玩家 hit radius；若改用线段中心线距离，才同时扣 hit radius 与 laser half-width。补测矩形侧边/端点的正、零、负净空，并与引擎碰撞几何一致。
- 重验：路径评分单测、`choose_action` 选择回归；再用真实引擎短轨迹核对边缘案例。

### F2 — 中：固定点基线记了到达，没证明到达后站住

- 位置：`src/stgtrain/specialist_feasibility.py:219-224, 229-249`；说明文件 `feasibility-author.md:19`
- 证据：距离目标不超过 4px 时设置 `target_reached_step`，此后只请求 action 0。`EnvWrapper` 的方向与 slow 通道分别受 `hold=[2,6]`、`delay=[0,2]` 随机状态机约束，因而请求停止后仍可能继续执行旧方向或旧 slow 位。轨迹有 `want/buttons/x/y`，但报告没有目标停留时长、位置漂移或 `stationary_pass` 字段。
- 违反/影响：契约要求固定点站桩检查，并要求记录站桩结果；目标到达不能代替已在该点站住。该实现不能支持“到达并站住”的结论。现有结果尚未声称通过固定点基线，所以这是证据门缺口，不是已观测到卡片失败。
- 最小修正：到达后继续记录实际位置与按钮，定义并输出目标容差、连续停留帧数、最大漂移及通过布尔值；若在 episode 结束前未满足停留条件则标记未通过/未证明。或者将该模式明确称为到达后请求停止的轨迹，不作为站桩基线。
- 重验：用 motor 开启的真实引擎轨迹覆盖到达目标后方向/slow 尚在 hold 或 delay 的情况，并验证报告只在满足停留标准时记通过。

### F3 — 低：`declared_ranks` 将闭区间误报为端点集合

- 位置：`src/stgtrain/specialist_feasibility.py:173-179, 276-292, 305-315`
- 证据：专项契约规定 `ranks=[0,3]`；`cards.allowed_ranks()` 将其作为含端点闭区间（`cards.py:139-142`）。当前 `_card_ranks()` 做成员测试，结果是 `[0,3]`，并写入 JSON 的 `declared_ranks`。实际运行循环不使用这个字段过滤：命令显式 `--ranks 0 1 2 3` 时确实执行四档，`config.ranks` 会记录四档。
- 违反/影响：覆盖执行正确，但报告声明会让读者误以为卡片只声明 Easy 和 Lunatic 两档，或怀疑 Normal/Hard 是越界运行；自动化消费者也可能按错误的离散集合解释它。
- 最小修正：对专项元数据按 `[lo, hi]` 展开成闭区间；再校验所请求的 ranks 与声明区间一致，或在报告中分别写明区间和本次实际运行矩阵。
- 重验：`ranks=[0,3]` 应报告支持档 `[0,1,2,3]`；测试实际 runs 覆盖 `--ranks 0 1 2 3`，并验证越界请求有明确处理。

## 已核对行为与边界

- **首次 done / 自动 reset：通过源码核对。** `EnvWrapper.step()` 给出的 `info.done` 来自刚结束那局，但 `nxt` 的缓冲观测可能已经是自动 reset 后的新局。`_trial()` 先记录这一步的 done 和 pre-step 位置，然后立即 break；terminal 时将 `end_xy` 置空，并保留 `ep_frames`，不会把 reset 后观测拼进本局。`done=2/1/3` 分别映为 `SUCCESS/DEATH/TIMEOUT`，与 engine episode 语义一致。
- **动作映射/边界/判定设置：通过当前 harness 范围核对。** 18 个动作按 `direction*2+slow`，方向顺序与 `actions.py` 一致，y 向下为正；对角线乘 `sqrt(0.5)`。观察字段给出固定角色高速 4.5 与 focus 位；项目引擎角色表低速为 2.0，因此当前 4.5/2.0 换算适用于此 harness。`hit_extra=[2,2]` 通过 `EnvWrapper.reset()` 下发，`player_hit_r` 是引擎解码的实际半径；帧轨迹本身没有逐帧存这两个状态，配置里有其设定值。
- **当前观测约束：通过。** `choose_action()` 仅接收当前 `RawObs` 可见激光、玩家状态和 motor 计数；预测窗口为 18 帧，未读取脚本、未来 RNG 或未出生激光。随机运动层在真实 step 中生效，但窗口外的 motor 抽样、未来出生和速度变化只在说明里作为限制，而非被假称已预测。
- **速度/运动约束的性质：启发式近似。** 对速度按当前焦点反推另一档是该固定角色的正确数值；不过 action 评分对方向与 slow 改变共用一个 `change_wait`，不模拟两个独立 motor 通道各自的 held/delay 隐状态。随机抽样不模拟已在作者报告披露，所以不能把预测轨迹当作 motor-aware 的逐帧证明；真实选定动作仍由 EnvWrapper 执行。此限度不单独阻断原型用途。
- **种子与重放：当前 harness 可复现。** `seed` 传入 `EnvWrapper/VecEnv`，motor 用该 seed 的确定性计数器流，命中半径和 intent 使用确定性 seed 初始化。用安全 fixture `example_laser`、rank 0、seed 7、80 帧，在两套不同临时输出目录复跑，均为 done=3 / 80帧，trajectory SHA 均为 `fa526794cfead48642bab2012ce606f1b1fc9c4bf8115ef14a26be6abc9cefca`。JSON report SHA 因其中包含绝对 report/trajectory 路径而不同；这是路径相关报告内容，不是轨迹不确定。seed 1/7 的批次实例本审查没有运行。
- **测试：** `.venv/bin/pytest -q tests/test_specialist_feasibility.py`，6 passed。现有测试覆盖几何距离、速度/角速度/长度推进、警告倒计时、done 标签和真实引擎帧限，但没有覆盖 hit radius + laser width 的组合净空、motor 后的站桩停留或 `[0,3]` rank 区间语义；正是上述问题目前漏出的边界。
- **不可推导的结论：** 启发式单例成功、单点站桩或源码几何不证明所有随机实例可解，也不证明训练收益。工具报告若无逐卡机器/可行性快照，就不能使任何卡通过正式纳入门。

## Round 1 定向复审（2026-10-01）

结论：**PASS（仅限 F1/F2/F3 修复后的工具实现）**。未读取或判断任何 batch3 正式卡片，也没有验证全随机范围的可行性。以下新快照取代上文针对旧实现的三个 revise 发现；原始首次审查保留作审计记录。

审查绑定：

- `src/stgtrain/specialist_feasibility.py`: `02afa09a64d91a94eecee9b61d7deeb28aac81e4d489d713accb58622cd60681`
- `tests/test_specialist_feasibility.py`: `0dfbffb1b00f1fb3baa76eeccc18f3e25228f31ba1309bec4eaf7ef21b7f4386`
- 作者说明 `docs/practice-cards/reports/batch3/feasibility-author.md`: `550a6584fdb3ca288368a3b63c8275cd9d95d36bccdb51102dc715bcea5ba30c`
- 当前执行澄清契约 `docs/practice-cards/laser-specialist-contract.md`: `3002dd8851028331a275e305097e4a527bb47b16b193e5d1a7c4f961ab910dfe`

F1 净空现在计算为“点到已含完整 `half_h` 的矩形距离减玩家 hit radius”；测试分别覆盖矩形侧边和端点外的正、零、负净空，没有二次扣除半宽。F3 将 `[lo, hi]` 展开为闭区间，显式 rank 会检查范围并拒绝越界或卡片未声明的档位；默认 rank 取卡片完整声明档位。

F2 对站桩的判定记录实际 `buttons` 解出的方向，要求实际方向连续为零至少 120 帧；同时输出目标容差、静止半径、连续帧数、静止漂移、到目标漂移及 `QUALIFIED` / `NOT_REACHED` / `TARGET_NOT_PROVEN` / `NOT_PROVEN` 状态。到达后实际方向仍不为零会重置连续静止窗口。首个 `done` 后停止，终局帧位置仍置空；轨迹末行保留终局标记，不把自动 reset 后的新局观察纳入本局。

证据与边界：

- `.venv/bin/pytest -q tests/test_specialist_feasibility.py`: **16 passed**。新增用例覆盖矩形净空、rank 闭区间与拒绝路径，以及真实 EnvWrapper motor 开启下的 120 帧站桩资格。
- 基线 smoke `/tmp/sunyunbo/stg-laser-batch3/review-calm-baseline/example_calm.json` SHA `ed340acc251c11f13128d3576440c6b639ddceb19ba4052549bee34451e3e21b`，索引 SHA `8732ea7c56ad45de9df25c6fc0f6c63dde643bd02e09f781428716f074d188a0`。报告绑定当前工具 SHA。11 条运行均在 `done=2`, `steps=ep_frames=293` 结束；JSON 的 report SHA 与 index 一致，11 条轨迹文件 SHA 均与各自 JSONL 内容一致，且最后一行均带相同终局 `done`。出生点、中下、左下、右下、左上/右上目标及四个场角都有结果：出生点、中下、左下、右下、底边左右角共 6 条为 `QUALIFIED`；左上/右上与顶边左右角共 4 条为 `NOT_PROVEN`，各自只有 104、89、48、37 个静止帧就遇到 fixture 的 `done=2`，报告没有误记为通过。四角目标使用真实边界坐标 `(-192,0)`, `(192,0)`, `(-192,448)`, `(192,448)`；该 smoke 只证明这些离散目标与短 fixture 的状态路径，不证明整条边或正式卡片的永久安全带。
- 作者给的旧 rank smoke `review-rank-range/reports/example_range.json` 使用 tool SHA `0cf97f4f...`，与本轮当前模块不匹配，因此不作为本轮快照证据。我用当前模块对只含测试 fixture 的 `example_range` 重跑 rank `0..3`, seed `7`, 80 帧。新报告 SHA `73bba10d5270308421e7c8e58599c18ef695e8a5b4964157dce7250762d18d87`，index SHA `01141a92b9f2c82da427493dbe5635b29c19c572beaf1e697900c0f62520394f`；tool SHA 与当前模块一致，`declared_ranks` 与实际 `config.ranks` 均为 `[0,1,2,3]`，四条均 `done=3`, `steps=ep_frames=80`。报告 SHA 与 index 一致，4 条轨迹文件哈希和末行 `done` 均匹配。
- 卡片几何 smoke 和 baseline 使用的是安全测试 fixture；rank 的 80 帧 smoke 只确认 rank 矩阵被执行和报告范围一致，不是 1860 帧卡验收。没有在此复审中启动 batch3 可行性批跑；尚无据此证明全随机实例可解或训练收益的结论。
