// th06_s7_mb1 —— 东方红魔乡 Stage Extra 中 boss 帕秋莉 符卡 月符「サイレントセレナ」
// 原文：ecldata7 Sub17（设置）→ Sub22 → Sub23（宣言 + 移至中央 + timer 2100）+ Sub24（攻击循环）。
// 逐段对照与近似见 report.md。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 118;
const RICE: int = 64;   // TH06 弹型 2 RICE
// §4.2b 等效截止：原文 bullet_fan 颗数随 I7 无上限增长（到 2100 帧约 81 颗），
// 我方 64px 回收边距让向上的扇弹在场时间约为原作 3 倍，无截止峰值 1415 > 1024。
// 按「颗数折减」把扇弹颗数封顶（原文 640 弹池同量级），依据与实测见 report.md。
const FAN_CAP: int = 40;

// Sub17 保留的 move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160,48)-(160,120)
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

// Sub24 的 bullet_random(2, 6, 1, 1, 0.0f, 0.0f, 1.59534f, 1.5462526f, 24)：
// flags 24 = 0x10 | 0x8。0x10 = 出生后 i0=96 帧沿自身方向加速度 f0（f1=-999）；
// f0 每颗随机 [0.005, 0.025)，xformdef 参数必须是常量，故用挂弹任务表达（0x8 出生特效不模拟）。
async sub rand_accel() {
    var a: fx = 0.005fx + 0.02fx / 256 * rand(256);
    set_accel(0, a);
    wait(96);
    stop_fx(0);
}

async sub pattern() {
    // Sub23：move_position_time_decelerate(120, 192.0f, 80.0f, 0.0f) → 移到中央
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);
    // Sub24
    var i7: int = 0;
    var i0: int = 0;
    var f0: fx = 0fx;
    var f1: fx = 0fx;
    var sp: fx = 0fx;
    var ang: angle = 0deg;
    sh_reset(0);
    sh_sprite(0, RICE, 8);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_speed(0, 2.7fx, 0fx);
    loop {
        // Sub24_0 / Sub24_20：每轮 2 颗随机弹
        for k1 in 0..2 {
            f0 = 384.0fx / 256 * rand(256);        // set_float_rand_bound($F0, 384.0f)
            f1 = 180.0fx / 256 * rand(256);        // set_float_rand_bound($F1, 180.0f)
            sp = 0.3fx - 0.3fx / 256 * rand(256);  // bullet_random 速度：s1=0，s2 钳到 0.3
            ang = 16128bam + rand(512) as angle;   // 角度 [1.5462526, 1.59534) = [88.59°, 91.41°)
            // 出弹点 = 敌位置 + (F0 - SELF_X, F1 - SELF_Y) = (F0, F1) → 我方 (F0-192, F1)
            _ = fire(RICE, 6, f0 - 192.0fx, f1, sp, ang, none, rand_accel);
        }
        // Sub24_400：bullet_fan(2, 8, I0, 1, 2.7f, 2.0f, -1.5707964f, 0.2617994f, 0)
        i0 = i7 / 5 + 12;                          // math_int_div + math_int_add
        if i0 > FAN_CAP { i0 = FAN_CAP; }          // §4.2b 等效截止（颗数折减）
        sh_count(0, i0, 1);
        sh_angle(0, -16384bam, 2731bam);           // 中轴 -90°、间隔 15°
        sh_fire(0);
        if i7 % 32 == 7 {                          // jump_neq 跳过：仅 I7%32==7 时移动
            wander(1.5fx, 90);                     // move_rand_in_bounds + move_speed + move_time_decelerate(90)
        }
        i7 = i7 + 1;
        // +6: jump(0, Sub24_0)
        wait(6);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(13.33fx);   // enemy_set_hitbox(40.0f, 56.0f) → min(40,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // Sub16 结束时 boss 位于 (192.0f, 120.0f) TH06 = (0.0fx, 120.0fx)
    _ = spawn_enemy(0.0fx, 120.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
