// th06_s7_w01 —— 东方红魔乡 Stage 7(Extra) 道中第 1 波
// 原文：ecldata7 timeline 帧 340–1100（全为 Sub0，共 72 只）；Extra 档
const TIME_LIMIT: int = 1180;
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

// Sub0 的自动射击：shoot_disable(); bullet_fan_aimed(0,6,1,1,4.0,0.0,0.0,0.0,4); shoot_enable();
//                    shoot_interval_delayed(60)
// flags 4 = 出生特效（我方不模拟）。自机狙单发，60 帧一发、首发 S+59−r（r∈[0,60)），k=0 时晚 1 帧。
async sub pellet_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_count(0, 1, 1);
    sh_speed(0, 4.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    var k: int = 59 - rand(60);            // §4.3：首发 k = n−1−rand(n)，相对设定帧 S
    if k > 0 { wait(k - 1); }              // 伴生任务首跑已在 S+1
    loop {
        sh_fire(0);
        wait(60);
    }
}

// Sub0：move_velocity(π/2, 2.0) 下落 → +40 左转(-π/128/帧) → +120 右转(π/160/帧) → +220 直飞
async sub sub0(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    spawn pellet_autoshoot();
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
    wait(9780);                            // +220 角速度归零直飞；出界由守卫退场
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 340)
// 4 个 block，每 block 9 个时间点（间隔 20 帧）× 每点 2 只，block 间隔 40 帧；
// block 0/2 在左列 x=-160/-128（Sub0），block 1/3 在右列 x=128/160（mirror）。
async sub wave() {
    wait(120);
    for blk in 0..4 {
        for i in 0..9 {
            var m: int = blk % 2;
            if m == 0 {
                _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub0(0));
                _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub0(0));
            } else {
                _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub0(1));
                _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub0(1));
            }
            if i < 8 { wait(20); }
        }
        if blk < 3 { wait(40); }
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
