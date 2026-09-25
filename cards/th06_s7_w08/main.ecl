// th06_s7_w08 —— 东方红魔乡 Stage 7（Extra，ecldata7）道中第 8 波
// 原文：ecldata7.ecl.txt timeline 帧 3160（Sub3 单只）+ sub Sub3（行 100–139）。
const TIME_LIMIT: int = 720;
const BALL: int = 48;   // TH06 弹型 3 BALL（中玉）

// bullet_circle flags 513 = 0x200|0x1：0x1 出生冲刺（§5）；0x200 音效丢弃
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

// Sub3：下落 40 帧 → 30 帧减速停住（+70）→ 原地螺旋 2 轮，每轮 8 发下行 + 8 发上行
// 每 4 帧一环、13 颗整周环；之后 +82 以 1.0 下飞，出界退场。
async sub sub3() {
    set_invuln(65535);
    set_hitbox(9.33fx);                     // enemy_set_hitbox(28,28,32) → min(28,28)/3
    spawn oob_guard();
    var ang: angle = 90deg;                 // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    var f0: angle = 0bam;
    var f1: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 move_acceleration(-0.06666667f)；+70 move_acceleration(0.0f)，逐帧积分到停
    acc = -0.06666667fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;
    spd = 0fx;
    move_vel(0, ang, spd, 0);
    // +70 螺旋：外层 2 轮（set_int($I5,2)）
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 13, 1);
    sh_xform(0, BURST);
    for k4 in 0..2 {
        // Sub3_192：set_int($I4,8); set_float_rand_bound_min($F0, 2π, −π); set_float($F1, 0.5)
        f0 = rand(65536) as angle;
        f1 = 0.5fx;
        // Sub3_256 内层 8 次：每发 F0 减 3.75°(683bam)、F1 加 0.18，+4 帧
        for k2 in 0..8 {
            sh_speed(0, f1, 0fx);
            sh_angle(0, f0, 0deg);
            sh_fire(0);
            f0 = f0 - 683bam;               // math_float_sub($F0, %F0, 0.06544985f)
            f1 = f1 + 0.18fx;               // math_float_add($F1, %F1, 0.18f)
            wait(4);
        }
        // 内层结束后原文立刻重置（set_int($I4,8) + 重新随机 F0 / F1=0.5）
        f0 = rand(65536) as angle;
        f1 = 0.5fx;
        // Sub3_436 内层 8 次：每发 F0 加 3.75°、F1 加 0.18，+4 帧
        for k3 in 0..8 {
            sh_speed(0, f1, 0fx);
            sh_angle(0, f0, 0deg);
            sh_fire(0);
            f0 = f0 + 683bam;               // math_float_add($F0, %F0, 0.06544985f)
            f1 = f1 + 0.18fx;               // math_float_add($F1, %F1, 0.18f)
            wait(4);
        }
        wait(4);                            // jump_dec(70, Sub3_192, $I5) 的 4 帧跳转间隔
    }
    // +82 move_velocity(1.5707964f, 1.0f)；原作 +10000 enemy_delete，实际靠出界退场
    ang = 90deg;
    spd = 1.0fx;
    move_vel(0, ang, spd, 0);
    loop { wait(1); }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 3160)
async sub wave() {
    wait(120);
    _ = spawn_enemy(0.0fx, -48.0fx, 1, 0, 0, 0, sub3());
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
