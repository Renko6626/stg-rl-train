// th06_s4_b8 —— 东方红魔乡 Stage 4 boss（帕秋莉）符卡 金＆水符「マーキュリポイズン」
// 原文：ecldata4.ecl.txt Sub40 → Sub90 → Sub91（宣言 + 移到中央 (192,80) + 暂不可伤，120 帧）
//       + Sub92（8 次内层：随机基准角双层环 × 2；随后随机游走 90 帧，jump 回 Sub92_20），时限 2400。
const TIME_LIMIT: int = 2400;
const BALL: int = 48;       // TH06 弹型 3 BALL 中玉（16px，色号原样）

// flags 37 = 0x20 | 0x4 | 0x1（mapping §5）：
//   bullet_effects(90, -1, -1, -1, 0.003f, ±0.012271847f, -1, -1)
//     → 前 90 帧每帧 speed += 0.003、angle += ±128bam；
//   0x1 = 出生冲刺：add_speed(5) 后 16 帧内按 -0.3125/帧 线性衰减（5 / 0.3125 = 16）；
//   0x4 = 出生特效，我方有意不模拟。
// ⚠️ 0x1 与 0x20 在 BulletManager.cpp:711-747 是 if/else if 互斥分支：冲刺的 16 帧里
// 0x20 的逐帧加速/转向完全不生效，冲刺结束（帧 16）才起，计时仍从出生算 i0=90 帧。
// @N 是后置延迟（执行本 op 再等 N 帧）：帧 0 add_speed + set_accel(-0.3125)，帧 16 换成
// set_accel(0.003) 并 set_ang_vel(±128bam)，再等 74 帧（到帧 90）stop_fx。
// 转向在出生后 16 帧内为 0，全程 74×128 = 9472bam（≈52°）。
xformdef CURVE_R { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_accel(0.003fx); @74 set_ang_vel(128bam); stop_fx(); }
xformdef CURVE_L { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_accel(0.003fx); @74 set_ang_vel(-128bam); stop_fx(); }

// Sub92 的 move_rand_in_bounds(-π, π); move_speed(1.5); move_time_decelerate(90)。
// 边界沿用 Sub27 的 move_bounds_set(32,48)-(352,144) → 我方 (-160,48)-(160,144)。
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

async sub pattern() {
    kill_all_enemies(KILL_SILENT);        // Sub91 enemy_kill_all()（跳过 boss 自己）
    move_to(120, 0.0fx, 80.0fx, 2);       // Sub91 move_position_time_decelerate(120, 192, 80)
    wait(120);                            // +120：前奏结束，进入 Sub92

    var rank: int = global(GVAR_RANK);
    var i7: int = 0;                      // Sub90 set_int($I7, 0)
    var i0: int = 0;                      // 角度向颗数 = i7 + 难度基值
    var i4: int = 0;                      // 内层次数 = 8
    var a0: angle = 0deg;                 // %F0 随机基准角

    // Sub91 shoot_offset(0,0,0)：出弹口 = boss 位置
    sh_reset(0);
    sh_sprite(0, BALL, 14);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_xform(0, CURVE_R);
    sh_reset(1);
    sh_sprite(1, BALL, 8);
    sh_aim(1, 1);
    sh_ring(1, 1);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_xform(1, CURVE_L);

    loop {                                // Sub92_20
        i4 = 8;                           // set_int($I4, 8)
        for k1 in 0..i4 {                 // Sub92_40 … jump_dec(0, Sub92_40, $I4)
            a0 = rand(65536) as angle;    // set_float_rand_bound_min($F0, 2π, -π) → 整周
            i0 = i7;                      // math_int_mul($I0, $I7, 1)
            if rank == RANK_EASY { i0 = i0 + 8; }          // !E
            else if rank == RANK_NORMAL { i0 = i0 + 15; }  // !N
            else if rank == RANK_HARD { i0 = i0 + 20; }    // !H
            else { i0 = i0 + 28; }                         // !L
            // bullet_circle_aimed(3, 14, $I0, 2, 1.5, 0.8, %F0, 3641bam, 37)
            sh_count(0, i0, 2);
            sh_speed(0, 1.5fx, -0.35fx);                   // (s2-s1)/c2 = (0.8-1.5)/2
            sh_angle(0, a0, 3641bam);                      // a1=%F0, a2=+20°
            sh_fire(0);
            wait(20);                     // +20
            // bullet_circle_aimed(3, 8, $I0, 2, 1.5, 0.8, %F0, -3641bam, 37)
            sh_count(1, i0, 2);
            sh_speed(1, 1.5fx, -0.35fx);
            sh_angle(1, a0, -3641bam);                     // a2=-20°
            sh_fire(1);
            wait(20);                     // +20（块时间 //40）
        }
        wander(1.5fx, 90);                // move_rand_in_bounds; move_speed(1.5); move_time_decelerate(90)
        i7 = i7 + 1;                      // math_inc($I7)
        wait(50);                         // +50（块时间 //90）
    }                                     // jump(0, Sub92_20)
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    // 原文 spellcard_start(1, N=77 / H=78 / L=79, "ST_ECLDATA4_SUB58_0")
    var rank: int = global(GVAR_RANK);
    var sid: int = 77;
    if rank == RANK_HARD { sid = 78; } else if rank >= RANK_LUNATIC { sid = 79; }
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
