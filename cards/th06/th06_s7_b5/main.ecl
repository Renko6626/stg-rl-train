// th06_s7_b5 —— Stage 7(Extra) boss 芙兰朵露 非符 3
// 原文：ecldata7.ecl.txt Sub48（行 1274–1318），timer_callback_threshold(1800) → Sub49。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;            // TH06 弹型 2 RICE

// Sub48 bullet_circle(2, 2, 32, 3, 4.0f, 1.0f, %F0, 0.0f, 513)：flags 0x1 = 出生冲刺（§5）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160, 48)-(160, 120)
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

// 原文 +90：shoot_disable → 随机基准角 → bullet_circle 配置 → shoot_enable → shoot_interval(60)。
// 之后每 60 帧用同一组 bulletProps 自动开火，直到 1800 帧超时。
// k = 原作开火帧相对设定帧 S（配置帧）的偏移：首发 k = interval − 1，此后每 interval 帧（§4.3 写法 A）。
// 子任务出生当帧不跑，首跑已在 S+1，故 wait(k − 1) 正好落在 S+k，与原作逐帧一致。
// until = 1710：原文 shoot_interval(0) 在绝对帧 1800，S 在 pattern 第 90 帧，k < 1710 才开火。
async sub autoshoot(interval: int, until: int) {
    var f0: angle = rand(65536) as angle;      // set_float_rand_bound_min($F0, 2π, −π)
    sh_reset(0);
    sh_sprite(0, RICE, 2);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 32, 3);
    sh_speed(0, 4.0fx, (1.0fx - 4.0fx) / 3);
    sh_angle(0, f0, 0deg);
    sh_xform(0, BURST);
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

async sub pattern() {
    set_enemy_flag(ENEMY_NO_BODY, 0);          // enemy_flag_invisible(0)/collision(1)/interactable(1)
    kill_all_enemies(KILL_SILENT);             // enemy_kill_all()（跳过调用者）
    var i7: int = 0;                           // set_int($I7, 0)
    wait(90);                                  // 原文 +90
    spawn autoshoot(60, 1710);                 // shoot_interval(60)
    loop {
        wander(2.5fx, 90);                     // move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(90)
        wait(100);                             // 到 +190
        i7 = i7 + 1;                           // math_inc($I7)
        wait(10);                              // 到 +200
        // jump(90, Sub48_532)：跳回时间 90 的循环顶
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                       // 上游 Sub37 enemy_set_hitbox(56,56,32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
