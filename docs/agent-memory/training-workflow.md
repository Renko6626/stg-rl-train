# 租机与 Magnus 启动概况

这里只记入口和结果流向。实际参数以脚本、配置和当前资源为准；提交、推送、启动训练及终止任务分别按用户授权执行。资源与版本同步约定集中在 [AGENTS.md](../../AGENTS.md)。

## 租机／本地

```bash
bash run.sh configs/base.toml my-run
bash run.sh --resume runs/<运行目录>
```

`run.sh` 负责锁定依赖、训练、评测、出图和打包，结果留在 `runs/`。新机器可先用 `bash run.sh configs/base.toml --bench` 选吞吐参数，或用 `bash run.sh --probe` 做租机巡检；这两个入口仍会执行实际计算。

开跑前确认 cgroup 实际 CPU 配额与 GPU，再决定并行数和每条线程数；不要沿用旧租机的核数。后台启动后检查真实训练进程和日志，完成后取回结果包。入口详见 [README](../../README.md)。

## Magnus

1. 用 `magnus cluster` 查空闲资源；提交已获授权、已推送的固定 commit，显式使用 B2。
2. Job 入口通常为 `bash magnus/train.sh <配置> <运行名>`；同卡多条用 `magnus/train-multi.sh`，首次环境核验用 `magnus/smoke.sh`。
3. `magnus/bootstrap.sh` 安装仓内 wheel 和指定依赖，随后训练／评测；退出时尝试打包并交给 File Custody。
4. 提交几分钟后查状态，结束后从 Job Result 取 secret，用 `magnus receive <SECRET> --output <结果包>` 下载。历史协议记录有效期为 240 分钟，收到结果后及时取回；实际期限以服务返回为准。

Magnus 入口使用 Python 3.11、torch 2.5.1+cu124、tensordict 0.6.2；本地按 `uv.lock` 安装，不能直接在 Magnus 镜像运行根目录 `run.sh` 替代 bootstrap。需要编译器的路径使用 CUDA 12.4 **devel** 镜像。修改 PPO／相关 API 后先做对应旧 CPU 栈检查，CUDA 图再在真实 GPU 核验。

脚本会尝试交回已有结果，但手动终止可能先删除工作区，不能保证救回 checkpoint；需要保留时先让训练按计划自行停止并取回结果。具体提交参数、旧 CPU 栈准备和 wheel 来源见 [Magnus 说明](../magnus-migration.md)。
