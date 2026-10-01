# 激光 token 与联合注意力实施计划

> 执行方式：本会话直接实现（superpowers:executing-plans）。用户已确认设计并要求立即写代码，不额外等待计划审批。

**目标：**实现v8特征、v3模型、图版本6导出及T6候选配置。
**设计：**[已确认的设计](../specs/2026-10-01-laser-token-joint-attention-design.md)。
**技术：**沿用PyTorch、stg_rl、ONNX，不新增依赖。

## 全局约束

- 在main工作，不创建worktree、提交、推送或启动训练Job。
- 旧12列和v7/v2运行语义保持；start_len采用独立RawObs字段。
- 固定形状、padding隔离、全空安全；支持旧torch2.5.1/tensordict0.6.2。
- 不更改卡池、reward、PPO、意图、课程或Top-K规则。
- 本轮只改训练仓；部署调用方适配和实际GPU验证明确列为未完成。

## 检查重点

- 大转角使用有限旋转，观测总转角不冒充未来角速度。
- 伸长棒和定长移动棒不能用当前长度替代start_len。
- 新字段与激光行严格对齐；缺失时v8报错。
- 联合层padding不得污染另一类型的有效token。
- 图版本6增加输入不改变旧版本签名。

## 任务

1. [x] `envwrap.py`追加`RawObs.laser_start_len`并解码；新增`danger_topk_v8.py`，注册并验证几何恢复、有限旋转、伸长和空集。
2. [x] 新增`set_attn_v3.py`，独立MLP+类型嵌入+共享一层SA+分类型池化，注册；验证跨类型依赖、padding、排列、梯度和空集。
3. [x] `export_onnx.py`增加v8导出孪生、图版本6独立输入、manifest、例子和CLI对拍；验证旧图和新图ORT一致。
4. [x] 添加T6配置和README说明，运行相关已有测试、旧CPU栈测试和小型PPO冒烟；记录实际命令和未验证项。

验收：以上行为检查通过，旧v7/v2仍可用；不以CPU冒烟或模型测试通过宣称训练收益或部署可用。

执行记录：4项已在训练仓完成；用户要求立即实现，未额外停在计划审批。实际证据见设计文档实施记录。旧CPU栈未安装ONNX/ORT，ONNX在本地锁定环境验证；部署调用方与GPU仍待后续。未提交／推送。
