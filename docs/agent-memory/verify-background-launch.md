---
name: verify-background-launch
description: 后台起长任务后必须确认真正的 python 进程在跑，等待循环要同时盯「进程提前退出」
metadata:
  type: feedback
---

后台启动诊断 / 探针后，**用 `ps -eo pid,etime,pcpu,args | grep "[p]ython …"` 确认目标进程本身在跑**，不能只数 shell 个数；
等待循环要同时检测「结果文件出现」与「进程已退出但结果不全」两种终态。

**Why:** 2026-09-25 把 `THREADS=24` 写在 `taskset` 之后，taskset 当它是程序名立即失败；我只数到外层 shell 就报「在跑」，
用户白等 40 分钟。
**How to apply:** 环境变量写在 `taskset` / 命令**前面**；启动后 sleep 十几秒看进程与 CPU 占用；监视脚本覆盖失败路径。
