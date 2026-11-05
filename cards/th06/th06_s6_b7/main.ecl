// th06_s6_b7 —— 东方红魔乡 Stage 6 关底 boss 非符 3（十六夜咲夜）
// 原文：ecldata6.ecl.txt Sub25（start_label +60 起循环 call Sub26/Sub27），timer_callback_threshold(2700)。
const TIME_LIMIT: int = 2700;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（32px，色号 1 → 我方 [0,2,…][1] = 2）

// boss 随机游走（mapping §7.3）。move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)。
// 原文：+60 每轮 call Sub26 返回后 move_rand_in_bounds(-π, π); move_speed(2.5); move_time_decelerate(90)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }               // (-π, π)
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

// Sub26（dir=1，角度 +1024bam/发）/ Sub27（dir=-1，角度 −1024bam/发）：
// bullet_circle(8, 1, 4, 2, s1, s2, %F0, 0.0f, 512) 每 2 帧一发，共 60 发。
// §4.2：bullet_circle → sh_aim(0,0)+sh_ring(1)+sh_angle(a1,a2)；层速 step=(s2−s1)/2。
sub ring_burst(dir: int) {
    var rank: int = global(GVAR_RANK);
    var s1: fx = 3.0fx;
    var s2: fx = 1.2fx;
    if rank == RANK_HARD { s1 = 4.5fx; s2 = 2.2fx; }
    else if rank >= RANK_LUNATIC { s1 = 6.0fx; s2 = 3.2fx; }
    var f0: angle = rand(65536) as angle;          // set_float_rand_bound_min(%F0, 2π, −π)
    var step: angle = 1024bam;
    if dir < 0 { step = -1024bam; }
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 2);                    // 弹型 8 色 1 → ARROWHEAD / color 2
    sh_offset(0, 0.0fx, -12.0fx);                  // shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 4, 2);
    sh_speed(0, s1, (s2 - s1) / 2);
    for k1 in 0..60 {
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + step;
        wait(2);
    }
}

async sub pattern() {
    // 登场设置：move_bounds_set / shoot_offset / ex_ins_call(4,0)（时停解除，无开停→no-op）在 +60 前。
    // 原文攻击从 +60 起，但 (0,96) 的 boss 向下的 6.0 弹约 50 帧即到自机出生点；
    // 为满足「开场 120 帧无致命弹到达 (0,384)」硬约束，开头整体后移 30 帧（详见 report 近似）。
    wait(90);                                      // +60（含 +30 开场缓冲）：set_int($I7, 0)（$I7 无消费者，丢弃）
    loop {
        ring_burst(1);                             // +60  call("Sub26")
        wander(2.5fx, 90);                         // call 返回同帧 move_rand_in_bounds + move_speed + move_time_decelerate(90)
        wait(128);                                 // +128 → 相对 188
        ring_burst(-1);                            // +188 call("Sub27")
        wait(100);                                 // +100 → 相对 288
        wait(10);                                  // +10 → 相对 298；math_inc($I7) 丢弃
        // +10 后 jump(60, Sub25_384)，循环体按跳转目标时间重算
    }
}

async sub boss_main() {
    set_hitbox(18.67fx);   // 段外继承：boss 初始化 Sub17 (56,56,32) → §6.1b
    set_invuln(65535);
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 本段起始位置未知，取 (0, 96)
    loop { wait(600); }
}
