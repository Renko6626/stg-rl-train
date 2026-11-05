// th06_s3_b7 —— 东方红魔乡 Stage 3 boss（红美铃）符卡 彩符「彩光乱舞」H/L
// 原文：ecldata3.ecl.txt Sub42 → Sub43（宣言 + 移到中央，120 帧）+ Sub44（攻击循环）；Sub10 为纯表现但阻塞计时。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 2160;
const SPELL_ID: int = 32;   // 原文 spellcard_start(0, H=32 / L=33, "ST_ECLDATA3_SUB32_0")；本卡取 H 的 32（仅 UI/计分）
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px，色号原样）

// flags 19 = 0x1|0x2|0x10 + bullet_effects(-1,-1,-1,-1, f0, f1, …)：
//   0x1  出生冲刺：+5 速度，16 帧线性衰减到 0
//   0x10 i0=-1（永久）沿固定角 f1 的直角加速度 f0 → set_gravity(f0·cos f1, f0·sin f1)
//   f1 是各组的固定角（相位 A 90°；相位 B 180°/0°/135°/45°）
xformdef CURVE_A   { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.0fx, 0.025fx); }              // 0.025 @ 90°
xformdef CURVE_180 { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(-0.024fx, 0.0fx); }             // 0.024 @ 180°
xformdef CURVE_0   { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.024fx, 0.0fx); }              // 0.024 @ 0°
xformdef CURVE_135 { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(-0.0169706fx, 0.0169706fx); }   // 0.024 @ 135°
xformdef CURVE_45  { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.0169706fx, 0.0169706fx); }    // 0.024 @ 45°

// Sub44_20/Sub44_108：每帧 4 发 SHARD（bullet_fan count1=1，即 fan 退化成单发），
// 基准角 f0 依次 +0/+90/+180/+270，色 6/10/11/8，速度恒 1.5；f0 每帧 +10°；共 40 帧。
// 原文 bullet_effects 粘滞 (f0=0.025, f1=90°)，4 发共用 CURVE_A。
sub phase_a(f0s: angle) {
    var f0: angle = f0s;
    for k in 0..40 {
        _ = fire(SHARD, 6, $self_x, $self_y, 1.5fx, f0, CURVE_A, none);
        _ = fire(SHARD, 10, $self_x, $self_y, 1.5fx, f0 + 90deg, CURVE_A, none);
        _ = fire(SHARD, 11, $self_x, $self_y, 1.5fx, f0 + 180deg, CURVE_A, none);
        _ = fire(SHARD, 8, $self_x, $self_y, 1.5fx, f0 + 270deg, CURVE_A, none);
        f0 = f0 + 1820bam;   // 0.17453292f = 10°
        wait(1);
    }
}

// Sub44_572：每 2 帧一轮，4 组 bullet_random（count2=1，逐颗随机角/随机速）。
// 组 g 的 angle1 = 基准角（f0 依次 +0/+90/+180/+270，原文经归一化），angle2 = 5.625°=1024bam；
// 每颗角 = GetRandomF32InRange(a1−a2)+a2，速度 = GetRandomF32InRange(s1−s2)+s2 = [0.3, 1.2)。
// H：20 轮、组 3/4 count1=1；L：30 轮、组 3/4 count1=2。f0 每轮 −30°。
sub phase_b(f0s: angle, rank: int) {
    var i4: int = 20;
    var n34: int = 1;
    if rank >= RANK_LUNATIC { i4 = 30; n34 = 2; }
    // n0 = f0 归一化到 (−180°, 180°] 的有符号 BAM（原文每帧 math_norm_angle）
    var n0: int = (f0s as int) % 65536;
    if n0 > 32767 { n0 = n0 - 65536; }
    if n0 < -32768 { n0 = n0 + 65536; }
    var a1i: int = 0;
    var w: int = 0;
    var sp: fx = 0fx;
    var an: angle = 0deg;
    for k in 0..i4 {
        // 组 1：色 2，固定角 180°
        a1i = n0;
        w = a1i - 1024;
        for j1 in 0..1 {
            sp = 0.3fx + 0.9fx / 256 * rand(256);
            if w >= 0 { an = (1024 + rand(w)) as angle; } else { an = (1024 - rand(0 - w)) as angle; }
            _ = fire(SHARD, 2, $self_x, $self_y, sp, an, CURVE_180, none);
        }
        // 组 2：色 4，固定角 0°，基准 f0+90°
        a1i = n0 + 16384;
        if a1i > 32767 { a1i = a1i - 65536; }
        w = a1i - 1024;
        for j2 in 0..1 {
            sp = 0.3fx + 0.9fx / 256 * rand(256);
            if w >= 0 { an = (1024 + rand(w)) as angle; } else { an = (1024 - rand(0 - w)) as angle; }
            _ = fire(SHARD, 4, $self_x, $self_y, sp, an, CURVE_0, none);
        }
        // 组 3：色 13，固定角 135°，基准 f0+180°
        a1i = n0 + 32768;
        if a1i > 32767 { a1i = a1i - 65536; }
        w = a1i - 1024;
        for j3 in 0..n34 {
            sp = 0.3fx + 0.9fx / 256 * rand(256);
            if w >= 0 { an = (1024 + rand(w)) as angle; } else { an = (1024 - rand(0 - w)) as angle; }
            _ = fire(SHARD, 13, $self_x, $self_y, sp, an, CURVE_135, none);
        }
        // 组 4：色 14，固定角 45°，基准 f0+270°
        a1i = n0 + 49152;
        if a1i > 32767 { a1i = a1i - 65536; }
        w = a1i - 1024;
        for j4 in 0..n34 {
            sp = 0.3fx + 0.9fx / 256 * rand(256);
            if w >= 0 { an = (1024 + rand(w)) as angle; } else { an = (1024 - rand(0 - w)) as angle; }
            _ = fire(SHARD, 14, $self_x, $self_y, sp, an, CURVE_45, none);
        }
        n0 = n0 - 5461;   // −0.5235988f = −30°
        if n0 < -32768 { n0 = n0 + 65536; }
        wait(2);
    }
}

// Sub44 帧 41：move_rand_in_bounds(-π, π) + move_speed(3.0) + move_time_accelerate(80)。
// 边界沿用 Stage 3 boss 的 move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)（同 th06_s3_b1）。
// move_time_accelerate 用当前角速：位移 = 3.0 × 80 / 2 = 120 px，easing 1 = QuadIn。
sub wander_move() {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }             // (-π, π)
    if $self_x < -64.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > 64.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < 96.0fx && v < 0 { v = 0 - v; }
    if $self_y > 96.0fx && v > 0 { v = 0 - v; }
    var d: fx = 120.0fx;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
    if ty < 48.0fx { ty = 48.0fx; } else if ty > 144.0fx { ty = 144.0fx; }
    move_to(80, tx, ty, 1);
}

// Sub42：Sub43（宣言 + 移到中央）→ Sub44（攻击循环）。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);       // Sub43 enemy_kill_all()
    move_to(120, 0.0fx, 64.0fx, 2);      // Sub43 move_position_time_decelerate(120, 192, 64)
    wait(120);                           // Sub43 call("Sub10", 120, 0) 阻塞 120 帧
    var rank: int = global(GVAR_RANK);
    loop {
        var f0: angle = rand(65536) as angle;   // Sub44_20 set_float_rand_bound_min($F0, 2π, −π)
        phase_a(f0);                            // 40 帧
        f0 = f0 + 7264bam;                      // phase_a 内 40 次 +10°（40×1820 ≡ 7264 mod 65536）
        wander_move();                          // Sub44 帧 41 起 move_rand_in_bounds/move_speed/move_time
        wait(80);                               // call("Sub10", 80, 0) 阻塞 80 帧
        wait(20);                               // +20: //21
        phase_b(f0, rank);                      // H 20 轮 / L 30 轮 × 2 帧
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                 // 该 boss 的 enemy_set_hitbox(56,56,32) → 56/3（同 th06_s3_b1）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
