## 对照表未记录 TH06 弹池 640，密集波次每单元都要自拟合

影响面：疑似同关 / 疑似全池（所有会打满屏的密集波次）

证据：
- `grep -n "640" transcribe/th06/mapping.md` → 无结果；mapping §4.2 只讲弹型/速度/角度，未提弹池上限。
- TH06 源码：`th06-decomp/src/BulletManager.hpp:125` `Bullet bullets[640];`；`BulletManager.cpp:534-556`
  `SpawnBulletPattern` 逐颗 `SpawnSingleBullet`，任一失败即 `goto out` 中止整发。
- 实测：本单元 `th06_s5_w05` Lunatic 忠实转写弹峰值 **1223 > 1024**，`stgtranscribe.validate` 报
  `✘ rank 3: 弹峰值 1223 > 1024`；同关 `th06_s5_w10`（峰值 1235/1178）、`th06_s3_w06`（1211）报告里
  各自写了同一条 640 等效截止，但都只落在 report.md，未回流对照表。

建议：改对照表 §4.2（或新增一节「TH06 弹池 640」），写明：TH06 池 640、池满整发中止；本引擎池 8192 /
观测 1024，转写密集波次时需按 640 拟合截发并在 report.md 记明。可附一条统一口径，避免每个单元各自发挥。
