// th06_s6_w06 —— 东方红魔乡 Stage 6 道中 第 6 波
// 原文：ecldata6.ecl.txt timeline 帧 1973–2053（双翼五连）+ sub Sub5（行 109–129）
const TIME_LIMIT: int = 500;
const RICE: int = 64;   // TH06 弹型 2 RICE 米弹

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

// Sub5：从场外水平飞入 → +40 一发整周自机狙环弹 → 随机 [45°,135°) 方向 1.8 速飞出
async sub sub5(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 0deg;                    // move_velocity(0.0f, 2.0f)
    var spd: fx = 2.0fx;
    if mirror != 0 { ang = 180deg; }          // 镜像只反水平速度（180°−0°）
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 bullet_circle_aimed(2, 6, count1, count2, s1, 1.0f, 0.0f, 0.0f, 4)
    // 难度粘滞：!E count1=40；!N=60/s1=1.6；!H=60/s1=2.8；!L=60/2 层/s1=3.2
    var n: int = 40;
    var layers: int = 1;
    var s1: fx = 1.6fx;
    if rank == RANK_NORMAL { n = 60; }
    else if rank == RANK_HARD { n = 60; s1 = 2.8fx; }
    else if rank >= RANK_LUNATIC { n = 60; layers = 2; s1 = 3.2fx; }
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (1.0fx - s1) / layers);
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
    // +40 move_acceleration(-0.06666667f) 被同帧的 move_acceleration(0.0f) 覆盖，净效果为 0
    // set_float_rand_bound_min($F0, π/2, π/4) → [45°,135°)；move_velocity(%F0, 1.8f)
    ang = 8192bam + rand(16384) as angle;
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);
    wait(9960);
    die();                                    // +10000 enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1973)，每 20 帧一对
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 92.0fx, 1, 0, 0, 0, sub5(0));   // 1973
    _ = spawn_enemy(224.0fx, 92.0fx, 1, 0, 0, 0, sub5(1));
    wait(20);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, sub5(0));  // 1993
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, sub5(1));
    wait(20);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub5(0));  // 2013
    _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, sub5(1));
    wait(20);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub5(0));   // 2033
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub5(1));
    wait(20);
    _ = spawn_enemy(-224.0fx, 48.0fx, 1, 0, 0, 0, sub5(0));   // 2053
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub5(1));
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
