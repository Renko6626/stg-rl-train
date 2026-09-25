// th06_s4_b11 —— 东方红魔乡 Stage 4 boss（帕秋莉）符卡 水符「プリンセスウンディネ」
// 原文：ecldata4.ecl.txt Sub51（入口）→ Sub52（宣言 + 移到中央）→ Sub53（激光棒 + 弹幕循环），时限 2100。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 44;       // 原文 spellcard_start 的 E 值（N 为 45；ranks 只取 E/N）
const BALL: int = 48;           // TH06 弹型 3 BALL
const LASERHEAD: int = 176;     // TH06 弹型 6 BIG_BALL（判定偏小，§3 已知）

// 原文 Sub52 的 move_bounds_set 在单元外（boss 初始化段），本单元没带边界。
// 沿用 mapping §7.3 的 boss 常见边界 (32,48)-(352,144) → (-160,48)-(160,144)。
sub wander(t: int, spd: fx) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                       // (-π, π)
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
    move_to(t, tx, ty, 2);                                 // move_time_decelerate
}

// Sub53 激光段的 shoot_interval(22) + bullet_fan_aimed(3, 6, 16, 2, 3.5, 1.2, π, π/9, 4)：
// 以「自机方向 + 180°」为中轴的 16 颗 × 2 层扇（正中 60° 缝朝自机），每 22 帧自动开火一次，
// 激光段结束（120 帧）停。写法 A（mapping §4.3 新口径）：k = n − 1，wait(k − 1)，停火守卫 k >= until。
// 伴生任务出生当帧不跑（S+1 才首跑），wait(k − 1) 正好落在原作开火帧 S + (n − 1)。
async sub autoshoot(interval: int, until: int) {
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_count(0, 16, 2);
    sh_speed(0, 3.5fx, (1.2fx - 3.5fx) / 2);               // 层速 3.5 / 2.35
    sh_angle(0, 32768bam, 3641bam);                        // 180° 中轴，20° 间隔
    var k: int = interval - 1;                             // 原作首发 = S + n − 1
    if k >= until { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var i7: int = 0;                                       // Sub51 set_int($I7, 0)
    var i0: int = 0;
    var f0: angle = 0bam;                                  // 角度累加器
    var f1: angle = 0bam;                                  // N 档抖动
    var lz_a: int = 0;
    var lz_b: int = 0;
    var lz_c: int = 0;
    // Sub52：spellcard_start / enemy_kill_all / shoot_interval(0) / shoot_offset(0,0)
    //        timer_callback_threshold(2100) 都在外壳表达；这里只留
    //        move_position_time_decelerate(120, 192.0, 80.0) + +120 ret。
    kill_all_enemies(KILL_SILENT);
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);
    loop {                                                 // Sub53_0
        // ---- 激光段：12 波 × 3 根飞棒，每波间隔 10 帧 ----
        spawn autoshoot(22, 120);                          // 首发 = 周期起点 S + 21
        f0 = 4096bam;                                      // math_float_div($F0, π, 8) = π/8 = 22.5°
        for k in 0..12 {                                   // jump_dec(0, Sub53_144, $I4=12)
            // laser_create_aimed(0, 6, 0, 4.0, 0, 0, 96, 6, 0, 9999, 30, 0, 30, 0)
            // 色 6（sprite 0 → 8 色表 13），宽 6 → 3，sl 96，速度 4 的飞棒
            lz_a = laser(13, $self_x, $self_y, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
            lz_aim(lz_a, 0bam);
            lz_speed(lz_a, 4.0fx, 96.0fx);
            lz_b = laser(13, $self_x, $self_y, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
            lz_aim(lz_b, f0);
            lz_speed(lz_b, 4.0fx, 96.0fx);
            lz_c = laser(13, $self_x, $self_y, 0bam, 0.0fx, 3.0fx, 0, 9999, 30);
            lz_aim(lz_c, 0bam - f0);                       // math_float_sub($F1, 0.0, %F0)
            lz_speed(lz_c, 4.0fx, 96.0fx);
            f0 = f0 - 273bam;                              // math_float_sub($F0, %F0, 0.02617994) = 1.5°
            wait(10);
        }
        // ---- 弹幕段：8 轮，每轮一发 ----
        wander(90, 1.5fx);                                 // move_rand_in_bounds + move_speed(1.5) + move_time_decelerate(90)
        f0 = 0bam;                                         // set_float($F0, 0.0)
        sh_reset(0);
        sh_sprite(0, LASERHEAD, 6);                        // 弹型 6 色 3 → 8 色表 [3] = 6
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_offset(0, 0.0fx, 0.0fx);
        sh_speed(0, 2.5fx, 0fx);
        for k2 in 0..8 {                                   // jump_dec(10, Sub53_532, $I4=8)
            i0 = i7 + 1;                                   // set_int($I0, $I7); math_int_add($I0, 1)
            sh_count(0, 10, 1);
            sh_angle(0, f0, 2341bam);                      // 0.22439948 rad = 12.857°
            sh_fire(0);                                    // bullet_fan_aimed(6, 3, 10, 1, 2.5, 0.7, %F0, 0.2244, 0)
            if rank == RANK_NORMAL {                       // !N
                sh_reset(1);
                sh_sprite(1, BALL, 6);
                sh_aim(1, 1);
                sh_ring(1, 0);
                sh_offset(1, 0.0fx, 0.0fx);
                sh_count(1, i0, 1);
                sh_speed(1, 0.7fx, 0fx);
                sh_angle(1, f0, 3641bam);                  // 20°
                sh_fire(1);                                // bullet_fan_aimed(3, 6, $I0, 1, 0.7, 0.7, %F0, 0.3491, 0)
                f1 = (-1170bam) + (rand(2341) as angle);   // set_float_rand_bound_min($F1, 0.2244, -0.1122)
                f0 = f0 - f1;                              // math_float_sub($F0, %F0, %F1)
            }
            wait(10);
        }
        wander(90, 1.5fx);                                 // 第二轮 move_rand_in_bounds + move_time_decelerate
        i7 = i7 + 1;                                       // math_inc($I7)
        wait(50);                                          // +50 jump(0, Sub53_0)
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
    // Sub52 move_position_time_decelerate 的目标点 (192,80) → (0,80)；起点未知，落在目标点
    _ = spawn_enemy(0.0fx, 80.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
