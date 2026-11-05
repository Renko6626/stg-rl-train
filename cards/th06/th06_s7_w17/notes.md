## unit.json 的 note 里小怪只数会少算

影响面：疑似同关（Stage 7 至少 w11、w17 都有）

证据：
- `th06_s7_w17/unit.json` note：「7693–8093 共 60 只」；但 `grep -c enemy_create source.txt` = **72**
  （左列 36 + 镜像 36，逐帧时间点核对一致）。
- `th06_s7_w11/unit.json` note：「每 15 帧两只、共 60 只」；`grep -c enemy_create th06_s7_w11/source.txt` = **72**。
- 对照 `th06_s7_w01` / `th06_s7_w16` note 与实际只数一致（72 / 11），说明不是「只」这个字另有含义。

建议：改摘录器 / 切分器——note 里的只数应直接数 timeline 段内的 `enemy_create*`，别用帧区间 × 间隔估算。
