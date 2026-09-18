## unit.json 的 note 对 ex_ins_0 仍写「整单元 skip」，与 mapping §10.2 矛盾

影响面：疑似同池（凡 `used_instructions` 含 `ex_ins_call` 的单元）

证据：
- `transcribe/work/units/th06_s2_b5/unit.json:27`：`Sub38 含 ex_ins_call(0,0)/(0,1)（全场弹停住变白/随机加速）→ 机械判定 ex_ins_0，整单元 skip。`
- `transcribe/th06/mapping.md:837`：`| 0 | CirnoRainbowBallJank… | **translate** | 见 §10.2（2026-09-19 由 skip-unit 改判）|`；
  `mapping-excerpt.md` 顶部表 `ex_ins_call | translate | §10` 且含 §10.2 写法。

建议：改切分器/摘录器重新生成 unit.json 的 note（至少对 `ex_ins_call` 不要写死 skip），
或提醒 worker 一律以 `mapping-excerpt.md` 为准。只是提醒——本单元按 §10.2 翻成了 translate。
