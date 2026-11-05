## enemy_create 的子敌不继承父敌的 shoot_offset

影响面：疑似全池

证据：`EnemyManager.cpp:104` 子敌生成为 `*newEnemy = this->enemyTemplate;`，而模板在
`EnemyManager.cpp:68` 明确 `enemy->shootOffset = D3DXVECTOR3(0.0f, 0.0f, 0.0f);`。
本单元 Sub36 先 `shoot_offset(0,-12,0)`（:885），再 `enemy_create` 出 Sub38–41；
Sub38–41 自己从不调 `shoot_offset`，故它们的出弹口是 `(0,0)` 而不是父敌的 `(0,-12)`。
对照表 §4.1 只说 `shoot_offset` 在「这只敌」身上粘滞，§6.1 没讲新建子敌是否继承。

建议：改对照表 §6.1，加一句「子敌用模板重置，`shoot_offset`/`bulletProps` 不继承父敌」。
