// th06_s5_w04 —— 东方红魔乡 Stage 5 道中 第 4 波（长连续编队）
// 原文：ecldata5.ecl.txt timeline 帧 1342–2002（Sub0 / Sub1 / Sub2），E/N/H/L 四档。
const TIME_LIMIT: int = 1080;
const BALL: int = 48;    // TH06 弹型 3 BALL 中玉
const RICE: int = 64;    // TH06 弹型 2 RICE 米弹

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

// Sub0：+0 以 90°/2.0 下落，+40 减速到 +70 停住，+70 起 8 轮自机狙环（间隔 5 帧），
// +110 恢复 90°/1.8 飞离。F0 每轮 +0.38，Lunatic 额外 +0.1（原文 !* … / !L …）。
async sub sub0() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                                             // +70 move_acceleration(0.0f)
    // !E 16 / !N 30 / !H 40 / !L 40 颗，1 层
    var count: int = 16;
    if rank == RANK_NORMAL { count = 30; }
    else if rank == RANK_HARD { count = 40; }
    else if rank >= RANK_LUNATIC { count = 40; }
    var f0: fx = 1.5fx;
    for k2 in 0..8 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, count, 1);
        sh_speed(0, f0, 1.0fx - f0);
        sh_angle(0, 0deg, 0deg);
        sh_fire(0);
        f0 = f0 + 0.38fx;                                  // !* math_float_add($F0, %F0, 0.38f)
        if rank >= RANK_LUNATIC { f0 = f0 + 0.1fx; }       // !L math_float_add($F0, %F0, 0.1f)
        wait(5);
    }
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);                              // +110 move_velocity(1.5707964f, 1.8f)
    wait(10000);
}

// Sub2：与 Sub0 同构，5 轮、间隔 4 帧，F0 每轮 +0.55（Lunatic 额外 +0.2）。
async sub sub2() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                                             // +70 move_acceleration(0.0f)
    // !E 12 / !N 24 / !H 32 / !L 32 颗，1 层
    var count: int = 12;
    if rank == RANK_NORMAL { count = 24; }
    else if rank == RANK_HARD { count = 32; }
    else if rank >= RANK_LUNATIC { count = 32; }
    var f0: fx = 1.5fx;
    for k2 in 0..5 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, count, 1);
        sh_speed(0, f0, 1.0fx - f0);
        sh_angle(0, 0deg, 0deg);
        sh_fire(0);
        f0 = f0 + 0.55fx;                                  // !* math_float_add($F0, %F0, 0.55f)
        if rank >= RANK_LUNATIC { f0 = f0 + 0.2fx; }       // !L math_float_add($F0, %F0, 0.2f)
        wait(4);
    }
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);                              // +90 move_velocity(1.5707964f, 1.8f)
    wait(10000);
}

// Sub1 的自动射击（原文 shoot_interval_delayed + bladeProps 粘滞的 bullet_random）：
// 每 interval 帧发 total = count1·count2 颗 RICE，角度 [0, π)、速度 [0.8, 1.8) 各自随机。
async sub autoshoot(total: int, interval: int) {
    var first: int = interval - rand(interval);
    wait(first);
    loop {
        for k1 in 0..total {
            var sp: fx = 0.8fx + 1.0fx / 256 * rand(256);
            var an: angle = rand(32768) as angle;
            _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
        }
        wait(interval);
    }
}

// Sub1：0° / 2.5 直飞（镜像 180°）；bullet_random 参数只在 config 时写一次，
// 之后由 shoot_interval_delayed 自动重复。E/N 间隔 60、H 40、L 30。
async sub sub1(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 0deg;
    var spd: fx = 2.5fx;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    // bullet_random(2, 6, c1, c2, 1.8, 0.8, π, 0, 516)：!E 3×1 / !N 3×2 / !H 4×2 / !L 5×2
    var c1: int = 3;
    var c2: int = 1;
    var interval: int = 60;
    if rank == RANK_NORMAL { c2 = 2; }
    else if rank == RANK_HARD { c1 = 4; c2 = 2; interval = 40; }
    else if rank >= RANK_LUNATIC { c1 = 5; c2 = 2; interval = 30; }
    spawn autoshoot(c1 * c2, interval);
    wait(10000);
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1342)。原文 Sub0 首帧 1342 → 卡帧 120。
async sub wave() {
    wait(120);
    // 1342：Sub0 双翼
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, sub0());
    _ = spawn_enemy(64.0fx, -48.0fx, 1, 0, 0, 0, sub0());
    wait(20);
    // 1362–1502：Sub1 左纵队，x=-224，y 160→216
    for i1 in 0..8 {
        _ = spawn_enemy(-224.0fx, (160 + i1 * 8) as fx, 1, 0, 0, 0, sub1(0));
        wait(20);
    }
    // 1522–1662：Sub1 右镜像，x=224，y 64→120
    for i2 in 0..8 {
        _ = spawn_enemy(224.0fx, (64 + i2 * 8) as fx, 1, 0, 0, 0, sub1(1));
        wait(20);
    }
    // 1682：Sub2 双翼
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    wait(20);
    // 1702–1842：Sub1 左，x=-224，y 64→120
    for i3 in 0..8 {
        _ = spawn_enemy(-224.0fx, (64 + i3 * 8) as fx, 1, 0, 0, 0, sub1(0));
        wait(20);
    }
    // 1862–2002：Sub1 右镜像，x=224，y 208→264
    for i4 in 0..8 {
        _ = spawn_enemy(224.0fx, (208 + i4 * 8) as fx, 1, 0, 0, 0, sub1(1));
        if i4 < 7 { wait(20); }
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
