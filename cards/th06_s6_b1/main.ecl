// th06_s6_b1 —— 东方红魔乡 Stage 6 boss 非符 1
// 原文：ecldata6.ecl.txt Sub19（+100 起 call Sub20×2 + 移动，jump 回 loop）+ Sub20（32 轮三向扇），timer 2700。
const TIME_LIMIT: int = 2700;
const BALL: int = 48;        // TH06 弹型 3 BALL
const LASERHEAD: int = 176;  // TH06 弹型 6 BIG_BALL / 9 BUBBLE（32px，只有 8 色）

// move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160, 48)-(160, 120)
// 对应 move_rand_in_bounds + move_speed + move_time_decelerate（mapping §7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                 // (-π, π)，16384 = π/2
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
    move_to(t, tx, ty, 2);                           // move_time_decelerate → QuadOut
}

// Sub20：32 轮 × 8 帧，每轮三向扇（BALL 横扇 + BUBBLE 上扇 + BIG_BALL 随机对向扇）
// 出弹口 shoot_offset(0, -12, 0)；flags 512 只是音效位，无出生冲刺/特效。
sub sub20() {
    var rank: int = global(GVAR_RANK);
    var f0: angle = 512bam;                        // 0.049087387f，每轮 +36°
    var f1: angle = -16384bam;                     // -1.5707964f，每轮 -22.5°
    var f2: angle = -32768bam + (rand(65536) as angle);   // set_float_rand_bound_min(F2, 2π, -π)
    var n3: int = 3;                               // !E bullet_fan(3,5,3,1,1.8f,...)
    var s3: fx = 1.8fx;
    var n9: int = 3;                               // !E bullet_fan(9,0,3,1,3.5f,...)
    var n6: int = 0;                               // !E 无 BIG_BALL 扇
    if rank == RANK_NORMAL { n9 = 4; n6 = 2; }
    else if rank == RANK_HARD { n3 = 4; s3 = 2.4fx; n9 = 5; n6 = 4; }
    else if rank >= RANK_LUNATIC { n3 = 5; s3 = 2.4fx; n9 = 6; n6 = 6; }

    for k in 0..32 {
        // bullet_fan(3, 5, n3, 1, s3, 1.2f, %F0, 0.09817477f, 512)
        sh_reset(0);
        sh_sprite(0, BALL, 5);
        sh_offset(0, 0.0fx, -12.0fx);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, n3, 1);
        sh_speed(0, s3, 0fx);
        sh_angle(0, f0, 1024bam);                  // 5.625°
        sh_fire(0);
        f0 = f0 + 6554bam;                         // +36°

        // bullet_fan(9, 0, n9, 1, 3.5f, 1.2f, %F1, 1.0471976f, 512) → BUBBLE→LASERHEAD，色 0
        sh_reset(0);
        sh_sprite(0, LASERHEAD, 0);
        sh_offset(0, 0.0fx, -12.0fx);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, n9, 1);
        sh_speed(0, 3.5fx, 0fx);
        sh_angle(0, f1, 10923bam);                 // 60°
        sh_fire(0);
        f1 = f1 - 4096bam;                         // -22.5°

        // bullet_fan(6, 3, n6, 1, 2.5f, 1.2f, %F2, 0.7853982f, 512) ×2（+180°）→ LASERHEAD，色 3→6
        if n6 > 0 {
            sh_reset(0);
            sh_sprite(0, LASERHEAD, 6);
            sh_offset(0, 0.0fx, -12.0fx);
            sh_aim(0, 0);
            sh_ring(0, 0);
            sh_count(0, n6, 1);
            sh_speed(0, 2.5fx, 0fx);
            sh_angle(0, f2, 8192bam);              // 45°
            sh_fire(0);
            f2 = f2 + 32768bam;                    // +π
            sh_angle(0, f2, 8192bam);
            sh_fire(0);
            f2 = f2 - 32768bam;                    // -π
        }
        f2 = f2 + 1638bam;                         // +9°
        wait(8);                                   // +8: //8
    }
    wait(10);                                      // +10: //18
}

async sub pattern() {
    wait(100);                                     // Sub19 +60: //100
    loop {
        sub20();                                   // Sub19_492 call("Sub20")
        wander(2.5fx, 90);                         // move_rand_in_bounds / move_speed / move_time_decelerate
        sub20();                                   // call("Sub20")
        wait(100);                                 // +100: //200
        wait(10);                                  // +10: //210
        // jump(100, Sub19_492) 重设时间 → 循环
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                           // 继承前段 Sub17 enemy_set_hitbox(56,56,32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
