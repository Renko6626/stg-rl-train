---
name: prefer-real-mechanics-over-shaping
description: 用户的研究取向——少喂构造信息、少用 reward 塑形；要改行为就改环境 / 引擎的真实机制
metadata:
  type: feedback
---

用户倾向 bitter lesson：**不往观测里塞我们构造的几何量**（d/t、动作危险度这类放到最后），
**也不用固定罚款式的 reward 塑形去替代真实后果**（09-25 否决了 near_miss 余量惩罚：固定小额罚款可被「付费」换取、
且余量 4 px 是我们替它定的偏好）。要教模型某件事，优先**改环境本身**——让引擎真判（判定点随机增大：
引擎按放大的判定真判死，stg_rl 0.4.0 的 set_hit_radius_extra）。需要时**直接去 stg-engine 加接口**，别在训练包装层绕。

**Why:** Q1/Q2 证明「按目标点构造的 token」一直在拖后腿（拿掉就 +9/+19pp）；用户据此定了方向。
**How to apply:** 提实验方案时先问「这是在改环境 / 结构，还是在喂答案 / 定偏好」；后者要先说明理由并征求同意。
改引擎前读 stg-engine 适用的 AGENTS.md，以及尚未迁移的 CLAUDE.md（P4 坏参数 no-op + 计数、写 API 钳制、ENGINE_VER bump 过评审、golden 校验和对拍）。
