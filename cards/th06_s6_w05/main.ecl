// th06_s6_w05 —— 东方红魔乡 Stage 6 道中 第 5 波（双翼一对，x 向对进）
// 原文：ecldata6.ecl.txt timeline 帧 1683（enemy_create_mirror + enemy_create）+ Sub5（行 109–129）

const TIME_LIMIT: int = 420;
const RICE: int = 64;      // TH06 弹型 2 RICE

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

// Sub5：从两侧向中央横飞 2.0 → +40 放自机狙整周环（难度决定颗数 / 层数 / 速度）
//       → 随机角 [45°,135°) 1.8 慢速离场。
// 原文 +40 的 move_acceleration(-0.06666667f) 紧接着又被 move_acceleration(0.0f) 覆盖，
// 同帧写入，净效果为零（EclManager::RunEcl 同帧顺序执行），故不建减速。
async sub sub5(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 2.0f)：角度 0 = 右
    var spd: fx = 2.0fx;
    if mirror != 0 { ang = 180deg; }       // enemy_create_mirror：水平速度取反
    move_vel(0, ang, spd, 0);
    wait(40);
    // bullet_circle_aimed(2, 6, c1, c2, s1, 1.0f, 0.0f, 0.0f, 4)：RICE 色 6，a1 = a2 = 0
    var rank: int = global(GVAR_RANK);
    var n: int = 40;                       // !E  c1 = 40, s1 = 1.6
    var layers: int = 1;
    var s1: fx = 1.6fx;
    if rank == RANK_NORMAL { n = 60; }                              // !N c1 = 60, s1 = 1.6
    else if rank == RANK_HARD { n = 60; s1 = 2.8fx; }               // !H c1 = 60, s1 = 2.8
    else if rank >= RANK_LUNATIC { n = 60; layers = 2; s1 = 3.2fx; }// !L c1 = 60, c2 = 2, s1 = 3.2
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (1.0fx - s1) / layers);   // s2 = 1.0，逐层递减
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
    // set_float_rand_bound_min($F0, 1.5707964f, 0.7853982f) → [45°, 135°)
    ang = 45deg + rand(16384) as angle;
    if mirror != 0 { ang = 180deg - ang; } // 镜像只取反水平分量
    spd = 1.8fx;                           // move_velocity(%F0, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9960);                            // +9960 → +10000
    die();                                 // enemy_delete(0)，实际由 oob_guard() 提前退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1683)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 144.0fx, 1, 0, 0, 0, sub5(0));   // enemy_create(-32) → x−192 = −224
    _ = spawn_enemy(224.0fx, 144.0fx, 1, 0, 0, 0, sub5(1));    // enemy_create_mirror(416) → 224
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
