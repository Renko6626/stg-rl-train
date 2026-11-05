// th06_s6_w04 —— 东方红魔乡 Stage 6 道中 第 4 波（双翼一对）
// 原文：ecldata6.ecl.txt timeline 帧 1571（enemy_create×2）+ Sub7（行 137–154）

const TIME_LIMIT: int = 520;
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

// Sub7：从 y=-32 下冲 2.0 → +40 放 60 颗自机狙环 → 随机角 [45°,135°) 1.8 慢速离场
// 原文 +40 的 move_acceleration(-0.06666667f) 紧接着又被 move_acceleration(0.0f) 覆盖，
// 同帧写入，净效果为零（EclManager::RunEcl 同帧顺序执行），故不建减速。
async sub sub7() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // bullet_circle_aimed(2, 6, 60, 1, 1.6f, 1.0f, 0.0f, 0.0f, 4)：60 颗单层自机狙整周环
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 60, 1);
    sh_speed(0, 1.6fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
    // set_float_rand_bound_min($F0, 1.5707964f, 0.7853982f) → [45°, 135°)
    ang = 45deg + rand(16384) as angle;
    spd = 1.8fx;                           // move_velocity(%F0, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9960);                            // +9960 → +10000
    die();                                 // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1571)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub7());
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub7());
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
