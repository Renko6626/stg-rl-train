## 时停窗口不推进 boss 计时器（原作），我方 spell 计时照走

影响面：疑似同关 / 疑似全池（所有用 `ex_ins_call(4,1)` 的卡，Stage 5/6）

证据：`th06-decomp/src/EnemyManager.cpp:735` `if (g_GameManager.isTimeStopped == 0) { curEnemy->bossTimer.Tick(); }`
——`isTimeStopped` 期间 `bossTimer` 不 tick；而 `timer_callback_threshold`/`spellcard_start` 的时限用的就是
这个 `bossTimer`（对照表 §9）。对照 `BulletManager.cpp:668`、`Player.cpp:158` 同受 `isTimeStopped` 门控。
实测（本单元 th06_s5_b5）：一轮时停 120 帧，1800 帧时限内只跑约 4.3 轮；按有效帧 298/轮算原作应约 6 轮。

建议：改对照表 §10.1 —— 补一句「时停窗口不计入 spell `time_limit`；转写时 `TIME_LIMIT` 仍照
`unit.json`，逐帧编排不变，总轮数会少于原作」。
