## flags 同时置 0x1 与 0x40/0x80/0x100 时，0x1 出生冲刺被覆盖

影响面：疑似同关（Stage 4 多张符卡 flags 含 `0x40|0x2|0x1`，如 b5/b6/b7/b8/b9/b16；凡 flags 同时
带 0x1 与 0x40/0x80/0x100 的单元都可能撞）

证据：`/data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/BulletManager.cpp`
- `:712-717` `if (curBullet->exFlags & 1)`：只把「冲刺速度」写进局部 `bulletSpeed` 并 `sincosmul`
  出 velocity，**不改 `curBullet->speed`**；
- `:751-776` `if (curBullet->exFlags & 0x40)`（0x80/0x100 同构）：随后用 `curBullet->speed` 与
  `curBullet->angle` **重算同一颗弹的 velocity**；
- 两条是顺序执行的独立 `if`（不是 else-if），后者每帧覆盖前者 ⇒ 0x1 的冲刺在本帧不可见。

复现：读上述两段（`sed -n '710,780p' …/BulletManager.cpp`）即可看到两次 `sincosmul(&curBullet->velocity, …)`。

建议：mapping §5 补一句组合规则——「0x1 与 0x40/0x80/0x100 同时置位时，0x1 的冲刺速度会被后者的
速度重算覆盖，不要把冲刺叠加进去」。（0x1 与 0x10 是 else-if 关系，mapping 现有的 `@(D−16)` 合并
写法没问题，别一起改。）
