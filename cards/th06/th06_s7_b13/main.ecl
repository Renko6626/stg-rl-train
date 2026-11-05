// th06_s7_b13 —— 东方红魔乡 Stage 7 boss 非符 7（芙兰朵露）
// 原文：ecldata7.ecl.txt Sub71（行 2028–2072），timer_callback_threshold(1800)。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;      // TH06 弹型 2 RICE

// flags 513 = 0x200|0x1：出生冲刺（0x200 音效按 §11 丢弃）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// bullet_circle(2, 6, 32, 3, 2.5f, 1.0f, %F0, 0.06544985f, 513)；
// 原文配置一次后靠 shoot_interval(30) 自动射击，$F0 随机基准角只抽一次。
async sub autoshoot(f0: angle, until: int) {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub71 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);                          // bullet_circle：不瞄自机
    sh_ring(0, 1);                         // 整周环
    sh_count(0, 32, 3);                    // 32 颗 × 3 层
    sh_speed(0, 2.5fx, (1.0fx - 2.5fx) / 3);
    sh_angle(0, f0, 683bam);               // a2 = 0.06544985f = 3.75°
    sh_xform(0, BURST);
    // §4.3 写法 A：k = 原作开火帧相对设定帧 S 的偏移，首发 k = n − 1 = 29；
    // 伴生任务首跑已在 S+1，所以 wait(k − 1) 正好落在 S+k。
    var k: int = 29;
    if k >= until { return; }
    wait(k - 1);
    loop {
        sh_fire(0);
        if k + 30 >= until { return; }
        wait(30);
        k = k + 30;
    }
}

// move_rand_in_bounds(-π, π); move_speed(2.5f); move_time_decelerate(90)（mapping §7.3）
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

async sub pattern() {
    var i7: int = 0;                       // set_int($I7, 0)
    wait(90);                              // 原文 T=90：配置发射器 + 首次移动
    var f0: angle = rand(65536) as angle;  // set_float_rand_bound_min($F0, 2π, -π)
    spawn autoshoot(f0, TIME_LIMIT);
    loop {
        // Sub71_532：jump(90, …) 把块时间设回 90 ⇒ 每轮先执行移动，再走 100 + 10 帧
        wander(2.5fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(100);
        i7 = i7 + 1;                       // math_inc($I7)
        wait(10);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);      // invisible(0)/collision(1)/interactable(1)
    set_hitbox(18.67fx);                   // enemy_set_hitbox(56, 56, 32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
