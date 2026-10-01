# T5：激光专项卡混合训练

2026-10-01：用户要求准备提交一次实验，并选择「混合训练，检验迁移收益」。用户随后明确授权「提交和推送，然后直接开始训练」。当前进入提交与启动阶段，Job状态以之后的实查记录为准。

## 实验处理

以 T2 配置为基线，从随机初始化训练一次，seed=1；在原作与30张混合合成卡之外，加入12张原创激光专项训练候选。5张专项留出只用于评测，3张NOT_PROVEN隔离卡不加载。加载器的held-out排除规则生效，不修改卡片或原作划分。

配置：[exp-t5-laser-specialist.toml](../../configs/exp-t5-laser-specialist.toml)。模型、观测、reward、运动层、意图混合和课程参数取T2；不采用T3按卡意图覆盖或T4组内归一化。已记录的编码器修改留待后续。

- 4096 env × 64 steps × 3500 updates = **917,504,000 环境帧**。
- 213张加载卡、195个rank2训练起点，其中12个专项起点；专项起点初始均匀份额12/195≈6.15%。课程改变实际概率，短局死亡也会影响帧份额；不能把起点比例称为有效练习帧占比。
- 与规范化T2配置只差`env.cards_dir`和`run.ckpt_every`；保存间隔100→250，以保留u2750/3000/3250/3500的模型，不改变更新算法与预算。
- 保留`env.json`的来源/起点映射和`curriculum.jsonl`，可复查完成局数与权重。现有入口不记录逐卡实际环境帧，不能据此宣称已实测有效暴露帧份额。

## 评测和判读

训练过程中仍使用原[13卡划分](../../eval/splits-laser.toml)，保持原有best选择口径。比较末四次固定评测均值和完整曲线，分开报告原10张普通卡、3张原作激光卡，逐卡和rank2/3均保留。

[专项留出划分](../../eval/splits-laser-specialist.toml)为五个家族的04布局，每卡rank0..3、每组32局。由[独立评测入口](../../tools/eval_specialist_checkpoints.py)在训练后评测末四个checkpoint；best另测自由、锚点、boss_or_free16意图。该评测不回写模型、不重新选best。原13卡best的四项历史探针继续由Magnus入口运行。

这是单臂、单训练种子的迁移试验。可与T2历史结果作描述性比较，但没有同批同版本控制臂；不能将变化全归因于专项内容，也不能作多种子显著性判断。原作`s4_b12`已用于开发讨论，不再视为完全未参与设计的测试内容。

专项候选仅有有限成功轨迹证据；corridor02未在rank2/3取得完成证据，sweep01仅在rank3取得完成证据。训练采样rank2仍包含这两张候选，结果应逐家族/逐卡检查，不能预先断言全部随机实例可解。

## 提交和结果保存

入口：[magnus/train-specialist.sh](../../magnus/train-specialist.sh)。沿用正式训练、历史探针和EXIT打包机制，专项评测在最终上传前完成；缺checkpoint或专项评测失败会返回非零，已有产物仍由EXIT trap打包。原有历史探针的失败处理沿用原入口，会记录日志但不使训练失败。沿用的File Custody保留期为240分钟，需在完成后及时取回；未新增定期上传或持久挂载保证。

提交前重新查询`magnus cluster`。本次查询空闲6张A100、108核、约484GiB内存，足够申请1张A100、32核、64G，优先级显式B2；该读数只表示本次查询时状态。

使用推送后的完整SHA提交，禁止把当前HEAD当作包含未提交专项卡的快照：

```bash
magnus job submit \
  --task-name stg-rl-train-t5-specialist \
  --namespace Renko6626 --repo-name stg-rl-train \
  --branch main --commit-sha 889a9d343af45ab4f5b30ee157ee40820fc0dea3 \
  --gpu-type a100 --gpu-count 1 --cpu-count 32 --memory-demand 64G \
  --ephemeral-storage 20G --job-type B2 \
  --container-image docker://pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel \
  --entry-command 'bash magnus/train-specialist.sh configs/exp-t5-laser-specialist.toml t5-specialist'
```

提交后几分钟检查状态和日志，区分排队、安装、实际训练与提前退出；完成后立即取回结果并核验3500updates、checkpoint、原作评测、专项评测和课程记录。

## 提交前验证

冻结清单20张（包括隔离卡）和20张验收报告的来源审查/机器/玩家报告SHA均匹配；候选目录编译213张，正式划分下训练起点195，五张held-out均不在训练起点内。卡池/意图/课程/模型相关测试本地59 passed、1 skipped。

旧torch CPU栈（torch2.5.1+cpu / tensordict0.6.2）同组测试为59 passed、1 skipped。正式卡池与原13卡划分的CPU冒烟完成1次PPO更新、26个卡/rank组评测及u1/latest/best checkpoint保存，产物为`runs/t5-preflight/20261001-123512-t5-full-split-smoke/`。冒烟使用32env、每组1局、300帧上限，关闭compile/CUDA图/AMP，不能用于衡量学习收益。

随后旧torch栈运行专项评测脚本，五张held-out×rank0..3×每组1局，在u1和best跟点、best自由/锚点/boss_or_free16共生成5份逐局JSON。脚本入口、卡池隔离和模型加载已验证；本次不是正式32局/完整时长评测，实际CUDA图仍需GPU验证。shell语法、Python编译、wheel SHA和diff空白检查通过。

## 2026-10-01 启动记录

用户明确授权提交、推送和直接训练。训练快照`889a9d343af45ab4f5b30ee157ee40820fc0dea3`已推送到origin/main；Job [`4aba4850f7ba4dff`](http://162.105.151.134:3011/jobs/4aba4850f7ba4dff) 于12:45北京时间提交，B2，1×A100、32核、64G。日志确认A100 80GB、Python3.11.10/torch2.5.1+cu124/CUDA12.4和项目wheel校验通过。12:48:36训练入口输出正式CUDA训练开始，实际213张卡、195个训练起点、26个原作卡/rank评测组，4096env，目标u1→3500。

提交前全仓测试490 passed、1 skipped；独立T5入口审查无阻塞问题。主机后台取回器在`runs/t5-monitor/`运行，每60秒查询状态，终态时尝试立即取回结果到`runs/job-4aba4850f7ba4dff.tar.gz`，检查u3500、最终评测和8份专项JSON。取回器已通过进程及日志确认在运行；这不是平台持久调度保证，若本机会话环境被关闭仍需人工复查。
