// th06_s5_b4 —— 东方红魔乡 Stage 5 boss 非符 4（原文 ecldata5 Sub36 + Sub37 + Sub38–42）
// 原文：ecldata5.ecl.txt:877-934(Sub36), 936-944(Sub37), 946-1064(Sub38–41), 1066-1089(Sub42)；攻击从 +60 起
const TIME_LIMIT: int = 2700;
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER
const KUNAI: int = 80;       // TH06 弹型 4 KUNAI

// Sub38–41 flags 2560(0x800 左右上反弹 | 0x200) + bullet_effects(i0 = 反弹次数, …)
xformdef BOUNCE1 { bounce_arm(7, 1); }   // E/N：1 次
xformdef BOUNCE2 { bounce_arm(7, 2); }   // H/L：2 次

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

// Sub38/39/40/41：四只使魔。move_dir_time_decelerate(370, dir, 0.8)（位移 0.8*370/2 = 148）
// 后在 +50 起每 14 帧发一次 bullet_fan(4, 2, c1, 1, s1, 1.2, %F0, 0.9°=164bam, 2560)，共 17 次，
// 基准角每发按 inc 递增。四只只有 dir 与 inc 不同；子弹随机基准角由 F0 抽取。
async sub minion(dir_angle: angle, inc: angle, color: int) {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);         // enemy_flag_interactable(0)
    var rank: int = global(GVAR_RANK);
    var c1: int = 4;
    var s1: fx = 1.4fx;
    var b2: int = 0;
    if rank == RANK_NORMAL { c1 = 6; s1 = 1.6fx; }
    else if rank == RANK_HARD { c1 = 5; s1 = 1.8fx; b2 = 1; }
    else if rank >= RANK_LUNATIC { c1 = 5; s1 = 2.2fx; b2 = 1; }
    var d: fx = 148.0fx;
    move_to(370, $self_x + cos(dir_angle) * d, $self_y + sin(dir_angle) * d, 2);
    var f0: angle = rand(65536) as angle;     // set_float_rand_bound_min($F0, 2π, −π)
    wait(50);
    for k1 in 0..17 {                         // math_int_div($I4, 250, 14) = 17
        sh_reset(0);
        sh_sprite(0, KUNAI, color);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, c1, 1);
        sh_speed(0, s1, 1.2fx - s1);
        sh_angle(0, f0, 164bam);
        if b2 != 0 { sh_xform(0, BOUNCE2); } else { sh_xform(0, BOUNCE1); }
        sh_fire(0);
        f0 = f0 + inc;
        wait(14);
    }
    wait(60);                                 // +60: //124 enemy_delete(0)
    die();
}

// Sub37：在 boss 当前位置生成四只使魔（Sub38–41），60 帧后返回
sub sub37() {
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(8192bam, 6554bam, 2));    // Sub38 45°,  +36°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(0bam, -2048bam, 6));      // Sub39 0°,   −11.25°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(24576bam, -6554bam, 6));  // Sub40 135°, −36°
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, minion(32768bam, 2048bam, 2));   // Sub41 180°, +11.25°
    wait(60);
}

// Sub42：+100 等 100 帧后发一整环 bullet_circle(8, 3, 24, 1, 2.0, 1.2, 90°=16384bam, 512bam, 512)，
// 再等 60 帧返回（cmp_float/%SELF_X 的 anm 分支丢弃）。总阻塞 160 帧。
sub sub42() {
    wait(100);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 6);               // TH06 弹型 8 色 3 → 我方色 6
    sh_offset(1, 0.0fx, -12.0fx);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 24, 1);
    sh_speed(1, 2.0fx, 1.2fx - 2.0fx);
    sh_angle(1, 16384bam, 512bam);
    sh_fire(1);
    wait(60);
}

// Sub36 +60 循环的自动射击：shoot_disable → bullet_circle_aimed(8,3,n,layers,s1,1.0,0,9°,516)
// → shoot_enable → shoot_interval_delayed(interval)。窗口是每轮 [60, 180)，到 180 停火
// （shoot_interval_delayed(0)），然后等到 480（= 主循环周期 420）。写法 A，k = n − 1 − rand(n)，k < 120 才发。
async sub boss_auto(interval: int, n: int, layers: int, s1: fx) {
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 6);               // TH06 弹型 8 色 3 → 我方色 6
    sh_offset(0, 0.0fx, -12.0fx);             // Sub36 shoot_offset(0.0, -12.0, 0.0)
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (1.0fx - s1) / layers);
    sh_angle(0, 0deg, 1638bam);               // 0.15707964f = 9°
    var k: int = 0;
    var pos: int = 1;                         // 当前时刻相对设定帧 S 的偏移（首跑在 S+1）
    wait(60);
    loop {
        k = interval - 1 - rand(interval);    // §4.3 写法 A：首发落在 S+k（k=0 时只能 S+1）
        if k > 0 { wait(k - 1); pos = k; } else { pos = 1; }
        sh_fire(0);
        loop {
            if k + interval >= 120 { break; }
            wait(interval);
            k = k + interval;
            pos = k;
            sh_fire(0);
        }
        wait(421 - pos);                      // 回到下一轮 S+1（主循环周期 420）
    }
}

// Sub36 里的 move_rand_in_bounds(-π, π); move_speed(1.5); move_time_decelerate(60)
// 边界 move_bounds_set(32, 48, 352, 132) → 我方 (-160, 48)-(160, 132)
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

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var b_n: int = 8;
    var b_layers: int = 1;
    var b_s1: fx = 1.8fx;
    var b_int: int = 60;
    if rank == RANK_NORMAL { b_n = 16; b_s1 = 2.0fx; b_int = 50; }
    else if rank == RANK_HARD { b_n = 16; b_layers = 2; b_s1 = 2.5fx; b_int = 50; }
    else if rank >= RANK_LUNATIC { b_n = 16; b_layers = 2; b_s1 = 2.5fx; b_int = 40; }
    spawn boss_auto(b_int, b_n, b_layers, b_s1);
    loop {
        sub37();                              // +60（阻塞 60 帧）
        wander(1.5fx, 60);                    // 第 1 次游走
        wait(60);                             // +60: //120
        wander(1.5fx, 60);                    // 第 2 次
        wait(60);                             // +60: //180
        wander(1.5fx, 60);                    // 第 3 次
        sub42();                              // shoot_interval_delayed(0); call("Sub42")（阻塞 160 帧）
        wait(70);                             // +70: //250
        wait(10);                             // +10: //260 → jump(60, Sub36_360)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                      // §6.1b：上游 Sub23 enemy_set_hitbox(56,56,32) → 56/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
