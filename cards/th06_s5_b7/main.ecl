// th06_s5_b7 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）非符 3
// 原文：ecldata5.ecl.txt Sub43（行 1091–1137，从 +60 起）+ Sub44（1139–1157）+ Sub45（1159–1177），
//       timer_callback_threshold(2700)。逐段对照见 report.md。
const TIME_LIMIT: int = 2700;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（32px）

// Sub44/45 的 flags 2560 = 0x800|0x200：
//   bullet_effects(i0, -1, -1, -1, -1.0f, …) + 0x800 ⇒ 左右上反弹 i0 次，f0<0 保持原速（mapping §5）
//   i0 = E/N:1、H/L:2
xformdef BOUNCE1 { bounce_arm(7, 1); }
xformdef BOUNCE2 { bounce_arm(7, 2); }

// 原文 Sub43：move_bounds_set(32,48,352,132) → 我方 (-160,48)-(160,132)
// move_rand_in_bounds(-π, π) + move_speed(2.0f) + move_time_decelerate(50)（mapping §7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 132.0fx;
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

// Sub44/Sub45 共用的弹：bullet_circle(8, col, c1, 2, s1, 1.2f, %F0, 164bam, 2560)
// 循环：8 发，每发相位 += dphi（Sub44 math_float_add = +1024bam；Sub45 math_float_sub = -1024bam），间隔 5 帧；循环后 +60 帧 ret。
sub ring_burst(c1: int, s1: fx, col: int, hi: int, dphi: angle) {
    var a0: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π)
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, col);           // 32px 弹色号已查表（mapping §3）
    sh_offset(0, 0.0fx, -12.0fx);           // shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, c1, 2);
    sh_speed(0, s1, (1.2fx - s1) / 2);
    if hi != 0 { sh_xform(0, BOUNCE2); } else { sh_xform(0, BOUNCE1); }
    for k1 in 0..8 {
        sh_angle(0, a0, 164bam);
        sh_fire(0);
        a0 = a0 + dphi;
        wait(5);
    }
    wait(60);
}

// Sub44：弹型 8 色 3 → ARROWHEAD 色 6。c1: E5/N5/H4/L5；s1 恒 1.8
sub sub44() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 5;
    if rank == RANK_HARD { c1 = 4; }
    var hi: int = 0;
    if rank >= RANK_HARD { hi = 1; }
    ring_burst(c1, 1.8fx, 6, hi, 1024bam);
}

// Sub45：弹型 8 色 1 → ARROWHEAD 色 2。c1: E5/N6/H5/L5；s1: E/N1.8、H/L2.0
sub sub45() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 5;
    var s1: fx = 1.8fx;
    if rank == RANK_NORMAL { c1 = 6; }
    else if rank == RANK_HARD { s1 = 2.0fx; }
    else if rank >= RANK_LUNATIC { s1 = 2.0fx; }
    var hi: int = 0;
    if rank >= RANK_HARD { hi = 1; }
    ring_burst(c1, s1, 2, hi, -1024bam);
}

// Sub43 的调度循环（从 +60 起）：Sub44 → 游走 → +60 → 游走 → Sub45 → +100 → +10 → 回跳 (+60)
async sub pattern() {
    wait(60);
    var i7: int = 0;                       // 原文 math_inc($I7)，计数不参与弹幕
    loop {
        sub44();
        wander(2.0fx, 50);
        wait(60);
        wander(2.0fx, 50);
        sub45();
        wait(100);
        i7 = i7 + 1;
        wait(10);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
