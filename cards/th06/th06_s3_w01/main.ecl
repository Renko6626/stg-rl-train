// th06_s3_w01 —— 东方红魔乡 Stage 3 道中 第 1 波
// 原文：ecldata3.ecl.txt timeline 帧 200–690（Sub0 / Sub1 / Sub2 / Sub3）
const TIME_LIMIT: int = 910;
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI

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

// !H 粘滞段：shoot_disable → bullet_fan_aimed(4,6,1,1,2.0f,0.0f,0.0f,0.1308997f,4) → shoot_enable
// → shoot_interval(60)。单发自机狙 KUNAI，速度 2.0；+115 被 shoot_interval_delayed(0) 停掉。
async sub autoshoot_h(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_angle(0, 0deg, 1365bam);           // a7 = 7.5°（单颗无展开）
    var t: int = 60;
    if t >= until { return; }
    wait(60);
    loop {
        sh_fire(0);
        t = t + 60;
        if t >= until { return; }
        wait(60);
    }
}

// !L 粘滞段：shoot_disable → bullet_circle_aimed(4,6,10,2,3.0f,1.0f,0.0f,0.1308997f,4)
// → shoot_enable → shoot_interval_delayed(200)。10 路自机狙环 × 2 层、层偏移 7.5°，
// 速度 3.0/2.0；首发在 200−rand(200) 帧，+115 被 shoot_interval_delayed(0) 停掉（最多一发）。
async sub autoshoot_l(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 3.0fx, -1.0fx);           // (s2−s1)/c2 = (1.0−3.0)/2
    sh_angle(0, 0deg, 1365bam);           // a7 = 7.5° 逐层偏移
    var first: int = 200 - rand(200);
    if first >= until { return; }
    wait(first);
    loop {
        sh_fire(0);
        first = first + 200;
        if first >= until { return; }
        wait(200);
    }
}

// Sub0 / Sub1：左列（镜像从右列）y=64，move_velocity(30°, 4.5)；+30 起角速度 −3.75°/帧转 85 帧；
// +115 角速度归零直线飞出。E/N 不发弹；H 单发；L 环。镜像只取反角速度，弹角不镜像。
async sub fairy_a(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn autoshoot_h(115); }
    else if rank >= RANK_LUNATIC { spawn autoshoot_l(115); }
    var ang: angle = 5461bam;              // 0.5235988f = 30°
    var spd: fx = 4.5fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = -683bam;                           // +30 move_angular_velocity(-0.06544985f) = −3.75°/帧
    if mirror != 0 { w = 683bam; }
    for k1 in 0..85 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +115 move_angular_velocity(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10000);
}

// Sub2 / Sub3：左列（镜像从右列）y=192，move_velocity(−60°, 4.0)；+30 起角速度 +2°/帧转 60 帧；
// +90 角速度归零直线飞出。发弹难度分支同 fairy_a，只是停止帧是 +90。
async sub fairy_b(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn autoshoot_h(90); }
    else if rank >= RANK_LUNATIC { spawn autoshoot_l(90); }
    var ang: angle = -10923bam;            // -1.0471976f = −60°
    var spd: fx = 4.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 364bam;                            // +30 move_angular_velocity(0.034906585f) = +2°/帧
    if mirror != 0 { w = -364bam; }
    for k1 in 0..60 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +90 move_angular_velocity(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10000);
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 200)
async sub wave() {
    wait(120);
    // 200–304：Sub0/Sub1 左列交替 14 只
    for i1 in 0..14 {
        _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, fairy_a(0));
        wait(8);
    }
    // 312–416：镜像 14 只
    for i2 in 0..14 {
        _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, fairy_a(1));
        wait(8);
    }
    wait(82);   // 416→506 的 90 帧，循环末尾已经等了 8
    // 506–594：Sub2/Sub3 左列交替 12 只
    for i3 in 0..12 {
        _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy_b(0));
        wait(8);
    }
    // 602–690：镜像 12 只
    for i4 in 0..12 {
        _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy_b(1));
        wait(8);
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
