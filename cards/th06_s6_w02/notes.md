## `enemy_flag_invisible` 的映射方向写反

影响面：疑似全池

证据：对照表 `transcribe/th06/mapping.md:784`（摘录 §8 同）写
`enemy_flag_invisible(0/1)` → `set_enemy_flag(ENEMY_NO_BODY, 1 − v)`，同一行注释却说「不可见的敌不参与体碰」，自相矛盾。
th06-decomp `src/EnemyManager.cpp:584`：

```cpp
if (curEnemy->flags.hasBeenInBounds != 0 && !curEnemy->flags.isInvisible)
{
    ...
    if (curEnemy->flags.isCollidable && curEnemy->flags.isInteractable) { ...体碰... }
```

即 `isInvisible=1` 才应禁用体碰；按 `1 − v` 算，v=1 时给出 0（反而允许体碰），方向相反。
命令复现：`grep -n "isInvisible" /data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/EnemyManager.cpp`。

建议：改对照表 §8 —— `enemy_flag_invisible(0/1)` 应映射为 `set_enemy_flag(ENEMY_NO_BODY, v)`（v=1 → 1），
并说明它同时屏蔽受击（decomp 该分支把体碰与受击一起 gate，本引擎无隐形位，只能用 NO_BODY 近似）。
