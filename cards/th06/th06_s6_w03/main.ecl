// th06_s6_w03 —— 东方红魔乡 Stage 6 道中 第 3 波（双翼一对）
// 原文：ecldata6.ecl.txt timeline 帧 1459（Sub5，行 109–129）
const TIME_LIMIT: int = 420;
const RICE: int = 64;   // TH06 弹型 2 RICE

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

// Sub5：从场外对向入场 → +40 发自机狙整周环 → 随机角俯冲离场（+10000 enemy_delete）
async sub sub5(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 0deg;                     // move_velocity(0.0f, 2.0f)
    var spd: fx = 2.0fx;
    if mirror != 0 { ang = 180deg - ang; }     // 镜像只取反水平速度（mapping §6.1）
    move_vel(0, ang, spd, 0);
    wait(40);

    // +40：move_acceleration(-0.06666667f) 同帧即被 move_acceleration(0.0f) 归零，无净效果；
    //      第一次 set_float_rand_bound_min($F0, 2π, −π) 随即被第二次覆盖，丢弃。
    var rank: int = global(GVAR_RANK);
    var n: int = 40;                           // !E bullet_circle_aimed(2, 6, 40, 1, 1.6f, 1.0f, 0, 0, 4)
    var layers: int = 1;
    var s1: fx = 1.6fx;                        // !E / !N
    if rank == RANK_NORMAL { n = 60; }                             // !N 60 颗
    else if rank == RANK_HARD { n = 60; s1 = 2.8fx; }              // !H 60 颗、s1 2.8
    else if rank >= RANK_LUNATIC { n = 60; layers = 2; s1 = 3.2fx; }  // !L 60 颗 × 2 层、s1 3.2
    var s2: fx = 1.0fx;
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (s2 - s1) / layers);
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);

    // 第二次 set_float_rand_bound_min($F0, π/2, π/4) → [45°, 135°)
    var a2: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a2 = 180deg - a2; }
    ang = a2;
    spd = 1.8fx;                               // move_velocity(%F0, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9960);                                // +9960 → 帧 10000（实际靠出界退场）
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 1459 − 1459)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 92.0fx, 1, 0, 0, 0, sub5(0));
    _ = spawn_enemy(224.0fx, 92.0fx, 1, 0, 0, 0, sub5(1));
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
