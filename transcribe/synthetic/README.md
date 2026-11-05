# 合成练习卡

与 [TH06](../th06/README.md)、[TH18](../th18/README.md) 同级的生产入口。任务从设计要求或已有底子卡开始；没有原作时不切分原作，不伪造source.txt或source_ref。

流程：设计brief → 作者生成 → 目标编译/运行 → 独立审核 → 必要返工 → 收入 `cards/synthetic/<id>/`。作者和审核者分开，沿用既有合成任务的模型安排，不因目录统一更换模型。当前仍由主会话准备和派发单任务，旧 `stgtranscribe.pipeline` 是TH06批量入口，不提供synthetic批量命令。

## 任务准备

任务放 `transcribe/work/synthetic/<id>/`，用 `brief.md` 写明练习目的、运动/发弹/激光要求、难度、时限、目标ECL工具路径和可写范围。需要底子时给可读卡路径与ID。作者交付 `out/main.ecl`、必要辅助ECL、`out/meta.toml`、简短 `out/report.md`；审核记录保留在自己的review目录。

- [作者契约](contracts/transcribe.md)
- [独立审核契约](contracts/review.md)
- [成品与metadata](../../cards/README.md)

从零合成标记 `source="synthetic"`、`generation_mode="standalone"`；底子变体保留 `base_card`，说明改动。题材用tags分类。已有laser_specialist卡保留其专用字段，普通新卡不必套激光专项schema。

## 运行检查

按任务要求用当前harness执行 `check <out目录>` 与 `run <out目录> --rank <rank> --frames <帧数>`，核编译、运行诊断、结束和关键设计行为。出现错误再修正并补相关检查；不要求每张卡穷尽种子或证明普遍可躲，不反复计算hash，也不加入冻结/签名门。

`stgtranscribe.validate` 当前只接受TH06/TH18编号，不能直接拿它验收一般synthetic卡。现有 `stgtrain.practice_validate`（底子overlay）与 `stgtrain.specialist_validate`（旧激光专项）是历史专用检查，按需使用，不能当作所有合成卡的必经标准。两者的 `--all` 已分别只选择启用的底子变体/激光专项，显式单卡路径可用于研究暂停卡。共用目标验收的后续抽取属于通用流水线实施。

完成审核后，将ECL、meta及必要卡说明放入 `cards/synthetic/<id>/`；过程报告不复制到成品目录。暂停使用只在meta写 `enabled=false`。收卡不代表已加入某个训练实验，实际选择由实验配置决定。
