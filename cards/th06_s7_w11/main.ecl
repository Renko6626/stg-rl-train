// th06_s7_w11 —— 东方红魔乡 Stage 7(Extra) 道中第 11 波
// 原文：ecldata7 timeline 帧 5373–5773（全为 Sub8，共 72 只）；Extra 档
const TIME_LIMIT: int = 820;
const BULLET: int = 128;   // TH06 弹型 0 PELLET

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

// Sub8 的自动射击：shoot_disable(); bullet_fan_aimed(0,6,3,1,4.0,0.0,0.0,0.19634955,4);
//                    shoot_enable(); shoot_interval_delayed(90)
// flags 4 = 出生特效（我方不模拟）。自机狙 3 颗扇、颗间隔 11.25°(2048bam)，
// 90 帧一发、首发随机延迟（写法 A，§4.3：原作首发 = S + k，k = 89 − rand(90)；k=0 时晚 1 帧）。
async sub fan_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_speed(0, 4.0fx, 0fx);               // 单层，写 s1=4.0
    sh_angle(0, 0deg, 2048bam);            // a1=0°、a2=π/16
    var k: int = 89 - rand(90);
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        wait(90);
    }
}

// Sub8：move_velocity(π/2, 2.0) 下落 → +40 左转(-π/128/帧) → +120 右转(π/160/帧) → +220 直飞
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    spawn fan_autoshoot();
    var ang: angle = 90deg;                // 镜像 180°−90° 仍是 90°
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
    w = 0deg;                              // +220 move_angular_velocity(0.0f)
    wait(9780);                            // +10000 enemy_delete(0)；出界由守卫提前退场
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 5373)
// 左列 x=-160/-128（Sub8），右列 x=128/160（enemy_create_mirror，镜像只取反水平速度）。
// 5373–5478 左列每 15 帧一对 ×8；5493 起左右交替；5613 起间隔缩为 10；5773 结尾只有右列一对。
async sub wave() {
    wait(120);
    // 5373–5478：左列 8 点（120/135/…/225），点间隔 15
    for i1 in 0..8 {
        _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
        _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
        wait(15);
    }
    // 5493：左一对 + 右一对
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    wait(15);
    // 5508–5598：右列 7 点，点间隔 15
    for i2 in 0..7 {
        _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
        _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
        wait(15);
    }
    // 5613：右一对 + 左一对；此后点间隔 10
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    wait(10);
    // 5623–5683：左列 7 点，点间隔 10
    for i3 in 0..7 {
        _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
        _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
        wait(10);
    }
    // 5693：左一对 + 右一对
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    wait(10);
    // 5703–5763：右列 7 点，点间隔 10
    for i4 in 0..7 {
        _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
        _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
        wait(10);
    }
    // 5773：结尾右列一对
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub8(1));
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
