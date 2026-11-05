// th06_s7_w02 —— 东方红魔乡 Stage 7（Extra，ecldata7）道中第 2 波
// 原文：ecldata7.ecl.txt timeline 帧 1260–2360（Sub5 ×52）+ sub Sub5（行 185–205）。
const TIME_LIMIT: int = 1520;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// bullet_fan_aimed flags 3 = 0x1|0x2：0x1 出生冲刺（§5）；0x2 出生特效有意不模拟
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

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

// Sub5：下落 → +60 停 → +70 自机狙 11 颗 ×3 层扇 → +130 加速右转 → +190 直飞加速
async sub sub5() {
    set_invuln(65535);
    set_hitbox(9.33fx);                      // enemy_set_hitbox(28,28,32) → min(28,28)/3
    spawn oob_guard();
    var ang: angle = 90deg;                  // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                               // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 bullet_fan_aimed(1, 2, 11, 3, 4.0f, 3.0f, 0.0f, 0.44879895f, 3)
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_offset(0, 12.0fx, -12.0fx);           // shoot_offset(12.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 11, 3);
    sh_speed(0, 4.0fx, (3.0fx - 4.0fx) / 3);
    sh_angle(0, 0bam, 4681bam);              // a1 = 0°，a2 = 25.71°
    sh_xform(0, BURST);
    sh_fire(0);
    wait(60);
    // +130 move_acceleration(0.05f); move_angular_velocity(0.05235988f → 546bam)
    acc = 0.05fx;
    w = 546bam;
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +190 move_angular_velocity(0.0f)：停止转向，继续加速直到 +1000 enemy_delete(0)
    w = 0deg;
    var t: int = 190;
    loop {
        ang = ang + w;
        spd = spd + acc;
        move_vel(0, ang, spd, 0);
        wait(1);
        t = t + 1;
        if t >= 1000 { die(); }
    }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1260)
async sub wave() {
    wait(120);
    // 1260–1500：x 176 → −208，共 13 只，间隔 20
    for i1 in 0..13 {
        _ = spawn_enemy(176.0fx - (i1 * 32) as fx, -48.0fx, 1, 0, 0, 0, sub5());
        if i1 < 12 { wait(20); }
    }
    wait(30);
    // 1530–1770：同上 13 只
    for i2 in 0..13 {
        _ = spawn_enemy(176.0fx - (i2 * 32) as fx, -48.0fx, 1, 0, 0, 0, sub5());
        if i2 < 12 { wait(20); }
    }
    wait(80);
    // 1850–2090：x −176 → 208，共 13 只
    for i3 in 0..13 {
        _ = spawn_enemy(-176.0fx + (i3 * 32) as fx, -48.0fx, 1, 0, 0, 0, sub5());
        if i3 < 12 { wait(20); }
    }
    wait(30);
    // 2120–2360：同上 13 只
    for i4 in 0..13 {
        _ = spawn_enemy(-176.0fx + (i4 * 32) as fx, -48.0fx, 1, 0, 0, 0, sub5());
        if i4 < 12 { wait(20); }
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
