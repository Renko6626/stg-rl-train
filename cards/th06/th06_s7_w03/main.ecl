// th06_s7_w03 —— 东方红魔乡 Stage 7(Extra) 道中 第 3 波
// 原文：ecldata7.ecl.txt timeline 帧 2560（Sub1，行 22–57）；Extra 档
const TIME_LIMIT: int = 720;
const BALL: int = 48;   // TH06 弹型 3 BALL

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

// Sub1：move_velocity(90°, 2.0) 入场 → +40 减速(-0.06666667/帧) → +70 停住
//   block 70–98：八轮 16-way 环，速度 0.5 起每轮 +0.3，相位每轮 +410bam（初相随机整周）
//   block 74–126：八轮 16-way 环，速度恒 4.0，相位每轮 -410bam
//   +78 起以 1.0 继续下落，出界由 oob_guard 退场
async sub sub1() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min(28,28)/3
    spawn oob_guard();

    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);                              // +40: //40
    acc = -0.06666667fx;                   // move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70: //70 move_acceleration(0.0f)
    spd = 0fx;
    move_vel(0, ang, spd, 0);              // 停住

    var f0: angle = rand(65536) as angle;  // set_float_rand_bound_min($F0, 2π, -π)
    var f1: fx = 0.5fx;                    // set_float($F1, 0.5f)
    // Sub1_236：bullet_circle(3, 6, 16, 1, %F1, 1.0f, %F0, 0.0f, 516)，8 轮 × 4 帧
    for k2 in 0..8 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, f1, 1.0fx - f1);
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + 410bam;                  // math_float_add($F0, %F0, 0.03926991f)
        f1 = f1 + 0.3fx;                   // math_float_add($F1, %F1, 0.3f)
        wait(4);                           // +4: //74 jump_dec(70, Sub1_236, $I4)（末轮也走满 4 帧）
    }
    f0 = rand(65536) as angle;             // set_float_rand_bound_min($F0, 2π, -π)
    f1 = 0.5fx;                            // set_float($F1, 0.5f)
    // Sub1_416：bullet_circle(3, 6, 16, 1, 4.0f, 1.0f, %F0, 0.0f, 516)，8 轮 × 4 帧
    for k3 in 0..8 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 4.0fx, 1.0fx - 4.0fx);
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 - 410bam;                  // math_float_add($F0, %F0, -0.03926991f)
        f1 = f1 + 0.3fx;                   // math_float_add($F1, %F1, 0.3f)（此循环未再用）
        wait(4);                           // +4: //78 jump_dec(74, Sub1_416, $I4)（末轮也走满 4 帧）
    }
    // +78: //78 move_velocity(1.5707964f, 1.0f)
    spd = 1.0fx;
    move_vel(0, ang, spd, 0);
    // +9922: //10000 enemy_delete(0)（下落出界，实际由 oob_guard 提前退场）
    wait(9922);
}

async sub wave() {
    wait(120);                             // 开场缓冲；原文帧 2560 = 卡帧 120
    _ = spawn_enemy(0.0fx, -48.0fx, 1, 0, 0, 0, sub1);
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
