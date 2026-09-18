## TH06 640 发弹池压画面，对照表/契约未提，密集卡照抄必超 1024

影响面：疑似全池（TH06 弹幕密集的符卡 / 波次）

证据：
- `renkolab/local/vendor/th06-decomp/src/BulletManager.hpp:125`：`Bullet bullets[640];`；
  池满时 `SpawnBulletPattern` 从失败那颗起整批放弃（`BulletManager.cpp:540-548`）。
- 本单元（th06_s6_b6）L 波 3/4 原作 32 颗鳞弹，照抄后
  `stg-harness run out --rank 3` 弹峰 **1394**，`validate` 报 `弹峰值 1394 > 1024` 直接 FAIL；
  H 档 12 颗也有 722。折到 L=18 后弹峰 926 才过。
- 同型先例：`transcribe/work/units/th06_s3_w12/feedback.md` 主会话已按 640 池裁定过等效截止。

建议：改对照表 §4/§5 或契约，写清「TH06 弹池 640 会压住密集卡的画面，转写需做**等效截止**近似，
目标弹峰 ≤ 1024」的口径与可接受的裁切方式（如离线按 640 池重放求静态截止），免得每个密集卡 worker 各自拍数。
