// th06_s6_b4 —— 东方红魔乡 Stage 6 关底 boss 非符 2（自机狙扇形 + 随机弹螺旋）
// 原文：ecldata6.ecl.txt Sub21（:452，攻击从 +60 起）+ Sub22（:517）/ Sub23（:550）/ Sub24（:595），
//       timer_callback_threshold(2700)、life_callback_threshold(1600) 确定段边界。逐段对照见 report.md。
const TIME_LIMIT: int = 2700;
const LASERHEAD: int = 176;   // TH06 弹型 6 BIG_BALL / 9 BUBBLE
const OUTLINE: int = 32;      // TH06 弹型 1 RING_BALL

// Sub21 的 boss 随机游走：move_rand_in_bounds(-π,π) + move_speed(2.5) + move_time_decelerate(t)。
// move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)（mapping §7.3）。
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
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

// Sub22 每轮：bullet_fan_aimed(9, 0, 1, 1, 6.0, 1.2, 0, 0, 4)，单颗 BUBBLE 自机狙。
// bullet_rank_influence(0, 0.8, 0, 0, 0, 0) 在 rank16 下 rs = 16·0.8/32 = 0.4 → s1 = 6.4（count2=1）。
sub fire_bubble() {
    sh_reset(0);
    sh_sprite(0, LASERHEAD, 0);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 6.4fx, 0fx);
    sh_angle(0, 0bam, 0bam);
    sh_fire(0);
}

// Sub22：开头 effect_particle ×20（每 5 帧，视觉丢弃、时序保留）→ 之后每 step 帧发一颗，共 total 颗。
sub sub22() {
    var rank: int = global(GVAR_RANK);
    wait(100);
    fire_bubble();
    if rank == RANK_EASY { wait(20); return; }       // E：两条 jump_dec 都不执行，只发 1 颗
    var total: int = 8;
    var step: int = 10;                              // !HL jump_dec(5,…) 在 +15
    if rank == RANK_NORMAL { total = 5; step = 20; } // !N jump_dec(5,…) 在 +25
    var k: int = 1;
    while k < total {
        wait(step);
        fire_bubble();
        k = k + 1;
    }
    wait(20);                                        // 最后一轮 jump_dec + 到 +25 的尾等待
}

// Sub23/Sub24 每轮：1 颗 BUBBLE 绝对角 f2 + 四组绕 f2 的随机弹（bullet_random 逐颗 fire）。
// F0 = f2 − δ、F1 = f2 + δ；角度区间 [f2−δ, f2+δ)；rank 影响 s += 0.4 / s2 += 0.2。
sub fire_spiral(f2: angle) {
    sh_reset(0);
    sh_sprite(0, LASERHEAD, 0);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 7.4fx, 0fx);                         // bullet_fan(9,0,1,1,7.0,1.2,…)
    sh_angle(0, f2, 0bam);
    sh_fire(0);

    // bullet_random(6, 1, 3, 1, 6.0, 5.0, F0, F1, 4)：±5.625°，速度 [5.2, 6.4)
    var i1: int = 0;
    while i1 < 3 {
        var sp1: fx = 5.2fx + 1.2fx / 256 * rand(256);
        var an1: angle = (f2 - 1024bam) + (rand(2048) as angle);
        _ = fire(LASERHEAD, 2, $self_x, $self_y - 12.0fx, sp1, an1, none, none);
        i1 = i1 + 1;
    }
    // bullet_random(6, 1, 5, 1, 5.0, 4.0, F0, F1, 4)：±9°，速度 [4.2, 5.4)
    var i2: int = 0;
    while i2 < 5 {
        var sp2: fx = 4.2fx + 1.2fx / 256 * rand(256);
        var an2: angle = (f2 - 1638bam) + (rand(3276) as angle);
        _ = fire(LASERHEAD, 2, $self_x, $self_y - 12.0fx, sp2, an2, none, none);
        i2 = i2 + 1;
    }
    // bullet_random(1, 2, 5, 1, 4.0, 2.0, F0, F1, 4)：±18°，速度 [2.2, 4.4)
    var i3: int = 0;
    while i3 < 5 {
        var sp3: fx = 2.2fx + 2.2fx / 256 * rand(256);
        var an3: angle = (f2 - 3277bam) + (rand(6554) as angle);
        _ = fire(OUTLINE, 2, $self_x, $self_y - 12.0fx, sp3, an3, none, none);
        i3 = i3 + 1;
    }
    // bullet_random(1, 2, 5, 1, 2.0, 1.0, F0, F1, 4)：±45°，速度 [1.2, 2.4)
    var i4: int = 0;
    while i4 < 5 {
        var sp4: fx = 1.2fx + 1.2fx / 256 * rand(256);
        var an4: angle = (f2 - 8192bam) + (rand(16384) as angle);
        _ = fire(OUTLINE, 2, $self_x, $self_y - 12.0fx, sp4, an4, none, none);
        i4 = i4 + 1;
    }
}

// Sub23/Sub24 公共骨架：100 帧蓄力 → 每轮 f2 += step → 共 8 轮（E 只 1 轮）。
// !HL jump_dec 在 +13（每轮 8 帧）、!N jump_dec 在 +20（每轮 15 帧）；末轮后统一再等 15 帧。
sub spiral(start: angle, step: angle) {
    var rank: int = global(GVAR_RANK);
    wait(100);
    var f2: angle = start;
    fire_spiral(f2);
    if rank == RANK_EASY { wait(15); return; }
    var w: int = 8;
    if rank == RANK_NORMAL { w = 15; }
    var k: int = 1;
    while k < 8 {
        wait(w);
        f2 = f2 + step;
        fire_spiral(f2);
        k = k + 1;
    }
    wait(15);
}

sub sub23() { spiral(0deg, 4096bam); }               // set_float($F2, 0.0f)，每轮 +22.5°
sub sub24() { spiral(32768bam, -4096bam); }          // set_float($F2, π)，每轮 −22.5°

// Sub21 +60 起的主循环：每轮 4 次移动 + Sub22/Sub23/Sub24/Sub22。
// 原文三处 jump_dec(60/61/62, …, $I4) 是等上一攻击收尾的门；进入本段时 $I4 已 ≤0（Sub21 从不写它），
// 退化为无等待，按调用序列照写。
async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var t: int = 90;                                 // !EN move_time_decelerate(90)
    if rank == RANK_HARD || rank >= RANK_LUNATIC { t = 60; }   // !HL 60
    loop {
        wander(2.5fx, t);                            // Sub21_420
        wait(1);                                     // +1 //61
        sub22();
        wander(2.5fx, t);
        wait(1);                                     // +1 //62
        sub23();
        wander(2.5fx, t);
        wait(1);                                     // +1 //63
        sub24();
        sub22();
        wait(10);                                    // +10 //73 → jump(60, Sub21_420)
    }
}

async sub boss_main() {
    set_hitbox(18.67fx);   // 段外继承：boss 初始化 Sub17 (56,56,32) → §6.1b
    set_invuln(65535);
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
