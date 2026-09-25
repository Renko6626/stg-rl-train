// th06_s4_b12 —— 东方红魔乡 Stage 4 boss 符卡 水符「ベリーインレイク」（自机 shot1 上级 H/L）
// 原文：ecldata4.ecl.txt Sub54（入口）→ Sub55（宣言 / timer 2100 / 移到中央 (192,80)）→ Sub56（攻击循环）。
// 每轮：12 组双向自机狙激光（每 10 帧一组）→ 8 轮 BUBBLE 扇形（每 10 帧一轮）→ 随机游走，之后回卷。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 46;      // 原文 H=46 / L=47；仅 UI/计分，取 H 的 46
const BALL: int = 48;          // TH06 弹型 3 BALL 中玉（16px，色号原样）
const LASERHEAD: int = 176;    // TH06 弹型 9 BUBBLE 气泡（16px，色号原样）
const LASER_COLOR: int = 13;   // laser sprite=0, color=6 → 8 色表 [0,2,4,6,8,10,13,15][6]
const LASER_STEP: int = 273;   // 激光角每轮 −0.02617994 rad = −1.5° = 273bam
const CIRCLE_A2: int = 3641;   // 圆环层间错开 0.34906584 rad = 20°

// 原文 Sub55 段前已由 Stage 4 boss 初始化：move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)。
// move_rand_in_bounds + move_speed(1.5f) + move_time_decelerate(90) 的 Boss 随机游走（mapping §7.3）。
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

// 原文 Sub56 开头：shoot_disable 期间配置 bullet_circle_aimed(3,6,24/30,2,3.0,1.8,0,20°,4)，
// shoot_enable + shoot_interval(22) 自动射击；到 +120 帧 shoot_interval(0) 停。
// 写法 A（mapping §4.3，2026-09-25 新口径）：原作首发 = S + n − 1，即 k = 21；
// 伴生任务出生当帧不跑，故 wait(k − 1) 后 sh_fire 正好落在 S + 21。
// 停火守卫用 k >= until（until = 原文 shoot_interval(0) 的相对帧 120）：开火帧 21/43/65/87/109。
async sub circle_auto(interval: int, until: int) {
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    var n: int = 24;                                    // !H count1 = 24
    if global(GVAR_RANK) >= RANK_LUNATIC { n = 30; }    // !L count1 = 30
    sh_count(0, n, 2);                                  // 2 层
    sh_speed(0, 3.0fx, (1.8fx - 3.0fx) / 2);            // 速度 3.0 / 2.4
    sh_angle(0, 0deg, CIRCLE_A2 as angle);              // 层间错开 20°
    sh_offset(0, 0.0fx, 0.0fx);
    var k: int = interval - 1;                          // 首发相对设定帧 S 的偏移
    if k >= until { return; }
    if k > 0 { wait(k - 1); }                           // 落在 S + k
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

async sub pattern() {
    kill_all_enemies(KILL_SILENT);                      // Sub55 enemy_kill_all()
    move_to(120, 0.0fx, 80.0fx, 2);                     // move_position_time_decelerate(120, 192, 80)
    wait(120);                                          // +120: Sub55 ret，进入 Sub56

    var rank: int = global(GVAR_RANK);
    var fan_a2: angle = 4096bam;                        // !H 0.3926991 = 22.5°
    var fan_sp: fx = 3.5fx;                             // !H speed1
    if rank >= RANK_LUNATIC { fan_a2 = 3277bam; fan_sp = 3.8fx; }   // !L 18° / 3.8
    var f0: angle = 4096bam;                            // F0 = π/8
    var f1: angle = 0deg;
    var f0f: angle = 0deg;                              // 扇形中轴
    var lz0: int = -1;
    var lz1: int = -1;
    loop {
        // ---- Sub56_0：12 组双向自机狙激光，每 10 帧一组 ----
        // laser_create_aimed(0, 6, F0/F1, 0, 0, 640, 640, 8, 20, 50, 10, 20, 10, 0)
        //   → 原点 = 敌 + shoot_offset(0,0)，warn/active/fade = 20/50/10，宽 8/2 = 4
        spawn circle_auto(22, 120);
        f0 = 4096bam;
        for k1 in 0..12 {
            lz0 = laser(LASER_COLOR, $self_x, $self_y, 0bam, 640.0fx, 4.0fx, 20, 50, 10);
            lz_aim(lz0, f0);
            lz1 = laser(LASER_COLOR, $self_x, $self_y, 0bam, 640.0fx, 4.0fx, 20, 50, 10);
            lz_aim(lz1, 0bam - f0);
            f0 = f0 - LASER_STEP as angle;              // F0 -= 1.5°
            wait(10);                                   // +10: jump_dec(0, Sub56_188, $I4)
        }
        // +10: shoot_interval(0)（由 circle_auto 的 until 表达）+ 随机游走
        wander(1.5fx, 90);
        // ---- Sub56_512：8 轮 BUBBLE 扇形，每 10 帧一轮 ----
        // bullet_fan_aimed(9, 1, 10, 1, 3.5/3.8, 0.7, %F0, 22.5°/18°, 0)
        f0f = 0deg;
        for k2 in 0..8 {
            sh_reset(1);
            sh_sprite(1, LASERHEAD, 1);
            sh_aim(1, 1);
            sh_ring(1, 0);
            sh_count(1, 10, 1);
            sh_speed(1, fan_sp, (0.7fx - fan_sp) / 1);
            sh_angle(1, f0f, fan_a2);
            sh_offset(1, 0.0fx, 0.0fx);
            sh_fire(1);
            // set_float_rand_bound_min($F1, 0.17453292, -0.08726646) → [-5°, +5°)
            f1 = -910bam + rand(1820) as angle;
            f0f = f0f - f1;                             // math_float_sub($F0, %F0, %F1)
            wait(10);                                   // +10: jump_dec(10, Sub56_512, $I4)
        }
        // +10: //20 随机游走 + math_inc($I7)
        wander(1.5fx, 90);
        wait(50);                                       // +50: //70 jump(0, Sub56_0)
    }
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
