## 0x40 族的 dirChangeRotation 可以是运行期随机值，xformdef 表达不了

影响面：疑似同关（Stage 6）/ 疑似全池（任何 `bullet_effects` + flags `0x1c0` 且 f0 为随机的 unit）

证据：`transcribe/th06/mapping.md` §5 给 `0x40/0x100/0x80` 的配方是 xformdef（`@I step_speed(0fx,I); turn(f0); …`），前提是 `f0 = exFloats[0]` 为编译期常量；
`/data/sunyunbo/www/renkolab/local/vendor/th06-decomp/src/BulletManager.cpp:351-368`（`if (bullet->exFlags & 0x1c0) { bullet->dirChangeRotation = bulletProps->exFloats[0]; … }`）
与 `:751-775`（`curBullet->angle = curBullet->angle + curBullet->dirChangeRotation;`）说明它是逐弹运行期值。
本单元 `ecldata6.ecl.txt:99` 写 `set_float_rand_bound_min($F2, 2π, -π); bullet_effects(60,1,-1,-1,%F2,-999,…)`，
即 `f0` 每发重抽；`docs/ecl-lang/4-bullets.md:415` 明确 xformdef 参数须编译期常量，故只能在 `sh_task` 里用弹 setter 近似。

建议：改对照表 §5，在 `0x40`（及 `0x100`/`0x80`）条目补一句「`f0` 为随机的单元改用 `sh_task` + `set_accel`/`turn`/`set_speed` 近似」。
