// th06_s2_w03 —— 东方红魔乡 Stage 2 道中 第 3 波
// 原文：ecldata2.ecl.txt timeline 帧 1250–1506（Sub6 横扫编队 + 随机 Sub0–Sub4），时限 676。
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

// Sub0/2/4 的 N/H 弹：bullet_offset_circle_aimed(4, 11, 4, 1, 2.0f, 0.0f, 0.0f, 0.0f, 4)
// 自机狙 4 向环、各颗错开半格（π/c1 = 45°）。
// 自动射击持续到 until（mapping §4.3 写法 A）：interval=180；until=180（Sub0）必只一发，
// until=200（Sub1/2/3/4）当 first <= 19 时下一发在 first+180 <= 199 < 200，还会补一轮。
async sub autoshoot_offset(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 11);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 4, 1);
    sh_speed(0, 2.0fx, -1.7fx);            // s2 = 0 钳到 0.3，步长 (0.3 − 2.0)/1
    sh_angle(0, 8192bam, 0deg);            // a1 = 0 加上 π/c1
    var t: int = 0;
    var next: int = 180 - rand(180);
    loop {
        if next >= until { return; }
        wait(next - t);
        t = next;
        sh_fire(0);
        next = next + 180;
    }
}

// Sub0–Sub4 的 L 弹：bullet_circle_aimed(4, 11, 10, 2, 2.5f, 0.0f, 0.0f, 0.0f, 4)
// 自机狙 10 颗 × 2 层（层速 2.5 / 1.4）；自动射击持续到 until（interval=180），
// until=200 且 first <= 19 时会补第二发（同 autoshoot_offset）。
async sub autoshoot_circle(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 11);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 2.5fx, -1.1fx);            // s2 = 0 钳到 0.3，步长 (0.3 − 2.5)/2
    sh_angle(0, 0deg, 0deg);
    var t: int = 0;
    var next: int = 180 - rand(180);
    loop {
        if next >= until { return; }
        wait(next - t);
        t = next;
        sh_fire(0);
        next = next + 180;
    }
}

// Sub0/1/2/3/4：move_velocity 直线 + move_acceleration(-0.015) 减速，停下后反向漂出。
// l_only != 0（Sub1/Sub3）：N/H 只写发射参数不发弹（原文 !N/!H 的 bullet_* 之后没有
// shoot_interval），只有 Lunatic 发；l_only == 0（Sub0/2/4）：N/H/L 都发。
async sub fairy(ang0: angle, l_only: int, until: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank >= RANK_LUNATIC { spawn autoshoot_circle(until); }
    else if l_only == 0 { if rank == RANK_NORMAL || rank == RANK_HARD { spawn autoshoot_offset(until); } }
    var ang: angle = ang0;
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub6：move_at_player(0.0f, 2.4f) 自机狙直进；+180 起 -256bam/帧转 100 帧（+280 归零）。
// 发弹整段都是 !L：只有 Lunatic 发 bullet_fan_aimed 3 颗小玉、每 120 帧一轮。
async sub sub6_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_speed(0, 2.5fx, -2.2fx);            // s2 = 0 钳到 0.3，步长 (0.3 − 2.5)/1
    sh_angle(0, 0deg, 2048bam);            // a2 = 11.25°
    wait(120 - rand(120));
    loop { sh_fire(0); wait(120); }
}

async sub sub6() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) >= RANK_LUNATIC { spawn sub6_autoshoot(); }
    var ang: angle = aim_player();
    var spd: fx = 2.4fx;
    move_vel(0, ang, spd, 0);
    wait(180);
    var w: angle = -256bam;
    for k1 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    loop { wait(1); }
}

// 导演：卡帧 = 120 + (原文 timeline 帧 − 1250)
async sub wave() {
    wait(120);
    var rx: fx = 0fx;
    // 1250
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1266
    _ = spawn_enemy(144.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1272 Sub4（x 随机 [0,384)）
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(24576bam, 0, 200)); wait(10);
    // 1282
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1298
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1314
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1330
    _ = spawn_enemy(80.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1336 Sub0
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(8192bam, 0, 180)); wait(10);
    // 1346
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1362
    _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1378
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1394
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1410
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1426
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1432 Sub1
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(12288bam, 1, 200)); wait(10);
    // 1442
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(16);
    // 1458
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1464 Sub2
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(16384bam, 0, 200)); wait(10);
    // 1474
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1480 Sub3
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(20480bam, 1, 200)); wait(10);
    // 1490
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6()); wait(6);
    // 1496 Sub0
    rx = (rand(384) - 192) as fx;
    _ = spawn_enemy(rx, -32.0fx, 1, 0, 0, 0, fairy(8192bam, 0, 180)); wait(10);
    // 1506
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub6());
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
