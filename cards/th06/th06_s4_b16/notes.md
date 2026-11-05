## 对照表 §5 没写「0x40 族的 f0 是运行期随机」时 xformdef 怎么翻

影响面：疑似全池（凡 `bullet_effects(...)` 的 f0 为 `%F0` 之类运行期随机、且 flags 带 0x40 族的单元）

证据：
- `mapping.md` §5 的 0x40 行只给模板 `@I step_speed(0fx, I); turn(f0); set_speed(f1);`，
  没有说明 f0 是运行期变量时的处理；同节又要求「xformdef 参数必须是编译期常量，每组不同参数写一个 xformdef」。
- 本单元 `source.txt:42` `bullet_effects(180, 1, -1, -1, %F0, 1.4f, -1.0f, -1.0f)`，
  其中 `%F0` 由上一行 `set_float_rand_bound_min($F0, π, -π/2)` 每轮重摇。
- `docs/ecl-lang/4-bullets.md`「xformdef」节与 `docs/xform-ops.md`：参数必须是编译期常量（字面量/const/一元负号）。
- `renkolab/local/vendor/th06-decomp/src/BulletManager.cpp:340-360`：`dirChangeRotation = bulletProps->exFloats[0]`
  在弹创建时拷入每颗弹，即同一轮所有弹共享同一个随机转角。

建议：改对照表 §5 —— 补一条口径，例如「f0 为运行期随机时，把值域 N 等分量化成 N 个 xformdef、
每轮 `rand(N)` 选一档（同轮共享转角），并在 report 写明量化档次」。本单元用了 N=4（±22.5°/±67.5°）。
