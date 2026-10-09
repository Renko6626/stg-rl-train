# B：请求动作惩罚训练（8根激光）

日期：2026-10-03。用户要求直接实现并提交B任务；基线为T7的8根激光。

## 处理与预算

配置：[exp-request-reward-k8.toml](../../configs/exp-request-reward-k8.toml)。展开配置与T7唯一差异为`reward.action_source: executed → request`。模型输入仍player15维，danger_topk_v8/set_attn_v3、graph6不变。现有key_press=-0.003、quick_change=-0.01移到运动层过滤前的原始请求，shift_toggle仍0。请求快照只供reward；其他奖励、实际执行、运动层、意图、课程和卡池保持原路线。

从随机初始化训练，seed1，4096env×64steps×3500updates＝917,504,000真实环境帧，bf16。每250轮保存／原13卡Hard-Lunatic评测，结束后沿用部署／自由／锚点／motor-off和专项留出探针。本轮只提交B，未重跑同期A；历史T7对照不能单独支持严格因果或稳定收益结论。

## 验证

- 本地相关reward/motor/envwrap/config/episodes：73 passed。
- 现有激光模型CPU训练→评测→checkpoint→部署包装冒烟：3 passed（原两臂＋request新臂）。
- v8真实torch/包装/ORT导出对拍：2 passed。
- 旧torch2.5.1+cpu/tensordict0.6.2的请求用例与冒烟：7 passed、61 deselected。
- 独立只读审查未发现实质性问题；完整命令见[方案实施记录](../superpowers/specs/2026-10-03-request-reward-b-design.md)。

## 提交与来源

Job [e1438561397ddfdb](http://162.105.151.134:3011/jobs/e1438561397ddfdb)，提交UTC时间`2026-10-03T10:37:29.138230+00:00`，B2、1×A100、32核、64G、20G临时盘。提交前实际空闲5张GPU／92核。容器为既有torch2.5.1-cu124-devel，使用`GPUCHECK=1`的train-specialist入口；GPU对拍失败即退出并保存已有产物。

没有git提交／推送授权：使用固定远端main基底`4a3bc4a35ca57d4fd114cca227206fed658a84a0`，以Magnus现有File Custody传送四文件源码覆盖包。归档SHA256：`745b4dc08c91a2a4b4ab7dc7a945fb953dd6e9b35bea7be3aec2157af170161e`。本机上传后下载对拍通过；Job日志已确认归档和四文件SHA通过。SHA清单与source-overlay.json保存在Job结果根目录，不把base commit误称为已包含本轮修改。

| 覆盖文件 | SHA256 |
|---|---|
| `src/stgtrain/config.py` | `dbf7056692abee5bb4c115c6dff4cdc31639dbfd9cc0977770fba2e7c96be932` |
| `src/stgtrain/envwrap.py` | `8a9015258eb751c390c16ec10dd10e000b85308e17533c37cb7f97e0207c33c3` |
| `src/stgtrain/reward.py` | `0bff1e7e6a58b6f930b93de972d89b30ac636750717e0eec7af7f6f3136aa65f` |
| `configs/exp-request-reward-k8.toml` | `d560e94cf023c86de30f6a842a42ce3c5a152177f40a877eeb5db494d40429ba` |

## 运行与取回

首次及提交几分钟后查询均为Running；源码归档／四文件SHA通过，bootstrap确认torch2.5.1+cu124、tensordict0.6.2、stg_rl0.4.1，已进入GPUCHECK。此状态不等于正式训练已开始或GPU对拍已通过。后续状态继续核验。

复用既有监视器，路径`runs/request-reward-monitor/`，Python PID4191974。监视Success或提前退出，及时取回240分钟File Custody结果，核验u3500／原作最终评测及8份专项JSON。来源与提交参数在`runs/request-reward-submit/`。PID只为启动记录；后台监视依赖本机存活。未操作游戏UI，未替换现有部署包。

## 用户中止后重开（2026-10-04）

用户说明服务器需让朋友使用，已关闭旧任务，并明确要求再开一次。API核验旧Job `e1438561397ddfdb`为Terminated；旧日志有GPUCHECK PASS和正式训练启动，不能将中途终止记为完整3500轮结果。

新Job [3c0392a2052fb68e](http://162.105.151.134:3011/jobs/3c0392a2052fb68e)，提交UTC时间`2026-10-04T12:37:03.597051+00:00`。同一base commit与同一源码覆盖包，SHA256仍为`745b4dc08c91a2a4b4ab7dc7a945fb953dd6e9b35bea7be3aec2157af170161e`，刷新File Custody领取码；配置、seed1、从头3500轮、GPUCHECK闸门与最终探针保持原处理。未改训练代码，未重复CPU测试。

提交前Magnus实际空闲5张A100／100核，申请仍B2、1×A100、32核、64G、20G临时盘。新监视路径`runs/request-reward-retry1-monitor/`，启动时Python PID240794，已核验实际Python进程和Running日志；Paused视为可恢复状态而继续等待，不误当最终退出。提交材料保存在`runs/request-reward-retry1-submit/`，与旧任务分开；未git提交／推送。

提交约两分钟后复查仍为Running；原归档和四文件SHA均通过，torch2.5.1+cu124／tensordict0.6.2／stg_rl0.4.1依赖已装好，进入GPUCHECK。正式训练启动和本次GPUCHECK最终结果尚待后续核验。

## 完成结果（2026-10-05）

重开Job已Success，GPUCHECK PASS，完整3500轮，best/latest均u3500；原作最终评测与8份专项JSON齐全，结果包已下载／校验。监视器在下载后的SHA记录阶段遇到Python3.10缺hashlib.file_digest，已补齐并修复，数据没有丢失。

相对历史T7，末四次普通91.88→88.16%、原作激光90.36→73.44%、专项42.85→35.59%；关运动层变向14.78→3.54次/秒，短移动段76.09→18.58%。平滑信号强，生存有代价，水符退步最明显。完整统计和口径见[结果分析](2026-10-05-request-reward-results.md)。未启动新训练或替换部署包。
