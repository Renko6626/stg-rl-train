// th06_s7_w06 —— 东方红魔乡 Stage 7(Extra) 道中第 6 波
// 原文：ecldata7 timeline 帧 2920（Sub3 单只）；Extra 档
const TIME_LIMIT: int = 720;
const BALL: int = 48;   // TH06 弹型 3 BALL

// flags 513 = 0x200|0x1：bit0 出生冲刺（mapping §5）；0x200 音效丢弃
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

// Sub3：下落 → +40 减速(-0.06666667/帧) → +70 停住并开始两轮环弹。
//   内层 A：i4=8，每轮 13 颗整周环，基准角 -683bam、速度 +0.18；每轮等待 4 帧。
//   内层 B：i4=8，基准角 +683bam，其余同 A。
//   外层 i5=2；之后 move_velocity(90°, 1.0) 直飞，出界由守卫退场。
async sub sub3() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    var f0: angle = 0deg;                  // $F0，环弹基准角
    var f1: fx = 0fx;                      // $F1，环弹速度
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)
    // bullet_circle(3, 2, 13, 1, %F1, 1.0f, %F0, 0.0f, 513)
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 13, 1);
    sh_xform(0, BURST);
    for k2 in 0..2 {                       // $I5 = 2 外层
        f0 = rand(65536) as angle;         // set_float_rand_bound_min($F0, 360°, -180°)
        f1 = 0.5fx;                        // set_float($F1, 0.5f)
        for k3 in 0..8 {                   // $I4 = 8，内层 A：基准角每轮 -683bam
            sh_speed(0, f1, 0fx);
            sh_angle(0, f0, 0deg);
            sh_fire(0);
            f0 = f0 - 683bam;
            f1 = f1 + 0.18fx;
            wait(4);
        }
        f0 = rand(65536) as angle;
        f1 = 0.5fx;
        for k4 in 0..8 {                   // $I4 = 8，内层 B：基准角每轮 +683bam
            sh_speed(0, f1, 0fx);
            sh_angle(0, f0, 0deg);
            sh_fire(0);
            f0 = f0 + 683bam;
            f1 = f1 + 0.18fx;
            wait(4);
        }
        wait(4);                           // +4: //82（外层 jump_dec(70, Sub3_192, $I5) 前的等待）
    }
    ang = 90deg;                           // +82 move_velocity(1.5707964f, 1.0f)
    spd = 1.0fx;
    move_vel(0, ang, spd, 0);
    loop { wait(1); }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2920)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, sub3());
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
