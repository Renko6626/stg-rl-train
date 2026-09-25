// th06_s2_b4 —— 东方红魔乡 Stage 2 boss（琪露诺）非符 2
// 原文：ecldata2.ecl.txt Sub25（+200 call Sub26）+ Sub26（8 轮自机狙环 + 偏置环）/ Sub27（3 组三根自机狙飞棒），
//       Sub26/Sub27 尾调用互调，段边界 timer_callback_threshold(3000)。逐段对照见 report.md。
const TIME_LIMIT: int = 3000;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL（16px，色号原样）
const BULLET: int = 128;   // TH06 弹型 0 PELLET（16px，色号原样）

// Sub26 bullet_offset_circle_aimed flags 5 = 0x1|0x4：0x1 出生冲刺（§5），0x4 出生特效不模拟
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// Sub21 move_bounds_set(32.0f, 48.0f, 352.0f, 134.0f) → 我方 (-160,48)-(160,134)
// Sub26/Sub27 每轮 move_speed(3.0) + move_rand_in_bounds(-π,π) + move_time_decelerate(60)（§7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 134.0fx;
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

// Sub26：8 轮，每轮 +0 自机狙环玉环 + +10 自机狙小玉偏置环（flags 5 → 出生冲刺）
sub sub26(rank: int, i7: int) {
    wander(3.0fx, 60);
    // math_int_add($I0, $I7, 5/8/14/20)
    var i0: int = i7 + 5;
    if rank == RANK_NORMAL { i0 = i7 + 8; }
    else if rank == RANK_HARD { i0 = i7 + 14; }
    else if rank >= RANK_LUNATIC { i0 = i7 + 20; }
    // !E/N/H bullet_circle_aimed(1, 6, $I0, 1, 2/3/4, 1.0, 0, 0, 4)；!L 2 层
    var layers: int = 1;
    var s1: fx = 2.0fx;
    if rank == RANK_NORMAL { s1 = 3.0fx; }
    else if rank == RANK_HARD { s1 = 4.0fx; }
    else if rank >= RANK_LUNATIC { s1 = 4.0fx; layers = 2; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 6);
    sh_offset(0, 0.0fx, 8.0fx);            // Sub26 shoot_offset(0.0f, 8.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, i0, layers);
    sh_speed(0, s1, (1.0fx - s1) / layers);
    sh_angle(0, 0deg, 0deg);
    // bullet_offset_circle_aimed(0, 5, 8, 1, 1.3f, 1.0f, 0.0f, 0.0f, 5)：a1 + 32768/8
    sh_reset(1);
    sh_sprite(1, BULLET, 5);
    sh_offset(1, 0.0fx, 8.0fx);
    sh_aim(1, 1);
    sh_ring(1, 1);
    sh_count(1, 8, 1);
    sh_speed(1, 1.3fx, (1.0fx - 1.3fx) / 1);
    sh_angle(1, 4096bam, 0deg);
    sh_xform(1, BURST);
    for k1 in 0..8 {                       // jump_dec(0, Sub26_72, $I4=8)
        sh_fire(0);                        // +0
        wait(10);                          // +10
        sh_fire(1);
        wait(10);                          // +20 jump_dec 回 +0
    }
}

// Sub27：3 组，每组三根自机狙飞棒（色 6/5/5、偏移 0/±π/8），H/L 另发一轮环玉环
sub sub27(rank: int) {
    wander(3.0fx, 60);
    for k2 in 0..3 {                       // jump_dec(0, Sub27_72, $I4=3)
        // laser_create_aimed：原点 = 敌位置 + shoot_offset(0,8)，w=6 → 3.0fx，sp=4、sl=192
        var l0: int = laser(13, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l0, 0bam);
        lz_speed(l0, 4.0fx, 192.0fx);
        var l1: int = laser(10, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l1, 4096bam);               // +0.3926991f = +π/8
        lz_speed(l1, 4.0fx, 192.0fx);
        var l2: int = laser(10, $self_x, $self_y + 8.0fx, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
        lz_aim(l2, -4096bam);
        lz_speed(l2, 4.0fx, 192.0fx);
        // !H bullet_circle_aimed(1, 6, 16, 2, 2.0, 1.0, 0, 0, 4) / !L 32 颗；E/N 不发
        if rank == RANK_HARD {
            sh_reset(0);
            sh_sprite(0, OUTLINE, 6);
            sh_offset(0, 0.0fx, 8.0fx);
            sh_aim(0, 1);
            sh_ring(0, 1);
            sh_count(0, 16, 2);
            sh_speed(0, 2.0fx, (1.0fx - 2.0fx) / 2);
            sh_angle(0, 0deg, 0deg);
            sh_fire(0);
        } else if rank >= RANK_LUNATIC {
            sh_reset(0);
            sh_sprite(0, OUTLINE, 6);
            sh_offset(0, 0.0fx, 8.0fx);
            sh_aim(0, 1);
            sh_ring(0, 1);
            sh_count(0, 32, 2);
            sh_speed(0, 2.0fx, (1.0fx - 2.0fx) / 2);
            sh_angle(0, 0deg, 0deg);
            sh_fire(0);
        }
        wait(50);                          // +50 jump_dec 回 +0
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    wait(200);                             // Sub25 +200 call("Sub26")
    var i7: int = 0;                       // Sub25 set_int($I7, 0)
    loop {
        sub26(rank, i7);
        sub27(rank);
        i7 = i7 + 1;                       // Sub27 末尾 math_int_add($I7, $I7, 1)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);      // Sub25 enemy_flag_collision(1) / enemy_flag_interactable(1)
    set_hitbox(16.0fx);                    // Sub21 enemy_set_hitbox(48, 56, 32) → min/3 = 16
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // Sub21 move_position(192, 96)
    loop { wait(600); }
}
