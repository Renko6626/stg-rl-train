// th06_s3_w09 —— 东方红魔乡 Stage 3 道中 第 9 波
// 原文：ecldata3.ecl.txt timeline 帧 4190–4894（Sub8 / Sub7 下落群 + Sub2 / Sub3 高速横切四段）
const TIME_LIMIT: int = 1184;
const BALL: int = 48;    // TH06 弹型 3 BALL
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI

// flags 25 = 0x1|0x8|0x10：出生冲刺 + 永久沿固定角 90° 重力 0.025（mapping §5）
xformdef SUB8_BULLET {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0fx, 0.025fx);
}

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

// Sub8：下落 2.5 → +40 减速（-1/12/帧，30 帧到 0）→ +70 随机上半圆散弹（BALL，flags 25）
//        → 45°~135° 1.5 速下落
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 2.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.083333336fx;
    for k1 in 0..30 {
        spd = spd + acc;
        move_vel(0, ang, spd, 0);
        wait(1);
    }
    // +70 bullet_random(3, 15, N, 1, 2.0, 0.3, 0, -π, 25)：逐颗随机角度/速度
    spd = 0fx;
    var cnt: int = 8;                            // !E
    if rank == RANK_NORMAL { cnt = 14; }         // !N
    else if rank == RANK_HARD { cnt = 20; }      // !H
    else if rank >= RANK_LUNATIC { cnt = 22; }   // !L
    for i in 0..cnt {
        var bsp: fx = 0.3fx + 1.7fx / 256 * rand(256);
        var ban: angle = -180deg + rand(32768) as angle;
        _ = fire(BALL, 15, $self_x, $self_y, bsp, ban, SUB8_BULLET, none);
    }
    var a2: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a2 = 180deg - a2; }
    ang = a2;
    spd = 1.5fx;
    loop { move_vel(0, ang, spd, 0); wait(1); }
}

// Sub7：下落 1.5 → +40 减速（-0.05/帧，30 帧到 0）→ +70 起 i4 轮 KUNAI 下向扇
//       （中轴 90°、速度每轮 +0.3、每轮隔 2 帧）；H 档额外一发 16 颗 BALL 自机狙环；
//       之后 45°~135° 上飞退场
async sub sub7(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;
    for k1 in 0..30 {
        spd = spd + acc;
        move_vel(0, ang, spd, 0);
        wait(1);
    }
    spd = 0fx;
    var iters: int = 12;                  // !E
    var fan_n: int = 1;
    var spread: angle = 1365bam;          // 7.5°
    if rank == RANK_NORMAL { iters = 16; }
    else if rank == RANK_HARD { iters = 16; spread = 4096bam; }                 // 22.5°
    else if rank >= RANK_LUNATIC { iters = 16; spread = 5461bam; fan_n = 5; }   // 30°
    if rank == RANK_HARD {
        // !H bullet_circle_aimed(3, 6, 16, 1, 1.6, 0.0, %F0, 22.5°, 4)
        sh_reset(1);
        sh_sprite(1, BALL, 6);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, 16, 1);
        sh_speed(1, 1.6fx, 0fx);
        sh_angle(1, 90deg, 4096bam);
        sh_fire(1);
    }
    // 全档 bullet_fan(4, 6, fan_n, 1, %F1, 0.0, %F0, spread, 4)
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, fan_n, 1);
    sh_angle(0, 90deg, spread);
    var f1: fx = 1.6fx;
    for k2 in 0..iters {
        sh_speed(0, f1, 0fx);
        sh_fire(0);
        f1 = f1 + 0.3fx;
        wait(2);
    }
    var a2: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a2 = 180deg - a2; }
    ang = a2;
    spd = -1.5fx;
    loop { move_vel(0, ang, spd, 0); wait(1); }
}

// Sub2 / Sub3 的自动射击（只 H / L 档发弹）：H = 60 帧定发 1 颗 KUNAI 自机狙；
// L = 延迟 200 帧随机首发、10×2 颗 KUNAI 自机狙环；原文 +90 处 shoot_interval_delayed(0) 停
async sub fast_autoshoot(rank: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_angle(0, 0deg, 1365bam);
    if rank == RANK_HARD {
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 2.0fx, 0fx);
        wait(60);
        sh_fire(0);
    } else {
        sh_ring(0, 1);
        sh_count(0, 10, 2);
        sh_speed(0, 3.0fx, -1.0fx);
        var first: int = 200 - rand(200);
        if first < 90 { wait(first); sh_fire(0); }
    }
    loop { wait(1); }
}

// Sub2 / Sub3：从场外 x=±224 横切，-60° 4.0 速，+30 起 +2°/帧 转 60 帧
//（镜像只取反水平速度：角度 180°−a、角速度取负）
async sub fast_fairy(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank >= RANK_HARD { spawn fast_autoshoot(rank); }
    var ang: angle = -60deg;
    var spd: fx = 4.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 364bam;                            // 2°/帧
    if mirror != 0 { w = -364bam; }
    for k1 in 0..60 {
        ang = ang + w;
        move_vel(0, ang, spd, 0);
        wait(1);
    }
    loop { move_vel(0, ang, spd, 0); wait(1); }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 4190)
async sub wave() {
    wait(120);
    // 4190–4340：Sub8 / Sub7 成对下落（每 30 帧一对）
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(30);
    _ = spawn_enemy(-68.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(68.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(30);
    _ = spawn_enemy(-4.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(4.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(30);
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(30);
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(30);
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(30);
    // 4370 / 4400：Sub8 单只
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    wait(30);
    _ = spawn_enemy(-4.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    wait(4);
    // 4404–4894：Sub2 / Sub3 高速交替，四段各 26 只、每 4 帧一只、段间 30 帧。
    // 原文侧序为 R L R L R L R L R L R L R R L R L R …（pos14 连出两只右侧，四段一致）
    for s in 0..4 {
        if s > 0 { wait(30); }
        for p in 0..26 {
            if p > 0 { wait(4); }
            var mir: int = 0;
            if p <= 12 {
                if p % 2 == 0 { mir = 1; }
            } else {
                if p % 2 == 1 { mir = 1; }
            }
            if mir == 0 {
                _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fast_fairy(0));
            } else {
                _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fast_fairy(1));
            }
        }
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
