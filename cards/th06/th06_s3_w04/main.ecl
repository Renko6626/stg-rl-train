// th06_s3_w04 —— 东方红魔乡 Stage 3 道中 第 4 波
// 原文：ecldata3.ecl.txt timeline 帧 1530–1866（Sub5 随机位置 ×10 + Sub6 左右双列 ×14），时限 816。
const TIME_LIMIT: int = 816;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// TH06 敌进过场地再出界即删（mapping §6.2）
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

// Sub6 的自动射击（mapping §4.3 写法 A）：原文 shoot_disable 下写好自机狙扇参数，
// shoot_enable 后 shoot_interval_delayed(interval) 每 interval 帧自动开火一次，
// 首发在 interval − rand(interval) 帧，+220（until）被 shoot_interval_delayed(0) 停掉。
async sub sub6_autoshoot(c1: int, s1: fx, a7: angle, interval: int, until: int) {
    sh_reset(0);
    sh_sprite(0, BULLET, 1);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, 1);
    sh_speed(0, s1, 0fx);
    sh_angle(0, 0deg, a7);
    var t: int = 0;
    var next: int = interval - rand(interval);
    loop {
        if next >= until { return; }
        wait(next - t);
        t = next;
        sh_fire(0);
        next = next + interval;
    }
}

// Sub5：move_velocity(90°, 1.5) 下落；+40 起 move_acceleration(-0.05) 减速 30 帧到零；
// +70 发一轮自机狙扇（E 8 / N 16 / H 24 单层 / L 24×3 层，环玉，速度 1+rand[0,1)）；
// $F2 = [0,π/2)+π/4，+100 以该角、速度 −1.5 反向漂出（原文 move_velocity(%F2, -1.5f)）。
async sub sub5() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;                         // +40 move_acceleration(-0.05f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)
    var s1: fx = 1.0fx + 1.0fx / 256 * rand(256);   // set_float_rand_bound($F1,1) + 1 → [1,2)
    var c1: int = 8;
    var c2: int = 1;
    var s2: fx = 0.3fx;                    // speed2 = 0 钳到 0.3（单层无影响）
    var a7: angle = 5461bam;               // a2 = 30°
    if rank == RANK_NORMAL { c1 = 16; a7 = 2731bam; }
    else if rank == RANK_HARD { c1 = 24; s2 = 1.0fx; a7 = 2185bam; }
    else if rank >= RANK_LUNATIC { c1 = 24; c2 = 3; s2 = 1.0fx; a7 = 2341bam; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, c2);
    sh_speed(0, s1, (s2 - s1) / c2);
    sh_angle(0, 0deg, a7);
    sh_fire(0);
    var a2: angle = 45deg + (rand(16384) as angle); // $F2 = [0,π/2) + π/4 → [45°,135°)
    wait(30);
    ang = a2;                              // +100 move_velocity(%F2, -1.5f)
    spd = -1.5fx;
    move_vel(0, ang, spd, 0);
    wait(9900);                            // +10000 enemy_delete（实际出界守卫先退场）
}

// Sub6：move_velocity(90°, 2.0) 下落；shoot_disable 下配置自机狙扇、shoot_enable 后
// 交给 sub6_autoshoot 自动连射（E 1 / N 3 / H 3@2.5 / L 7@2.5 颗小玉，interval
// 300/190/120/90，+220 停）。+40 起 −256bam/帧转 80 帧，+120 起 +205bam/帧转 100 帧
// （镜像取反角速度），+220 角速度归零直落。
async sub sub6(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;
    var s1: fx = 1.5fx;
    var a7: angle = 546bam;                // a2 = 3°
    var interval: int = 300;
    if rank == RANK_NORMAL { c1 = 3; interval = 190; }
    else if rank == RANK_HARD { c1 = 3; s1 = 2.5fx; interval = 120; }
    else if rank >= RANK_LUNATIC { c1 = 7; s1 = 2.5fx; a7 = 364bam; interval = 90; }
    spawn sub6_autoshoot(c1, s1, a7, interval, 220);
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }  // 90° 镜像后仍是 90°；弹角不镜像
    move_vel(0, ang, spd, 0);
    wait(40);
    w = -256bam;                           // +40 move_angular_velocity(-0.024543693f)
    if mirror != 0 { w = 256bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 205bam;                            // +120 move_angular_velocity(0.019634955f)
    if mirror != 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +220 move_angular_velocity(0.0f)
    wait(9780);                            // +10000 enemy_delete（实际出界守卫先退场）
}

// 导演：卡帧 = 120（开场缓冲）+ (原文 timeline 帧 − 1530)
async sub wave() {
    wait(120);
    var rx: fx = 0fx;
    // 1530–1610：Sub5 随机 x∈[0,384) ×5（每 20 帧）
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(6);
    // 1616–1688：Sub6 左双列 ×7 批（x=64,96 → −128,−96，非镜像）
    for i1 in 0..7 {
        _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
        _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
        if i1 < 6 { wait(12); }
    }
    wait(20);                              // 1688 → 1708
    // 1708–1788：Sub5 随机 x ×5（每 20 帧）
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, sub5()); wait(6);
    // 1794–1866：Sub6 右镜像双列 ×7 批（x=320,288 → 128,96，invertX）
    for i2 in 0..7 {
        _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
        _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
        if i2 < 6 { wait(12); }
    }
    loop { wait(1); }
}

async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, wave, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
