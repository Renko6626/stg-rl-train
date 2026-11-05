// th06_s7_b11 —— 东方红魔乡 Stage 7(Extra) boss 非符 6
// 原文：ecldata7 Sub65（:1810-1854），全档 !ENHL；timer/life_callback_threshold(1800/2200) → Sub66。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;      // TH06 弹型 2 RICE

// flags 513 = 0x200(音效，丢) | 0x1(出生冲刺)：出生后 16 帧额外速度 5→0 线性衰减（mapping §5）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// bullet_circle(2, 6, 32, 2, 3.5f, 1.0f, %F0, 0.0f, 513) + shoot_interval(30)
// 单次配置：32 颗 × 2 层，速度 3.5/2.25，整周环、基准角随机；之后每 30 帧自动射击。
async sub autoshoot(interval: int, until: int) {
    var a0: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, −π)
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_offset(0, 0.0fx, -12.0fx);           // shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 32, 2);
    sh_speed(0, 3.5fx, -1.25fx);            // (s2 − s1) / c2 = (1.0 − 3.5) / 2
    sh_angle(0, a0, 0deg);
    sh_xform(0, BURST);
    // k = 原作开火帧相对设定帧 S 的偏移：首发 n − 1，此后每 n 帧（§4.3 写法 A）
    var k: int = interval - 1;
    if k >= until { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// move_rand_in_bounds(-π, π) + move_speed(2.5f) + move_time_decelerate(90)（mapping §7.3）
// move_bounds_set(32, 48, 352, 120) → 我方 (-160, 48)-(160, 120)
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

async sub pattern() {
    set_enemy_flag(ENEMY_NO_BODY, 0);       // invisible(0)/collision(1)/interactable(1) → NO_BODY=0
    kill_all_enemies(KILL_SILENT);          // enemy_kill_all()
    wait(90);                               // +30 的 can_take_damage / drop_items 已丢 → +60 //90
    spawn autoshoot(30, 1710);              // shoot_interval(30)；until = 1800 − 90（本任务起点）
    var i7: int = 0;                        // set_int($I7, 0)
    loop {
        wander(2.5fx, 90);                  // Sub65_532
        wait(100);                          // +100 //190
        i7 = i7 + 1;                        // math_inc($I7)
        wait(10);                           // +10 //200 → jump(90, Sub65_532)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                    // 回调链上游 Sub37 enemy_set_hitbox(56, 56, 32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
