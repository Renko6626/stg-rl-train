// th06_s7_w09 —— 东方红魔乡 Stage 7(Extra) 道中第 9 波
// 原文：ecldata7 timeline 帧 3640（Sub4 单只，行 141–183）；Extra 档
const TIME_LIMIT: int = 720;
const RICE: int = 64;   // TH06 弹型 2 RICE

// flags 513 = 0x201：0x200 音效（丢弃）+ 0x1 出生冲刺（mapping §5）
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

// Sub4：move_velocity(π/2, 2.0) 下落 → +40 减速 → +70 停在 (0, ~94) 发弹
//   外层 $I5=6：$I0 = 4,7,10,13,16,19；内层 A $I4=14（每轮 3 帧）、内层 B $I4=8（每轮 4 帧）
async sub sub4() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    var f0: angle = 0deg;                  // set_float_rand_bound_min($F0, 2π, -π)
    var f1: fx = 0fx;                      // set_float($F1, …)
    var i0: int = 4;
    var i1: int = 0;
    var i4: int = 0;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)
    spd = 0fx;
    move_vel(0, ang, spd, 0);
    f0 = rand(65536) as angle;             // 首个随机起始角，只在进外层前取一次
    for k2 in 0..6 {                       // jump_dec(70, Sub4_220, $I5=6)
        i4 = 14;                           // Sub4_220
        f1 = 0.5fx;
        for k3 in 0..14 {                  // jump_dec(70, Sub4_260, $I4=14)
            i1 = i0 + 2;                   // math_int_add($I1, $I0, 2)
            sh_reset(0);
            sh_sprite(0, RICE, 2);
            sh_aim(0, 0);
            sh_ring(0, 1);
            sh_count(0, i1, 1);
            sh_speed(0, f1, 1.0fx - f1);   // bullet_circle(2,2,$I1,1,%F1,1.0,%F0,0,513)
            sh_angle(0, f0, 0deg);
            sh_xform(0, BURST);
            sh_fire(0);
            f0 = f0 - 1024bam;             // math_float_sub($F0, %F0, 0.09817477f)
            f1 = f1 + 0.2fx;               // math_float_add($F1, %F1, 0.2f)
            wait(3);
        }
        i4 = 8;                            // Sub4_464 段前设置
        f0 = rand(65536) as angle;         // set_float_rand_bound_min($F0, 2π, -π)
        f1 = 2.0fx;
        for k4 in 0..8 {                   // jump_dec(73, Sub4_464, $I4=8)
            sh_reset(0);
            sh_sprite(0, RICE, 6);
            sh_aim(0, 0);
            sh_ring(0, 1);
            sh_count(0, i0, 1);
            sh_speed(0, f1, 1.0fx - f1);   // bullet_circle(2,6,$I0,1,%F1,1.0,%F0,0,513)
            sh_angle(0, f0, 0deg);
            sh_xform(0, BURST);
            sh_fire(0);
            f0 = f0 + 328bam;              // math_float_add($F0, %F0, 0.03141593f)
            f1 = f1 + 0.15fx;              // math_float_add($F1, %F1, 0.15f)
            wait(4);
        }
        i0 = i0 + 3;                       // math_int_add($I0, $I0, 3)
        wait(4);                           // +4: //81 → jump_dec(70, Sub4_220, $I5)
    }
    spd = 1.0fx;                           // move_velocity(1.5707964f, 1.0f)
    move_vel(0, ang, spd, 0);
    wait(9919);                            // +9919: //10000 enemy_delete(0)
    die();
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 3640)；本单元只有一只敌
async sub wave() {
    wait(120);
    _ = spawn_enemy(0.0fx, -16.0fx, 1, 0, 0, 0, sub4);
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
