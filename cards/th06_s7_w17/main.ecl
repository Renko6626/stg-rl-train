// th06_s7_w17 —— 东方红魔乡 Stage 7(Extra) 道中 第 17 波
// 原文：ecldata7 timeline 帧 7693–8093（Sub9），共 72 只
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

// Sub9 的自动射击：shoot_disable(); bullet_fan_aimed(0,6,3,1,4.0,0.0,0.0,0.3926991,4);
//                    shoot_enable(); shoot_interval_delayed(70)
// 弹型 0→BULLET、色 6、3 向自机狙扇、相邻 22.5°=4096bam、速度 4.0；
// flags 4 = 出生特效（我方不模拟）。每 70 帧一发、首发 k = 69 − rand(70)（S + k 帧）。
async sub fan_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_count(0, 3, 1);
    sh_speed(0, 4.0fx, 0fx);
    sh_angle(0, 0deg, 4096bam);
    var k: int = 70 - 1 - rand(70);        // §4.3：delayed 首发 k = n − 1 − rand(n)
    if k > 0 { wait(k - 1); }              // 伴生任务首跑已在 S+1；k == 0 只能在 S+1 发
    loop {
        sh_fire(0);
        wait(70);
    }
}

// Sub9：move_velocity(π/2, 2.0) 下落 → +40 左转(-π/128/帧) → +120 右转(π/160/帧) → +220 直飞
// 镜像只取反水平速度 ⇒ move_velocity(90°) 不变，角速度取反（§6.1）
async sub sub9(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    spawn fan_autoshoot();
    var ang: angle = 90deg;
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

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 7693)
async sub wave() {
    wait(120);
    // 7693–7798：左侧 x=-160/-128，8 点 ×15 帧
    for i1 in 0..8 {
        _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
        _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
        if i1 < 7 { wait(15); }
    }
    // 7813：左二 + 右二
    wait(15);
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    // 7828–7918：右侧 x=128/160，7 点 ×15 帧
    for i2 in 0..7 {
        wait(15);
        _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
        _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    }
    // 7933：右二 + 左二
    wait(15);
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    // 7943–8003：左侧，7 点 ×10 帧
    for i3 in 0..7 {
        wait(10);
        _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
        _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    }
    // 8013：左二 + 右二
    wait(10);
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub9(0));
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
    // 8023–8093：右侧，8 点 ×10 帧
    for i4 in 0..8 {
        wait(10);
        _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
        _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub9(1));
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
