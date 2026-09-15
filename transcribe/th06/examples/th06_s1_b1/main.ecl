// th06_s1_b1 —— 东方红魔乡 Stage 1 boss（露米娅）非符 1
// 原文：ecldata1 Sub14（+100 起 call Sub15）+ Sub15/16/17/18 尾调用链，timer_callback_threshold(2100)。
// 尾调用链翻成调度循环（mapping §2.4）。逐段对照见 notes.md。
const TIME_LIMIT: int = 2100;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const RICE: int = 64;      // TH06 弹型 2 RICE
const BALL: int = 48;      // TH06 弹型 3 BALL

// move_bounds_set(32.0f, 48.0f, 352.0f, 144.0f) → 我方 (-160, 48)-(160, 144)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
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

// 发弹两件套：TH06 速度钳位（s1≠0 时 ≥0.3，s2 恒 ≥0.3）+ 层速公式（mapping §4.2）
sub fan_aimed(shape: int, color: int, n: int, layers: int, s1: fx, s2: fx, a1: angle, spread: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, shape, color);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub13 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, t1, (t2 - t1) / layers);
    sh_angle(0, a1, spread);
    sh_fire(0);
}

sub circle_aimed(shape: int, color: int, n: int, layers: int, s1: fx, s2: fx, a1: angle, a2: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(1);
    sh_sprite(1, shape, color);
    sh_offset(1, 0.0fx, -12.0fx);
    sh_aim(1, 1);
    sh_ring(1, 1);
    sh_count(1, n, layers);
    sh_speed(1, t1, (t2 - t1) / layers);
    sh_angle(1, a1, a2);
    sh_fire(1);
}

// Sub15：中玉 N 颗 × 10 层自机狙扇，7 连
sub sub15() {
    var rank: int = global(GVAR_RANK);
    wander(3.0fx, 60);
    wait(12);
    var s: fx = 3.0fx;                     // +12 只有 Easy 是 3.0
    if rank == RANK_NORMAL { s = 4.0fx; } else if rank == RANK_HARD { s = 5.0fx; } else if rank >= RANK_LUNATIC { s = 6.0fx; }
    fan_aimed(BALL, 2, 1, 10, s, 1.0fx, 0deg, 2048bam);
    var hs: fx = 4.0fx;                    // 其后 E/N 4.0、H 5.0、L 6.0
    if rank == RANK_HARD { hs = 5.0fx; } else if rank >= RANK_LUNATIC { hs = 6.0fx; }
    var nh: int = 1;
    var nl: int = 1;
    // +20 … +60：Hard / Lunatic 的颗数逐发递增（H 1,1,1,2,3,4 · L 2,2,3,3,4,5）
    for i in 0..6 {
        wait(8);
        var n: int = 1;
        if i == 0 { nh = 1; nl = 2; } else if i == 1 { nh = 1; nl = 2; } else if i == 2 { nh = 1; nl = 3; }
        else if i == 3 { nh = 2; nl = 3; } else if i == 4 { nh = 3; nl = 4; } else { nh = 4; nl = 5; }
        if rank == RANK_HARD { n = nh; } else if rank >= RANK_LUNATIC { n = nl; }
        var col: int = 1;
        if i % 2 == 1 { col = 2; }
        fan_aimed(BALL, col, n, 10, hs, 1.0fx, 0deg, 2048bam);
    }
    wait(120);                             // +180 调度
}

// Sub16：环玉自机狙环（快慢交替）× 4 夹小玉环 × 4
sub sub16() {
    var rank: int = global(GVAR_RANK);
    wander(3.0fx, 60);
    var n: int = 6;
    var ly: int = 1;
    var a2: angle = 0deg;
    var np: int = 8;
    if rank == RANK_NORMAL { n = 12; np = 16; } else if rank == RANK_HARD { n = 24; np = 32; } else if rank >= RANK_LUNATIC { n = 24; np = 24; }
    wait(60);
    for v in 0..4 {
        // 环玉：+60 快、+76 慢、+92 快、+108 慢；Lunatic 全程双层，Hard 后两发双层（32 颗仅 L）
        var sp: fx = 4.0fx;
        if v % 2 == 1 { sp = 2.0fx; }
        var nn: int = n;
        ly = 1;
        a2 = 0deg;
        if rank >= RANK_LUNATIC { ly = 2; a2 = 2731bam; if v >= 2 { nn = 32; } }
        if rank == RANK_HARD && v >= 2 { ly = 2; a2 = 2731bam; }
        if v % 2 == 1 { a2 = 0deg - a2; }
        circle_aimed(OUTLINE, 6, nn, ly, sp, 1.0fx, 0deg, a2);
        if v < 3 {
            wait(8);
            circle_aimed(BULLET, 5, np, 1, 3.0fx, 1.0fx, 0deg, 0deg);   // 小玉环 +68 / +84 / +100
            wait(8);
        }
    }
    wait(120);                             // +108 最后一发环玉后 +120 → +228 调度
}

// Sub17：米弹 16 层自机狙扇 + （N 起）环玉环
sub sub17() {
    var rank: int = global(GVAR_RANK);
    wander(3.0fx, 60);
    wait(80);
    var n: int = 2;
    if rank == RANK_NORMAL { n = 3; } else if rank >= RANK_HARD { n = 5; }
    fan_aimed(RICE, 2, n, 16, 5.0fx, 1.0fx, 0deg, 1365bam);          // +80
    wait(30);                                                         // +110（Easy 不发）
    if rank == RANK_NORMAL { circle_aimed(OUTLINE, 6, 16, 1, 2.0fx, 1.0fx, 0deg, 0deg); }
    else if rank == RANK_HARD { circle_aimed(OUTLINE, 6, 24, 2, 2.5fx, 1.0fx, 0deg, 0deg); }
    else if rank >= RANK_LUNATIC { circle_aimed(OUTLINE, 6, 48, 3, 4.0fx, 1.0fx, 0deg, 1365bam); }
    wait(90);                                                         // +200 调度
}

// Sub18：环玉扇 16 连扫（随机顺/逆），速度每发 +0.25
sub sub18() {
    var rank: int = global(GVAR_RANK);
    wander(3.0fx, 60);
    var f0: fx = 1.0fx;
    var f1: angle = -5461bam;              // -0.2617994f
    var step: angle = 1365bam;             // 0.06544985f
    if rand(2) == 0 { f1 = 5461bam; step = 0deg - step; }   // cmp_int($I0, 0); jump_equ → Sub18_456 分支
    var n: int = 1;
    var ly: int = 1;
    var s2: fx = 0fx;
    if rank == RANK_HARD { n = 2; ly = 2; s2 = 1.0fx; } else if rank >= RANK_LUNATIC { n = 3; ly = 3; s2 = 1.0fx; }
    for k1 in 0..16 {
        wait(2);
        fan_aimed(OUTLINE, 10, n, ly, f0, s2, f1, 1365bam);
        f0 = f0 + 0.25fx;
        f1 = f1 + step;
    }
    wait(120);                             // Sub18_740：+120 调度
}

async sub pattern() {
    wait(100);                             // Sub14 +100 call("Sub15")
    var next: int = 15;
    var r: int = 0;
    loop {
        // 每个 sub 末尾：set_int_rand_bound($I0, 3); call_equ(A, …, 0); call_equ(B, …, 1); call(C)
        if next == 15 {
            sub15();
            r = rand(3);
            if r == 0 { next = 16; } else if r == 1 { next = 17; } else { next = 18; }
        } else if next == 16 {
            sub16();
            r = rand(3);
            if r == 0 { next = 15; } else if r == 1 { next = 17; } else { next = 18; }
        } else if next == 17 {
            sub17();
            r = rand(3);
            if r == 0 { next = 16; } else if r == 1 { next = 15; } else { next = 18; }
        } else {
            sub18();
            r = rand(3);
            if r == 0 { next = 16; } else if r == 1 { next = 17; } else { next = 15; }
        }
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(17.33fx);                   // enemy_set_hitbox(48, 56, 32) → 48/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);    // Sub13 登场停在 (192, 96)
    loop { wait(600); }
}
