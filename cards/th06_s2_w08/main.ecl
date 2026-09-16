// th06_s2_w08 —— 东方红魔乡 Stage 2 道中 第 8 波
// 原文：ecldata2.ecl.txt timeline 帧 5123–5593（Sub8 / Sub9 / Sub10 / Sub11 / Sub12），E–L 四档
const TIME_LIMIT: int = 890;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// flags 3 = 0x1|0x2：出生冲刺 5→0 线性衰减（mapping §5）；0x2 出生特效不模拟
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

// Sub8 / Sub9 / Sub10 / Sub11：随机 x 出现，move_rand(45°,135°) + speed 5 斜向下穿场，不发弹。
// 四个 sub 只差 anm_set_main（丢弃），行为完全相同，故合并。
async sub fairy() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(7.33fx);                               // enemy_set_hitbox(22, 22, 32) → 22/3
    var ang: angle = 45deg + rand(16384) as angle;    // move_rand(0.7853982f, 2.3561945f) = [45°,135°)
    move_vel(0, ang, 5.0fx, 0);                       // move_speed(5.0f)
    wait(10000);                                      // +10000 enemy_delete(0)；实际出界由守卫退场
}

// Sub12：垂直下落 60 帧 → 停住 → +70 自机狙扇（按难度分档）→ +130 加速 + 回转 → +190 直飞加速
async sub shooter() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                               // enemy_set_hitbox(28, 28, 32) → 28/3
    var ang: angle = 90deg;                           // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                                        // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 bullet_fan_aimed(1, 1, c1, c2, s1, 0.8f, 0.0f, a2, 3)
    //   !E (3, 1, 1.4, 45°) / !N (7, 2, 1.4, 36°) / !H (9, 3, 1.4, 22.5°) / !L (11, 5, 2.4, 15°)
    var rank: int = global(GVAR_RANK);
    var c1: int = 3;
    var c2: int = 1;
    var s1: fx = 1.4fx;
    var spread: angle = 8192bam;
    if rank == RANK_NORMAL { c1 = 7; c2 = 2; spread = 6554bam; }
    else if rank == RANK_HARD { c1 = 9; c2 = 3; spread = 4096bam; }
    else if rank >= RANK_LUNATIC { c1 = 11; c2 = 5; s1 = 2.4fx; spread = 2731bam; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 1);
    sh_offset(0, 12.0fx, -12.0fx);                    // shoot_offset(12.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, c2);
    sh_speed(0, s1, (0.8fx - s1) / c2);
    sh_angle(0, 0deg, spread);
    sh_xform(0, BURST);
    sh_fire(0);
    wait(60);
    acc = 0.05fx;                                     // +130 move_acceleration(0.05f); move_angular_velocity(0.05235988f)
    var w: angle = 546bam;
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }   // +190 move_angular_velocity(0.0f)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5123)。每 10 帧一只 Sub8..Sub11（轮转，行为相同）；
// 原文帧 5193 起每 40 帧追加一只 Sub12，x 从 352 每 40 帧 −32 到 32（卡里 x−192 = 160→−160）。
async sub wave() {
    wait(120);
    var i: int = 0;
    loop {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy());
        if i >= 7 && (i - 7) % 4 == 0 {
            // k = (i−7)/4 = 0..10 → x(TH06) = 352 − 32k → x(卡) = 160 − 32k
            _ = spawn_enemy((160 - 32 * ((i - 7) / 4)) as fx, -32.0fx, 1, 0, 0, 0, shooter());
        }
        i = i + 1;
        if i >= 48 { break; }
        wait(10);
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
