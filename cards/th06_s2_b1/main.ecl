// th06_s2_b1 —— 东方红魔乡 Stage 2 boss（琪露诺）非符 1
// 原文：ecldata2.ecl.txt Sub22（登场设置 +70 call Sub23）+ Sub23（自机狙鳞弹扇 ×3）+ Sub24（随机游走 + 三波环），
//       Sub23/Sub24 尾调用互调；段边界 timer_callback_threshold(1500)（E/N→Sub30，H/L→Sub33）。逐段对照见 report.md。
const TIME_LIMIT: int = 1500;
const SHARD: int = 96;    // TH06 弹型 5 SHARD（16px，色号原样）
const BALL: int = 48;     // TH06 弹型 3 BALL（16px，色号原样）
const OUTLINE: int = 32;  // TH06 弹型 1 RING_BALL（16px，色号原样）

// Sub24 第二波：bullet_effects(60, 1, -1, -1, 0.0f, 4.0f, -1.0f, -1.0f) + flags 132(0x80|0x4)
// 0x80：60 帧线性减速到 0 → 朝向自机 + f0(=0) → 速度设为 f1(=4.0)
xformdef DECEL_AIM { @60 step_speed(0fx, 60); aim_player(0deg); set_speed(4.0fx); }

// ── 发射器（TH06 出弹口 shoot_offset(0.0f, -12.0f, 0.0f) 全程粘滞）──────────────

// Sub23 自机狙鳞弹扇：以 a1 为中轴、a2 逐颗间隔对称展开，n 颗 × 1 层（bullet_fan）
sub shard_fan(n: int, s1: fx, a1: angle, a2: angle) {
    var t1: fx = s1;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, SHARD, 6);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, n, 1);
    sh_speed(0, t1, 0fx);
    sh_angle(0, a1, a2);
    sh_fire(0);
}

// Sub23 H/L：中玉整周环，基准 a1、层间错开 a2，n 颗 × layers 层（bullet_circle）
sub ball_circle(n: int, layers: int, s1: fx, s2: fx, a1: angle, a2: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, t1, (t2 - t1) / layers);
    sh_angle(0, a1, a2);
    sh_fire(0);
}

// Sub24 第一/三波：环玉自机狙环（开火当帧从出弹口朝自机定向），n 颗 × layers 层（bullet_circle_aimed）
sub outline_ring(n: int, layers: int, s1: fx, s2: fx) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 6);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, t1, (t2 - t1) / layers);
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
}

// Sub24 第二波：鳞弹自机狙环 + 60 帧减速后转头追自机（flags 132）
sub shard_ring_homing(n: int, s1: fx) {
    var t1: fx = s1;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, SHARD, 15);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_speed(0, t1, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, DECEL_AIM);
    sh_fire(0);
}

// ── Sub24 三波，按档取颗数 / 层数 / 速度 ───────────────────────────────────────
// bullet_rank_influence(-0.5, 0.3, 0, 4, 0, 0)，开局 rank 16 → speed −0.1、count1 +2（mapping §4.6）

// 第一波：!E 8 / !N 16 / !H 24 / !L 24×2，speed1 2.0 → 1.9；flags 4（无变换）
sub burst1(rank: int) {
    var n: int = 10;                       // E: 8+2
    var layers: int = 1;
    var s2: fx = 0fx;
    if rank == RANK_NORMAL { n = 18; }
    else if rank == RANK_HARD { n = 26; }
    else if rank >= RANK_LUNATIC { n = 26; layers = 2; s2 = 0.95fx; }
    outline_ring(n, layers, 1.9fx, s2);
}

// 第二波：!E 16 / !N 32 / !H 32 / !L 32，speed1 E2.0/N3.0/H4.0/L5.0 → −0.1；flags 132（DECEL_AIM）
sub burst2(rank: int) {
    var n: int = 18;                       // E: 16+2
    var s: fx = 1.9fx;
    if rank == RANK_NORMAL { n = 34; s = 2.9fx; }
    else if rank == RANK_HARD { n = 34; s = 3.9fx; }
    else if rank >= RANK_LUNATIC { n = 34; s = 4.9fx; }
    shard_ring_homing(n, s);
}

// 第三波：!E 6 / !N 14 / !H 16 / !L 16×2，speed1 E4.0/N2.0/H2.0/L2.0 → −0.1；flags 4
sub burst3(rank: int) {
    var n: int = 8;                        // E: 6+2
    var s: fx = 3.9fx;
    var layers: int = 1;
    var s2: fx = 0fx;
    if rank == RANK_NORMAL { n = 16; s = 1.9fx; }
    else if rank == RANK_HARD { n = 18; s = 1.9fx; }
    else if rank >= RANK_LUNATIC { n = 18; s = 1.9fx; layers = 2; s2 = 0.95fx; }
    outline_ring(n, layers, s, s2);
}

// Sub24：move_speed(3.0f) + 每轮 move_rand_in_bounds(-π,π) / move_time_decelerate(60) + 三波环；
// 每轮 time_set($I7*3 / $I7*5) 把后面的等待缩短（mapping §2.4）
sub sub24(i7: int, ang: angle, rank: int) {
    move_vel(0, ang, 3.0fx, 0);            // move_speed(3.0f)：保持朝向、速度 3.0（Sub23 移动结束时的朝向）
    var i4: int = 3;
    var d3: int = i7 * 3;
    var d5: int = i7 * 5;
    wait(1);                               // +1 块（set_int($I4,3) / bullet_rank_influence）：首次进入也要先过 +1 帧
    for k2 in 0..3 {                       // Sub24_72 … jump_dec(1, Sub24_72, $I4)
        wait(20);                          // +21（首轮 0→1→21 共 21 帧，jump_dec 后每轮 20）
        // move_rand_in_bounds(-π, π)：边界 (-160,48)-(160,134) → x 反射阈值 ±64、y 阈值 96 / 86
        var v: int = rand(65536);
        if v >= 32768 { v = v - 65536; }
        if $self_x < -64.0fx {
            if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
        }
        if $self_x > 64.0fx {
            if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
        }
        if $self_y < 96.0fx && v < 0 { v = 0 - v; }
        if $self_y > 86.0fx && v > 0 { v = 0 - v; }
        // move_time_decelerate(60)：沿 v 位移 speed·t/2 = 3.0·60/2 = 90
        // 目标点夹紧到 Sub21 move_bounds_set(32,48,352,134) → 我方 x∈[-160,160]、y∈[48,134]
        // （TH06 每帧 ClampPos，EnemyManager.cpp:469-490/:542/:571；只反射角度不足以留在带内）
        var tx: fx = $self_x + cos(v as angle) * 90.0fx;
        var ty: fx = $self_y + sin(v as angle) * 90.0fx;
        if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
        if ty < 48.0fx { ty = 48.0fx; } else if ty > 134.0fx { ty = 134.0fx; }
        move_to(60, tx, ty, 2);
        // bullet_effects(…) 折进 DECEL_AIM
        burst1(rank);
        wait(20 - d3);                     // +41，time_set($I7*3)
        burst2(rank);
        wait(20 - d3);                     // +61，time_set($I7*3)
        burst3(rank);
        wait(40 - d5);                     // +101，time_set($I7*5)
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var i7: int = 0;                       // Sub22 +50 set_int($I7, 0)
    var ang: angle = 0deg;
    wait(70);                              // Sub22 +70 call("Sub23")
    loop {
        // ── Sub23：move_position_time_decelerate(40, 192, 96) + 自机狙鳞弹扇 ×3 ──
        var f1: angle = 683bam;            // !H / !L 基准散布
        if rank == RANK_EASY { f1 = 431bam; } else if rank == RANK_NORMAL { f1 = 585bam; }
        ang = atan2(96.0fx - $self_y, 0.0fx - $self_x);   // 本段移动结束时的朝向（供 Sub24 开场漂移）
        move_to(40, 0.0fx, 96.0fx, 2);
        var i4: int = 3;
        wait(41);                          // jump_dec 目标时刻；+41 起第一发
        for k1 in 0..3 {
            var f0: angle = aim_player();  // math_float_add($F0, %PLAYER_ANGLE, 0.0f)
            // bullet_rank_influence(-0.5,1.0, 0,2,0,0) rank16 → speed +0.25、count1 +1
            shard_fan(2, 5.25fx, f0, f1);  wait(2);   // +41
            shard_fan(3, 4.75fx, f0, f1);  wait(2);   // +43
            shard_fan(4, 4.25fx, f0, f1);  wait(2);   // +45
            shard_fan(5, 3.75fx, f0, f1);  wait(2);   // +47
            shard_fan(6, 3.25fx, f0, f1);  wait(2);   // +49
            shard_fan(7, 2.75fx, f0, f1);             // +51
            if rank == RANK_HARD { ball_circle(17, 1, 3.25fx, 1.125fx, f0, f1); }
            else if rank >= RANK_LUNATIC { ball_circle(33, 2, 3.25fx, 1.125fx, f0, f1); }
            if rank == RANK_EASY { f1 = f1 + 410bam; }
            else if rank == RANK_HARD { f1 = f1 + 512bam; }
            else if rank >= RANK_LUNATIC { f1 = f1 + 683bam; }
            else { f1 = f1 + 512bam; }                 // N
            wait(60);                                  // → +111，jump_dec 回 +41
        }
        // ── Sub24：随机游走 + 三波环 ──
        sub24(i7, ang, rank);
        i7 = i7 + 1;                       // Sub24 末尾 math_int_add($I7, $I7, 1)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);      // Sub22 enemy_flag_collision(1)
    set_hitbox(16.0fx);                    // Sub21 enemy_set_hitbox(48, 56, 32) → min/3 = 16
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // Sub21 move_position(192, 96)
    loop { wait(600); }
}
