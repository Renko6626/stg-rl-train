// th06_s2_w04 —— 东方红魔乡 Stage 2 道中 第 4 波（Sub6 横扫编队 + Sub0–Sub4 随机散兵）
// 原文：ecldata2.ecl.txt timeline 帧 1606–1862（Sub0–Sub4 行 2–101、Sub6 行 113–129）
const TIME_LIMIT: int = 676;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI

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

// Sub0–Sub4 的自动射击：shoot_interval_delayed(180)，until 帧 shoot_interval(0) 停（开火帧 >= until 不发，§4.3）。
// !N/!H 为 bullet_offset_circle_aimed(4,11,4,1,2.0,…)：偏移半周 45°、4 颗 1 层、速 2.0；
// !L 为 bullet_circle_aimed(4,11,10,2,2.5,…)：正环 10 颗 2 层、速 2.5→0.3。
async sub kunaishot(rank: int, until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 11);
    sh_aim(0, 1);
    sh_ring(0, 1);
    if rank >= RANK_LUNATIC {
        sh_count(0, 10, 2);
        sh_speed(0, 2.5fx, (0.3fx - 2.5fx) / 2);
        sh_angle(0, 0deg, 0deg);
    } else {
        sh_count(0, 4, 1);
        sh_speed(0, 2.0fx, 0fx);
        sh_angle(0, 8192bam, 0deg);          // π/c1 = 32768/4
    }
    var first: int = 180 - rand(180);
    if first >= until { return; }
    wait(first);
    var t: int = first;
    loop {
        sh_fire(0);
        if t + 180 >= until { return; }
        wait(180);
        t = t + 180;
    }
}

// Sub6 的自动射击（仅 Lunatic）：bullet_fan_aimed(0,6,3,1,2.5,0,0,2048,4)，
// shoot_interval_delayed(120) 首发 120−rand(120) 后，此后每 120 帧一次。
async sub pelletfan() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_speed(0, 2.5fx, 0fx);
    sh_angle(0, 0deg, 2048bam);              // 11.25°
    wait(120 - rand(120));
    loop {
        sh_fire(0);
        wait(120);
    }
}

// Sub0–Sub4：move_velocity(a, 3.0) + move_acceleration(-0.015) 极坐标逐帧积分；
// nh!=0（Sub0/2/4）N/H/L 自机狙，nh==0（Sub1/3）只有 L 发。
async sub diver(ang: angle, stop: int, nh: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                      // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    var rank: int = global(GVAR_RANK);
    var shoot: int = 0;
    if nh != 0 && rank >= RANK_NORMAL { shoot = 1; }
    if nh == 0 && rank >= RANK_LUNATIC { shoot = 1; }
    if shoot != 0 { spawn kunaishot(rank, stop); }
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub6：move_at_player(0, 2.4)；+180 起角速度 -256bam/帧转 100 帧，+280 归零直飞。
async sub sweeper() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) >= RANK_LUNATIC { spawn pelletfan(); }
    var ang: angle = aim_player();
    var spd: fx = 2.4fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    for k1 in 0..180 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -256bam;                             // !* move_angular_velocity(-0.024543693f) @+180
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                                // !* move_angular_velocity(0.0f) @+280
    loop { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 1606)；Sub6 帧 1606–1862 每 16 帧一只（x −160→+112），
// 随机散兵 Sub4/Sub0/Sub1/Sub2/Sub3/Sub0 穿插在 1628/1692/1788/1820/1836/1852。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);   // 1606
    _ = spawn_enemy(-144.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);    // 1622
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(24576bam, 200, 1)); wait(10);  // 1628 Sub4
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);   // 1638
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);   // 1654
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);    // 1670
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);     // 1686
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(8192bam, 180, 1)); wait(10);   // 1692 Sub0
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);    // 1702
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);    // 1718
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);    // 1734
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);    // 1750
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);      // 1766
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);      // 1782
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(12288bam, 200, 0)); wait(10);  // 1788 Sub1
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(16);     // 1798
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);      // 1814
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(16384bam, 200, 1)); wait(10);  // 1820 Sub2
    _ = spawn_enemy(80.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);      // 1830
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(20480bam, 200, 0)); wait(10);  // 1836 Sub3
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sweeper()); wait(6);      // 1846
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, diver(8192bam, 180, 1)); wait(10);   // 1852 Sub0
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sweeper());              // 1862
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
