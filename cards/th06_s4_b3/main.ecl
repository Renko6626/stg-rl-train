// th06_s4_b3 —— 东方红魔乡 Stage 4 boss 帕秋莉 符卡 火符「アグニシャイン上級」
// 原文：ecldata4.ecl.txt Sub45 → Sub46（宣言 + 移到中央，120 帧）→ Sub47（随机角双环 ×5 + 游走），
//       Hard–Lunatic（spellcard_start id H=40 / L=41），时限 1800。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 40;          // Sub46 的 H 档 id（ranks 下界 = Hard）
const AMULET: int = 112;           // TH06 弹型 7 FIREBALL
const COLOR_FIRE: int = 0;         // TH06 色号 0（32px 弹色表 [0,2,4,6,8,10,13,15] → 0）

// bullet_effects(128, -1, -1, -1, 0.0f, ±0.024543693f, …) + flags 32(0x20)：
// 前 128 帧每帧 angle += ±256bam（speed 增量 f0 = 0），之后停。
xformdef ROT_R { set_accel(0fx); @128 set_ang_vel(256bam); stop_fx(); }
xformdef ROT_L { set_accel(0fx); @128 set_ang_vel(-256bam); stop_fx(); }

// move_rand_in_bounds + move_speed + move_time_decelerate 的合成（mapping §7.3）。
// 边界取标准 boss 游走框 TH06 (32,48)-(352,144) → (-160,48)-(160,144)。
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
    var rank: int = global(GVAR_RANK);

    // Sub46 宣言：清场（跳过调用者自己）+ 出弹口归零
    kill_all_enemies(KILL_SILENT);
    sh_reset(0);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_sprite(0, AMULET, COLOR_FIRE);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_xform(0, ROT_R);
    sh_reset(1);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_sprite(1, AMULET, COLOR_FIRE);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_xform(1, ROT_L);

    // Sub46 move_position_time_decelerate(120, 192, 80) + +120 ret
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);

    // Sub47
    var i7: int = 0;                       // Sub45 set_int($I7, 0)
    var s1: fx = 2.0fx;                    // !E/!N/!H speed1
    if rank >= RANK_LUNATIC { s1 = 2.5fx; }   // !L speed1
    var sstep: fx = (1.2fx - s1) / 2;      // speed2 = 1.2、c2 = 2（§4.2 层速）
    loop {                                 // Sub47_0
        var i4: int = 5;                   // set_int($I4, 5)
        var i0: int = i7 / 3 + 8;          // math_int_div + !E/!N math_int_add 8
        if rank == RANK_HARD { i0 = i7 / 3 + 9; }           // !H
        else if rank >= RANK_LUNATIC { i0 = i7 / 3 + 10; }  // !L
        for j in 0..5 {                    // Sub47_140，jump_dec(0, Sub47_140, $I4) 共 5 次
            var f0: angle = rand(65536) as angle;   // set_float_rand_bound_min：$F0 整周随机
            sh_count(0, i0, 2);
            sh_speed(0, s1, sstep);
            sh_angle(0, f0, 1365bam);      // angle2 = 7.5°（逐层错开）
            sh_fire(0);
            var f1: angle = rand(65536) as angle;
            sh_count(1, i0, 2);
            sh_speed(1, s1, sstep);
            sh_angle(1, f1, 1365bam);
            sh_fire(1);
            wait(8);                       // +8
        }
        wait(120);                         // +120（块时 8→128）
        wander(1.5fx, 90);                 // move_rand_in_bounds + move_speed(1.5) + move_time_decelerate(90)
        i7 = i7 + 1;                       // math_inc($I7)
        wait(10);                          // +10
    }                                      // +10 jump(0, Sub47_0)
}

async sub boss_main() {
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
