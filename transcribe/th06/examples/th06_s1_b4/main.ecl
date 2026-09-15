// th06_s1_b4 —— 东方红魔乡 Stage 1 boss（露米娅）符卡 闇符「ディマーケイション」
// 原文：ecldata1 Sub29 → Sub30（宣言 + 移到中央 + bullet_rank_influence）+ Sub31（攻击循环），时限 1500。
// 一个 sub 引用 4 个 xformdef 会超 locals 上限（每物理槽 3 字），所以环与扫射拆成两个同步任务。
// 逐段对照见 notes.md。
const TIME_LIMIT: int = 1500;
const SPELL_ID: int = 5;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const RICE: int = 64;      // TH06 弹型 2 RICE
const CYCLE: int = 336;    // Sub31 一轮：0/60/120 三对环 + 180 起两轮扫射（96 帧）+ 60

// flags 68 = 0x40|0x4 + bullet_effects(40, 1, -1, -1, ±1.5707964f, 1.5f, …)：减速 40 帧 → 转 ±90° → 速度 1.5
xformdef TURN_R { @40 step_speed(0fx, 40); turn(90deg); set_speed(1.5fx); }
xformdef TURN_L { @40 step_speed(0fx, 40); turn(-90deg); set_speed(1.5fx); }
// flags 132 = 0x80|0x4 + bullet_effects(40, 1, -1, -1, 0.0f, 3.0f / 4.0f, …)：减速 40 帧 → 瞄自机 → 速度 3 / 4
xformdef AIM_S3 { @40 step_speed(0fx, 40); aim_player(0deg); set_speed(3.0fx); }
xformdef AIM_S4 { @40 step_speed(0fx, 40); aim_player(0deg); set_speed(4.0fx); }

// Sub30 保留的 move_bounds_set(32.0f, 48.0f, 352.0f, 144.0f) → (-160, 48)-(160, 144)
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

// 一对环：先 xf_first 的环（相位 0），再 xf_second 的环（相位 a1）。
// sh_xform 与 sh_fire 必须在同一个 sub 里（xformdef 暂存在本 sub 的 locals）。
async sub rings() {
    var rank: int = global(GVAR_RANK);
    // bullet_rank_influence(-1.0f, 1.0f, -3, 6, 0, 0)：rank 16 下 c1 += 16·9/32 − 3 = 1，速度 +0（mapping §4.6）
    // 环：!E 12 / !N 16 / !H 28（+60 那对 H 是 20）/ !L 28 × 2 层（s2 1.0）
    var n: int = 13;
    var n60: int = 13;
    var ly: int = 1;
    var s2: fx = 0.3fx;
    var a1: angle = 2731bam;               // 0.2617994f
    if rank == RANK_NORMAL { n = 17; n60 = 17; a1 = 2048bam; }                           // 0.19634955f
    else if rank == RANK_HARD { n = 29; n60 = 21; a1 = 1638bam; }                        // 0.15707964f
    else if rank >= RANK_LUNATIC { n = 29; n60 = 29; ly = 2; s2 = 1.0fx; a1 = 1170bam; }  // 0.11219974f
    sh_reset(0);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_speed(0, 3.0fx, (s2 - 3.0fx) / ly);
    sh_xform(0, TURN_R);
    sh_reset(1);
    sh_offset(1, 0.0fx, -12.0fx);
    sh_aim(1, 1);
    sh_ring(1, 1);
    sh_speed(1, 3.0fx, (s2 - 3.0fx) / ly);
    sh_xform(1, TURN_L);
    loop {                                 // Sub31_0
        sh_sprite(0, RICE, 6);  sh_count(0, n, ly);   sh_angle(0, 0deg, 0deg); sh_fire(0);    // +0   右转环
        sh_sprite(1, RICE, 6);  sh_count(1, n, ly);   sh_angle(1, a1, 0deg);   sh_fire(1);    //      左转环（错开）
        wait(60);
        sh_sprite(1, RICE, 10); sh_count(1, n60, ly); sh_angle(1, 0deg, 0deg); sh_fire(1);    // +60  左转环
        sh_sprite(0, RICE, 10); sh_count(0, n60, ly); sh_angle(0, a1, 0deg);   sh_fire(0);    //      右转环（错开）
        wait(60);
        sh_sprite(0, RICE, 2);  sh_count(0, n, ly);   sh_angle(0, 0deg, 0deg); sh_fire(0);    // +120 右转环
        sh_sprite(1, RICE, 2);  sh_count(1, n, ly);   sh_angle(1, a1, 0deg);   sh_fire(1);    //      左转环（错开）
        wait(CYCLE - 120);
    }
}

// +180 起：bullet_fan_aimed(1, 6, 1(+1), 1, %F0, 0.0f, %F1, 0.09817477f, 132) 两轮逆 / 顺扫
async sub sweeps() {
    var rank: int = global(GVAR_RANK);
    sh_reset(2);
    sh_sprite(2, OUTLINE, 6);
    sh_offset(2, 0.0fx, -12.0fx);
    sh_aim(2, 1);
    sh_count(2, 2, 1);
    if rank >= RANK_HARD { sh_xform(2, AIM_S4); } else { sh_xform(2, AIM_S3); }
    var f0: fx = 0fx;
    var f1: angle = 0deg;
    wait(180);
    loop {
        wander(2.0fx, 120);                // move_rand_in_bounds; move_speed(2.0f); move_time_decelerate(120)
        for rep in 0..2 {                  // set_int($I5, 2) … jump_dec(180, Sub31_1588, $I5)
            f0 = 1.0fx;
            f1 = -5958bam;                 // -0.57119864f
            for ka in 0..12 {              // Sub31_1648：每 2 帧一发
                wait(2);
                sh_speed(2, f0, 0fx);
                sh_angle(2, f1, 1024bam);
                sh_fire(2);
                f0 = f0 + 0.2fx;
                f1 = f1 + 1489bam;         // 0.14279966f
            }
            f0 = 1.0fx;
            f1 = 5958bam;
            for kb in 0..12 {              // Sub31_1824
                wait(2);
                sh_speed(2, f0, 0fx);
                sh_angle(2, f1, 1024bam);
                sh_fire(2);
                f0 = f0 + 0.2fx;
                f1 = f1 - 1489bam;
            }
        }
        wander(2.0fx, 60);                 // move_time_decelerate(60)
        wait(60);                          // +244 jump(0, Sub31_0)：到下一轮的 +180 还有 180 帧
        wait(180);
    }
}

async sub pattern() {
    move_to(120, 0.0fx, 96.0fx, 2);        // Sub30 move_position_time_decelerate(120, 192.0f, 96.0f, 0.0f)
    wait(120);                             // Sub30 +120 ret → Sub31 开始
    spawn rings();
    spawn sweeps();
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(17.33fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
