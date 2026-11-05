// th06_s7_b1 —— 东方红魔乡 Extra（Stage 7）boss 芙兰朵露 非符 1
// 原文：ecldata7.ecl.txt Sub38（行 873–924），Sub37 用 enemy_interrupt_set(Sub38) 切入；
//       timer_callback_threshold(1800) 收段。Extra 档（ranks [4,4]），无难度分叉。

const TIME_LIMIT: int = 1800;
const RICE: int = 64;          // TH06 弹型 2 RICE（mapping §3）

// bullet_* flags 0x1 出生冲刺：出生 16 帧内额外速度 5 → 0 线性衰减（mapping §5）
// 原文 bullet_circle(..., 513) 的 513 = 0x200(音效，丢弃) | 0x1(冲刺)
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// Sub38 move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160, 48)-(160, 120)
// 与 mapping §7.3 的 boss 随机游走同构：move_rand_in_bounds(-π,π) + move_speed + move_time_decelerate
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
    var v: int = rand(65536);              // set_float_rand_bound_min($F0, 2π, -π)
    if v >= 32768 { v = v - 65536; }       // (-π, π)
    // EclManager.cpp:625-648：靠近边界时反射随机角
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;               // move_time_decelerate：位移 s·t/2
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);                 // decelerate → QuadOut
}

// Sub38 //70：shoot_disable(); bullet_circle(2, 2, 64, 2, 2.0f, 1.0f, %F0, 0.0f, 513); shoot_enable(); shoot_interval(60);
// 原文 shoot_disable 期间 bullet_circle 只写 props 不发弹，首轮由自动射击在配置后 interval 帧打出。
// 写法 A（mapping §4.3 新口径）：k = 相对配置帧 S 的开火偏移，守卫 `k >= until`。
async sub autoshoot(interval: int, delayed: int, until: int) {
    var a: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π) → 整周随机基准角（一轮一次，之后固定）
    sh_reset(0);
    sh_sprite(0, RICE, 2);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub38 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);                          // bullet_circle：不瞄
    sh_ring(0, 1);                         // 整周均分
    sh_count(0, 64, 2);                    // c1=64 颗 × c2=2 层
    sh_speed(0, 2.0fx, (1.0fx - 2.0fx) / 2);   // s1=2.0, s2=1.0 → 步长 -0.5
    sh_angle(0, a, 0deg);                  // a1=%F0, a2=0
    sh_xform(0, BURST);
    var k: int = interval - 1;             // §4.3：原作首发在设定帧 S 之后第 n−1 帧
    if delayed != 0 { k = interval - 1 - rand(interval); }
    if k >= until { return; }
    if k > 0 { wait(k - 1); }              // 子任务出生当帧不跑，首跑在 S+1，等 k−1 正好落在 S+k
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

async sub pattern() {
    set_enemy_flag(ENEMY_NO_BODY, 0);      // enemy_flag_invisible(0)/collision(1)/interactable(1) → 可体碰
    kill_all_enemies(KILL_SILENT);         // enemy_kill_all()（跳过调用者自己）
    var i7: int = 0;                       // set_int($I7, 0)；原文每轮 math_inc($I7) 但从不读
    wait(70);                              // //70（//30–//60 只有丢弃的表现指令）
    spawn autoshoot(60, 0, 1730);          // 配置帧起算：段末 1800 − 配置帧 70
    loop {
        wander(2.5fx, 60);                 // Sub38_676：move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(60)
        wait(100);                         // //70 → //170
        i7 = i7 + 1;                       // math_inc($I7)
        wait(10);                          // //170 → //180
                                           // //180 jump(70, Sub38_676)：循环 110 帧一轮
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                   // Sub37 enemy_set_hitbox(56,56,32) → 56/3（mapping §6.1b/§8）
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // Sub37 move_position_time_decelerate(120, 192, 96) 后停在 (192,96) → 我方 (0,96)
    loop { wait(600); }
}
