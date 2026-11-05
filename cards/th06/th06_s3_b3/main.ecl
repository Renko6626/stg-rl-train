// th06_s3_b3 —— 东方红魔乡 Stage 3 boss（十六夜咲夜）非符 2
// 原文：ecldata3.ecl.txt Sub24（+160 起）+ Sub25 + Sub26/27/28 + Sub29，timer 2400。

const TIME_LIMIT: int = 2400;
const BALL: int = 48;    // TH06 弹型 3 BALL 中玉
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI 苦无

// Sub27 的 bullet_effects(-1,-1,-1,-1, 0.025f, 1.5707964f, …) + flags 25(0x10|0x8|0x1)：
// 出生冲刺 5.0 用 16 帧线性降到原速，此后沿固定角 90° 永久加速 0.025（0x8 出生特效不模拟）。
xformdef BURST_GRAV {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0.0fx, 0.025fx);
}

// 出界即删（TH06 先进过场地再出界就回收，留 16px 贴图余量）
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

// move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)。
// move_rand_in_bounds + move_speed(2.0) + move_time_accelerate(80)：位移 = speed·t/2 = 80，缓动 QuadIn。
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
    move_to(t, tx, ty, 1);
}

// ── boss 本体发弹（c1 已加 bullet_rank_influence(-1,1,-2,6,0,0) 在 rank16 的 +2）──

// Sub26：中玉环 ×3（+0 / +70 / +140；色号 5 / 6 / 5），a1 每发重抽 [−π,π)，层间偏移 15°
sub boss_circle(shape: int, color: int, n: int, layers: int, s1: fx, s2: fx) {
    var a1: angle = (rand(65536) - 32768) as angle;
    sh_reset(0);
    sh_sprite(0, shape, color);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (s2 - s1) / layers);
    sh_angle(0, a1, 2731bam);
    sh_fire(0);
}

sub sub26() {
    var rank: int = global(GVAR_RANK);
    var layers: int = 1;
    var n: int = 18;
    if rank == RANK_NORMAL { layers = 2; }
    else if rank == RANK_HARD { layers = 3; }
    else if rank >= RANK_LUNATIC { layers = 3; n = 22; }
    boss_circle(BALL, 5, n, layers, 3.0fx, 2.0fx);
    wait(70);
    boss_circle(BALL, 6, 18, 2, 3.0fx, 2.0fx);   // 中间一发色号 6
    wait(70);
    boss_circle(BALL, 5, n, layers, 3.0fx, 2.0fx);
}

// Sub27：中玉(3,6) 随机散弹 ×3，角度 [−π,0)、速度 [0.3,2.0)，flags 25 → BURST_GRAV
// 逐颗 fire 的循环直接内联（带参子调用每帧吃满单任务 1024 指令预算）；出弹点当帧不变先读出。
sub sub27() {
    var rank: int = global(GVAR_RANK);
    var n: int = 10;
    if rank == RANK_NORMAL { n = 16; }
    else if rank == RANK_HARD { n = 20; }
    else if rank >= RANK_LUNATIC { n = 22; }
    var px: fx = $self_x;
    var py: fx = $self_y;
    var step: fx = 1.7fx / 256;           // 速度 [0.3, 2.0)
    for i1 in 0..n {
        var spa: fx = 0.3fx + step * rand(256);
        var ana: angle = (rand(32768) - 32768) as angle;
        _ = fire(BALL, 6, px, py, spa, ana, BURST_GRAV, none);
    }
    wait(70);
    for i2 in 0..18 {
        var spb: fx = 0.3fx + step * rand(256);
        var anb: angle = (rand(32768) - 32768) as angle;
        _ = fire(BALL, 6, px, py, spb, anb, BURST_GRAV, none);
    }
    wait(70);
    for i3 in 0..n {
        var spc: fx = 0.3fx + step * rand(256);
        var anc: angle = (rand(32768) - 32768) as angle;
        _ = fire(BALL, 6, px, py, spc, anc, BURST_GRAV, none);
    }
}

// Sub28：中玉(3,5) 随机散弹 ×3，角度整周、速度 [1.3,4.0)，flags 2（无变换）
sub sub28() {
    var rank: int = global(GVAR_RANK);
    var n: int = 14;
    if rank == RANK_NORMAL { n = 26; }
    else if rank == RANK_HARD { n = 30; }
    else if rank >= RANK_LUNATIC { n = 34; }
    var px: fx = $self_x;
    var py: fx = $self_y;
    var step: fx = 2.7fx / 256;           // 速度 [1.3, 4.0)
    // 首发 L 有 34 颗，单任务每帧 1024 指令预算放不下，拆成两帧各 17（见 report 近似）
    var first: int = n;
    if n > 30 { first = n / 2; }
    for j1 in 0..first {
        var sp1: fx = 1.3fx + step * rand(256);
        var an1: angle = rand(65536) as angle;   // 整周；[−π,π) 与 [0,2π) 同集合
        _ = fire(BALL, 5, px, py, sp1, an1, none, none);
    }
    if n > 30 { wait(1); }
    for j1b in 0..(n - first) {
        var sp1b: fx = 1.3fx + step * rand(256);
        var an1b: angle = rand(65536) as angle;
        _ = fire(BALL, 5, px, py, sp1b, an1b, none, none);
    }
    wait(70);
    for j2 in 0..18 {
        var sp2: fx = 1.3fx + step * rand(256);
        var an2: angle = rand(65536) as angle;
        _ = fire(BALL, 5, px, py, sp2, an2, none, none);
    }
    wait(70);
    for j3 in 0..26 {
        var sp3: fx = 1.3fx + step * rand(256);
        var an3: angle = rand(65536) as angle;
        _ = fire(BALL, 5, px, py, sp3, an3, none, none);
    }
}

// Sub25：一次生成 6 只使魔（x = 32/352/96/288/160/224，y = -32），+30/+30 两批
sub sub25() {
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, familiar);
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, familiar);
    wait(30);
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, familiar);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, familiar);
    wait(30);
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, familiar);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, familiar);
}

// Sub29：使魔。竖直下移 1.5 并以 -0.05/帧 减速 30 帧到静止（逐帧积分），
// 之后 4 轮：H/L 每轮 16 路自机狙环 + 30 发苦无扇（E/N 各 1 颗、H/L 各 3 颗，速度 +0.18/发）。
async sub familiar() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    move_vel(0, ang, spd, 0);
    for k1 in 0..40 { wait(1); }                                  // +40 之前恒速
    for k2 in 0..30 { spd = spd - 0.05fx; move_vel(0, ang, spd, 0); wait(1); }  // +40 move_acceleration(-0.05)
    spd = 0fx;
    move_vel(0, ang, spd, 0);                                     // +70 move_acceleration(0)
    for round in 0..4 {
        if round > 0 { wait(30); }                                // 外层 jump_dec 回 Sub29_96 的 +30
        var f0: angle = aim_player();                             // math_float_add($F0, %PLAYER_ANGLE, 0)
        var f1: fx = 1.6fx;
        if rank >= RANK_HARD {
            // !HL bullet_circle_aimed(3, 6, 16, 1, 1.6f, 0.0f, %F0, 22.5°, 4)
            sh_reset(0);
            sh_sprite(0, BALL, 6);
            sh_aim(0, 1);
            sh_ring(0, 1);
            sh_count(0, 16, 1);
            sh_speed(0, 1.6fx, 0fx);
            sh_angle(0, f0, 4096bam);
            sh_fire(0);
        }
        for i in 0..30 {
            // !E/!N 1 颗、!H/!L 3 颗：bullet_fan(4, 6, 1|3, 1, %F1, 0.0f, %F0, 30°, 4)
            sh_reset(1);
            sh_sprite(1, KUNAI, 6);
            sh_aim(1, 0);
            sh_ring(1, 0);
            var fn: int = 1;
            if rank >= RANK_HARD { fn = 3; }
            sh_count(1, fn, 1);
            sh_speed(1, f1, 0fx);
            sh_angle(1, f0, 5461bam);
            sh_fire(1);
            f1 = f1 + 0.18fx;
            wait(2);
        }
        wait(160);                                                // +160
    }
    var fly: angle = 45deg + rand(16384) as angle;                // set_float_rand_bound_min($F2, π/2, π/4)
    move_vel(0, fly, 1.5fx, 0);
    wait(9768);                                                   // +9768 之后 enemy_delete（多半先被出界守卫回收）
    die();
}

// Sub24：每 160+... 帧一轮：Sub25 出使魔 → 4 次（随机 Sub26/27/28 → 随机游走 80 帧）→ 等 120
async sub pattern() {
    wait(160);
    loop {
        sub25();
        for i6 in 0..4 {
            var i0: int = rand(3);
            if i0 == 0 { sub26(); }
            else if i0 == 1 { sub27(); }
            else { sub28(); }
            wander(2.0fx, 80);
            wait(80);
        }
        wait(120);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                   // enemy_set_hitbox(56,56,32) → 56/3
    set_enemy_flag(ENEMY_NO_BODY, 0);      // enemy_flag_collision(1) + interactable(1)
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    kill_all_enemies(KILL_SILENT);         // 原作收段 Sub30 的 enemy_kill_all()：清掉残留使魔
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
