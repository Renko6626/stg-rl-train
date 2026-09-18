// th06_s5_mb1 —— 东方红魔乡 Stage 5 中 boss（十六夜咲夜）非符
// 原文：ecldata5 Sub13（+30 起）+ Sub14 + Sub15，timer_callback_threshold(2400)。逐段对照见 report.md。
const TIME_LIMIT: int = 2400;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（32px，色 3→6）
const KUNAI: int = 80;       // TH06 弹型 4 KUNAI

// move_bounds_set(32.0f, 48.0f, 352.0f, 176.0f) → 我方 (-160, 48)-(160, 176)
// move_rand_in_bounds + move_speed(1.5) + move_time_decelerate(90)（mapping §7.1/§7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 176.0fx;
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

// Sub14：DAGGER 扇 ×10，中轴以 f0 每发递增；8 帧一发，共 80 帧
// bullet_fan(8, 3, E4/NHL8, 1, E2.8/NHL3.2, 1.0, %F1, 0.28559932, 0)
sub arrow_fan(f0: angle, f1: angle) {
    var rank: int = global(GVAR_RANK);
    var n: int = 4;
    var sp: fx = 2.8fx;
    if rank >= RANK_NORMAL { n = 8; sp = 3.2fx; }
    for k1 in 0..10 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, n, 1);
        sh_speed(0, sp, 1.0fx - sp);
        sh_angle(0, f1, 2979bam);
        sh_fire(0);
        f1 = f1 + f0;
        wait(8);
    }
}

// Sub15：KUNAI 扇 ×10，中轴以 f0 每发递增；3 帧一发，共 30 帧
// bullet_fan(4, 2, E4/N4/H5/L5, E1/N2/H2/L3, 2.0, 1.0, %F1, 0.044879895, 0)
sub kunai_fan(f0: angle, f1: angle) {
    var rank: int = global(GVAR_RANK);
    var n: int = 4;
    var ly: int = 1;
    if rank == RANK_NORMAL { ly = 2; }
    else if rank == RANK_HARD { n = 5; ly = 2; }
    else if rank >= RANK_LUNATIC { n = 5; ly = 3; }
    for k2 in 0..10 {
        sh_reset(1);
        sh_sprite(1, KUNAI, 2);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, n, ly);
        sh_speed(1, 2.0fx, (1.0fx - 2.0fx) / ly);
        sh_angle(1, f1, 468bam);
        sh_fire(1);
        f1 = f1 + f0;
        wait(3);
    }
}

// Sub13：+30 起 Sub13_360 循环；call 同步，F1 由调用方每次显式重建（ret 会恢复调用方变量）
async sub pattern() {
    wait(120);                             // 原文 +30，额外补 90 帧开场缓冲（见 report 近似）
    loop {
        arrow_fan(3277bam, 0deg);          // call Sub14(0, +18°)，F1=0
        wander(1.5fx, 90);                 // move_rand_in_bounds / move_speed / move_time_decelerate
        kunai_fan(-3277bam, 32768bam);     // call Sub15(0, -18°)，F1=π
        wait(30);                          // +60
        arrow_fan(-3277bam, 32768bam);     // call Sub14(0, -18°)，F1=π
        kunai_fan(3277bam, 0deg);          // call Sub15(0, +18°)，F1=0
        wait(1);                           // +1，回到 +30
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(13.33fx);                   // enemy_set_hitbox(40, 56, 32) → 40/3
    clear_bullets_at(0.0fx, 224.0fx, 1024.0fx, 0);   // bullet_cancel
    kill_all_enemies(KILL_SILENT);         // enemy_kill_all
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);   // move_position(192.0f, 128.0f, 0.0f)
    loop { wait(600); }
}
