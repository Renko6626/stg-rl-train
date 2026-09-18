// th06_s5_b1 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）非符 1
// 原文：ecldata5 Sub24（+100 起循环）+ Sub25 出使魔 + Sub26 下向扇形 + Sub27–34 使魔米弹扇，
//       timer_callback_threshold(2700)。

const TIME_LIMIT: int = 2700;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER
const RICE: int = 64;        // TH06 弹型 2 RICE

// 与 TH06 一致：先进过场地，再离开（留 16px 贴图余量）就退场
async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

// move_bounds_set(32.0f, 48.0f, 352.0f, 132.0f) → 我方 (-160, 48)-(160, 132)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 132.0fx;
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

// Sub24：shoot_interval_delayed 自动打 8/16 颗 ARROWHEAD 自机狙环
// 参数窗口 = 配置后 120 帧（boss +100 配置，+220 关）
async sub autoshoot(interval: int, delayed: int) {
    var rank: int = global(GVAR_RANK);
    var ways: int = 8;
    var layers: int = 1;
    var s1: fx = 1.8fx;
    if rank == RANK_NORMAL { ways = 16; s1 = 2.0fx; }
    else if rank == RANK_HARD { ways = 16; layers = 2; s1 = 2.5fx; }
    else if rank >= RANK_LUNATIC { ways = 16; layers = 2; s1 = 3.0fx; }
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 3);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub24 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, ways, layers);
    sh_speed(0, s1, (1.0fx - s1) / layers);
    sh_angle(0, 0deg, 1638bam);            // a1=0, a2=9° 层间错开
    var t: int = 0;
    var first: int = interval;
    if delayed != 0 { first = interval - rand(interval); }
    if first > 120 { return; }
    wait(first); t = first;
    loop {
        sh_fire(0);
        if t + interval > 120 { return; }
        wait(interval); t = t + interval;
    }
}

// Sub27–34 的共用体：一只使魔。dir = move_dir_time_decelerate 方向，inc = 扇心每轮转向
// 使魔：RICE，E 4 颗 / N-H-L 5 颗，单层，速度 1.2/1.6/1.8/2.0，间隔 1.5°，每 6 帧一轮共 40 轮
async sub minion(dir: angle, inc: angle) {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
    var rank: int = global(GVAR_RANK);
    var n: int = 5;
    var s1: fx = 2.0fx;
    if rank == RANK_EASY { n = 4; s1 = 1.2fx; }
    else if rank == RANK_NORMAL { s1 = 1.6fx; }
    else if rank == RANK_HARD { s1 = 1.8fx; }
    var f0: angle = rand(65536) as angle;  // set_float_rand_bound_min($F0, 2π, -π)
    var d: fx = 0.8fx * 370 / 2;           // move_dir_time_decelerate(370, dir, 0.8)
    move_to(370, $self_x + cos(dir) * d, $self_y + sin(dir) * d, 2);
    wait(50);
    // L 档按 640 弹池等效折减：每 4 轮漏 1 轮（只减发射轮数，几何/时序/扇心推进不动）
    var cut_mod: int = 0;
    if rank >= RANK_LUNATIC { cut_mod = 4; }
    for k in 0..40 {
        sh_reset(0);
        sh_sprite(0, RICE, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, n, 1);
        sh_speed(0, s1, 0fx);
        sh_angle(0, f0, 273bam);           // a2 = 1.5°
        if cut_mod == 0 { sh_fire(0); }
        else if k % cut_mod != cut_mod - 1 { sh_fire(0); }
        f0 = f0 + inc;
        wait(6);
    }
    wait(60);                              // +60: //116
    die();
}

// Sub25：在 boss 位置出 4/6/8 只使魔（E/N 4，H 6，L 8）
sub sub25() {
    var rank: int = global(GVAR_RANK);
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(8192bam, 6554bam));      // Sub27 45°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(0deg, -3277bam));       // Sub28 0°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(24576bam, -6554bam));   // Sub29 135°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(32768bam, 3277bam));    // Sub30 180°
    if rank >= RANK_HARD {
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(4096bam, -3277bam));  // Sub33 22.5°
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(28672bam, 3277bam));  // Sub34 157.5°
    }
    if rank >= RANK_LUNATIC {
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(12288bam, 6554bam));  // Sub31 67.5°
        _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(20480bam, -6554bam)); // Sub32 112.5°
    }
    wait(60);
}

// Sub26：+170 起 12 轮下向（90°）扇形，扇面角度 1.5°→ 每轮 +18°，每轮 8 帧，收尾 +60 ret
sub sub26() {
    wait(170);
    var rank: int = global(GVAR_RANK);
    var c1: int = 2;
    var c2: int = 6;
    var s1: fx = 3.0fx;
    if rank == RANK_NORMAL { c2 = 8; s1 = 4.0fx; }
    else if rank == RANK_HARD { c1 = 4; c2 = 8; s1 = 4.0fx; }
    else if rank >= RANK_LUNATIC { c1 = 4; c2 = 8; s1 = 4.0fx; }
    var f0: angle = 512bam;                // set_float($F0, 0.049087387f)
    for k in 0..12 {
        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 2);
        sh_offset(1, 0.0fx, -12.0fx);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, c1, c2);
        sh_speed(1, s1, (1.2fx - s1) / c2);
        sh_angle(1, 16384bam, f0);         // 中轴 90°，扇面 f0
        sh_fire(1);
        f0 = f0 + 3277bam;                 // math_float_add($F0, %F0, 0.31415927f)
        wait(8);
    }
    wait(60);
}

async sub pattern() {
    wait(100);                             // Sub24 +100 起
    var rank: int = global(GVAR_RANK);
    var interval: int = 40;
    if rank == RANK_EASY { interval = 60; }
    else if rank == RANK_NORMAL { interval = 50; }
    else if rank == RANK_HARD { interval = 50; }
    loop {
        sub25();                           // 出使魔，内部 wait(60)
        spawn autoshoot(interval, 1);      // 配置自机狙环并延迟自动射击
        wander(1.7fx, 60);                 // +100
        wait(60);                          // +160
        wander(1.7fx, 60);
        wait(60);                          // +220
        wander(1.7fx, 60);
        sub26();                           // 内部 170 + 12×8 + 60
        wait(70);                          // +290
        wait(10);                          // +300 jump(100, Sub24_496)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                   // Sub23 enemy_set_hitbox(56, 56, 32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);   // Sub23 停在 (192, 128)
    loop { wait(600); }
}
