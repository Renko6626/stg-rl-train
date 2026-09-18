// th06_s6_b10 —— 东方红魔乡 Stage 6 关底 boss 非符 4（十六夜咲夜）
// 原文：ecldata6.ecl.txt Sub28（+60 起循环 call Sub29 + Sub30，Sub29 内生成 Sub31 使魔），
//       timer_callback_threshold(3600)。逐段对照见 report.md。
const TIME_LIMIT: int = 3000;
const RICE: int = 64;        // TH06 弹型 2 RICE（16px，色号原样）
const LASERHEAD: int = 176;  // TH06 弹型 9 BUBBLE（16px，色号原样）
const AMULET: int = 112;     // TH06 弹型 7 FIREBALL（32px，色号 1 → [0,2,…][1] = 2）

// bullet_effects(-1,-1,-1,-1, 0.025f, 1.5707964f, -1.0f, -1.0f) + flags 528(0x210)：
// 0x10 且 i0=-1 → 永久；f1=90°（非自身方向）→ 固定角；加速度 0.025 → set_gravity(0, 0.025)（§5）。
xformdef GRAV { set_gravity(0.0fx, 0.025fx); }

// 出界守卫（§6.2）
async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

// Sub31 使魔：无害装饰（无体碰、不发弹）。原文 +9970 enemy_delete 前早被出界回收。
async sub sub31() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3（§8）
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
    spawn oob_guard();
    var a: angle = rand(32768) as angle;   // set_float_rand_bound($F0, π) = [0, π)
    var w: angle = ((-4096 + rand(8192)) / 20) as angle;  // set_float_rand_bound_min($F1, π/4, −π/8) 再 /20
    var spd: fx = 5.0fx + 4.0fx / 256 * rand(256);        // set_float_rand_bound_min($F2, 4, 5) = [5,9)
    move_vel(0, a, spd, 0);
    wait(30);
    loop {                                 // +30 move_angular_velocity(%F1)，逐帧积分（§7.2）
        a = a + w;
        move_vel(0, a, spd, 0);
        wait(1);
    }
}

// 三种发弹模式（Sub29 的 i7%3 分支）。每次射击重配发射器并立即开火，
// 保证 sh_xform 与 sh_fire 在同一 sub（§2.4）。
sub fire_mode(mode: int) {
    var rank: int = global(GVAR_RANK);
    if mode == 0 {
        // bullet_random(2,2, E7/N11/H15/L20, 1, E/N2.0 H/L2.5, 1.0, π, −π, 528)
        var n0: int = 7;
        var s0: fx = 2.0fx;
        if rank == RANK_NORMAL { n0 = 11; }
        else if rank == RANK_HARD { n0 = 15; s0 = 2.5fx; }
        else if rank >= RANK_LUNATIC { n0 = 20; s0 = 2.5fx; }
        for k0 in 0..n0 {
            var sp0: fx = 1.0fx + (s0 - 1.0fx) / 256 * rand(256);
            var an0: angle = rand(65536) as angle;
            _ = fire(RICE, 2, $self_x, $self_y - 12.0fx, sp0, an0, GRAV, none);
        }
    } else if mode == 1 {
        // bullet_fan_aimed(9,0, E/N9 H11 L13, 1, E3.5/N5.0/H6.5/L8.0, 1.0, 0, a2, 528)
        var n1: int = 9;
        var s1: fx = 3.5fx;
        var d1: angle = 4096bam;           // 22.5°
        if rank == RANK_NORMAL { s1 = 5.0fx; d1 = 3641bam; }
        else if rank == RANK_HARD { n1 = 11; s1 = 6.5fx; d1 = 2521bam; }
        else if rank >= RANK_LUNATIC { n1 = 13; s1 = 8.0fx; d1 = 2048bam; }
        sh_reset(0);
        sh_sprite(0, LASERHEAD, 0);
        sh_offset(0, 0.0fx, -12.0fx);      // Sub28 shoot_offset(0.0f, -12.0f, 0.0f)
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, n1, 1);
        sh_speed(0, s1, 0fx);
        sh_angle(0, 0deg, d1);
        sh_xform(0, GRAV);
        sh_fire(0);
    } else {
        // bullet_circle_aimed(7,1, E16/N12/H12/L20, 2, E/N/H5.0 L6.0, 2.0, 0, 0, 528)
        var n2: int = 16;
        var s2a: fx = 5.0fx;
        if rank == RANK_NORMAL { n2 = 12; }
        else if rank == RANK_HARD { n2 = 12; }
        else if rank >= RANK_LUNATIC { n2 = 20; s2a = 6.0fx; }
        sh_reset(1);
        sh_sprite(1, AMULET, 2);           // 32px 色 1 → 2（§3）
        sh_offset(1, 0.0fx, -12.0fx);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, n2, 2);
        sh_speed(1, s2a, (2.0fx - s2a) / 2);
        sh_angle(1, 0deg, 0deg);
        sh_xform(1, GRAV);
        sh_fire(1);
    }
}

// boss 随机游走（§7.3）。move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)。
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

// Sub29 前段：100 帧蓄力粒子（丢弃）→ enemy_flag_interactable(0) → 30 帧生成 60 只 Sub31。
sub sub29_spawn() {
    wait(100);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    for k in 0..30 {
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub31);
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub31);
        wait(1);
    }
}

// Sub28 循环体（call Sub29 返回后相对 t=60..360）：
// 7 次随机游走 + 后台自动射击（interval 由模式定）+ t=270 call Sub30。
sub cycle(mode: int, interval: int) {
    var f: int = 0;
    var next: int = interval;
    while f < 300 {
        if f == 0 { wander(4.0fx, 30); }
        else if f == 30 { wander(7.0fx, 30); }
        else if f == 60 { wander(4.0fx, 30); }
        else if f == 90 { wander(7.0fx, 30); }
        else if f == 120 { wander(4.0fx, 30); }
        else if f == 150 { wander(7.0fx, 30); }
        else if f == 180 { wander(4.0fx, 30); }
        else if f == 210 { set_enemy_flag(ENEMY_NO_BODY, 0); }   // Sub30：interactable(1)
        if f == next {
            if f <= 210 { fire_mode(mode); }   // 自动射击窗口，t=270 后停
            next = next + interval;
        }
        wait(1);
        f = f + 1;
    }
}

async sub pattern() {
    set_enemy_flag(ENEMY_NO_BODY, 0);   // Sub28 enemy_flag_collision(1)
    wait(60);                            // start_label +60：set_int($I7, 0)
    var i7: int = 0;
    loop {
        sub29_spawn();                   // +60 call("Sub29", 0, 0.0f)（含 ~130 帧）
        var mode: int = i7 % 3;
        var interval: int = 8;
        if mode == 1 { interval = 16; } else if mode == 2 { interval = 10; }
        cycle(mode, interval);           // 相对 t=60..360
        i7 = i7 + 1;                     // +350 math_inc($I7)；+360 jump(60) 回卷
    }
}

async sub boss_main() {
    set_invuln(65535);
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 本段起始位置未知，取 (0,96)
    loop { wait(600); }
}
