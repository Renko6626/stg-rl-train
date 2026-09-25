// th06_s1_b3 —— 东方红魔乡 Stage 1 boss（露米娅）非符 2
// 原文：ecldata1.ecl.txt Sub19（:567）+ Sub22/23/24/25 尾调用链，timer_callback_threshold(1800)。
const TIME_LIMIT: int = 1800;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const RICE: int = 64;      // TH06 弹型 2 RICE

// move_bounds_set(32, 48, 352, 144)（Sub13 设、之后一直生效）→ 我方 (-160,48)-(160,144)
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

// TH06 速度钳位（s1≠0 时 ≥0.3，s2 恒 ≥0.3）+ 层速公式（mapping §4.2）
sub fan_aimed(shape: int, color: int, n: int, layers: int, s1: fx, s2: fx, a1: angle, spread: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, shape, color);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub13 shoot_offset(0.0f, -12.0f, 0.0f) 粘滞
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, t1, (t2 - t1) / layers);
    sh_angle(0, a1, spread);
    sh_fire(0);
}

sub circle_aimed(shape: int, color: int, n: int, layers: int, s1: fx, s2: fx, a1: angle, a2: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(1);
    sh_sprite(1, shape, color);
    sh_offset(1, 0.0fx, -12.0fx);
    sh_aim(1, 1);
    sh_ring(1, 1);
    sh_count(1, n, layers);
    sh_speed(1, t1, (t2 - t1) / layers);
    sh_angle(1, a1, a2);
    sh_fire(1);
}

// Sub22：+12 环玉扇（E1/N2/H5/L7 × 8 层），+20…+60 六条自机狙激光
//（w=16 → 8.0fx，预警 120 / 生效 60 / 收缩 16；原点 = 敌位置 + shoot_offset(0,-12)）
sub sub22() {
    wander(3.0fx, 60);
    var rank: int = global(GVAR_RANK);
    var n: int = 1;
    if rank == RANK_NORMAL { n = 2; }
    else if rank == RANK_HARD { n = 5; }
    else if rank >= RANK_LUNATIC { n = 7; }
    wait(12);
    fan_aimed(OUTLINE, 10, n, 8, 3.0fx, 1.0fx, 0deg, 1024bam);
    var lz: int = 0;
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(8);
    lz = laser(13, $self_x, $self_y - 12.0fx, 0bam, 500.0fx, 8.0fx, 120, 60, 16);
    lz_aim(lz, 0bam);
    wait(164);                              // 60 → 224：跳过的只是 effect_sound
}

// Sub23：三发米弹环（+60/+120 同形）+ 小玉环（+90，自机狙）
sub sub23() {
    wander(3.0fx, 60);
    var rank: int = global(GVAR_RANK);
    var n1: int = 24;
    var l1: int = 1;
    var s1a: fx = 2.0fx;
    var s2a: fx = 1.0fx;
    if rank == RANK_NORMAL { n1 = 36; }
    else if rank == RANK_HARD { n1 = 48; l1 = 2; }
    else if rank >= RANK_LUNATIC { n1 = 48; l1 = 2; s1a = 3.0fx; s2a = 1.5fx; }
    wait(60);
    circle_aimed(RICE, 10, n1, l1, s1a, s2a, 0deg, 0deg);
    var n2: int = 28;
    var l2: int = 1;
    var s1b: fx = 2.6fx;
    var s2b: fx = 1.0fx;
    if rank >= RANK_LUNATIC { n2 = 32; l2 = 2; s1b = 3.6fx; s2b = 1.5fx; }
    wait(30);
    circle_aimed(BULLET, 10, n2, l2, s1b, s2b, 0deg, 0deg);
    wait(30);
    circle_aimed(RICE, 10, n1, l1, s1a, s2a, 0deg, 0deg);
    wait(120);
}

// Sub24：三发米弹自机狙扇（+60/+80/+100，颗数逐发不同）
sub sub24() {
    wander(3.0fx, 60);
    var rank: int = global(GVAR_RANK);
    var spread: angle = 5461bam;
    if rank == RANK_NORMAL { spread = 2731bam; }
    else if rank == RANK_HARD { spread = 2048bam; }
    else if rank >= RANK_LUNATIC { spread = 1365bam; }
    var n: int = 4;
    if rank == RANK_NORMAL { n = 8; }
    else if rank == RANK_HARD { n = 12; }
    else if rank >= RANK_LUNATIC { n = 16; }
    wait(60);
    fan_aimed(RICE, 13, n, 2, 3.0fx, 1.0fx, 0deg, spread);
    n = 5;                                  // Easy 第 2 发无条件置回该档值，别靠上一发残留
    if rank == RANK_NORMAL { n = 9; }
    else if rank == RANK_HARD { n = 15; }
    else if rank >= RANK_LUNATIC { n = 23; }
    wait(20);
    fan_aimed(RICE, 13, n, 2, 3.0fx, 1.0fx, 0deg, spread);
    n = 7;                                  // Easy 第 3 发
    if rank == RANK_NORMAL { n = 10; }
    else if rank == RANK_HARD { n = 14; }
    else if rank >= RANK_LUNATIC { n = 20; }
    wait(20);
    fan_aimed(RICE, 13, n, 2, 3.0fx, 1.0fx, 0deg, spread);
    wait(120);
}

// Sub25：随机方向扫射扇；速度每发 +0.25，中轴角每发 ±8.182°，共 16 发、每 2 帧一发
// I0=0 走 Sub25_456（中轴从 +40.91° 起、逐发 −8.182°），否则从 −40.91° 起逐发 +8.182°
sub sub25() {
    wander(3.0fx, 60);
    var rank: int = global(GVAR_RANK);
    var n: int = 2;
    var ly: int = 1;
    var s2: fx = 0.0fx;
    if rank == RANK_HARD { n = 3; ly = 2; s2 = 1.0fx; }
    else if rank >= RANK_LUNATIC { n = 4; ly = 3; s2 = 1.0fx; }
    var f0: fx = 1.0fx;
    var f1: angle = 0deg;
    var r: int = rand(2);
    if r == 0 {
        f1 = 7447bam;                       // +40.91°
        wait(2);                            // jump_equ 设 time=2 + 块内 +2，实际共 +2（与 r==1 同）
        for k1 in 0..16 {
            fan_aimed(OUTLINE, 10, n, ly, f0, s2, f1, 1489bam);
            f0 = f0 + 0.25fx;
            f1 = f1 - 1489bam;
            if k1 < 15 { wait(2); }
        }
    } else {
        f1 = -7447bam;                      // −40.91°
        wait(2);
        for k2 in 0..16 {
            fan_aimed(OUTLINE, 10, n, ly, f0, s2, f1, 1489bam);
            f0 = f0 + 0.25fx;
            f1 = f1 + 1489bam;
            if k2 < 15 { wait(2); }
        }
    }
    wait(120);                              // jump(4, Sub25_740) + +120
}

// 尾调用链调度（mapping §2.4）：Sub22/23/24/25 末尾随机 call_equ 下一个，从不 ret
async sub pattern() {
    wait(200);                              // Sub19 +200: call("Sub22")
    var next: int = 22;
    var r: int = 0;
    loop {
        if next == 22 {
            sub22();
            r = rand(3);
            if r == 0 { next = 23; } else if r == 1 { next = 24; } else { next = 25; }
        } else if next == 23 {
            sub23();
            r = rand(3);
            if r == 0 { next = 22; } else if r == 1 { next = 24; } else { next = 25; }
        } else if next == 24 {
            sub24();
            r = rand(3);
            if r == 0 { next = 23; } else if r == 1 { next = 22; } else { next = 25; }
        } else {
            sub25();
            r = rand(3);
            if r == 0 { next = 23; } else if r == 1 { next = 24; } else { next = 22; }
        }
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                     // Sub13 enemy_set_hitbox(48, 56, 32) → min(48,56)/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
