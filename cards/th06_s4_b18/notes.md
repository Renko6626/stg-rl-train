## flags 0x1（出生冲刺）与任何 dirChange 位同用时无净效果

影响面：疑似全池（任何 `bullet_effects` + `flags` 里同时含 `0x1` 与 `0x40/0x80/0x100/0x400/0x800` 的单元）

证据：`renkolab/local/vendor/th06-decomp/src/BulletManager.cpp`。弹更新循环里，
`if (curBullet->exFlags & 1)`（:712）先算出带 5→0 冲刺的 `velocity`（:717）；紧接着**独立的**
`if (curBullet->exFlags & 0x40) … else if (curBullet->exFlags & 0x100)` 分支（:751 / :778）在本帧
**再次** `sincosmul(&curBullet->velocity, curBullet->angle, bulletSpeed)`（:776 / :803），用不含冲刺的
`bulletSpeed` 把 0x1 的贡献整个覆盖。所以 0x1 只有在不与其他 `exFlags` 位同用时才看得见。

实测（本单元 th06_s4_b18，`flags 257 = 0x100|0x1`）：`stg-harness run out --rank 2 --frames 200 --at 124`
首波首发 24 条速度为层速 `6.000 / 4.167 / 2.333`，没有 `+5` 的冲刺；我们的卡按「0x1 被覆盖」不建冲刺，
两档 `validate` 均 OK。

建议：改对照表 §5，在 `0x1` 行注明「与 `0x40/0x80/0x100/0x400/0x800` 同用时被后者每帧重算速度覆盖，
无净效果」。
