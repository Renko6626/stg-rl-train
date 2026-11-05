// th06_s4_w14 —— 东方红魔乡 Stage 4 道中 第 14 波
// 原文：ecldata4.ecl.txt timeline 帧 5418–5548（Sub7，行 154–167），全难度（ENHL）
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

// 原文 Sub7：下右向 -60° 4.5 速度 → +30 起以 3.75°/帧 转 80 帧 → +110 角速度归零直飞
// 全段无弹（原文未设任何 bullet_*，+110 shoot_interval_delayed(0) 停自动射击）
async sub sub7(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                            // enemy_set_hitbox(28,28,32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);              // enemy_flag_collision(0)
    spawn oob_guard();
    var ang: angle = -10923bam;                    // move_velocity(-1.0471976f, 4.5f)
    var spd: fx = 4.5fx;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = 683bam;                         // +30 move_angular_velocity(0.06544985f)
    if mirror != 0 { w = -683bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +110 move_angular_velocity(0.0f); shoot_interval_delayed(0)：此后直飞，出界由守卫退场
    wait(9890);
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5418)
// 原文 5418–5548：左 non-mirror / 右 mirror 成对，每 10 帧一只，共 7 对 14 只
async sub wave() {
    wait(120);
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub7(0));
        wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub7(1));
        if i < 6 { wait(10); }
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
