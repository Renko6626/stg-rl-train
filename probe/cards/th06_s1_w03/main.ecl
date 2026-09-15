// th06_s1_w03 —— 东方红魔乡 Stage 1 道中第 3 波
// 原文：ecldata1.ecl.txt timeline 帧 1554–1762（Sub0 纵队），E–L 四档（发弹仅 Lunatic）
const TIME_LIMIT: int = 628;
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

// Sub0 的 Lunatic 段（`!L` 粘滞到 +40）：
//   shoot_disable(); bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.0f, 4); shoot_enable(); shoot_interval_delayed(120);
// 1 颗 PELLET 自机狙，speed 3.0；shoot_interval_delayed 首发 120 − rand(120)，此后每 120 帧一发。
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

// Sub0：下落（90°，2.0）→ +40 左转（-π/128/帧）→ +120 右转（π/160/帧）→ +220 直飞
// mirror 只取反水平速度（mapping §6.1）：初始 90° 无水平分量，故只把角速度取反。
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
    wait(9780);                            // +220 角速度归零直飞；+10000 enemy_delete 由出界守卫取代
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 1554)。
// 1554–1634：镜像 Sub0 ×6 对（右侧）；1650–1762：正向 Sub0 ×8 对（左侧）；每 16 帧一对。
async sub wave() {
    wait(120);
    // 1554：x 128 / 160
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1570：x 120 / 152
    _ = spawn_enemy(120.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(152.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1586：x 112 / 144
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(144.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1602：x 104 / 136
    _ = spawn_enemy(104.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(136.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1618：x 96 / 128
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1634：x 88 / 120
    _ = spawn_enemy(88.0fx, -32.0fx, 1, 0, 0, 0, sub0(1));
    _ = spawn_enemy(120.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    // 1650：x -128 / -96
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1666：x -120 / -88
    _ = spawn_enemy(-120.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-88.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1682：x -112 / -80
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1698：x -104 / -72
    _ = spawn_enemy(-104.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-72.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1714：x -96 / -64
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1730：x -88 / -56
    _ = spawn_enemy(-88.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-56.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1746：x -80 / -48
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    // 1762：x -72 / -40
    _ = spawn_enemy(-72.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
    _ = spawn_enemy(-40.0fx, -32.0fx, 1, 0, 0, 0, sub0(0));
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
