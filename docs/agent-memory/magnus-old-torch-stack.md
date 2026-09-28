---
name: magnus-old-torch-stack
description: "Magnus A100 jobs run torch 2.5.1+cu124 / tensordict 0.6.2 / Py3.11, not the repo's locked torch 2.14 / tensordict 0.14 — API differences only surface there"
metadata:
  node_type: memory
  type: project
  originSessionId: eeac6ecc-4642-439c-b86b-9a7d4042fb56
  modified: 2026-09-24T08:10:34.078Z
---

Magnus Job 用缓存镜像 `pytorch:2.5.1-cuda12.4-cudnn9-devel`（驱动 550 跑不了 CUDA 13），`magnus/bootstrap.sh`
装 tensordict 0.6.2；本地 / Vast 的 uv 环境是 torch 2.14 + tensordict 0.14。两边 API 有差：
0.6.2 的 `CudaGraphModule.__init__` 没有 `device` 参数——2026-09-24 Job 356819cb7a21700f 因此在 gpucheck 就挂了，
白等了约 1.5 小时排队。

**Why:** Magnus 排队时长不定（有时一两个小时，2026-09-24 晚的 phase_probe Job 提交即开跑、几分钟跑完），版本差导致的 TypeError 只在 Job 里才暴露，代价很高。
别预设要等很久：提交后过几分钟就用 `magnus job status <ID>` 看一眼。

**How to apply:** 改到 ppo / 录图 / tensordict / torch API 的代码，提交 Magnus 前先在旧版本 venv 里跑相关测试：
`uv venv -p 3.11 <scratch>/v062` + `uv pip install --extra-index-url https://download.pytorch.org/whl/cpu 'torch==2.5.1+cpu' 'tensordict==0.6.2' 'numpy<2.3' pytest matplotlib psutil nvidia-ml-py tensorboard magnus/wheels/*.whl`，
再 `PYTHONPATH=src <venv>/bin/python -m pytest -q tests/test_ppo.py ...`。本机没有可用 GPU，CUDA 图本身仍只能在 Magnus 验。
