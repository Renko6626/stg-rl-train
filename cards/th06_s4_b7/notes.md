## flags 同时含 0x1 与 0x40/0x80/0x100 时，出生冲刺被完全抹掉

影响面：疑似全池（任何 `bullet_effects` + `flags` 同时带 0x1 与 0x40/0x80/0x100 的弹）

证据：`/data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/BulletManager.cpp:710-770`
（`BULLET_STATE_FIRED` 的逐帧更新）：

```cpp
if (curBullet->exFlags & 1)      { ... sincosmul(&curBullet->velocity, angle, 5-t*5/16 + speed); }
else if (curBullet->exFlags & 0x10) ...
else if (curBullet->exFlags & 0x20) ...
if (curBullet->exFlags & 0x40) { ... bulletSpeed = speed - (...)*speed/interval; sincosmul(&velocity, angle, bulletSpeed); }
else if (curBullet->exFlags & 0x100) { ... }
else if (curBullet->exFlags & 0x80)  { ... }
```

`if (0x40/0x100/0x80)` 是独立 `if`（不是 `else if`），排在 0x1 之后，同帧无条件用自己算出的
`bulletSpeed` 再 `sincosmul` 一次速度向量；它读的 `curBullet->speed` 不含 0x1 的冲量 ⇒ 0x1 白写。
本单元 `flags 67 = 0x40|0x2|0x1` 实测：按 mapping §5 只写 0x40 的 `step_speed` 复刻，`--at 380`
的减速/转向/复速时序与原文一致；若按 §5 直译再加 `add_speed(5)` 会多出一段不存在的冲刺。

建议：改对照表 §5 —— 在 0x1 行注明「与 0x40/0x80/0x100 同时出现时被后者覆盖，勿叠加」。
