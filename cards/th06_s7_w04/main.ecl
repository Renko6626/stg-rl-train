// th06_s7_w04 —— 东方红魔乡 Stage 7（Extra）道中 第 4 波
// 原文：ecldata7.ecl.txt timeline 帧 2680（Sub1 双翼 ×2）+ sub Sub1（行 22–57）
const TIME_LIMIT: int = 720;
const BALL: int = 48;   // TH06 弹型 3 BALL / 中玉

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

// Sub1：从 y=-48 竖直下落 2.0fx 40 帧 → +40 减速 -0.06666667（30 帧，+70 归零悬停）
//       → 两组 8 波环形弹（每 4 帧一波、每波 16 颗）→ 竖直下落 1.0fx；出界由守卫退场。
// 第一个 `enemy_create` 无镜像（x=32/352 各自定位），故不需要 invertX 处理。
async sub wing() {
    set_invuln(65535);
    set_hitbox(9.33fx);                 // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;             // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 move_acceleration(-0.06666667f)：逐帧积分到 +70
    acc = -0.06666667fx;
    for k1 in 0..30 {
        spd = spd + acc;
        move_vel(0, ang, spd, 0);
        wait(1);
    }
    // +70 move_acceleration(0.0f)：悬停
    acc = 0fx;
    spd = 0fx;
    move_vel(0, ang, spd, 0);

    // +70 起第一组：8 波 bullet_circle(3, 6, 16, 1, %F1, 1.0, %F0, 0.0, 516)
    //   flags 516 = 0x204：0x200 音效（丢）+ 0x4 出生特效（不模拟）；无 0x1 冲刺。
    var f0: angle = rand(65536) as angle;   // set_float_rand_bound_min(F0, 2π, -π) = [-π, π)
    var f1: fx = 0.5fx;                     // set_float(F1, 0.5f)
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 16, 1);
    for k2 in 0..8 {
        sh_speed(0, f1, (1.0fx - f1) / 1);
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + 410bam;                   // math_float_add(F0, F0, 0.03926991f) = +2.25°
        f1 = f1 + 0.3fx;                    // math_float_add(F1, F1, 0.3f)
        wait(4);
    }
    // +74 起第二组：同形但速度固定 4.0，角度反向旋转
    f0 = rand(65536) as angle;
    f1 = 0.5fx;
    for k3 in 0..8 {
        sh_speed(0, 4.0fx, (1.0fx - 4.0fx) / 1);
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 - 410bam;                   // math_float_add(F0, F0, -0.03926991f) = -2.25°
        f1 = f1 + 0.3fx;                    // 原文仍自增，但本组不读 F1
        wait(4);
    }
    // +78（本组结束后）move_velocity(1.5707964f, 1.0f)
    move_vel(0, 90deg, 1.0fx, 0);
    wait(10000);
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2680)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, wing());
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, wing());
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
