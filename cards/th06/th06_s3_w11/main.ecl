// th06_s3_w11 —— 东方红魔乡 Stage 3 道中 第 11 波
// 原文：ecldata3.ecl.txt timeline 帧 5334（Sub8 双翼一对），E–L 四档
const TIME_LIMIT: int = 440;
const BALL: int = 48;   // TH06 弹型 3 BALL

// flags 25 = 0x1|0x8|0x10 + bullet_effects(-1, -1, -1, -1, 0.025f, 1.5707964f, -1.0f, -1.0f)：
// 出生冲刺 5→0（16 帧），随后沿固定角 90°（下）永久重力 0.025/帧²（mapping §5）。
xformdef BURST_GRAV { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.0fx, 0.025fx); }

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

// Sub8：下落 → +40 减速（−1/12 /帧 ×30 帧，到 +70 速度归零）→ +70 BALL 随机弹幕
// （角度 [−180°, 0°)、速度 [0.3, 2.0)，逐颗独立随机）+ 新方向 1.5 飞出。
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.5f)
    var spd: fx = 2.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.083333336fx;                  // +40 move_acceleration(-0.083333336f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 set_float($F0, π/2) / set_float($F1, 1.6f) / set_int($I4, 16) 在本 sub 内无读取，删。
    // +70 move_acceleration(0.0f)：积分到此结束，速度已为 0。
    var rank: int = global(GVAR_RANK);
    var n: int = 8;                        // !E bullet_random(3, 15, 8, 1, 2.0f, 0.3f, 0.0f, -3.1415927f, 25)
    if rank == RANK_NORMAL { n = 14; }     // !N
    else if rank == RANK_HARD { n = 20; }  // !H
    else if rank >= RANK_LUNATIC { n = 22; }  // !L
    for i in 0..n {
        var an: angle = -32768bam + rand(32768) as angle;          // 角度 [−180°, 0°) = [−π, 0)
        var sp: fx = 0.3fx + 1.7fx / 256 * rand(256);             // 速度 [0.3, 2.0)
        _ = fire(BALL, 15, $self_x, $self_y, sp, an, BURST_GRAV, none);
    }
    // set_float_rand_bound($F2, π/2); math_float_add($F2, %F2, π/4) → 角 [45°, 135°)
    var a1: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a1 = 180deg - a1; }   // 镜像只取反水平速度（mapping §6.1）
    spd = 1.5fx;                           // move_velocity(%F2, 1.5f)
    ang = a1;
    move_vel(0, ang, spd, 0);
    wait(9930);                            // +10000 enemy_delete(0)：实际由 oob_guard 出界删除
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5334)；本单元只有一对双翼
async sub wave() {
    wait(120);
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
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
