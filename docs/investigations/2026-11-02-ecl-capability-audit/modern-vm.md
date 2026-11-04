# 现代ECL VM、变量与敌人能力核对

本报告以 **TH16 v1.00a** 原生行为和当前 `stg-engine ENGINE_VER27` 源码为基准。只静态阅读，本轮未运行游戏、训练或原作对拍。浮点改定点的数值误差不降类别；时钟、分布、所有权、碰撞形状与帧相位仍决定类别。现有导入器及训练0.4.2 wheel未接新源码能力。

分类：1直接精准，2现有组合精准（必须满足列出的条件），3现有组合近似，4建议取舍，5缺少且对扩样关键。待核实用“待核”而非5。所有4类都是本轮新建议 `proposed`，需用户确认；不代表已经舍弃。

## 结论与优先缺口

- **可用地基**：普通数值运算、当前敌/自机坐标、每敌4int/8fx共享槽、有限静态call、整数正常时钟、固定难度和若干几何运算。2类的条件与操作步骤在下表和JSON逐组列出。
- **按当前扩样目标判断缺口**：固定rank、单段、敌无敌的躲弹卡，只需保留攻击内部实际影响发射与碰撞的行为。async ID取消仅在攻击内部控制发射源时是前置；浮点时钟/变速仅在所选攻击确有使用时是前置；非圆框仅在玩家实际需要避让敌接触框时阻塞精确几何。
- **完整战斗另议**：运行中HP、多段/超时/死亡中断、动态Rank随miss/bomb变化和炸弹伤害比例的能力缺口已核，但当前不训练炸弹，也不恢复完整战斗。没有样本证据证明其为当前固定rank单段无敌卡的关键前置，相关条目由5改为null，重要性待目标/样本确认；固定rank可以作为转换输入，单段终止可使用现有卡边界。
- **已有机制不等于原生等价**：每任务三类各4个插值值槽已存在；它们在任务执行前tick，不是原生循环末写回任意变量的8槽。每敌共享12槽已存在；当前spawn_enemy仍全零初始化，继承可在有限条件下用12实参和子sub初始化补齐。
- **社区表有版本错误**：TH16的89是角差一次规范化，非继承说明所说的乘法；561是死亡音效/ANM，566才调用Enemy__die。802广播遍历boss0..2且排除调用者boss槽，不能套用“所有boss”文字。均已从原exe raw-op→case表与对应反编译核对。

## 证据与版本边界

原生依据主要为renkolab TH16文档01/04/05/07和已有 `functions.jsonl`；本轮按函数名/地址只读提取。高位opcode由TH16 exe文件偏移 `0x22044 + raw_opcode`（VA `0x422c44 + raw_opcode`）读压缩case索引，再对 `EnemyData__ecl_run_over_300`（TH16 `0x41dcb0`）case；这一步只确定分派，必须继续阅读case及消费者才能判断行为。没有重跑命名脚本或开Ghidra。原始反编译留在忽略目录和/tmp，本文不复制。

社区清单使用本轮已解析继承的th16-inventory.json；命名表296个instruction。本领域取<600或≥800，并补18/19/20/41。非空网站说明也纳入，空占位和number=-1删除项不算已实现。网站的“继承自TH13/10”是文档继承，不能证明TH16实现相同。`01`文档开头把TH16误称鬼形兽是文案错误，本轮按文件/二进制版本TH16天空璋处理。

TH18仅另外使用其原生 `01-boss-interrupts-and-spellcard.md`和`02-item-drops.md`：8槽HP/超时中断、Spellcard对象和两个敌Timer有TH18自己的地址证据。TH18另有573覆盖timed_ex_drop、574设置窗口并复位计时的原生证据（`02-item-drops.md:300`、`:318`）；与TH16 573空操作不同，当前仅可脚本近似3。TH18中断能力差异已核，但完整战斗重要性同样待目标/样本确认，不是当前固定单段卡的必做前置。其他TH16行为不外推；TH18季节机制也不按TH16套用。

## 关键证据定位

| 用途 | 原生或我方证据 |
|---|---|
| 原生VM时间门、call、特殊系统码 | [TH16解释循环](/data/sunyunbo/www/renkolab/engine/ecl/th16/04-ecl-vm-interpreter.md:48)、[41与18/19/20](/data/sunyunbo/www/renkolab/engine/ecl/th16/04-ecl-vm-interpreter.md:156) |
| 原生变量与abs/rel/共享槽 | [变量字段图](/data/sunyunbo/www/renkolab/engine/ecl/th16/01-ecl-context-and-variables.md:33) |
| 原生创建与继承参数块 | [创建证据](/data/sunyunbo/www/renkolab/engine/ecl/th16/05-fire-interface.md:68)；TH16函数0x423050 |
| 本轮反编译核对 | functions.jsonl中0x472030、0x41dcb0、0x474430、0x4744e0、0x473bc0、0x471db0；每个JSON记录给对应JSONL行号 |
| 我方调度、调用和异步取消 | [vm.rs](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/vm.rs:179)、[取消域](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/vm.rs:433)、[任务帧相位](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/vm.rs:546) |
| 我方共享槽和创建清零 | [enemy_vars.rs](/data/sunyunbo/www/stg-engine/crates/stg-core/src/world/enemy_vars.rs:26)、[新敌初始化](/data/sunyunbo/www/stg-engine/crates/stg-core/src/ecl/syscall/enemy.rs:263) |
| 社区版本继承资料 | [TH16指令页](https://priw8.github.io/#b=modding/&p=ins&table=16)、[变量页](https://priw8.github.io/#b=modding/&p=vars)；本轮本地解析清单仅作社区来源，不替代原生case |

## 关键机制对照

| 机制 | TH16原生 | 当前实现与适用结论 |
|---|---|---|
| 同步call | 复制实参到新栈帧，保存time/PC/sub及栈基址；ret恢复 | 当前CALL只存PC，locals整任务共享；静态无递归调用可内联/编译分槽，≤64locals/32eval/8call时为2。动态递归与41用途待核 |
| async创建/ID | 同一敌的独立上下文；新节点前插；查ID从main哨兵起再遍历async，通常匹配最新同ID | 当前全局256任务池、次帧首跑、返回池索引。不能把ID当句柄；原生main的-1 ID可能参与查找，危险参数不列精准子集 |
| async取消 | 17终止同敌查到的上下文；21杀同敌异步列表 | kill_children仅当前任务直系，孙任务可分离；不覆盖原生每敌取消域，5 |
| script time | 时间门、跳转写time、wait减time；末尾加dt；call/ret保存恢复time | 当前wait为u16倒数。dt=1静态整数时间可转换2；waitf/变速一般行为5 |
| 三种变量寻址 | 指令mask决定字面量/引用；非负引用访问栈基址+偏移；特定负值是栈相对；其余负ID走敌的global读取器 | 不可把所有负数都当特殊变量；固定locals可编译降低，动态引用仍待核 |
| 12敌共享槽 | I0..3/F0..7内嵌敌对象，同敌main/async共用，创建时快照继承 | 当前self_int/fx明确存在且1；spawn默认清零，传12实参并子sub首部写回为条件2 |
| 敌龄/脚本龄 | time_alive不随513归零；time_in_ecl可归零；各运行上下文另有time | 当前self_age=$frame-task.born_frame，async新生会重置，不能直译敌龄。保存敌出生frame可覆盖dt=1子集 |
| 运动层 | abs/rel各PosVel，final合成；各层角速/圆半径可读 | 当前一份位置+速度，move_to接管且0时硬停；手工轨迹为3，不能把Rel理解成目标点加偏移后万事等价 |
| 插值相位 | 91/92启动写初值，VM循环末推进并回写目标，wait期间也继续 | 当前tick在born/owner门后且exec前，三类各4槽、显式读值，无自动左值写回。等待期间共享变量可见相位不同，3 |
| 碰撞框 | 500/501宽高独立；563椭圆/矩形；564旋转 | 当前接触半径/受击半径二圆；正圆子集可用，一般框5 |
| 主sub结束 | main上下文结束导致敌静默消失；async结束仅自身消失 | spawn_enemy登记main_task且本帧无活async时OP_END同语义1；有async时当前DYING标记到相位9才回收，后续任务可能仍跑，列3；binding根入口也不在精准条件内 |
| 死亡/中断 | 阈值、超时、death sub和跨敌重置；800清目标全部async，802跳其他boss中断 | death_script目前只入事件，没有执行回调；spell_begin/end不能替代通用敌中断。恢复完整战斗/多段时才需评估；当前固定单段无敌卡不被阻塞，重要性待核 |
| ANM | 可读slot状态，某加载case缓存动画尺寸，独立ANM可在敌消失后继续 | 纯外观有条件建议4；凡影响框、脚本或回调不能一起删。set_anm_state不是ANM VM |

源路径与精确行号在JSON每条engine_refs/original_refs；后续源码变动应重核行号。原生18/19/20写而未发现读的结论来自既有逆向文档，不宣称本轮重跑全.text消费者扫描。

## 五类逐组表

以下每行逐编号展开覆盖，多个行为子集可重复出现。2类配方只在“条件”成立时精准；未满足不自动归2。

| 编号及名称 | 类别 | 行为、条件与配方/差异 |
|---|---|---|
| 0 nop、22 debug22、27 unknown27、30 unknown30、31 unknown31、573 unknown573、900 debug900、901 debug901、902 debug902、903 debug903、904 debug904 | 2 | TH16正式版空操作；27被游戏分派范围闸拒绝，573/900..904落默认case。 条件：只保留执行时序；不需要模拟调试菜单；转换后同帧执行量须不超现有任务/全局指令预算。 配方：转换时不发副作用指令，保留原指令时间/难度门。 |
| 1 delete | 1 | 终止当前运行上下文；若为敌主上下文，宿主使敌静默退场。 条件：以spawn_enemy建立并登记main_task的敌主任务；非根binding入口；该帧无仍会运行的同敌async；不触发击破掉落。 配方：当前OP_END；非主任务仅结束自身。 |
| 10 ret、11 call、40 stackAlloc、42 pushi、43 seti、44 pushf、45 setf | 2 | 同步调用、返回、局部/表达式栈取写：有限静态程序可在编译时分配不同槽。 条件：调用图静态且不递归；展开后的locals≤64、求值栈≤32、同步深度≤8；普通整数时钟且无跨调用活动的指令91/92；空栈ret需转END；转换后同帧执行量须不超现有任务/全局指令预算。 配方：为每个活跃调用点分独立locals区；调用前复制实参到被调区；ret回正确续点；caller局部不覆盖；将各sub时间门展开为相对wait，必要时把非递归调用内联。 差异：这是编译转换配方，当前CALL只存返回PC，直接照抄原字节码不成立。 |
| 40 stackAlloc、41 native41 | 待核 | 原生栈帧分配/回收与typed stack-relative引用。41只做栈回收，不执行10的PC/时间恢复。 41用途与合法嵌套模式未完整核验；动态偏移、递归及负栈引用不能仅按固定locals重命名证明准确。 |
| 12 jmp、13 jmpEq、14 jmpNeq、23 wait | 2 | 跳转同时写脚本时间；wait通过扣减脚本时间推迟后续时间门。 条件：正常dt=1、整数延迟在0..65535；静态时间标签可消除，且分支/回跳均已分析成等价wait；不含改变gameSpeed；转换后同帧执行量须不超现有任务/全局指令预算。 配方：把标签的time连同PC纳入转换；沿每条控制流边计算下一次到期帧，发wait差值后jmp；if非零使用两次JZ或交换分支；不能仅丢掉jmp第二时间参数。 |
| 24 waitf、547 gameSpeed | 5 | 浮点wait和GAME_SPEED决定上下文时间增量，含不足一帧的到期相位。 条件：需真实脚本时钟；浮点/定点数值差异豁免不包括把子帧等待四舍五入。 配方：无一般等价接口；整数dt=1子集见clock-control。 差异：当前wait是u16帧倒数；无世界GAME_SPEED对应。 |
| 15 callAsync | 3 | 同一敌人上创建独立上下文，继承难度掩码，参数复制且上下文挂敌人链表。 配方：使用spawn传实参；owner维持同敌；按已知样本校正首次执行帧。 差异：原作链表调度与当前全局池升序/出生次帧门不同；不能保证任意动态spawn同帧读写顺序。 |
| 16 callAsyncId、17 killAsync、21 killAllAsync | 5 | 异步ID在同一敌人的上下文链中查找；17取先匹配项，21遍历敌人异步列表。 条件：重复ID采用链表最近插入者；ID不是任务池索引；main与async取消域需区分。 配方：当前spawn只返池索引，kill_children只杀当前任务直系；不能替代每敌按用户ID查找和全async清理。 差异：跨async产生的孙任务仍属于同一敌人的原作取消域。 |
| 18 native18、19 native19、20 native20 | 4 | 按ID写另一异步上下文的+0x11e4位/+0x101c字段；既有原生调查未发现TH16消费者。 条件：仅TH16；“未发现读取点”不是全版本无效证明。 配方：建议转换为无副作用操作；保留ID参数解析产生的其他求值效果。 |
| 50 addi、51 addf、52 subi、53 subf、54 muli、55 mulf、56 divi、57 divf、58 modi、59 eqi、60 eqf、61 neqi、62 neqf、63 lessi、64 lessf、65 leqi、66 leqf、67 greateri、68 greaterf、69 geqi、70 geqf、79 stackSin、80 stackCos、83 negi、84 negf | 1 | 标量加减乘除余、比较、三角和取负；浮点参数改用fx，角度改BAM。 条件：输入在当前数值表示有效域内；除数非0、无整数溢出；角度单位转换；本轮按约定不因数值精度降级。 配方：对应ADD/SUB/MUL/DIV/MOD、MULF/DIVF、EQ..GE、SINB/COSB、NEG。 |
| 71 noti、72 notf、73 or、74 and、78 deci | 2 | 逻辑取反/或/与与先取旧值再自减。 条件：操作数先全部按原顺序求值，不能新增短路而漏RNG等副作用；转换后同帧执行量须不超现有任务/全局指令预算。 配方：not: v==0；or: (a!=0)+(b!=0)>0；and:两布尔相乘；dec:先存旧值再v=v-1并返回旧值。 |
| 75 xor、76 bit_or、77 bit_and | 2 | 整数逐位异或/或/与的单比特子集。 条件：两个已求值操作数均在{0,1}并存于locals；结果存入locals；该调用点本帧的任务与全局预算均至少剩6条VM指令。 配方：xor: a!=b；or: a+b>0；and: a*b。or可降为PUSHL(a)、PUSHL(b)、ADD、PUSHI(0)、GT、POPL(out)，共6条；xor/and各4条。 |
| 75 xor、76 bit_or、77 bit_and | 待核 | 一般32位整数逐位异或/或/与。 算术分解32个位是候选方案；尚未落地并核算完整求值、符号位、循环与写回指令数，不能确认在现有1024条单任务预算内同帧完成；不据此宣称一般32位为2类。 |
| 81 circlePos、82 validRad、85 squareSum、86 squareSumRoot、87 getAngle、89 linearFunc、90 pointRotate | 2 | 圆坐标、角度规范化、平方和、向量长度、两点角、角差及点旋转。89原生是角差并作一次±2π调整，非社区继承描述的乘法。 条件：89输入为规范化角；单位/值域可表示；两输出先算完再赋值以免引用别名破坏；转换后同帧执行量须不超现有任务/全局指令预算。 配方：81=(r*cos(a),r*sin(a))；82转BAM规范化；85=x*x+y*y；86=dist(x,y)；87=atan2(y2-y1,x2-x1)；89=b-a后按原判据±整圈；90=(x*cos(a)-y*sin(a),y*cos(a)+x*sin(a))。 |
| 88 stackSqrt | 待核 | 浮点栈元素开方。 现有dist为sqrt(x*x+y*y)，不是通用sqrt(x)接口；本轮未确认表层可操作等价降低及负输入规则。 |
| 91 floatTime、92 math92 | 3 | 每运行上下文8个浮点插值器，启动即写初值，循环末推进并写回指定变量。92另带两附加参数。 条件：91常规曲线可手算；92附加参方向/曲线需按TH16补核。 配方：保留每槽目标和值，以ease/Hermite读值后显式写回；每帧执行一次，并为共享变量安排单一写者。 差异：当前三类各4槽为每任务私有值槽，执行前tick；没有8个任意左值写回器。wait期间写回、同帧其他async读取相位及容量均不同。 |
| 93 math93 | 3 | 原生取两次signed随机浮点，一次定角，一次线性定有符号半径，再转平面点；不能改成面积均匀圆盘。 配方：以rand构造两次有符号取值，角乘π，半径按原式r=signed*(max-min)+min，再cos/sin。 差异：现有RNG族/取样格点与原生流未逐项对齐；随机分布与抽取顺序不列入浮点豁免。 |
| 300 enmCreate、301 enmCreateA、304 enmCreateM、305 enmCreateAM、309 enmCreateF、310 enmCreateAF、311 enmCreateMF、312 enmCreateAMF、321 enmMapleEnemy | 3 | 分配新敌并按名起主sub；相对/绝对坐标和镜像变体；F族在boss0存在时不创建；复制父敌12数值槽及父ID等参数。 配方：spawn_enemy传坐标/生命/掉落和子主任务；相对坐标显式加self位置；镜像显式改x和方向；F条件由场景已知boss生命周期约束；12值以实参带入子任务初始化。 差异：新敌槽当前全零；需显式复制且出生当帧不能保证原生调度/外部观察一致；现有固定池容量和原生可调上限不同。 |
| 302 anmSelect、303 anmSetSprite、306 anmSetMain、307 anmPlay、308 anmPlayAbs、313 anmSelectedPlay、314 anmPlayHigh、315 anmPlayRotate、316 anm316、317 anmSwitch、318 anmReset、319 anmRotate、320 anmMove、323 deathAnm、325 anmColor、326 anmColorTime、327 anmAlpha、328 anmAlphaTime、329 anmScale、330 anmScaleTime、331 anmAlpha2、332 anmAlpha2Time、333 anm333、334 anm334、335 anmScale2、336 anmLayer、337 anmBlendMode、338 anmPlayPos、339 anm339 | 4 | 选择/加载/独立播放ANM，修改附着位置、颜色、alpha、scale、层和混合；317向动画树发中断。 条件：仅在逐样本证实这些指令不影响碰撞框、位置、回调、存活/脚本分支时；303/306可缓存动画尺寸，-9961可读ANM状态，不能无条件删。 配方：建议对纯外观子集省略；若样本读取ANM状态或借尺寸设判定，先提取语义，不能以set_anm_state冒充完整ANM VM。 差异：当前仅sprite+anm_state公告板，不是原作动画VM。 |
| 324 enm324、555 enmAlive、801 enmPos | 2 | 按原生enemy_id查询存活/坐标；324查不到时退回调用者坐标，801缺失目标没有该兜底。 条件：导入器持有原生ID到当前打包句柄的映射，目标有效；555含dying时刻须按样本核对，仅一般存活子集；转换后同帧执行量须不超现有任务/全局指令预算。 配方：spawn_enemy返回句柄后保存到get_var/set_var的静态ID对应槽；801=enemy_x/y；324在enemy_alive为0时返回self_x/y。 差异：不得把原生ID整数直接作为当前含generation的句柄。 |
| 340 enmDelete | 待核 | 按原生ID将目标敌标为退场。 当前没有公开按任意句柄静默删除单敌的接口；kill_self只终止当前任务，kill_all范围过大；本轮未把缺该接口直接判数据扩充关键。 |
| 400 movePos、401 movePosTime、402 movePosRel、403 movePosRelTime、404 moveVel、405 moveVelTime、406 moveVelRel、407 moveVelRelTime、418 moveAdd、419 move419、424 moveSetMirror、427 moveReset、428 moveVelNM、429 moveVelNMTime、430 moveVelNMRel、431 moveVelNMRelTime、436 moveAddTime、437 moveAddRelTime、440 moveAngle、441 moveAngleTime、442 moveAngleRel、443 moveAngleRelTime、444 moveSpeed、445 moveSpeedTime、446 moveSpeedRel、447 moveSpeedRelTime、558 flagMirror | 3 | 原生各有绝对/相对PosVel运动层；位置/速度/朝向/速率的立即和定时写入、增量/非镜像和镜像开关。 配方：单层非镜像用move_to/move_vel/move_angle/move_speed；双层手存两层状态后按帧合成位置，镜像在写坐标/角度处显式处理。 差异：当前一份位置和速度，位置插值接管而非两PosVel相加；move_to(0)清速度和在飞插值，原生400/402写位置并更新最终位置不能据此宣称硬停等价；转角最短弧及帧相位需逐样本核。 |
| 408 moveCircle、409 moveCircleTime、410 moveCircleRel、411 moveCircleRelTime、412 moveRand、413 moveRandRel、414 moveBoss、415 moveBossRel、416 movePos3d、417 movePos3dRel、420 moveEllipse、421 moveEllipseTime、422 moveEllipseRel、423 moveEllipseRelTime、425 moveBezier、426 moveBezierRel、432 moveEnm、433 moveEnmRel、434 moveCurve、435 moveCurveRel、438 moveCurveAdd、439 moveCurveAddRel | 3 | 圆/椭圆、Bezier/曲线、随机Boss移动、3D及依敌位置等现代运动变体。 条件：曲线/圆周可逐帧计算二维轨迹；随机Boss分支和依敌目标需保留原生条件；3D深度只可投影近似。 配方：用sin/cos/ease/Hermite计算每帧位置后move_to(0,x,y,linear)；跨层状态分别保留，不用单个插值槽覆盖两层。 差异：坐标能拟合不等于速度/角度/半径读值、镜像和发射相位都一致；原生moveRand按位置边界和自机侧多次抽样，不可改均匀选点。 |
| 500 setHurtbox、501 setHitbox、563 unknown563、564 hitboxRotate | 5 | 分别写受击框/接触框宽高；563切矩形/椭圆模式，564写框旋转角。 条件：正圆子集可用现有半径；宽高不等及旋转矩形不能一个r准确表达。 配方：圆形子集分别set_hurtbox/set_hitbox；一般宽高框无现有精确接口。 差异：引擎敌池/碰撞接口只有两个圆半径，形状/旋转缺失；外接圆会改变可穿空隙。 |
| 502 flagSet、503 flagClear | 3 | 置/清敌状态位；部分标志同时影响动画。 条件：仅映射已知NO_BODY/KILLALL_EXEMPT位，其余位不能原样传递。 配方：原生位翻译到本引擎SETTABLE掩码再调用set_enemy_flag。 差异：当前公开可写仅两位，原生位域含镜像/无敌/矩形/敌生命周期等，不能整体等同。 |
| 504 moveLimit、505 moveLimitReset | 3 | 设置/取消位置约束区域，含原生flag开关。 配方：脚本按帧将拟定坐标clamp到边界后move_to。 差异：当前无每敌常驻移动约束；与速度层/发射同帧的执行相位须由脚本近似，碰边时速度语义未证等价。 |
| 506 dropClear | 3 | 清空待掉落配置中的额外项，原生保留特定主项。 配方：drop_clear后重加应保留的主掉落。 差异：当前清空全部计数，且主项/季节项布局和数量上限不同。 |
| 507 dropExtra、508 dropArea、509 dropItems、510 dropMain、562 dropItemsSp、1000 dropSeason、1001 seasonItemDamage | 3 | 配置/生成道具及散布；1000随击破时间衰减季节点数，1001按累计伤害生成季节点。 配方：用drop_add/drop_items/drop_item表达已有道具类型；脚本记录出生帧并按伤害/时间估计掉落数量。 差异：原生季节点、奖励衰减、伤害累计触发和spell practice门不同；当前计数增量钳u8，无TH16季节资源系统。 |
| 511 lifeSet、572 lifeNow | 待核 | 511同步写current/max/段生命等，572仅写当前HP及其7倍缓存。 条件：适用目标：恢复完整战斗或全关卡；当前固定rank、单段、敌无敌的躲弹卡不被此项阻塞。创建时hp可给定；运行中改生命及分段阈值需真实语义。 配方：spawn_enemy只覆盖初始化；无一般运行中lifeSet/lifeNow公开写口。 原生行为及当前缺少通用对应机制的能力事实已核；尚无证据证明它是当前扩充固定rank单段无敌躲弹卡的关键前置，因此重要性待用户目标/样本确认，暂不列5类必做建议。 |
| 512 setBoss | 3 | 设置/取消boss编号并登记到敌管理器boss表。 配方：boss_set填写公告板槽；配现有spell_begin建立攻击任务。 差异：当前UI槽/符卡绑定不是原生boss_id表，原生变量boss0、802广播与Boss等待不能仅靠UI登记推出。 |
| 513 timerReset、514 setInterrupt、521 setTimeout、556 setDeath、566 unknown566、800 enmCall、802 broadcastInterrupt | 待核 | 敌脚本计时重置；HP/超时中断；设置death sub；566执行死亡逻辑；800按敌ID清async并重置/加载主sub；802遍历boss0..2，排除调用者boss槽并触发有效中断。 条件：适用目标：恢复完整战斗或全关卡；当前固定rank、单段、敌无敌的躲弹卡不被此项阻塞。中断覆盖主+全部async，保留敌对象共享状态；TH16 802不包含自身boss槽。 配方：现有spell_begin/end只能组织自己的符卡任务，不能替代任意敌重入/HP阈值/timeout/death回调。 差异：当前death_script字段仅记录进死亡事件，未见启动执行；按句柄重置某敌上下文及8槽阈值无公开实现。 原生行为及当前缺少通用对应机制的能力事实已核；尚无证据证明它是当前扩充固定rank单段无敌躲弹卡的关键前置，因此重要性待用户目标/样本确认，暂不列5类必做建议。 |
| 515 setInvuln | 3 | 写受击无敌倒计时。 条件：非负u16帧、正常速度；仅对应受击门，不代替541接触框禁用。 配方：set_invuln(frames)。 差异：无敌计时写入接口存在；原生Enemy tick内受伤结算与当前相位2写/相位5减/后续碰撞的边界未逐帧核对，先保留可能一帧边界差。 |
| 541 noHitboxDur | 2 | 写no-hitbox计时器，临时禁用接触判定。 条件：只使用明确接触NO_BODY位，原位已设状态由脚本保存；frames正常整数；独立协程不同时覆盖此位；转换后同帧执行量须不超现有任务/全局指令预算。 配方：set_enemy_flag(NO_BODY,1)，等待n帧后恢复原位；不使用set_invuln代替。 |
| 516 playSound、517 setScreenShake、527 lifeMarker、540 stars、552 zIndex、553 hitSound、554 stageLogo、557 fogTime、561 die | 4 | 音效/震屏/血条标记/星标/层号/Logo/雾；TH16 561仅执行死亡音效和ANM路径，实际Enemy__die在566。 条件：只有纯表现与UI子集；出现脚本回读或影响判定时需另审。 配方：建议训练侧省略对应外观；561不能译成当前die()，否则提前结束敌并产生掉落。 差异：外观系统未完整复刻。 |
| 518 dialogRead、519 dialogWait、520 bossWait | 3 | 启动对话并清场；等待对话/等待boss消失门。 配方：独立攻击片段可将入口前清场/等待裁切成明确起点；完整关卡可由stage脚本轮询已知boss句柄。 差异：原生518还调用清弹与kill_all；对话不是纯表现nop；没有原生GUI门或boss0..2表的通用对应。 |
| 522 spellEx、523 spellEnd、528 spellUnused、537 spell、538 spell2、539 spell3、542 spellTimeout、543 unknown543、567 unknown567、568 spellMode | 3 | 符卡宣言/结束、耐久和奖励/伤害状态。原生多个宣言号共case，含随难度调整卡号。 配方：spell_begin/spell_end表达当前符卡；难度卡号在转换时计算；耐久以时间限制和现有胜负系统组织。 差异：原生Spellcard奖励/档案/伤害减免与敌中断互相独立；当前统一符卡任务生命周期不等同所有状态位。 |
| 529 rankF3、530 rankF5、531 rankF2、532 rankI3、533 rankI5、534 rankI2 | 待核 | 按动态RANK离散选值或连续插值，RANK与Easy/Normal/Hard/Lunatic不是同一量。 条件：适用目标：恢复完整战斗或全关卡；当前固定rank、单段、敌无敌的躲弹卡不被此项阻塞。可离线固定RANK只覆盖单一rank切片。 配方：已知固定RANK可编译常量；一般运行时动态rank缺少世界状态来源。 原生行为及当前缺少通用对应机制的能力事实已核；尚无证据证明它是当前扩充固定rank单段无敌躲弹卡的关键前置，因此重要性待用户目标/样本确认，暂不列5类必做建议。 |
| 535 diffI、536 diffF、548 diffWait | 2 | 按当前难度选整数/浮点参数或等待时长。 条件：按配置分别转换四种难度；Extra等值另设固定输入；选值本身不依赖动态RANK；转换后同帧执行量须不超现有任务/全局指令预算。 配方：每个难度构建相应表达式/等待值；若参数有求值副作用，保留原生先求值顺序。 |
| 525 enmKillAll | 3 | 调用敌管理器清除群敌，需遵循原生豁免与退场规则。 配方：kill_all_enemies(KILL_SILENT/DIE)并映射豁免标志。 差异：两套敌flags及死亡回调范围未等同，不能只凭函数名判断模式。 |
| 526 etProtectRange | 待核 | 写该敌发射时使用的自机附近保护半径，601将其临时传入弹管理器。 依赖发射器领域对601原生spawn抑制与当前shooter接口的专项核对；本VM报告不将参数存在当成已实现。 |
| 545 laserCancel | 待核 | 原生派发case0x56调用全激光取消函数。 取消范围、各激光状态及转道具规则由modern-bullets报告核对；不因当前有laser_clear就先判精准。 |
| 546 bombShield、565 bombInvuln | 待核 | 写炸弹护盾开关/参数与受炸弹伤害比例。 条件：适用目标：恢复完整战斗或全关卡；当前固定rank、单段、敌无敌的躲弹卡不被此项阻塞。原生565可含负值回血，set_invuln只提供二值门。 配方：没有对应可编程伤害比例口；不得以固定无敌帧替代比例。 原生行为及当前缺少通用对应机制的能力事实已核；尚无证据证明它是当前扩充固定rank单段无敌躲弹卡的关键前置，因此重要性待用户目标/样本确认，暂不列5类必做建议。 |
| 559 enmLimit | 3 | 写敌管理器可生成敌人上限。 配方：脚本维护自身已知生成/退场计数，在spawn前检查所需上限；当前池cap仍是硬上限。 差异：不能覆盖不经该脚本创建的敌或超池容量的原生场景。 |
| 322 enm322 | 待核 | 按ANM槽索引写辅助数组，消费者待查 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 524 setChapter | 待核 | 章节/关卡状态相关写入，完整副作用待查 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 544 unknown544 | 待核 | 写敌flag bit27 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 549 unknown549 | 待核 | 写敌flag bit31 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 550 unknown550 | 待核 | 写敌数据+0x278字段 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 551 unknown551 | 待核 | 调用0x41da30辅助函数 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 560 unknown560 | 待核 | 向派发时取得的目标结构+0x48/+0x4c写浮点 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 569 unknown569 | 待核 | 调整章节出生数计数 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 570 unknown570 | 待核 | 按章节条件累加击破数 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 571 unknown571 | 待核 | 调用未展开辅助函数 已核TH16派发存在，但字段消费者/完整模式或引擎映射不足；暂不推为5类。 |
| 400 movePos、404 moveVel、428 moveVelNM、440 moveAngle、444 moveSpeed | 1 | 单一绝对层的立即位置/极坐标速度/朝向/速率写入，可用现有运动接口直接表达。 条件：rel层恒零，无mirror或原生skip-argument哨兵，无正在运行的位置/速度插值；400另要求原速度为零；两端都在本帧运动积分前执行；正常参数范围。 配方：400=>move_to(0,x,y,linear)；404/428=>move_vel(0,angle,speed,linear)；440=>move_angle(0,angle,linear)；444=>move_speed(0,speed,linear)。 |
| 1 delete | 3 | 主上下文结束与同敌异步任务同时存在时的退场相位。 配方：尽可能在结束主sub前由脚本通知已知async停止；不把未知后代混进kill_children。 差异：当前main自然End只标ENEMY_DYING，owner门只检查槽存活；本帧后续同敌任务仍可能跑到相位9回收。原生main返回非0立即退出该敌上下文遍历。 |

## 特殊变量逐ID登记

数值为原生负ID；完整逐项证据和条件见JSON。网站继承但尚未逐case确认的变量保留待核，尤其Double Spoiler遗留名、-9905跨作说明和-9906网站自带的版本疑问。

| ID/名称 | 类别 | 语义与转换边界 |
|---|---|---|
| -9985 I0、-9984 I1、-9983 I2、-9982 I3、-9981 F0、-9980 F1、-9979 F2、-9978 F3、-9935 F4、-9934 F5、-9933 F6、-9932 F7 | 1 | I0..I3/F0..F7是每敌共享槽，同敌main/async互通，与每调用locals不同。 只判同敌读写；继承另列。 I0..3=>self_int/set_self_int(0..3)；F0..7=>self_fx/set_self_fx(0..7)。 |
| -9997 FINAL_X、-9996 FINAL_Y、-9977 FINAL_X2、-9976 FINAL_Y2 | 1 | 敌最终二维位置及其别名。 当前owner是该敌；原生坐标系须转换；不据此宣称abs/rel层已有。 self_x/self_y。 |
| -9991 PLAYER_X、-9990 PLAYER_Y、-9965 PLAYER_X2、-9964 PLAYER_Y2 | 1 | 自机坐标及其别名。 单人，按原作目标自机配置为players[0]。 player_x/player_y。 |
| -9989 ANGLE_PLAYER、-9944 DIST_PLAYER | 2 | 从敌最终位置到自机的角度/距离。 单人；差值在fx范围内；转换后同帧执行量须不超现有任务/全局指令预算。 atan2(player_y-self_y,player_x-self_x)；dist(dx,dy)。 |
| -9954 LIFE | 1 | 敌当前生命。 self_hp。 |
| -9957 TRUE | 2 | 常量真。 ；转换后同帧执行量须不超现有任务/全局指令预算。 发字面整数1。 |
| -9959 DIFF、-9953 EASY、-9952 NORMAL、-9951 HARD、-9950 LUNATIC | 2 | 难度枚举和四个相等谓词。 每难度独立构建脚本/输入常量，不误用动态rank；转换后同帧执行量须不超现有任务/全局指令预算。 固定difficulty值及其==0/1/2/3。 |
| -10000 RAND、-9999 RANDF、-9998 RANDRAD、-9987 RANDF2 | 3 | 原作RNG的整数、单位、有符号和弧度取样。 rand(n)并缩放到对应区间，保持每次读取都抽新值。 PRNG流、整数取样范围和分布未对齐，不因数值豁免跳过分布验证。 |
| -9988 TIME | 2 | 敌已存活时间，不是当前任务的age，也不是可被513重置的脚本time_in_ecl。 敌出生帧显式传入全部async且跨主sub切换保留；dt=1；必须明确采样相位；转换后同帧执行量须不超现有任务/全局指令预算。 在创建时保存$frame为共享初值或任务实参；所有读取=$frame-enemy_birth_frame，避免现有self_age()直接替代。 |
| -9995 ABS_X、-9994 ABS_Y、-9993 REL_X、-9992 REL_Y、-9975 ABS_X2、-9974 ABS_Y2、-9973 REL_X2、-9972 REL_Y2、-9971 ABS_ANGLE、-9970 REL_ANGLE、-9969 ABS_SPEED、-9968 REL_SPEED、-9967 ABS_ORIGIN_DIST、-9966 REL_ORIGIN_DIST、-9958 FINAL_ANGLE、-9956 ABS_ANGLE_PLAYER、-9955 REL_ANGLE_PLAYER | 3 | 绝对/相对运动层的坐标、角、速度、圆半径与朝自机角。 转换脚本维护两层状态，合成坐标后写当前单层敌位置；读值从各自脚本变量取。 当前self_angle/self_speed只有单份运动状态，近零朝向回填还有阈值；并发写层及同帧观察相位未保证。 |
| -9960 RANK | 待核 | 动态Rank，随游戏进度与miss/bomb变化。 适用目标：恢复完整战斗或全关卡；当前固定rank、单段、敌无敌的躲弹卡不被此项阻塞。 原生行为及当前缺少通用对应机制的能力事实已核；尚无证据证明它是当前扩充固定rank单段无敌躲弹卡的关键前置，因此重要性待用户目标/样本确认，暂不列5类必做建议。 |
| -9926 GI0、-9925 GI1、-9924 GI2、-9923 GI3、-9922 GF0、-9921 GF1、-9920 GF2、-9919 GF3、-9918 GF4、-9917 GF5、-9916 GF6、-9915 GF7 | 2 | 管理器级全局4int/8float槽，跨敌共享。 可用共享var槽预留12个，其他脚本不占用；完整编号空间统一重命名；转换后同帧执行量须不超现有任务/全局指令预算。 I/GF映射到独立get_var/set_var槽；float按fx传raw，禁止与敌槽/局部槽混用。 |
| -9943 BI0、-9942 BI1、-9941 BI2、-9940 BI3、-9939 BF0、-9938 BF1、-9937 BF2、-9936 BF3、-9963 BOSS_X、-9962 BOSS_Y、-9911 ANGLE_BOSS、-9910 SPEED_BOSS | 待核 | boss0的共享槽与最终位置/移动角速。 现有self_int/fx不能按任意敌句柄读取；可由boss主动镜像到全局槽的静态子集有候选方案，但未核原生读时序与boss0不存在时的返回。 |
| -9931 LAST_ENM_ID、-9914 ID、-9909 UNKNOWN9 | 2 | 最后生成敌ID、自身ID和父敌ID。 静态/有界ID映射；数值只作身份与查找，不依赖原生分配器具体递增值；原生父ID含义仍按变量读取器核；转换后同帧执行量须不超现有任务/全局指令预算。 保存spawn_enemy句柄，子任务显式传parent句柄；self_enemy读当前句柄；编号表用于801/555转换。 |
| -9986 TIMEOUT | 待核 | 敌超时标志；不等于当前spell_result 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9961 ANM_ID | 待核 | ANM slot0状态，可被ECL读取，不能随ANM外观一并无条件删 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9949 MISS_COUNT | 待核 | 局内miss累计 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9948 BOMB_COUNT | 待核 | 局内bomb累计 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9947 CAPTURE | 待核 | 收符资格标志 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9946 ENM_CNT_REAL | 待核 | 含特殊敌的存活敌数量 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9945 SHOTTYPE | 待核 | 机体shot类型 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9930 POWER | 待核 | 自机火力 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9929 DS1 | 待核 | 继承网站表列出的特殊变量；本作含义/消费者尚未完成原生核对。 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9928 DS2 | 待核 | 继承网站表列出的特殊变量；本作含义/消费者尚未完成原生核对。 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9927 DS3 | 待核 | 继承网站表列出的特殊变量；本作含义/消费者尚未完成原生核对。 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9913 DS_PHOTOCOUNT | 待核 | 继承网站表列出的特殊变量；本作含义/消费者尚未完成原生核对。 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9912 DS4 | 待核 | 继承网站表列出的特殊变量；本作含义/消费者尚未完成原生核对。 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9908 ENM_CNT | 待核 | 可击破敌数量 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9907 SPELL_ID | 待核 | 符卡ID 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9906 MIRROR | 待核 | 镜像标志，网站自己标版本待核 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9905 unnamed-9905 | 待核 | 章节相关值，描述指向TH17，不作为TH16原生定论 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9904 MISS_COUNT_GLOBAL | 待核 | 全局miss累计 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |
| -9903 SUBSEASON | 待核 | TH16所选副季枚举 需逐case核TH16读取来源、作用域及无对象返回；当前没有已确认等价公开ECL读口，未知不自动归5。 |

## 待核与未验证

炸弹伤害、动态rank完整演化、一般HP/多段和通用中断虽已核能力差异，其对当前固定rank单段无敌卡的重要性待目标/样本确认，不列必做前置。一般32位75/76/77的同帧预算尚未证明，已另列待核；2类仅限上述有明确指令数的单比特子集。未知编号322/524/544/549/550/551/560/569/570/571等已确认有分派，但字段消费者或完整副作用未核完，保持null。41的栈清理用途、92附加参数、88通用sqrt降低、各运动模式的同帧相位及完整中断阈值路径需继续核；526/545依赖弹幕报告，未在本领域抢先判精准。

所有2类是静态表达能力判断，尚未接入导入器、未生成完整转换器实现，也没有本轮动态等价证明。类别3的逐帧轨迹配方不能据此当作已验证卡。4类需用户确认；5类只是调研建议，不是实施或架构批准。

实际执行：只读Python解析清单、functions.jsonl和原exe case映射；读取当前Rust源码。产出后执行JSON解析、领域opcode/变量覆盖、类别字段与路径行号检查。没有跑pytest、训练、游戏或浏览器流程，这些不属于本轮资料调研验收。

本领域基准 243 个instruction编号，JSON全部覆盖；特殊变量 98 个负ID全部登记。instruction记录类别统计（允许同编号按子集重复）为 {2: 9, 1: 3, None: 20, 5: 3, 3: 17, 4: 3}。

复核命令：`python /tmp/sunyunbo/check-modern-vm-audit.py`。结果见91条记录、243个TH16指令编号、98个TH16变量ID；证据路径与行号均有效。
