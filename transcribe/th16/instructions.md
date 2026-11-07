# TH16 原作 ECL 指令表

适用 **TH16 v1.00a《天空璋》**。本表从TH18的同编号指令说明搬迁，以[Priw8 TH16指令页](https://priw8.github.io/#b=modding/&p=ins&table=16)和本机`th16.eclm`限定条目范围；参数与语义沿用同编号的公共定义，TH16明确差异在对应行改写。表内“继承”表示跨版本共通说明，不宣称本轮逐项重做原生验证。目标写法见各专题，总入口见[纲要](README.md)。

## 读表约定

- 参数按原作调用顺序排列。`int` 为整数，`float` 为原作浮点，`str` 为程序名或字符串，`label` 为跳转目的；`&` 标记写回变量，不是源文本里要加的符号。`args…` 是可变实参。
- 坐标／长度通常为像素，速度为像素/帧，角度为弧度，角速度为弧度/帧，时间为帧。特殊含义在条目中注明。空参数 `()` 不代表没有输入：算术指令从表达式栈取操作数。
- `id`／`etId` 是源发射器槽，`laserId` 是源激光编号；源敌ID、任务用户ID、插值槽和目标句柄互不等同。EX 的 `type`、发射 `mode` 和插值 `mode` 分别查自己的表。
- **继承**：TH18同编号说明，结合Priw8的TH16继承链使用；适用边界仍见专题。**部分**：已有定义但存在明确未核字段／组合。**社区**：社区表的继承说明，未在本轮提升为TH16原生验证。**待核**：只有名称／格式或关键语义未知。格式已知不等于行为已核，原作行为已核也不等于目标能够表达。
- 社区说明也是可查阅的公开资料，不要求作者逐条重做原生验证；条目明确标出的未知参数、冲突或本卡缺失行为才需交回。
- `p1/p2…` 仅表示位置，绝不表示已理解含义。实际攻击依赖未核项时交主会话；已批准的普通奖励／纯表现省略直接沿用[公共口径](transcription-policy.md)，无需重新证明。

## 目录

[控制流与数学](#控制流与数学) / [敌创建与动画](#敌创建与动画) / [移动](#移动) / [敌状态与阶段](#敌状态与阶段) / [发射器与效果配置](#发射器与效果配置) / [激光](#激光) / [跨敌交互](#跨敌交互) / [调试与作品专用入口](#调试与作品专用入口)


## 控制流与数学

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 0 | `nop()` | 不执行操作；指令所在的时间门仍有效。 | 继承；[专题](mapping.md) |
| 1 | `delete()` | 结束当前上下文；敌主上下文结束使敌退场，额外 async 结束不等于敌死亡。 | 继承；[专题](mapping.md) |
| 10 | `ret()` | 同步返回；根调用栈返回则结束。 | 继承；[专题](mapping.md) |
| 11 | `call(sub:str, args…)` | sub 为被调用程序，args 为按值实参；同步调用保存返回位置、时钟和栈帧。 | 继承；[专题](mapping.md) |
| 12 | `jmp(target:label, time:int)` | 跳至 target，同时将脚本时间改为 time；并非只改程序位置。 | 继承；[专题](mapping.md) |
| 13 | `jmpEq(target:label, time:int)` | 栈条件为零时跳转并改脚本时间；条件来自表达式栈。 | 继承；[专题](mapping.md) |
| 14 | `jmpNeq(target:label, time:int)` | 栈条件非零时跳转并改脚本时间。 | 继承；[专题](mapping.md) |
| 15 | `callAsync(sub:str, args…)` | 同敌创建额外执行上下文，实参按值传递；敌共享槽仍共享。 | 继承；[专题](mapping.md) |
| 16 | `callAsyncId(sub:str, id:int, args…)` | 同敌异步调用，赋予用户 id；id 用于 killAsync，不是目标任务池索引。 | 继承；[专题](mapping.md) |
| 17 | `killAsync(id:int)` | 取消同敌指定用户 id 的 async；重复 id／特殊 id 的完整匹配规则待核。 | 继承；[专题](enemy-state.md) |
| 21 | `killAllAsync()` | 取消同敌 async；目标直系子任务取消不能直接覆盖其范围。 | 继承；[专题](enemy-state.md) |
| 22 | `debug22(p1:int, p2:str)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 23 | `wait(frames:int)` | 从脚本时钟减去 frames，推迟后续时间门；与时间标签一起恢复实际等待。 | 继承；[专题](mapping.md) |
| 24 | `waitf(frames:float)` | 浮点时钟等待；子帧与 gameSpeed 的组合需按实际调用核。 | 继承；[专题](mapping.md) |
| 27 | `unknown27(参数格式待核)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 30 | `unknown30(format:str, args…)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 31 | `unknown31(参数格式待核)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 40 | `stackAlloc(bytes:int)` | 为局部栈预留空间；恢复高层局部变量后不逐条照搬。 | 社区；[专题](mapping.md) |
| 42 | `pushi(value:int)` | 整数压栈；裸值表达式也会编译成压栈。 | 继承；[专题](mapping.md) |
| 43 | `seti(out:int&)` | 取整数栈结果写入 out。 | 继承；[专题](mapping.md) |
| 44 | `pushf(value:float)` | 浮点压栈。 | 继承；[专题](mapping.md) |
| 45 | `setf(out:float&)` | 取浮点栈结果写入 out。 | 继承；[专题](mapping.md) |
| 50 | `addi()` | 整数加法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 51 | `addf()` | 浮点加法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 52 | `subi()` | 整数减法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 53 | `subf()` | 浮点减法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 54 | `muli()` | 整数乘法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 55 | `mulf()` | 浮点乘法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 56 | `divi()` | 整数除法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 57 | `divf()` | 浮点除法；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 58 | `modi()` | 整数余数；操作数从表达式栈取，结果回栈。 | 继承；[专题](mapping.md) |
| 59 | `eqi()` | 整数等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 60 | `eqf()` | 浮点等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 61 | `neqi()` | 整数不等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 62 | `neqf()` | 浮点不等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 63 | `lessi()` | 整数小于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 64 | `lessf()` | 浮点小于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 65 | `leqi()` | 整数小于等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 66 | `leqf()` | 浮点小于等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 67 | `greateri()` | 整数大于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 68 | `greaterf()` | 浮点大于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 69 | `geqi()` | 整数大于等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 70 | `geqf()` | 浮点大于等于；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 71 | `noti()` | 整数逻辑非；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 72 | `notf()` | 浮点逻辑非；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 73 | `or()` | 逻辑或；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 74 | `and()` | 逻辑与；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 75 | `xor()` | 整数逐位异或；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 76 | `bit_or()` | 整数逐位或；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 77 | `bit_and()` | 整数逐位与；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 78 | `deci(value:int&)` | 先将 value 的旧值压栈，再自减；不能丢掉旧值用途。 | 继承；[专题](mapping.md) |
| 79 | `stackSin()` | 浮点正弦；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 80 | `stackCos()` | 浮点余弦；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 81 | `circlePos(x:float&, y:float&, angle:float, radius:float)` | 输出 x=radius*cos(angle)、y=radius*sin(angle)，不自动加敌位置。 | 社区；[专题](mapping.md) |
| 82 | `validRad(angle:float&)` | 原地规范化弧度角；端点约定按调用用途核。 | 社区；[专题](mapping.md) |
| 83 | `negi()` | 整数取负；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 84 | `negf()` | 浮点取负；操作数／结果使用表达式栈。 | 继承；[专题](mapping.md) |
| 85 | `squareSum(out:float&, x:float, y:float)` | 输出平方和 x²+y²。 | 社区；[专题](mapping.md) |
| 86 | `squareSumRoot(out:float&, x:float, y:float)` | 输出 sqrt(x²+y²)。 | 社区；[专题](mapping.md) |
| 87 | `getAngle(out:float&, x1:float, y1:float, x2:float, y2:float)` | 输出从 (x1,y1) 指向 (x2,y2) 的弧度角。 | 社区；[专题](mapping.md) |
| 88 | `stackSqrt()` | 浮点平方根；操作数／结果使用表达式栈。 | 社区；[专题](mapping.md) |
| 89 | `linearFunc(out:float&, a:float, x:float)` | 社区解释为 out=a*x；本作消费者未复核，不据名字扩大承诺。 | 社区；[专题](mapping.md) |
| 90 | `pointRotate(outX:float&, outY:float&, x:float, y:float, angle:float)` | 将输入点绕原点旋转 angle，写两输出。 | 社区；[专题](mapping.md) |
| 91 | `floatTime(slot:int, out:float&, frames:int, mode:int, start:float, goal:float)` | 用上下文槽 slot 插值并写回 out；mode 决定 goal 含义，输入在配置时求值。 | 继承；[专题](interpolation-modes.md#变量插值指令91与92) |
| 92 | `math92(slot:int, out:float&, frames:int, mode:int, start:float, goal:float, extra1:float, extra2:float)` | 91 的额外参数版；mode8 取两切线，mode17 取 extra2 为初速。解码格式有来源冲突，见专题。 | 部分；[专题](interpolation-modes.md#变量插值指令91与92) |
| 93 | `math93(outX:float&, outY:float&, r1:float, r2:float)` | 社区记录为随机取点；r1/r2 的几何意义、分布与取样规则未核。 | 待核；[专题](mapping.md) |

## 敌创建与动画

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 300 | `enmCreate(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为父 FINAL 上的相对输入，hp 为血量，score 为分数，item 为掉落。子镜像初值0；父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 301 | `enmCreateA(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为绝对输入坐标，hp 为血量，score 为分数，item 为掉落。子镜像初值0；父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 302 | `anmSelect(anmIndex:int)` | anmIndex 选择后续动画文件。 | 社区；[专题](enemy-state.md) |
| 303 | `anmSetSprite(slot:int, script:int)` | slot 为动画槽，script 为脚本号，使用已选动画文件。 | 社区；[专题](enemy-state.md) |
| 304 | `enmCreateM(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为父 FINAL 上的相对输入，hp 为血量，score 为分数，item 为掉落。子镜像初值1；父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 305 | `enmCreateAM(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为绝对输入坐标，hp 为血量，score 为分数，item 为掉落。子镜像初值1；父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 306 | `anmSetMain(slot:int, script:int)` | slot 为主动画槽，script 为静止基准脚本；移动状态切换附属动画。 | 社区；[专题](enemy-state.md) |
| 307 | `anmPlay(anmIndex:int, script:int)` | anmIndex/script 选择在敌当前位置播放的独立动画。 | 社区；[专题](enemy-state.md) |
| 308 | `anmPlayAbs(anmIndex:int, script:int)` | anmIndex/script 选择在原点播放的独立动画。 | 社区；[专题](enemy-state.md) |
| 309 | `enmCreateF(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为父 FINAL 上的相对输入，hp 为血量，score 为分数，item 为掉落。子镜像初值0；F 门：boss0 存在时跳过。父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 310 | `enmCreateAF(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为绝对输入坐标，hp 为血量，score 为分数，item 为掉落。子镜像初值0；F 门：boss0 存在时跳过。父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 311 | `enmCreateMF(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为父 FINAL 上的相对输入，hp 为血量，score 为分数，item 为掉落。子镜像初值1；F 门：boss0 存在时跳过。父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 312 | `enmCreateAMF(sub:str, x:float, y:float, hp:int, score:int, item:int)` | 创建执行 sub 的敌；x/y 为绝对输入坐标，hp 为血量，score 为分数，item 为掉落。子镜像初值1；F 门：boss0 存在时跳过。父镜像另作用于最终出生坐标。 | 继承；[专题](enemy-state.md#2-创建子敌名字与继承顺序) |
| 313 | `anmSelectedPlay(script:int)` | script 为已选文件中的动画脚本。 | 社区；[专题](enemy-state.md) |
| 314 | `anmPlayHigh(anmIndex:int, script:int)` | anmIndex/script 指定高层动画；具体层规则未核。 | 社区；[专题](enemy-state.md) |
| 315 | `anmPlayRotate(anmIndex:int, script:int, angle:float)` | anmIndex/script 指定动画，angle 为旋转角。 | 社区；[专题](enemy-state.md) |
| 316 | `anm316(p1:int, p2:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 317 | `anmSwitch(slot:int, switch:int)` | slot 指定动画槽，switch 指定动画中断编号。 | 社区；[专题](enemy-state.md) |
| 318 | `anmReset()` | 重置部分动画状态；字段范围未核。 | 社区；[专题](enemy-state.md) |
| 319 | `anmRotate(slot:int, r:float)` | slot 为动画槽，r 为旋转角。 | 社区；[专题](enemy-state.md) |
| 320 | `anmMove(slot:int, x:float, y:float)` | slot 为动画槽，x/y 为依附敌的局部位置。 | 社区；[专题](enemy-state.md) |
| 321 | `enmMapleEnemy(sub:str, x:int, y:int, hp:int, score:int, item:int)` | 特殊敌创建入口；与普通创建的差异未核。 | 社区；[专题](enemy-state.md) |
| 322 | `enm322(p1:int, p2:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 323 | `deathAnm(anmIndex:int, script:int)` | anmIndex/script 配置死亡动画。 | 社区；[专题](enemy-state.md) |
| 324 | `enm324(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 325 | `anmColor(slot:int, R:int, G:int, B:int)` | slot 为动画槽，R/G/B 为0–255颜色分量。 | 社区；[专题](enemy-state.md) |
| 326 | `anmColorTime(slot:int, time:int, mode:int, R:int, G:int, B:int)` | slot 指定动画，time/mode 指定插值，R/G/B 为目标颜色。 | 社区；[专题](enemy-state.md) |
| 327 | `anmAlpha(slot:int, alpha:int)` | slot 指定动画，alpha 为0–255透明度。 | 社区；[专题](enemy-state.md) |
| 328 | `anmAlphaTime(slot:int, time:int, mode:int, alpha:int)` | slot 指定动画，time/mode 指定插值，alpha 为目标透明度。 | 社区；[专题](enemy-state.md) |
| 329 | `anmScale(slot:int, w:float, h:float)` | slot 指定动画，w/h 为横纵缩放。 | 社区；[专题](enemy-state.md) |
| 330 | `anmScaleTime(slot:int, time:int, mode:int, w:float, h:float)` | slot 指定动画，time/mode 指定插值，w/h 为目标缩放。 | 社区；[专题](enemy-state.md) |
| 331 | `anmAlpha2(slot:int, alpha:int)` | slot 指定动画，alpha 为第二透明度通道。 | 社区；[专题](enemy-state.md) |
| 332 | `anmAlpha2Time(slot:int, time:int, mode:int, alpha:int)` | slot 指定动画，time/mode 指定插值，alpha 为第二通道目标。 | 社区；[专题](enemy-state.md) |
| 333 | `anm333(p1:int, p2:int, p3:int, p4:float, p5:float)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 334 | `anm334(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 335 | `anmScale2(slot:int, w:float, h:float)` | slot 指定动画，w/h 为相乘缩放因子。 | 社区；[专题](enemy-state.md) |
| 336 | `anmLayer(slot:int, layer:int)` | slot 指定动画，layer 为显示层。 | 社区；[专题](enemy-state.md) |
| 337 | `anmBlendMode(slot:int, b:int)` | slot 指定动画，b 为混合模式；枚举未核。 | 社区；[专题](enemy-state.md) |
| 338 | `anmPlayPos(anmIndex:int, script:int, x:float, y:float, z:float)` | anmIndex/script 选择动画，x/y/z 为偏移；3D细节未核。 | 社区；[专题](enemy-state.md) |
| 339 | `anm339(p1:int, p2:int, p3:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 340 | `enmDelete(id:int)` | 指定源敌 ID 退场；过滤及退场消费者完整行为待核。 | 部分；[专题](enemy-state.md) |

## 移动

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 400 | `movePos(x:float, y:float)` | 写 ABS 位置层；REL 独立于 ABS，不能当作给最终位置加偏移。 | 继承；[专题](enemy-state.md#3-绝对相对镜像与限位如何组合) |
| 401 | `movePosTime(frames:int, mode:int, x:float, y:float)` | 对 ABS 位置插值到 x/y；mode 查插值表。 | 继承；[专题](interpolation-modes.md) |
| 402 | `movePosRel(x:float, y:float)` | 写 REL 位置层；REL 独立于 ABS，不能当作给最终位置加偏移。 | 继承；[专题](enemy-state.md#3-绝对相对镜像与限位如何组合) |
| 403 | `movePosRelTime(frames:int, mode:int, x:float, y:float)` | 对 REL 位置插值到 x/y；mode 查插值表。 | 继承；[专题](interpolation-modes.md) |
| 404 | `moveVel(angle:float, speed:float)` | 设置 ABS 的极坐标方向和线速度。 | 继承；[专题](enemy-state.md) |
| 405 | `moveVelTime(frames:int, mode:int, angle:float, speed:float)` | 插值 ABS 角／速；普通 mode 为目标值，mode7 为增量。普通转角走最短弧。 | 继承；[专题](interpolation-modes.md) |
| 406 | `moveVelRel(angle:float, speed:float)` | 设置 REL 的极坐标方向和线速度。 | 继承；[专题](enemy-state.md) |
| 407 | `moveVelRelTime(frames:int, mode:int, angle:float, speed:float)` | 插值 REL 角／速；普通 mode 为目标值，mode7 为增量。普通转角走最短弧。 | 继承；[专题](interpolation-modes.md) |
| 408 | `moveCircle(phase:float, omega:float, radius:float, radialSpeed:float)` | ABS 圆周运动；相位 rad、角速度 rad/帧、半径 px、径向增量 px/帧。圆心快照见专题。 | 继承；[专题](circular-motion.md) |
| 409 | `moveCircleTime(frames:int, mode:int, omega:float, radius:float, radialSpeed:float)` | 插值 ABS 的角速度、半径和径向增量；没有目标相位参数。 | 继承；[专题](circular-motion.md) |
| 410 | `moveCircleRel(phase:float, omega:float, radius:float, radialSpeed:float)` | REL 圆周运动；相位 rad、角速度 rad/帧、半径 px、径向增量 px/帧。圆心快照见专题。 | 继承；[专题](circular-motion.md) |
| 411 | `moveCircleRelTime(frames:int, mode:int, omega:float, radius:float, radialSpeed:float)` | 插值 REL 的角速度、半径和径向增量；没有目标相位参数。 | 继承；[专题](circular-motion.md) |
| 412 | `moveRand(frames:int, angleMode:int, speed:float)` | ABS 随机移动；speed 为起始速，angleMode 不覆盖速度插值槽的 mode。已核入口及限位见配方。 | 继承；[专题](movement.md) |
| 413 | `moveRandRel(frames:int, mode:int, speed:float)` | REL 随机移动入口；完整本作选择规则与 mode 继承未核。 | 部分；[专题](movement.md) |
| 414 | `moveBoss()` | 读取 Boss 的 ABS 位置；Boss 缺失行为未核。 | 社区；[专题](movement.md) |
| 415 | `moveBossRel()` | 读取 Boss 的 REL 位置；Boss 缺失行为未核。 | 社区；[专题](movement.md) |
| 416 | `movePos3d(x:float, y:float, z:float)` | x/y/z 为 ABS 三维位置；z 的消费未核。 | 社区；[专题](movement.md) |
| 417 | `movePos3dRel(x:float, y:float, z:float)` | x/y/z 为 REL 三维位置；z 的消费未核。 | 社区；[专题](movement.md) |
| 418 | `moveAdd(x:float, y:float)` | x/y 为 ABS 位置增量。 | 社区；[专题](movement.md) |
| 419 | `move419(x:float, y:float)` | x/y 的 REL 增量解释存在社区疑问，消费者待核。 | 社区；[专题](movement.md) |
| 420 | `moveEllipse(phase:float, omega:float, radius:float, radialSpeed:float, axis:float, ratio:float)` | ABS 椭圆运动；前四参同圆周，axis 为轴角快照，ratio 为该轴缩放。 | 继承；[专题](circular-motion.md) |
| 421 | `moveEllipseTime(frames:int, mode:int, omega:float, radius:float, radialSpeed:float, axis:float, ratio:float)` | ABS Time 配置；axis/ratio 槽不被普通 tick 消费，不能按名字假定完整椭圆插值。 | 部分；[专题](circular-motion.md#未覆盖的time变体) |
| 422 | `moveEllipseRel(phase:float, omega:float, radius:float, radialSpeed:float, axis:float, ratio:float)` | REL 椭圆运动；前四参同圆周，axis 为轴角快照，ratio 为该轴缩放。 | 继承；[专题](circular-motion.md) |
| 423 | `moveEllipseRelTime(frames:int, mode:int, omega:float, radius:float, radialSpeed:float, axis:float, ratio:float)` | REL Time 配置；axis/ratio 槽不被普通 tick 消费，不能按名字假定完整椭圆插值。 | 部分；[专题](circular-motion.md#未覆盖的time变体) |
| 424 | `moveSetMirror(enabled:int)` | 置清敌镜像位；各指令怎样使用镜像见敌状态专题。 | 继承；[专题](enemy-state.md) |
| 425 | `moveBezier(frames:int, tangent0X:float, tangent0Y:float, x:float, y:float, tangent1X:float, tangent1Y:float)` | ABS Hermite 位置路径；起点为当前层位置，中间一对为终点，首尾两对为归一化时间切线，非两控制点。 | 继承；[专题](interpolation-modes.md#mode8hermite端点与切线) |
| 426 | `moveBezierRel(frames:int, tangent0X:float, tangent0Y:float, x:float, y:float, tangent1X:float, tangent1Y:float)` | REL Hermite 位置路径；起点为当前层位置，中间一对为终点，首尾两对为归一化时间切线，非两控制点。 | 继承；[专题](interpolation-modes.md#mode8hermite端点与切线) |
| 427 | `moveReset()` | 重置移动状态；具体字段范围待核。 | 社区；[专题](movement.md) |
| 428 | `moveVelNM(angle:float, speed:float)` | 设置 ABS 的极坐标方向和线速度。NM 的镜像差异按调用点核。 | 部分；[专题](enemy-state.md) |
| 429 | `moveVelNMTime(frames:int, mode:int, angle:float, speed:float)` | 插值 ABS 角／速；普通 mode 为目标值，mode7 为增量。NM 镜像分支待核。 | 部分；[专题](interpolation-modes.md) |
| 430 | `moveVelNMRel(angle:float, speed:float)` | 设置 REL 的极坐标方向和线速度。NM 的镜像差异按调用点核。 | 部分；[专题](enemy-state.md) |
| 431 | `moveVelNMRelTime(frames:int, mode:int, angle:float, speed:float)` | 插值 REL 角／速；普通 mode 为目标值，mode7 为增量。NM 镜像分支待核。 | 部分；[专题](interpolation-modes.md) |
| 432 | `moveEnm(id:int)` | id 为源敌ID，读取其 ABS 位置；失败行为未核。 | 社区；[专题](movement.md) |
| 433 | `moveEnmRel(id:int)` | id 为源敌ID，读取其 REL 位置；失败行为未核。 | 社区；[专题](movement.md) |
| 434 | `moveCurve(time:int, mode:int, c:int, x:float, y:float)` | time/mode 控制 ABS 路径，x/y 为目标，c 的轨迹意义未核。 | 社区；[专题](movement.md) |
| 435 | `moveCurveRel(time:int, mode:int, c:int, x:float, y:float)` | time/mode 控制 REL 路径，x/y 为目标，c 的轨迹意义未核。 | 社区；[专题](movement.md) |
| 436 | `moveAddTime(time:int, mode:int, x:float, y:float)` | time/mode 控制 ABS 增量插值，x/y 为增量。 | 社区；[专题](movement.md) |
| 437 | `moveAddRelTime(time:int, mode:int, x:float, y:float)` | time/mode 控制 REL 增量插值，x/y 为增量。 | 社区；[专题](movement.md) |
| 438 | `moveCurveAdd(time:int, mode:int, c:int, x:float, y:float)` | 434 的 ABS 增量入口；c 的轨迹意义未核。 | 社区；[专题](movement.md) |
| 439 | `moveCurveAddRel(time:int, mode:int, c:int, x:float, y:float)` | 435 的 REL 增量入口；c 的轨迹意义未核。 | 社区；[专题](movement.md) |
| 440 | `moveAngle(angle:float)` | 独立更新 ABS 方向，速率另存。 | 继承；[专题](enemy-state.md) |
| 441 | `moveAngleTime(frames:int, mode:int, angle:float)` | 插值 ABS 方向；特殊 mode、镜像和残余状态按调用点处理。 | 继承；[专题](interpolation-modes.md) |
| 442 | `moveAngleRel(angle:float)` | 独立更新 REL 方向，速率另存。 | 继承；[专题](enemy-state.md) |
| 443 | `moveAngleRelTime(frames:int, mode:int, angle:float)` | 插值 REL 方向；特殊 mode、镜像和残余状态按调用点处理。 | 继承；[专题](interpolation-modes.md) |
| 444 | `moveSpeed(speed:float)` | 独立更新 ABS 线速度，方向另存。 | 继承；[专题](enemy-state.md) |
| 445 | `moveSpeedTime(frames:int, mode:int, speed:float)` | 插值 ABS 速率；普通 mode 为目标速度。 | 继承；[专题](interpolation-modes.md) |
| 446 | `moveSpeedRel(speed:float)` | 独立更新 REL 线速度，方向另存。 | 继承；[专题](enemy-state.md) |
| 447 | `moveSpeedRelTime(frames:int, mode:int, speed:float)` | 插值 REL 速率；普通 mode 为目标速度。 | 继承；[专题](interpolation-modes.md) |

## 敌状态与阶段

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 500 | `setHurtbox(width:float, height:float)` | 设置受击框；普通圆形分支用第一值×0.5 为半径，矩形另核。 | 继承；[专题](enemy-state.md#1-敌默认判定与-flags) |
| 501 | `setHitbox(width:float, height:float)` | 设置敌撞自机的体碰框；普通圆形分支用第一值×0.5。 | 继承；[专题](enemy-state.md#1-敌默认判定与-flags) |
| 502 | `flagSet(mask:int)` | 按 mask 置敌 flags，原位不能直接传给目标 flag API。 | 继承；[专题](enemy-state.md) |
| 503 | `flagClear(mask:int)` | 按 mask 清敌 flags；其他禁碰原因仍可能有效。 | 继承；[专题](enemy-state.md) |
| 504 | `moveLimit(centerX:float, centerY:float, width:float, height:float)` | 设置逐帧位置限位矩形；width/height 是完整宽高。 | 继承；[专题](movement.md#限位与执行顺序) |
| 505 | `moveLimitReset()` | 取消位置限位。 | 继承；[专题](enemy-state.md) |
| 506 | `dropClear()` | 清额外掉落配置。 | 社区；[专题](enemy-state.md) |
| 507 | `dropExtra(type:int, amount:int)` | type 为掉落类型，amount 为数量。 | 社区；[专题](enemy-state.md) |
| 508 | `dropArea(w:float, h:float)` | w/h 为掉落分布区域宽高。 | 社区；[专题](enemy-state.md) |
| 509 | `dropItems()` | 发放当前掉落配置；公共口径省略普通奖励。 | 社区；[专题](enemy-state.md) |
| 510 | `dropMain(type:int)` | type 为主掉落类型。 | 社区；[专题](enemy-state.md) |
| 511 | `lifeSet(hp:int)` | 设置当前与最大血量。 | 社区；[专题](enemy-state.md) |
| 512 | `setBoss(bossId:int)` | 登记 Boss 槽；社区记 -1 结束 Boss 模式，其他值的完整TH16行为待核。 | 社区；[专题](enemy-state.md) |
| 513 | `timerReset()` | 重置段计时相关状态；不表示清空 TIME、脚本时钟及所有计时器。 | 继承；[专题](enemy-state.md) |
| 514 | `setInterrupt(slot:int, hp:int, time:int, sub:str)` | 设置中断槽的血量阈值、超时阈值和跳转 sub；活动计时基点／取消范围沿入口恢复。 | 部分；[专题](enemy-state.md#4-同一敌人的段入口恢复状态而非重置模板) |
| 515 | `setInvuln(frames:int)` | 设置无敌计时；无敌不自动关闭敌体碰。 | 继承；[专题](enemy-state.md) |
| 516 | `playSound(id:int)` | id 为音效编号。 | 社区；[专题](enemy-state.md) |
| 517 | `setScreenShake(time:int, startIntensity:int, endIntensity:int)` | time 为震屏时长，startIntensity/endIntensity 为起止强度。 | 社区；[专题](enemy-state.md) |
| 518 | `dialogRead(dialogueId:int)` | dialogueId 为对话条目；可能有清场副作用，不能仅按纯表现删除。 | 社区；[专题](enemy-state.md) |
| 519 | `dialogWait()` | 等待对话结束条件。 | 社区；[专题](enemy-state.md) |
| 520 | `bossWait()` | 等待 Boss 不再存活。 | 社区；[专题](enemy-state.md) |
| 521 | `setTimeout(slot:int, sub:str)` | 设置对应中断槽的超时目标；第二参是程序名，不是时长。 | 社区；[专题](enemy-state.md#4-同一敌人的段入口恢复状态而非重置模板) |
| 522 | `spellEx(id:int, time:int, type:int, name:str)` | id 为符卡编号，time 为声明时长，type 的完整含义待核，name 为标题。 | 社区；[专题](enemy-state.md) |
| 523 | `spellEnd()` | 结束符卡声明；攻击结束另看中断与任务。 | 社区；[专题](enemy-state.md) |
| 524 | `setChapter(a:int)` | a 为章节／UI相关参数，具体作用随作品不同。 | 社区；[专题](enemy-state.md) |
| 525 | `enmKillAll()` | 对通过过滤的敌执行死亡路径及非空 setDeath 回调；与直接删除不同。 | 继承；[专题](enemy-state.md) |
| 526 | `etProtectRange(r:float)` | r 为自机附近禁止出生的半径。 | 社区；[专题](enemy-state.md) |
| 527 | `lifeMarker(slot:int, hp:float, c:int)` | slot 为血条标记槽，hp 为标记血量，c 为颜色相关值（用途未核）。 | 社区；[专题](enemy-state.md) |
| 528 | `spellUnused(id:int, time:int, type:int, name:str)` | 符卡声明入口，id/time/type/name；本作与522的差异未核。 | 社区；[专题](enemy-state.md) |
| 529 | `rankF3(var:float&, a:float, b:float, c:float)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 530 | `rankF5(var:float&, a:float, b:float, c:float, d:float, e:float)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 531 | `rankF2(var:float&, a:float, b:float)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 532 | `rankI3(var:int&, a:int, b:int, c:int)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 533 | `rankI5(var:int&, a:int, b:int, c:int, d:int, e:int)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 534 | `rankI2(var:int&, a:int, b:int)` | 按动态 RANK 档位选择值，阈值未核；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 535 | `diffI(var:int&, E:int, N:int, H:int, L:int)` | 按难度 E/N/H/L 选择值；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 536 | `diffF(var:float&, E:float, N:float, H:float, L:float)` | 按难度 E/N/H/L 选择值；var 为写回目标，后续参数为候选值。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 537 | `spell(id:int, time:int, mode:int, name:str)` | id/time/mode/name 为符卡编号、声明时长、模式、标题；mode 未全核，声明时长不能替代中断时限。 | 社区；[专题](enemy-state.md) |
| 538 | `spell2(id:int, time:int, mode:int, name:str)` | 符卡声明变体；id/time/mode/name，编号修正规则须按本作确认。 | 社区；[专题](enemy-state.md) |
| 539 | `spell3(id:int, time:int, mode:int, name:str)` | 符卡声明变体；id/time/mode/name，编号修正规则须按本作确认。 | 社区；[专题](enemy-state.md) |
| 540 | `stars(cnt:int)` | cnt 为显示星数。 | 社区；[专题](enemy-state.md) |
| 541 | `noHitboxDur(frames:int)` | 独立临时禁体碰计时；不等于无敌或关闭受击。 | 继承；[专题](enemy-state.md) |
| 542 | `spellTimeout()` | 标记耐久符卡；不直接定义任务退出时刻。 | 社区；[专题](enemy-state.md) |
| 543 | `unknown543()` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 544 | `unknown544(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 545 | `laserCancel()` | 取消激光；本作过滤与取消相位待核。 | 社区；[专题](enemy-state.md) |
| 546 | `bombShield(a:int, script:int)` | a 为炸弹保护开关，script 为关联动画脚本；槽及保护细节待核。 | 社区；[专题](enemy-state.md) |
| 547 | `gameSpeed(scale:float)` | 改变游戏速度倍率；浮点时钟和 dt 相关行为不能直接取整。 | 社区；[专题](mapping.md) |
| 548 | `diffWait(easy:int, normal:int, hard:int, lunatic:int)` | 按当前难度选等待帧数；与动态 RANK 区分。 | 社区；[专题](mapping.md) |
| 549 | `unknown549(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 550 | `unknown550(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 551 | `unknown551(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 552 | `zIndex(layers:int)` | layers 为动画显示层增量。 | 社区；[专题](enemy-state.md) |
| 553 | `hitSound(id:int)` | id 为受击音效号。 | 社区；[专题](enemy-state.md) |
| 554 | `stageLogo()` | 显示关卡标题动画。 | 社区；[专题](enemy-state.md) |
| 555 | `enmAlive(out:int&, id:int)` | 按源敌 ID 查询存活并写 out；失败／特殊 ID 的本作规则待核。 | 社区；[专题](enemy-state.md) |
| 556 | `setDeath(sub:str)` | 设置死亡回调程序；攻击内部回调副作用仍需保留。 | 继承；[专题](enemy-state.md) |
| 557 | `fogTime(time:int, mode:int, color:int, start:float, end:float)` | time/mode 为雾插值，color 为颜色，start/end 为距离参数。 | 社区；[专题](enemy-state.md) |
| 558 | `flagMirror(state:int)` | state 为镜像开关；与424是否完全同路未作本作承诺。 | 社区；[专题](enemy-state.md) |
| 559 | `enmLimit(limit:int)` | limit 为敌数量上限，后续创建可能被拒绝。 | 社区；[专题](enemy-state.md) |
| 560 | `unknown560(p1:float, p2:float)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 561 | `die()` | 触发死亡相关入口；与 delete/enmDelete 的本作完整差异待核。 | 社区；[专题](enemy-state.md) |
| 562 | `dropItemsSp()` | 练习模式掉落入口；普通奖励已准省略。 | 社区；[专题](enemy-state.md) |
| 563 | `unknown563(flagState:int)` | flagState 为形状相关开关；本作圆／矩形完整路径未核，不套别作定义。 | 社区；[专题](enemy-state.md) |
| 564 | `hitboxRotate(angle:float)` | angle 为碰撞形状旋转角；形状及消费者需本作定义。 | 社区；[专题](enemy-state.md) |
| 565 | `bombInvuln(red:float)` | red 为炸弹伤害倍率；本作细节待核。 | 社区；[专题](enemy-state.md) |
| 566 | `unknown566()` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 567 | `unknown567(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 568 | `spellMode(state:int)` | state 为符卡减伤开关；具体本作规则待核。 | 社区；[专题](enemy-state.md) |
| 569 | `unknown569(weight:int)` | 登记／增加章节统计权重；独立躲弹卡按公共口径省略非攻击统计。 | 继承；[专题](transcription-policy.md) |
| 570 | `unknown570()` | 章节匹配时结算并清零统计。 | 继承；[专题](transcription-policy.md) |
| 571 | `unknown571()` | 另一敌清场路径，先清死亡回调；完整过滤仍待核。 | 部分；[专题](enemy-state.md) |
| 572 | `lifeNow(hp:int)` | hp 为当前血量，不改最大血量。 | 社区；[专题](enemy-state.md) |
| 573 | `unknown573(p1:int, p2:int)` | 限时击破奖励掉落配置；逐参字段名未核，普通奖励按公共口径省略。 | 部分；[专题](transcription-policy.md) |

## 发射器与效果配置

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 600 | `etNew(id:int)` | 重置指定发射器及辅助偏移／游标；同敌有16份配置。 | 继承；[专题](aim-modes.md) |
| 601 | `etOn(id:int)` | 读取当前配置生成整波；配置共享、创建顺序和随机取样见专题。 | 继承；[专题](aim-modes.md) |
| 602 | `etSprite(id:int, type:int, color:int)` | 设置弹型与色号，不立即发弹；原 type 不是目标 appearance。 | 继承；[专题](bullet-types.md) |
| 603 | `etOffset(id:int, x:float, y:float)` | 设置相对发射口偏移；从敌 FINAL 合成实际出生点。 | 继承；[专题](aim-modes.md) |
| 604 | `etAngle(id:int, angle:float, spread:float)` | 设置基础角和第二角；第二角随 aim 表示路间距、层偏转或随机幅度。 | 继承；[专题](aim-modes.md) |
| 605 | `etSpeed(id:int, speed0:float, speed1:float)` | 普通模式为首末层速；随机速度模式7/8中 speed1 为幅度。 | 继承；[专题](aim-modes.md) |
| 606 | `etCount(id:int, count:int, layers:int)` | 设置路数和层数；任一不为正时不发弹。 | 继承；[专题](aim-modes.md) |
| 607 | `etAim(id:int, mode:int)` | 设置发射模式0–12；几何、速度和创建顺序查模式表。 | 继承；[专题](aim-modes.md) |
| 608 | `etSound(id:int, fireSound:int, changeSound:int)` | 设置发射／变换音效编号；纯音效按公共口径省略。 | 社区；[专题](transcription-policy.md) |
| 609 | `etExSet(id:int, index:int, async:int, type:int, a:int, b:int, r:float, s:float)` | 指定 index 写 EX 记录并推进游标；async 为并行门，type 为效果值，a…n 查效果表。短式保留 c/d/m/n。 | 继承；[专题](ex-effects.md) |
| 610 | `etExSet2(id:int, index:int, async:int, type:int, a:int, b:int, c:int, d:int, r:float, s:float, m:float, n:float)` | 指定 index 写 EX 记录并推进游标；async 为并行门，type 为效果值，a…n 查效果表。 | 继承；[专题](ex-effects.md) |
| 611 | `etEx(id:int, async:int, type:int, a:int, b:int, r:float, s:float)` | 按追加游标写 EX 记录并推进游标；async 为并行门，type 为效果值，a…n 查效果表。短式保留 c/d/m/n。 | 继承；[专题](ex-effects.md) |
| 612 | `etEx2(id:int, async:int, type:int, a:int, b:int, c:int, d:int, r:float, s:float, m:float, n:float)` | 按追加游标写 EX 记录并推进游标；async 为并行门，type 为效果值，a…n 查效果表。 | 继承；[专题](ex-effects.md) |
| 613 | `etClearAll()` | 取消全场普通弹及激光；不清空发射器配置。 | 继承；[专题](aim-modes.md) |
| 614 | `etCopy(dst:int, src:int)` | 将 src 发射器配置及两组偏移复制到 dst；不复制单独 EX 追加游标。参数方向来自社区表及本地调用，复制范围已有本作证据。 | 继承；[专题](aim-modes.md) |
| 615 | `etCancel(radius:float)` | 以敌位置为中心的圆域消弹；各入口的 mode／保护过滤不同，完整本作取消消费者待核。 | 部分；[专题](aim-modes.md) |
| 616 | `etClear(radius:float)` | 以敌位置为中心的圆域消弹；各入口的 mode／保护过滤不同，完整本作取消消费者待核。 | 部分；[专题](aim-modes.md) |
| 617 | `etSpeedR3(etId:int, spd1l:float, spd1m:float, spd1h:float, spd2l:float, spd2m:float, spd2h:float)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 618 | `etSpeedR5(etId:int, spd1l:float, spd1ml:float, spd1m:float, spd1mh:float, spd1h:float, spd2l:float, spd2ml:float, spd2m:float, spd2mh:float, spd2h:float)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 619 | `etSpeedR2(etId:int, spd1l:float, spd1h:float, spd2l:float, spd2h:float)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 620 | `etCountR3(etId:int, cnt1l:int, cnt1m:int, cnt1h:int, cnt2l:int, cnt2m:int, cnt2h:int)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 621 | `etCountR5(etId:int, cnt1l:int, cnt1ml:int, cnt1m:int, cnt1mh:int, cnt1h:int, cnt2l:int, cnt2ml:int, cnt2m:int, cnt2mh:int, cnt2h:int)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 622 | `etCountR2(etId:int, cnt1l:int, cnt1h:int, cnt2l:int, cnt2h:int)` | 按动态 RANK 档位选择值，阈值未核；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 623 | `angleToPlayer(out:float&, x:float, y:float)` | 输出从指定 (x,y) 朝玩家的弧度角；按调用时点取样。 | 社区；[专题](aim-modes.md) |
| 624 | `etSpeedD(etId:int, spd1e:float, spd1n:float, spd1h:float, spd1l:float, spd2e:float, spd2n:float, spd2h:float, spd2l:float)` | 按难度 E/N/H/L 选择值；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 625 | `etCountD(etId:int, cnt1e:int, cnt1n:int, cnt1h:int, cnt1l:int, cnt2e:int, cnt2n:int, cnt2h:int, cnt2l:int)` | 按难度 E/N/H/L 选择值；etId 为发射器，先列第一字段各档值，再列第二字段各档值；spd为速度，cnt为路数／层数。 | 社区；[专题](mapping.md#35-游戏内变量与随机伪变量) |
| 626 | `etOffsetRad(id:int, angle:float, radius:float)` | 设置极坐标发射偏移；与603的合成顺序／状态关系仍按本作调用核。 | 社区；[专题](aim-modes.md) |
| 627 | `etDist(id:int, distance:float)` | 沿每弹出生方向再偏移 distance；与 ANIM 的4倍初速退位移合成。 | 继承；[专题](aim-modes.md#出生距离与anim退位移) |
| 628 | `etOffsetAbs(id:int, x:float, y:float)` | 设置绝对发射位置配置；与相对偏移的覆盖／合成细节未在本书完整核清。 | 社区；[专题](aim-modes.md) |
| 629 | `fog(r:float, color:int)` | r 为雾半径，color 为颜色。 | 社区；[专题](enemy-state.md) |
| 630 | `callSTD(switch:int)` | switch 为 STD 中断编号。 | 社区；[专题](enemy-state.md) |
| 631 | `lifeHide(time:int)` | time 为隐藏血条时长。 | 社区；[专题](enemy-state.md) |
| 632 | `funcSet(functionId:int)` | 安装逐帧回调；本作0清除、1使近玩家的EX_REACT弹跳到后续效果、2每帧清玩家主/季节火力。 | 本作一手；[专题](special-functions.md) |
| 633 | `flagExtDmg(state:int)` | state 为外部伤害开关；读哪个共享槽及执行顺序待核。 | 社区；[专题](enemy-state.md) |
| 634 | `setHitboxFunc(functionId:int)` | 选择特殊碰撞函数；函数号的本作几何含义需单独定义。 | 部分；[专题](enemy-state.md) |
| 635 | `etCancel2(radius:float)` | 以敌位置为中心的圆域消弹；各入口的 mode／保护过滤不同，完整本作取消消费者待核。 | 部分；[专题](aim-modes.md) |
| 636 | `etClear2(radius:float)` | 以敌位置为中心的圆域消弹；各入口的 mode／保护过滤不同，完整本作取消消费者待核。 | 部分；[专题](aim-modes.md) |
| 637 | `funcCall(functionId:int)` | 从同一函数表取回调并立即调用一次；本六面源未使用。 | 本作一手；[专题](special-functions.md) |
| 638 | `scoreAdd(n:int)` | n 为分数增量。 | 社区；[专题](enemy-state.md) |
| 639 | `funcSet2(functionId:int)` | 与632一样安装逐帧回调，另设敌字段`+0x451c=1`；此标志的后续用途未核，本六面源未使用。 | 本作部分；[专题](special-functions.md) |
| 640 | `etExSub(id:int, index:int, sub:str)` | 给指定 EX 记录设置程序名字符串；不等于普通同步 call。 | 社区；[专题](ex-effects.md) |
| 641 | `etExSubtract(id:int)` | 社区记为追加游标减1，最低0；本作边界行为未复核。 | 社区；[专题](ex-effects.md) |

## 激光

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 700 | `laserNew(id:int, initialLength:float, targetLength:float, lengthLimit:float, width:float)` | 配置初长、目标长度、Line路程裁剪参数和显示宽度；判定几何需换算。 | 继承；[专题](lasers.md) |
| 701 | `laserTiming(id:int, startup:int, expand:int, hold:int, shrink:int, flags:int)` | Infinite 四段时长与初始 flags；Curve 的 startup 槽为轨迹长度。 | 继承；[专题](lasers.md) |
| 702 | `laserOn(id:int)` | 生成 Line 并复制发射器 EX。 | 继承；[专题](lasers.md) |
| 703 | `laserStOn(id:int, laserId:int)` | 生成 Infinite，赋予可重复使用的源编号。 | 继承；[专题](lasers.md) |
| 704 | `laserOffset(laserId:int, x:float, y:float)` | 写激光原点及保存基点。 | 继承；[专题](lasers.md) |
| 705 | `laserTrajectory(laserId:int, x:float, y:float)` | 写附加向量；每tick从基点恢复后加一次，不是连续累加漂移。 | 继承；[专题](lasers.md) |
| 706 | `laserStLength(laserId:int, speed:float)` | 写长度增长速率，不是立即设置总长。 | 继承；[专题](lasers.md) |
| 707 | `laserStWidth(laserId:int, width:float)` | 写当前宽，随后可能被 phase 更新覆盖。 | 继承；[专题](lasers.md) |
| 708 | `laserStAngle(laserId:int, angle:float)` | 写绝对弧度角。 | 继承；[专题](lasers.md) |
| 709 | `laserStRotation(laserId:int, omega:float)` | 写每帧角速度，单位 rad/帧。 | 继承；[专题](lasers.md) |
| 710 | `laserStEnd(laserId:int)` | 取消并解除编号，遍历全部同编号实例。 | 继承；[专题](lasers.md) |
| 711 | `laserCuOn(id:int)` | 生成带轨迹历史的 Curve；当前用户明确暂缓。 | 继承；[专题](lasers.md) |
| 712 | `etCancelRect(width:float, height:float)` | 以敌位置取消矩形区域普通弹；不处理全部激光。 | 继承；[专题](lasers.md) |
| 713 | `unknown713(id:int, laserId:int)` | 进入 kind=3 分配路径；消费者未核。thecl 参数格式存在冲突，见资料说明。 | 部分；[专题](lasers.md) |
| 714 | `unknown714(laserId:int, value:int)` | 对对应实体调用控制入口，value 的具体含义未核。 | 部分；[专题](lasers.md) |

## 跨敌交互

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 800 | `enmCall(id:int, sub:str)` | 请求指定源敌切换程序；实际生效调度与取消范围按调用点核。 | 社区；[专题](enemy-state.md) |
| 801 | `enmPos(outX:float&, outY:float&, id:int)` | 查询源敌位置，写 outX/outY；查询失败行为未核。 | 社区；[专题](enemy-state.md) |
| 802 | `broadcastInterrupt(slot:int)` | 社区记为触发各存活 Boss 的对应中断槽；本作过滤与时序未完整核。 | 社区；[专题](enemy-state.md) |

## 调试与作品专用入口

| 编号 | 名字与参数 | 参数语义／直接作用 | 依据与专题 |
|---:|---|---|---|
| 900 | `debug900(p1:int)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 901 | `debug901()` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 902 | `debug902()` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 903 | `debug903(参数格式待核)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 904 | `debug904(p1:float)` | 参数含义及TH16行为待核；不从名字推断。 | 待核 |
| 1000 | `dropSeason(time:int, max:int, min:int)` | 敌被击破时的季节道具数从max在time帧内线性降到min；独立训练外壳不模拟掉落。 | Priw8 TH16；[口径](transcription-policy.md) |
| 1001 | `seasonItemDamage(damage:int)` | Boss每受damage点伤害掉一个季节道具；独立无敌外壳不模拟受伤掉落。 | Priw8 TH16；[口径](transcription-policy.md) |

## 资料与版本

助记名和条目范围按本机[Priw8 TH16 eclmap](https://github.com/Priw8/eclmap/blob/f146162e330c27d1b0a8880c3a41884615147a11/eclmap/th16.eclm)；参数参考[Priw8指令原始数据](https://priw8.github.io/js/ecl/ins.js)中的TH16项及继承项。本机map未命名的编号不等于游戏没有该指令；此表只列已命名范围。TH18另有1002–1020等专用条目，不归TH16。共同机制的详细配方来自TH18指南，原生地址和单卡证据只归TH18；TH16差异以本作资料和实际源调用为准。
