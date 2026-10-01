# batch3 激光专项卡：制作与验收结果（2026-10-01）

本轮生成20张原创纯激光专项卡，五个家族各四布局，rank0..3。15个独立Luna作者任务制作，非作者Luna审查，返工按最终SHA闭环；峰值16个子代理同时运行。没有启动训练、提交或推送。

**20/20机器门通过；17张取得有限真实完成证据并通过独立源码/样本审查，作为实验候选；3张隔离。** 17张中12张train、5张held-out。候选不等于每档/每种子可躲已证明，更不代表训练收益。

| 家族 | 候选 | 隔离 |
|---|---:|---:|
| 错峰穿行 | 4 | 0 |
| 平移走廊 | 2 | 2 |
| 旋转扫场 | 3 | 1 |
| 逐组封位 | 4 | 0 |
| 短棒流场 | 4 | 0 |

## 产物与数据划分

- 候选：[cards-laser-specialist](../../cards-laser-specialist/README.md)。
- 隔离：[cards-laser-specialist-quarantine](../../cards-laser-specialist-quarantine/README.md)。
- [逐卡JSON汇总](reports/batch3/batch3-acceptance-summary.json)、[CSV](reports/batch3/batch3-acceptance.csv)、[当前文件清单](reports/batch3/final-current-manifest.json)。
- 五张04为held-out，加载器无论eval_ids如何均排除训练起点。批次未修改旧训练配置，默认和T2原有卡池不会自动扩入新目录；新held-out列表不能替代原作13卡旧划分。

## 验证与证据边界

机器矩阵：每卡全部rank0..3×seed1/7×1860帧，六项诊断唯一且全零，原始World逐帧稳定句柄出生/回收与几何、并发和空档检查，关键帧与harness对拍。新Rust追踪器与源码/编译锁/可执行SHA绑定，不修改引擎。机器工具、真实玩家检查器和补充cell控制器均有非作者独立审查。

真实玩家：每卡8条causal18f启发式与80条固定位置基线，CPU/1线程/frame_skip1，hit_extra=[2,2]，motor hold=[2,6]/delay=[0,2]/slow。当前角色高速4.5/低速2.0；初次导出半径2.5、后续实际压力半径4.5，逐帧记录实际按键/半径。固定点资格需实际到达、120连续静止帧及位置容差；出现成功样本不等于源码保证的通带。

corridor02仅补充可见几何cell控制器在rank0/1×seed1/7找到4条完成轨迹，rank2/3仍NOT_PROVEN。sweep01的18f完成轨迹仅rank3两个种子，rank0..2仍NOT_PROVEN。逐卡汇总明确列motion_witnessed_ranks与motion_not_proven_ranks，不将脚本支持rank范围混作通过轨迹范围。

隔离corridor01、corridor03、sweep02：18f、45f、90f因果观测策略均未完成已声明8局样本；两走廊另做可见cell控制器亦未完成。原因是缺成功避让证据，不是证明无解。源码与机器合格不自动纳入。

残余固定站位样本已记录：bars03有39/80资格站桩完成，两个指定位置各8/8；其他卡也有有限幸存站位。独立审查未发现修订版本的参数全域保证通带，但这并非全空间/全随机域穷举，后续有效暴露及学习检验仍需做。

最终轨迹保存在忽略的 `runs/laser-specialist-batch3-validation/`；大文件不入git。临时补充诊断source已逐字归档在 [tools/batch3_diagnostics](../../tools/batch3_diagnostics/README.md)。部分历史tmp轨迹可能被版本重跑覆盖，历史报告不替当前SHA验收。

## 生产发现与修复

明确关闭enemy体碰的NoBody API、phase开局即开始、实际段结束事件、joint真实玩家净空、直接瞄准线的非零偏角站桩漏洞、随机端点/角度单位、通道warn运动与active压力、整场边界和内部的源码永久通带，以及缺失的收缩/精确回收/1800快照均已通过作者修订和独立复审处理。旧卡只堵边角不够；量化slot间距后仍可有窄通带，最终使用受约束位置抖动闭合支持域。

held-out按布局预划分，制作和审查与训练布局分开。开发验收查看了各自真实轨迹；sweep04作者误用一次父目录--all看到兄弟标识/状态，held-out审查者看过一次批次汇总，这些范围披露在报告中。没有据held-out布局反馈调整训练卡；不宣称完全盲开发的未接触测试集。

## 软件验证

`.venv/bin/pytest -q`：490 passed、1 skipped，4条既有CPU无CUDA/tensordict警告；不是GPU验证。Rust fmt和相关功能测试通过，Python检查脚本编译通过，最终文件/报告SHA、held-out排除和本地链接另经核对。原作转写后端及其抽检流程未改。
