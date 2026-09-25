// th06_s4_w13 —— 东方红魔乡 Stage 4 道中 第 13 波
// 原文：ecldata4.ecl.txt timeline 帧 5138–5268（Sub6），E–L 四档；小怪 14 只 = 7 对镜像，每 10 帧一对。
const TIME_LIMIT: int = 500;

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

// 原文 Sub6：全程无任何 bullet_*，且 +70 的 shoot_interval_delayed(0) 把自动射击定为 0，
// 所以这 14 只只做曲线飞行、一颗弹都不发（Stage 4 的运道具妖）。
async sub sub6(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 4.5f)
    var spd: fx = 4.5fx;
    if mirror != 0 { ang = 180deg; }       // 镜像只取反水平速度（§6.1）
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = -683bam;                // +30 move_angular_velocity(-0.06544985f)
    if mirror != 0 { w = 683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +70 move_angular_velocity(0.0f); shoot_interval_delayed(0)
    wait(9930);                            // +10000 enemy_delete(0)；实际由出界守卫退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5138)。14 只小怪，每 10 帧一只，镜像成对。
async sub wave() {
    wait(120);
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0)); wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1)); wait(10);
    }
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
