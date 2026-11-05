// th06_s2_w07 —— 东方红魔乡 Stage 2 道中 第 7 波
// 原文：ecldata2.ecl.txt timeline 帧 4533–5003（Sub8–Sub11 小怪群 + Sub12 射手）
const TIME_LIMIT: int = 890;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// flags 3 = 0x1|0x2：出生冲刺（mapping §5）
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

// Sub8–Sub11：随机 x 出生，随机下冲角 [45°,135°)，速度 5，不发弹；出界即退场
async sub fairy() {
    set_invuln(65535);
    set_hitbox(7.33fx);                              // enemy_set_hitbox(22, 22, 32) → 22/3
    spawn oob_guard();
    var ang: angle = 45deg + rand(16384) as angle;   // move_rand(0.7853982f, 2.3561945f)
    move_vel(0, ang, 5.0fx, 0);                      // move_speed(5.0f)
    wait(10000);
}

// Sub12：垂直下落 2.0 → +60 停住 → +70 自机狙扇 → +130 加速 + 3°/帧转向 → +190 停转继续加速
async sub shooter() {
    set_invuln(65535);
    set_hitbox(9.33fx);                              // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    sh_reset(0);
    sh_offset(0, 12.0fx, -12.0fx);                   // shoot_offset(12.0f, -12.0f, 0.0f)
    var ang: angle = 90deg;                          // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                                       // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 bullet_fan_aimed(1, 1, n, layers, s1, 0.8f, 0.0f, spread, 3)，四档
    var rank: int = global(GVAR_RANK);
    var n: int = 3;                                  // !E
    var layers: int = 1;
    var spread: angle = 8192bam;                     // 45°
    var s1: fx = 1.4fx;
    if rank == RANK_NORMAL { n = 7; layers = 2; spread = 6554bam; }          // !N 36°
    else if rank == RANK_HARD { n = 9; layers = 3; spread = 4096bam; }       // !H 22.5°
    else if rank >= RANK_LUNATIC { n = 11; layers = 5; spread = 2731bam; s1 = 2.4fx; }  // !L 15°
    sh_sprite(0, OUTLINE, 1);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, s1, (0.8fx - s1) / layers);
    sh_angle(0, 0deg, spread);
    sh_xform(0, BURST);
    sh_fire(0);
    wait(60);
    // +130 move_acceleration(0.05f); move_angular_velocity(0.05235988f)
    acc = 0.05fx;
    w = 546bam;
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +190 move_angular_velocity(0.0f)
    w = 0deg;
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// 导演：原文 4533–5003；卡帧 = 120 + (原文帧 − 4533)。
// Sub8–Sub11 每 10 帧一只（共 48 只，随机 x）；Sub12 每 40 帧一只（共 11 只，x = −160…160）
async sub wave() {
    wait(120);
    var s12: int = 0;
    for k1 in 0..48 {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy());
        if s12 < 11 && k1 == 7 + s12 * 4 {
            var sx: fx = (s12 * 32 + 32 - 192) as fx;
            _ = spawn_enemy(sx, -32.0fx, 1, 0, 0, 0, shooter());
            s12 = s12 + 1;
        }
        if k1 < 47 { wait(10); }
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
