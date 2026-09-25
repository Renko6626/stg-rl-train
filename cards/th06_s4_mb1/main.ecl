// th06_s4_mb1 —— 东方红魔乡 Stage 4 中 boss（小恶魔）非符
// 原文：ecldata4.ecl.txt Sub21（行 465–498，攻击从 +30 起）+ Sub22（500–513）+ Sub23（515–521）+ Sub1（18–41）
const TIME_LIMIT: int = 2400;

const LASERHEAD: int = 176;   // TH06 弹型 9 BUBBLE
const KUNAI: int = 80;        // TH06 弹型 4 KUNAI

// Sub22 bullet_effects(-1,-1,-1,-1, 0.024, -999, …) + flags 20(0x10|0x4)：
// i0 = -1（永久）沿自身方向加速 0.024；0x4 出生特效我方不模拟
xformdef ACCEL { set_accel(0.024fx); }

// 与 TH06 一致：先进过场地，再离开（留 16px 贴图余量）就退场
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

// Sub22：8 向环弹，每步基准角 +$F0，20 帧一步 × 8
// bullet_circle(9, 1, 8, 1, 1.2f, 1.0f, %F1, 0.0f, 20)
sub sub22(f0: angle) {
    var f1: angle = rand(65536) as angle;   // set_float_rand_bound_min($F1, 2π, −π) → 整周
    var k: int = 0;
    while k < 8 {
        sh_reset(0);
        sh_sprite(0, LASERHEAD, 1);
        sh_offset(0, 0.0fx, 0.0fx);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, 8, 1);
        sh_speed(0, 1.2fx, 0fx);            // c2 = 1，s2 = 1.0 的层速差用不到
        sh_angle(0, f1, 0deg);
        sh_xform(0, ACCEL);
        sh_fire(0);
        f1 = f1 + f0;
        wait(20);
        k = k + 1;
    }
}

// Sub1：子敌。随机出弹口 + 随机相位环弹，6 帧一发 × 12，再等 120 帧退场
async sub sub1() {
    set_invuln(65535);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);       // enemy_flag_interactable(0)
    wait(30);                               // +30 set_int($I4, 12)
    var rank: int = global(GVAR_RANK);
    var n: int = 2;                         // !E  bullet_circle(4, 6, 2, 1, …)
    if rank == RANK_NORMAL { n = 4; }       // !N
    else if rank == RANK_HARD { n = 8; }    // !H
    else if rank >= RANK_LUNATIC { n = 16; }// !L
    var k: int = 0;
    while k < 12 {
        var ox: fx = -40.0fx + 80.0fx / 256 * rand(256);   // set_float_rand_bound_min($F0, 80, −40)
        var oy: fx = -40.0fx + 80.0fx / 256 * rand(256);   // set_float_rand_bound_min($F1, 80, −40)
        var a0: angle = rand(65536) as angle;              // set_float_rand_bound_min($F0, 2π, −π)
        var sp: fx = 1.0fx + 1.0fx / 256 * rand(256);      // set_float_rand_bound_min($F1, 1, 1) → [1, 2)
        sh_reset(0);
        sh_sprite(0, KUNAI, 6);
        sh_offset(0, ox, oy);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, n, 1);
        sh_speed(0, sp, 0fx);
        sh_angle(0, a0, 1024bam);           // a2 = 0.09817477f，c2 = 1 用不到
        sh_fire(0);
        wait(6);
        k = k + 1;
    }
    wait(120);
    die();
}

// Sub23：在 boss 当前位置造 2 只 Sub1，间隔 30 帧
sub sub23() {
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub1);
    wait(30);
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub1);
}

// move_bounds_set(32, 48, 352, 176) → 我方 (−160, 48)–(160, 176)（mapping §7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 176.0fx;
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
    move_to(t, tx, ty, 2);                  // move_time_decelerate(90)
}

async sub pattern() {
    wait(120);                              // 原文 start_label +30（+30 后即开火）；为满足开场 120 帧安全补足缓冲
    loop {
        sub22(2048bam);                     // +30 call("Sub22", 0, 0.19634955f)
        wander(1.5fx, 90);                  // move_rand_in_bounds(-π,π) + move_speed(1.5) + move_time_decelerate(90)
        sub23();                            // call("Sub23", 0, 0.0f)
        wait(60);                           // +60
        sub22(-2048bam);                    // call("Sub22", 0, -0.19634955f)
        sub23();
        wait(1);                            // +1
    }
}

async sub boss_main() {
    set_invuln(65535);
    kill_all_enemies(KILL_SILENT);          // enemy_kill_all()
    clear_bullets_at(0.0fx, 224.0fx, 1024.0fx, 0);  // bullet_cancel()
    set_hitbox(13.33fx);                    // enemy_set_hitbox(40, 56, 32) → min(40,56)/3
    phase_begin(0, pattern, TIME_LIMIT, 0); // timer_callback_threshold(2400)
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // 原文 Sub21 move_position(192.0f, 128.0f) → 我方 (0, 128)
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
