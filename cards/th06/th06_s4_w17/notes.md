## mapping-excerpt 缺 §5，但 flags 低位需要它

影响面：疑似全池（任何 `bullet_*` 的 flags 含 0x1 出生冲刺的单元）

证据：
- `source.txt` Sub17 行：`bullet_offset_circle_aimed(...)` / `bullet_circle_aimed(...)` 的 `flags=5`（0x1|0x4），Sub11 为 `flags=4`。
- `grep -n '^## §5' /data/sunyunbo/www/stg-rl-train/transcribe/work/units/th06_s4_w17/mapping-excerpt.md` 无输出；对照表摘录只有 §4，但摘录 §4.2 自己写着「`1` = 出生冲刺（§5）」。
- 本单元 `used_instructions` 不含 `bullet_effects`，摘录生成按指令取节，于是 §5 被漏掉，而 flags 的 `0x1` 落点（`add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx();`）只在 §5。

建议：摘录生成把「`bullet_*` 出现」也视为需要 §5；或至少在 §4.2 的 flags 段落下补一句 xformdef 模板。只是提醒（本次已 grep 全文对照表 §5 取到正确写法）。
