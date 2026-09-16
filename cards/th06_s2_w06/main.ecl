// th06_s2_w06 —— 东方红魔乡 Stage 2 道中 第 6 波（中 boss 退场后的妖精雨）
// 原文：ecldata2.ecl.txt timeline 帧 3498–4413（Sub7），E–L 四档
const TIME_LIMIT: int = 1235;

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

// Sub7：随机 x 出生，随机下冲角 [45°,135°)，速度 3，全程不发弹，只有体碰；出界即退场
async sub fairy() {
    set_invuln(65535);
    set_hitbox(5.33fx);                              // enemy_set_hitbox(16.0f, 16.0f, 32.0f) → 16/3
    spawn oob_guard();
    var ang: angle = 45deg + rand(16384) as angle;   // move_rand(0.7853982f, 2.3561945f) = [45°,135°)
    move_vel(0, ang, 3.0fx, 0);                      // move_speed(3.0f)
    wait(10000);                                     // +10000 enemy_delete(0)；实际出界由守卫退场
}

// 导演：原文 3498–4413；卡帧 = 120（开场缓冲）+ (原文帧 − 3498)。
// 每 5 帧一只，共 184 只（3498 + 5×183 = 4413）。
async sub wave() {
    wait(120);
    for k1 in 0..184 {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, fairy());
        if k1 < 183 { wait(5); }
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
