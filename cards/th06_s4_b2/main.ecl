// th06_s4_b2 —— 东方红魔乡 Stage 4 boss（帕秋莉）符卡 火符「アグニシャイン」
// 原文：ecldata4.ecl.txt Sub42 → Sub43（宣言 + 移到中央 (192,80) + 暂不可伤，120 帧）
//       + Sub44（三层旋转火弹环循环，jump 回 Sub44_0），时限 1800。逐段对照见 out/report.md。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 37;    // 原文 spellcard_start(1, E=37 / N=38, "ST_ECLDATA4_SUB42_0")；仅 UI/计分，取 E 的 37
const AMULET: int = 112;     // TH06 弹型 7 FIREBALL（32px 弹，色号 0 → 0）

// bullet_effects(128, -1, -1, -1, 0.0f, ±0.024543693f, -1, -1) + flags 32(0x20)（§5）：
//   前 128 帧每帧 angle += ±256bam（speed 增量 f0=0），之后停连续效果、弹沿末方向直飞。
//   @N 是后置延迟：set_accel/set_ang_vel 同帧发射，set_ang_vel 之后等 128 帧再 stop_fx。
xformdef SPIN_R { set_accel(0fx); @128 set_ang_vel(256bam); stop_fx(); }
xformdef SPIN_L { set_accel(0fx); @128 set_ang_vel(-256bam); stop_fx(); }

// boss 随机游走（原文 move_rand_in_bounds(-π, π); move_speed(1.5f); move_time_decelerate(90)）。
// 边界沿用 Sub27/26 设的 move_bounds_set(32,48)-(352,144) → 我方 (-160,48)-(160,144)。
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

// Sub44：外层每轮 i7+1，5 次内层（每 8 帧一轮）三层环，然后 wait 120、随机游走 90 帧、wait 10，
// 回到 Sub44_0（块时间重设为 0）。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);        // Sub43 enemy_kill_all()（跳过调用者 = boss）
    move_to(120, 0.0fx, 80.0fx, 2);       // move_position_time_decelerate(120, 192, 80) → (0,80)
    wait(120);                            // +120：前奏结束，进入 Sub44

    var rank: int = global(GVAR_RANK);
    var i7: int = 0;                      // Sub42 set_int($I7, 0)
    var i0: int = 0;                      // 环弹数
    var a0: angle = 0deg;                 // %F0，每环随机基准角
    var i4: int = 0;                      // 内层次数

    // 三层：+256bam / -256bam / +256bam，各自独立随机基准角；出弹口 = boss（Sub43 shoot_offset(0,0,0)）
    sh_reset(0); sh_sprite(0, AMULET, 0); sh_aim(0, 0); sh_ring(0, 1); sh_xform(0, SPIN_R);
    sh_reset(1); sh_sprite(1, AMULET, 0); sh_aim(1, 0); sh_ring(1, 1); sh_xform(1, SPIN_L);
    sh_reset(2); sh_sprite(2, AMULET, 0); sh_aim(2, 0); sh_ring(2, 1); sh_xform(2, SPIN_R);

    loop {                                // Sub44_0
        i4 = 5;
        i0 = i7 / 3;                      // math_int_div($I0, $I7, 3)
        if rank == RANK_EASY { i0 = i0 + 7; } else { i0 = i0 + 11; }  // !E +7 / !N +11（H/L 无此卡）
        sh_count(0, i0, 1);
        sh_count(1, i0, 1);
        sh_count(2, i0, 1);
        for k1 in 0..i4 {                 // Sub44_92: jump_dec(0, Sub44_92, $I4)，共 5 轮
            a0 = rand(65536) as angle;
            sh_speed(0, 2.2fx, 0fx); sh_angle(0, a0, 1365bam); sh_fire(0);   // bullet_circle(7,0,$I0,1,2.2,0.7,%F0,7.5°,32)
            a0 = rand(65536) as angle;
            sh_speed(1, 1.5fx, 0fx); sh_angle(1, a0, 1365bam); sh_fire(1);   // 第二层 1.5，反向旋转
            a0 = rand(65536) as angle;
            sh_speed(2, 0.7fx, 0fx); sh_angle(2, a0, 1365bam); sh_fire(2);   // 第三层 0.7，正向旋转
            wait(8);                      // +8
        }
        wait(120);                        // +120: //128（内层末停在 T=8）
        wander(1.5fx, 90);                // move_rand_in_bounds; move_speed(1.5); move_time_decelerate(90)
        i7 = i7 + 1;                      // math_inc($I7)
        wait(10);                         // +10: //138
    }                                     // jump(0, Sub44_0)
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
