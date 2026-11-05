// th06_s6_mb1 —— 东方红魔乡 Stage 6 中 boss 非符 1
// 原文：ecldata6.ecl.txt Sub9（+30 起 Sub9_772 循环）+ Sub10 + Sub11，timer_callback_threshold(1020)。
const TIME_LIMIT: int = 1020;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（32px，色 3 → 我方 6）
const KUNAI: int = 80;       // TH06 弹型 4 KUNAI

// Sub11 苦无：flags 66 = 0x40|0x2 + bullet_effects(60, 1, -1, -1, %F2, -999, …)
// 0x40：60 帧内线性减速到 0，随后 angle += 随机角、速度恢复原速（`f1 < 0` 保持原速）。
// 随机角是运行期值，xformdef 参数须编译期常量，故改成挂在每颗弹上的私有任务，
// 用 set_accel 复刻线性减速（TH06 每帧把 speed 直接写成 v0·(1−t/60)，等价于切向加速度 −v0/60）。
async sub kunai_drift() {
    set_accel(0, -2.5fx / 60);
    wait(60);
    set_accel(0, 0fx);
    turn(0, rand(65536) as angle);
    set_speed(0, 2.5fx);
}

// Sub10：DAGGER 扇形（bullet_fan(8, 3, E4/N8/H12/L12, 1, E2.8/N3.2/H3.2/L4.8, 1.0, %F1, 15°, 0)）
// 每次调用 12 发、每发间隔 4 帧，中轴 F1 每发 +step。
sub sub10(f1: angle, step: angle) {
    var rank: int = global(GVAR_RANK);
    var cnt: int = 4;
    var spd: fx = 2.8fx;
    if rank == RANK_NORMAL { cnt = 8; spd = 3.2fx; }
    else if rank == RANK_HARD { cnt = 12; spd = 3.2fx; }
    else if rank >= RANK_LUNATIC { cnt = 12; spd = 4.8fx; }
    var a: angle = f1;
    for k in 0..12 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, cnt, 1);
        sh_speed(0, spd, 0fx);
        sh_angle(0, a, 2731bam);           // 15°
        sh_fire(0);
        a = a + step;
        wait(4);
    }
}

// Sub11：KUNAI 随机朝向扇形（set_int($I4, 16) + jump_dec，每帧一发共 16 发）
// bullet_fan(4, 2, E3/N5/H7/L9, 1, 2.5, 1.0, %F1, a2, 66)，%F1 每发重抽；
// 苦无的减速/随机转向（%F2，每发重抽）交给 kunai_drift。
sub sub11() {
    var rank: int = global(GVAR_RANK);
    var cnt: int = 3;
    var spread: angle = 655bam;            // 3.6°
    if rank == RANK_NORMAL { cnt = 5; spread = 468bam; }        // 2.571°
    else if rank == RANK_HARD { cnt = 7; spread = 410bam; }     // 2.25°
    else if rank >= RANK_LUNATIC { cnt = 9; spread = 364bam; }  // 2°
    for k in 0..16 {
        var ang: angle = rand(65536) as angle;                  // set_float_rand_bound_min($F1, 2π, -π)
        wait(1);                                                // +1: //1
        sh_reset(0);
        sh_sprite(0, KUNAI, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, cnt, 1);
        sh_speed(0, 2.5fx, 0fx);
        sh_angle(0, ang, spread);
        sh_task(0, kunai_drift);
        sh_fire(0);
    }
}

// move_rand_in_bounds(-π, π); move_speed(1.5); move_time_decelerate(90)
// move_bounds_set(32.0f, 48.0f, 352.0f, 128.0f) → 我方 (-160, 48)-(160, 128)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 128.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                 // (-π, π)
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
    // 原文 +30 前是登场/设置；Sub10 的 L 档首扇（12 路、15° 间隔、4.8 速）当场就有一路朝正下方，
    // 按 +30 首发会在卡开始后约 76 帧打到自机出生点，不满足 120 帧安全，故补到 110 帧。
    wait(110);
    loop {
        sub10(0deg, 2731bam);              // Sub9_772: F1 = 0；call Sub10(+15°)
        wander(1.5fx, 90);
        sub11();                           // call Sub11
        wait(1);                           // +1
        sub10(180deg, -2731bam);           // F1 = 180°；call Sub10(-15°)
        sub11();
        wait(1);                           // +1；jump(30) 回到循环头
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(13.33fx);                   // enemy_set_hitbox(40, 56, 32) → 40/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);   // move_position(192.0f, 128.0f)
    loop { wait(600); }
}
