// th06_s7_b3 —— 东方红魔乡 Stage 7（Extra）boss 非符 2
// 原文：ecldata7.ecl.txt Sub43（行 1102–1146），Sub38 death_callback 进入；timer/life 回调 1800。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;          // TH06 弹型 2 RICE

// flags 513 = 0x201 = 0x200(音效,丢弃) | 0x1(出生后 16 帧额外速度 5→0)
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// move_bounds_set(32, 48, 352, 120) → 我方 (-160,48)-(160,120)。
// move_rand_in_bounds(-π, π) 含 TH06 的边界反射（EclManager.cpp:626）。
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
    // ---- 原文 Sub43 t=0：只保留有行为的指令 ----
    set_enemy_flag(ENEMY_NO_BODY, 0);        // flag_invisible(0) + collision(1) + interactable(1)
    kill_all_enemies(KILL_SILENT);           // enemy_kill_all()
    wait(90);                                // +30 drop_items(20)；+60 到 t=90

    // ---- t=90：原文 shoot_disable 期间只配置发射器，之后靠 shoot_interval(30) 自动射击 ----
    sh_reset(0);
    sh_sprite(0, RICE, 2);
    sh_offset(0, 0.0fx, -12.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 64, 2);
    sh_speed(0, 2.0fx, -0.5fx);              // (1.0 − 2.0) / 2
    var a0: angle = rand(65536) as angle;    // set_float_rand_bound_min($F0, 2π, −π)
    sh_angle(0, a0, 0deg);
    sh_xform(0, BURST);
    wander(2.5fx, 50);                       // t=90 第一次移动，move_time_decelerate(50)

    // 自动射击：原作首发 = 90 + 30 − 1 = t=119（§4.3），之后每 30 帧；移动每 110 帧一次（jump(90)）
    var t: int = 90;
    var nxt_move: int = 200;
    var nxt_fire: int = 119;
    loop {
        wait(1);
        t = t + 1;
        if t == nxt_move { wander(2.5fx, 50); nxt_move = nxt_move + 110; }
        if t == nxt_fire { sh_fire(0); nxt_fire = nxt_fire + 30; }
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                     // Sub37 enemy_set_hitbox(56,56,32) 沿用 → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
