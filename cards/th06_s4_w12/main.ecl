// th06_s4_w12 —— 东方红魔乡 Stage 4 道中第 12 波
// 原文：ecldata4.ecl.txt timeline 帧 4858–4988（行 3384–3411）+ Sub6（行 139–152）
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

// Sub6：水平飞入 30 帧 → 40 帧角速度 ∓3.75°/帧（左敌逆时针、镜像顺时针）→ 直飞。
// 原文全程不发弹（shoot_interval_delayed(0)），+9930 的 enemy_delete(0) 实际由出界守卫提前退场。
async sub sub6(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min(28,28)/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 4.5f)
    var spd: fx = 4.5fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg; }       // 镜像只取反水平速度：180° − 0°
    move_vel(0, ang, spd, 0);
    wait(30);
    w = -683bam;                           // +30 move_angular_velocity(-0.06544985f)
    if mirror != 0 { w = 683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +70 move_angular_velocity(0.0f)：之后直飞；出界由守卫退场
    wait(9950);                            // +9930 → 块帧 10000
    die();                                 // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 4858)，14 只每 10 帧一只，左右交替
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4858
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4868
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4878
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4888
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4898
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4908
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4918
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4928
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4938
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4948
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4958
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4968
    wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub6(0));   // 4978
    wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub6(1));    // 4988
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
