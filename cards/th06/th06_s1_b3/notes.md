## th06_s1_b3 的切分 note 仍写「整单元 skip」，但对照表已允许激光转写

影响面：疑似同关（所有 `laser_create_aimed` / `laser_create` 单元）

证据：
- `transcribe/work/split/s1/split.json:105-118` 的 th06_s1_b3 note：
  「Sub22 含 laser_create_aimed（并与 Sub23/24/25 互调）→ 整单元 skip」。
- `transcribe/th06/mapping-excerpt.md:28`：`laser_create_aimed | translate | §14`；
  `mapping.md:766` §14 标题「激光（2026-09-25 起可转）」。
- 实测：本卡按 §14 转写后 `validate` 通过（rank 0/1/2/3，段结束 1803）。

建议：只是提醒——若后续再由 split note 生成任务，含激光的单元会被误标 skip；以 mapping 表为准即可。
