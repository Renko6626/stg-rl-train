// th06_s3_mb1 —— 东方红魔乡 Stage 3 中 boss（爱丽丝）非符
// 原文：ecldata3.ecl.txt Sub9（登场 + Sub10 定时 100 帧 + 从 +30 起的攻击循环）+ Sub11 + Sub12 + Sub10 + Sub20，
// timer_callback_threshold(1800)。逐条对照见 report.md。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;      // TH06 弹型 2 RICE
const BALL: int = 48;      // TH06 弹型 3 BALL
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// Sub11：8 连随机速度整周环（BALL 色 6），每发前重抽一次出弹口偏移；E12 / N16 / H20 / L24 颗。
// 原文 bullet_random_speed 每颗速度独立随机 → 只能逐颗 fire。最后一发用的出弹口偏移写进
// 16/17 号全局槽，供随后（同一轮）H/L 的自动射击出弹口使用（TH06 的 shootOffset 是粘滞状态）。
sub sub11() {
    var rank: int = global(GVAR_RANK);
    var c: int = 12;
    if rank == RANK_NORMAL { c = 16; }
    else if rank == RANK_HARD { c = 20; }
    else if rank >= RANK_LUNATIC { c = 24; }
    var f0: fx = 32.0fx / 256 * rand(256) - 16.0fx;   // set_float_rand_bound($F0,32); F0-=16
    var f1: fx = 32.0fx / 256 * rand(256) - 16.0fx;   // set_float_rand_bound($F1,32); F1-=16
    wait(20);
    for k in 0..8 {
        set_global(16, f0 as int);                     // 记下本发 shoot_offset 的 x
        set_global(17, f1 as int);                     // 记下本发 shoot_offset 的 y
        for i in 0..c {
            var sp: fx = 1.7fx + 1.3fx / 256 * rand(256);   // [1.7, 3.0)
            var an: angle = (i * 65536 / c) as angle;       // i·2π/c1，不瞄
            _ = fire(BALL, 6, $self_x + f0, $self_y + f1, sp, an, none, none);
        }
        f0 = f0 + (32.0fx / 256 * rand(256) - 16.0fx); // F0 += [-16,16)
        f1 = f1 + 24.0fx / 256 * rand(256);            // F1 += [0,24)
        wait(8);
    }
    wait(40);
}

// Sub12：单发整周大环（OUTLINE 色 2，速度 1.1），出弹口归零；E64 / N76 / H88 / L96 颗。
sub sub12() {
    var rank: int = global(GVAR_RANK);
    var c: int = 64;
    if rank == RANK_NORMAL { c = 76; }
    else if rank == RANK_HARD { c = 88; }
    else if rank >= RANK_LUNATIC { c = 96; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, c, 1);
    sh_speed(0, 1.1fx, 0fx);   // 原文 (s1,s2)=(1.1,0.6) 但 c2=1，只用 s1
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
    wait(10);
}

async sub pattern() {
    // Sub9 登场：move_position(352,-96) → move_position_time_accelerate(100, 192, 150)。
    // 紧随其后的 call("Sub10",100,0.0) 是与位移同步的 100 帧纯表现定时（effect_particle/effect_sound），
    // 定时结束主任务时间仍停在 0，再经 +10/+20/+30 三次 spellcard_effect（纯表现）后攻击。
    // 故攻击的墙钟起点 = 100 + 30 = 130 帧（start_label "+30" 是块内时间，见 report.md）。
    move_to(100, 0.0fx, 150.0fx, 1);          // accelerate（QuadIn）
    wait(100);                                // Sub10(100)
    set_enemy_flag(ENEMY_NO_BODY, 0);         // enemy_flag_interactable(1)
    wait(30);                                 // 到 +30（墙钟 130）
    var rank: int = global(GVAR_RANK);
    for it in 0..160 {                        // set_int($I4,160); jump_dec(30, Sub9_524, $I4)
        if it % 2 == 0 { sub11(); }           // math_int_mod($I3,$I4,2); call_equ("Sub11",…,$I3,0)
        else { sub12(); }                     // call_equ("Sub12",…,$I3,1)
        if rank >= RANK_HARD {                // !HL
            // shoot_disable() 期间配好 circle_aimed 的发射参数（不发弹），enable 后由
            // shoot_interval_delayed(30) 在接下来 50 帧里自动射击；这里直接复刻自动射击。
            sh_reset(1);
            sh_sprite(1, RICE, 2);
            if it % 2 == 0 { sh_offset(1, (global(16) as fx), (global(17) as fx)); }
            else { sh_offset(1, 0.0fx, 0.0fx); }
            sh_aim(1, 1);
            sh_ring(1, 1);
            if rank == RANK_HARD {
                sh_count(1, 24, 1);           // !H bullet_circle_aimed(2,2,24,1,2.5,0.0,0,364bam,4)
                sh_speed(1, 2.5fx, 0fx);
            } else {
                sh_count(1, 32, 2);           // !L bullet_circle_aimed(2,2,32,2,3.0,2.0,0,364bam,4)
                sh_speed(1, 3.0fx, -0.5fx);
            }
            sh_angle(1, 0deg, 364bam);        // a2 = 0.034906585f = 2° 逐层偏移
        }
        // !* move_rand_in_bounds(-π,π); move_speed(5.0); move_time_accelerate(50)
        var v: int = rand(65536);
        if v >= 32768 { v = v - 65536; }      // (-π, π)
        if $self_x < -64.0fx {                // lowerMoveLimit.x + 96
            if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
        }
        if $self_x > 64.0fx {                 // upperMoveLimit.x − 96
            if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
        }
        if $self_y < 96.0fx && v < 0 { v = 0 - v; }    // lowerMoveLimit.y + 48
        if $self_y > 96.0fx && v > 0 { v = 0 - v; }    // upperMoveLimit.y − 48
        var d: fx = 125.0fx;                  // move_speed(5.0) * move_time_accelerate(50) / 2
        var tx: fx = $self_x + cos(v as angle) * d;
        var ty: fx = $self_y + sin(v as angle) * d;
        if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
        if ty < 48.0fx { ty = 48.0fx; } else if ty > 144.0fx { ty = 144.0fx; }
        move_to(50, tx, ty, 1);
        // call("Sub10", 50, 0.0)：50 帧定时；期间 H/L 的自动射击在跑（shoot_interval_delayed(30)）。
        if rank >= RANK_HARD {
            var r0: int = rand(30);           // shoot_interval_delayed 的随机初值 [0,30)
            var first: int = 30 - r0;         // 首发延迟
            var t: int = 0;
            while t < 50 {
                wait(1);
                t = t + 1;
                if t == first { sh_fire(1); }
                if t == first + 30 { sh_fire(1); }
            }
        } else {
            wait(50);
        }
        wait(60);                             // +60: //90
    }
    die();                                    // 原文循环走完后 call("Sub20") + enemy_delete(0)
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                      // enemy_set_hitbox(56,56,32) → min(56,56)/3
    set_enemy_flag(ENEMY_NO_BODY, 1);         // enemy_flag_interactable(0)
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(160.0fx, -96.0fx, 1000, 0, 0, 1, boss_main);   // move_position(352.0f,-96.0f) → x−192
    loop { wait(600); }
}
