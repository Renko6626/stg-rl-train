// th06_s1_w02 —— 东方红魔乡 Stage 1 道中第 2 波
// 原文：ecldata1 timeline 帧 1174–1354（Sub0 / Sub2）；小怪 Sub0（:2-20）、Sub2（:43-59）
const TIME_LIMIT: int = 600;
const BULLET: int = 128;   // TH06 弹型 0 PELLET 小玉

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

// Sub0 / Sub2 的 Lunatic 段（`!L` 从 shoot_disable 粘滞到 +40）：
//   shoot_disable(); bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.0f, 4); shoot_enable(); shoot_interval_delayed(120);
// E/N/H 一颗弹都不发；只有 Lunatic 起这台自动射击（120 帧一发、首发起始随机 [0,120)）。
async sub pellet_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_count(0, 1, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    wait(120 - rand(120));
    loop {
        sh_fire(0);
        wait(120);
    }
}

// Sub0：下落 → +40 左转（-π/128/帧 = -256bam）→ +120 右转（π/160/帧 = 205bam）→ +220 直飞
async sub sub0(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)；镜像 180°−90° 仍是 90°
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(40);
    w = -256bam;                           // +40 move_angular_velocity(-0.024543693f)
    if mirror != 0 { w = 256bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 205bam;                            // +120 move_angular_velocity(0.019634955f)
    if mirror != 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9780);                            // +220 角速度归零直飞；出界由守卫退场
}

// Sub2：下落 → +100 右转（π/160/帧 = 205bam）→ +200 直飞
async sub sub2(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var w: angle = 205bam;
    if mirror != 0 { w = -205bam; }
    move_vel(0, ang, spd, 0);
    wait(100);
    for k1 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9800);                            // +200 角速度归零直飞；出界由守卫退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1174)。每 10 帧一只随机位置小怪（x 随机 [0,384)）。
async sub wave() {
    wait(120);
    // 1174 mirror Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(10);
    // 1184 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1194 mirror Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    // 1204 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1214 mirror Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    // 1224 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1234 mirror Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(10);
    // 1244 random Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    // 1254 mirror Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    // 1264 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1274 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1284 mirror Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(10);
    // 1294 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1304 mirror Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    // 1314 random Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    // 1324 mirror Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(10);
    // 1334 random Sub0
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(10);
    // 1344 mirror Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    // 1354 random Sub2
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2(0));
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
