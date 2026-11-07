# 卡库

成品按来源放置，训练、评测和预览共用 `stgtrain.cards` 加载器：

```text
cards/
  th06/<卡ID>/       东方红魔乡转写卡
  th18/<卡ID>/       东方虹龙洞转写卡
  synthetic/<卡ID>/ 合成变体与从零设计的练习卡
```

一张卡包含 `main.ecl`、必要的辅助 `.ecl` 与 `meta.toml`。生产资料与任务日志留在[transcribe](../transcribe/README.md)，不因训练用途再复制卡目录。源码路径改变，卡ID保持不变；评测清单仍按ID引用。

## 分类与选择

来源由 `source` 表示；题材用 `tags`，合成方式用 `generation_mode`，有底子时保留 `base_card`。现有专项卡的 `synthetic_kind`、`family` 继续使用。一般从零合成使用 `source="synthetic"`、`generation_mode="standalone"`，无需伪造原作引用或底子。

`enabled=false` 的卡默认不进入训练、评测或批量预览。要研究暂停卡，可显式读取单卡路径或在Python调用 `discover(path, include_disabled=True)`；不再建quarantine目录。`split="held-out"` 的从零合成卡排除训练起点；其他实验评测划分继续由 `eval/splits*.toml` 指定，已有变体的底子留出规则保留。

```toml
[env]
cards_dir = "cards"
card_filter = { sources = ["th06", "synthetic"] }
```

`card_filter` 可用 `sources`、`tags`、`ids`、`exclude_synthetic_kinds` 四个字符串列表；空列表不限制，tags为全部匹配。只选TH18可写 `sources=["th18"]`；指定tags/ids时须同步选择该卡集合适用的评测清单。旧T2–T4配置用 `exclude_synthetic_kinds=["laser_specialist"]` 保持只加30张变体的范围；T5及后续混合配置包括17张启用的专项卡。默认配置只加载TH06。

旧checkpoint中的已知 `cards` / `cards-synthetic` / `cards-laser-specialist` 配置由配置读取器转换，现行配置使用新路径与筛选项；没有旧路径软链。直接调用 `discover("cards")` 会发现全部启用卡，读取实验配置时应调用 `configured_cards(cfg["env"])`。`eval_ckpt --cards-dir` 显式覆盖目录时清空原筛选条件。

2026-11-05迁移时共216张：TH06 166张、合成50张，其中3张暂停；TH18尚无正式卡。旧卡ECL未修改，未启动训练。来源目录下面仍保留旧卡附带的TASK/machine-spec供追溯，它们不是新卡通用必填项。

2026-11-05随后完成三张TH18真实转写卡[th18_s1_b2](th18/th18_s1_b2/notes.md)、[th18_s1_b4](th18/th18_s1_b4/notes.md)与[th18_s2_b2](th18/th18_s2_b2/notes.md)，当时卡库合计219张。2026-11-06又完成二面第二符、三面首符和五面首符，TH18共6张，卡库合计222张；已有训练配置不变。

## 使用与出处

转写/生成结果收进本库后，可用于目标引擎预览、PPO训练和评测。训练输出checkpoint，再导出ONNX供游戏插件使用；游戏插件不直接加载这些卡来替换原作攻击。

原作转写卡只包含按原作数值重写的本引擎脚本与元数据，不包含原作程序、素材或ECL原文。TH06/TH18出处见各卡 `origin` / `source_ref`；原作版权归上海アリス幻樂団 / ZUN。合成变体如实保留底子来源，从零创作不伪称原作。
