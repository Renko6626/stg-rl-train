// th06_s3_b1 —— 东方红魔乡 Stage 3 boss（红美铃）非符 1
// 原文：ecldata3.ecl.txt Sub22（+50 起调 Sub23，其后每 272 帧再调一次）+ Sub23（自机狙鳞弹扇形螺旋，152 帧），
//       timer_callback_threshold(1800)。逐段对照见 report.md。
const TIME_LIMIT: int = 1800;
const SHARD: int = 96;   // TH06 弹型 5 SHARD（16px，色号原样）

// bullet_circle_aimed(5, 2, $I0, 1, %F2, 0.6f, %F0, 0.0f, 4)：SHARD 色 2、n 颗 × 1 层、
// 整周自机狙环，基准角 ang；出弹口 Sub21 shoot_offset(0, -12, 0) 粘滞
sub volley(n: int, sp: fx, ang: angle) {
    sh_reset(0);
    sh_sprite(0, SHARD, 2);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_speed(0, sp, 0.6fx - sp);                // 层数 1，步长无实际作用
    sh_angle(0, ang, 0deg);
    sh_fire(0);
}

// Sub22 +50 call("Sub23", 0, 0.0f)；Sub23 每次自抽随机相位、速度与弹数，
// i7 = 第几次调用（Sub22 set_int($I7,0) 后每次 math_inc）
sub sub23(i7: int, rank: int) {
    // math_int_add($I0, $I7, 5); cmp_int($I0, 10); jump_lss → i0 = min(i7+5, 10)
    var i0: int = i7 + 5;
    if i0 >= 10 { i0 = 10; }
    // !E −1 / !H +2 / !L +5（粘滞难度前缀）
    if rank == RANK_EASY { i0 = i0 - 1; }
    else if rank == RANK_HARD { i0 = i0 + 2; }
    else if rank >= RANK_LUNATIC { i0 = i0 + 5; }
    var i1: int = i7 % 2;                       // math_int_mod($I1, $I7, 2)
    var f0: angle = rand(65536) as angle;       // set_float_rand_bound_min($F0, 2π, −π)
    var f2: fx = 2.0fx;                         // set_float($F2, 2.0f)
    // 第一段：30 发、每 4 帧一发，弹数 i0、整周自机狙环，相位每发 ±1024bam（5.625°）、速度 +0.05
    for k1 in 0..30 {
        volley(i0, f2, f0);
        if i1 == 0 { f0 = f0 + 1024bam; } else { f0 = f0 - 1024bam; }
        f2 = f2 + 0.05fx;
        wait(4);
    }
    // Sub23 帧 120：move_rand_in_bounds(-π, π) + move_speed(5.0) + move_time_accelerate(40)
    // 边界取 Sub22 move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }            // (-π, π)
    if $self_x < -64.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > 64.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < 96.0fx && v < 0 { v = 0 - v; }
    if $self_y > 96.0fx && v > 0 { v = 0 - v; }
    var d: fx = 100.0fx;                        // move_speed 5.0 × move_time 40 / 2
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
    if ty < 48.0fx { ty = 48.0fx; } else if ty > 144.0fx { ty = 144.0fx; }
    move_to(40, tx, ty, 1);                     // accelerate（QuadIn）
    var f1: angle = 410bam;                     // set_float($F1, 0.03926991f) = 2.25°
    // 第二段：16 发、每 2 帧一发，相位步长 f1 从 410bam 每发 +683bam，速度每发 +0.06
    for k2 in 0..16 {
        volley(i0, f2, f0);
        if i1 == 0 { f0 = f0 + f1; } else { f0 = f0 - f1; }
        f1 = f1 + 683bam;
        f2 = f2 + 0.06fx;
        wait(2);
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var i7: int = 0;                            // Sub22 +50 set_int($I7, 0)
    wait(160);                                  // Sub22 +50 call("Sub23")；开场缓冲补足到 +160（见 report）
    loop {
        sub23(i7, rank);
        i7 = i7 + 1;                            // Sub22 math_inc($I7)
        wait(120);                              // Sub22 +120: //170（jump 回 +50）
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);           // Sub22 enemy_flag_collision(1) / interactable(1)
    set_hitbox(18.67fx);                        // Sub21 enemy_set_hitbox(56, 56, 32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // Sub21 出场后停在 (192.0f, 150.0f)；Sub22 move_bounds_set(...,144) 把它夹到 y=144
    _ = spawn_enemy(0.0fx, 144.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
