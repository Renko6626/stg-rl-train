// th06_s1_w05 —— 东方红魔乡 Stage 1 道中 第 5 波
// 原文：ecldata1.ecl.txt timeline 帧 4372–4852，SmallFairy Sub0 / Sub1（行 1367–1459, 2–20, 22–41）
const TIME_LIMIT: int = 900;
const BULLET: int = 128;   // TH06 弹型 0 PELLET

// TH06 敌「进过场地再出界」立即删除（mapping §6.2）
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

// Sub0 / Sub1 开头的 `!L` 粘滞块（shoot_disable → bullet_fan_aimed → shoot_enable → shoot_interval_delayed(120)）：
// 只有 Lunatic 会发弹。参数 = PELLET(0)/色 6/自机狙 1 颗/速度 3.0；disable 期间只配置不发。
// flags 4 = 出生特效，我方不模拟（mapping §4.2 / §5）。
async sub pellet_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    wait(120 - rand(120));                 // shoot_interval_delayed(120)：首发 120 − rand(120)
    loop {
        sh_fire(0);
        wait(120);
    }
}

// Sub0：下落 → +40 左转（-π/128 = -256bam/帧）→ +120 右转（π/160 = 205bam/帧）→ +220 直飞
async sub sub0(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(40);
    w = -256bam;                           // +40 move_angular_velocity(-0.024543693f)
    if mirror != 0 { w = 256bam; }         // 镜像只取反角速度
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 205bam;                            // +120 move_angular_velocity(0.019634955f)
    if mirror != 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9780);                            // +220 角速度归零直飞；+10000 enemy_delete(0)，实际先出界由守卫退场
}

// Sub1：与 Sub0 同，只有 +120 的角速度走 math_float_div($F1, 0.019634955f, 2.0f) = 102.4bam/帧
async sub sub1(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(40);
    w = -256bam;                           // +40 move_angular_velocity(-0.024543693f)
    if mirror != 0 { w = 256bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 102bam;                            // +120 0.019634955f / 2 = 0.0098174775 → 102.4bam，取 102
    if mirror != 0 { w = -102bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9780);                            // +220 直飞；出界由守卫退场
}

// 导演：按 timeline 相对帧出怪。原文帧 4372 → 卡帧 120（开场缓冲），每 16 帧一批、每批 2 只。
async sub wave() {
    wait(120);
    // 4372–4468：Sub0 非镜像纵队 ×7（x = -160+8i / -128+8i）
    for i1 in 0..7 {
        var off1: fx = (i1 * 8) as fx;
        _ = spawn_enemy(-160.0fx + off1, -32.0fx, 1, 0, 0, 0, sub0(0));
        _ = spawn_enemy(-128.0fx + off1, -32.0fx, 1, 0, 0, 0, sub0(0));
        wait(16);
    }
    // 4484–4596：Sub0 镜像纵队 ×8（enemy_create_mirror，x = 128-8i / 160-8i）
    for i2 in 0..8 {
        var off2: fx = (i2 * 8) as fx;
        _ = spawn_enemy(128.0fx - off2, -32.0fx, 1, 0, 0, 0, sub0(1));
        _ = spawn_enemy(160.0fx - off2, -32.0fx, 1, 0, 0, 0, sub0(1));
        wait(16);
    }
    // 4612–4724：Sub0 非镜像纵队 ×8
    for i3 in 0..8 {
        var off3: fx = (i3 * 8) as fx;
        _ = spawn_enemy(-160.0fx + off3, -32.0fx, 1, 0, 0, 0, sub0(0));
        _ = spawn_enemy(-128.0fx + off3, -32.0fx, 1, 0, 0, 0, sub0(0));
        wait(16);
    }
    // 4740–4852：Sub1 镜像纵队 ×8（enemy_create_mirror，回转角减半）
    for i4 in 0..8 {
        var off4: fx = (i4 * 8) as fx;
        _ = spawn_enemy(128.0fx - off4, -32.0fx, 1, 0, 0, 0, sub1(1));
        _ = spawn_enemy(160.0fx - off4, -32.0fx, 1, 0, 0, 0, sub1(1));
        wait(16);
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
