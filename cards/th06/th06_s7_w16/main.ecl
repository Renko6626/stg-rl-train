// th06_s7_w16 —— 东方红魔乡 Stage 7(Extra) 道中 第 16 波
// 原文：ecldata7 timeline 帧 7273–7373（Sub10–Sub14，11 只）；Extra 档
const TIME_LIMIT: int = 340;
const BULLET: int = 128;   // TH06 弹型 0 PELLET

// flags 3 = 0x1|0x2：出生冲刺 5→0（16 帧）；出生特效（0x2）我方不模拟（mapping §5）
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

// Sub10：+30 起 8 轮，每轮 16 颗随机整周环、速度 1.2（1 层），轮间隔 11 帧
async sub Sub10() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);      // enemy_flag_interactable(1)
    for k1 in 0..8 {
        var a1: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π)
        sh_reset(0);
        sh_sprite(0, BULLET, 2);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.2fx, -0.2fx);        // (1.0 − 1.2) / 1
        sh_angle(0, a1, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        wait(11);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
    wait(30);
    die();                                 // enemy_delete(0)
}

// Sub11：+30 起 7 轮，每轮 20 颗、角度整周随机、速度 [0.6, 1.8)，轮间隔 12 帧
async sub Sub11() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    for k1 in 0..7 {
        for i in 0..20 {
            var sp: fx = 0.6fx + 1.2fx / 256 * rand(256);
            var an: angle = rand(65536) as angle;
            _ = fire(BULLET, 2, $self_x, $self_y, sp, an, BURST, none);
        }
        wait(12);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    die();
}

// Sub12：+30 起 6 轮，每轮自机狙扇 9 颗、间隔 18°=3277bam、速度 1.6，轮间隔 20 帧
async sub Sub12() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    for k1 in 0..6 {
        sh_reset(0);
        sh_sprite(0, BULLET, 6);
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, 9, 1);
        sh_speed(0, 1.6fx, -1.0fx);        // (0.6 − 1.6) / 1
        sh_angle(0, 0deg, 3277bam);
        sh_xform(0, BURST);
        sh_fire(0);
        wait(20);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    die();
}

// Sub13：+30 起 6 轮，每轮自机狙单列 4 层（速度 2.5→1.375，间隔 -0.375），轮间隔 20 帧
async sub Sub13() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    for k1 in 0..6 {
        sh_reset(0);
        sh_sprite(0, BULLET, 6);
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, 1, 4);
        sh_speed(0, 2.5fx, -0.375fx);      // (1.0 − 2.5) / 4
        sh_angle(0, 0deg, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        wait(20);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    die();
}

// Sub14：+30 起 4 轮，每轮 10 颗 × 3 层随机整周环（速度 2.2→1.133…），轮间隔 30 帧
async sub Sub14() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    for k1 in 0..4 {
        var a1: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π)
        sh_reset(0);
        sh_sprite(0, BULLET, 2);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, 10, 3);
        sh_speed(0, 2.2fx, -0.5333333fx);  // (0.6 − 2.2) / 3
        sh_angle(0, a1, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        wait(30);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(30);
    die();
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 7273)；x 随机 [0,384) → (rand(384) − 192) as fx
async sub wave() {
    wait(120);
    _ = spawn_enemy((rand(384) - 192) as fx, 64.0fx, 1, 0, 0, 0, Sub10); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 128.0fx, 1, 0, 0, 0, Sub11); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 96.0fx, 1, 0, 0, 0, Sub12); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 64.0fx, 1, 0, 0, 0, Sub13); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 32.0fx, 1, 0, 0, 0, Sub14); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 128.0fx, 1, 0, 0, 0, Sub10); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 80.0fx, 1, 0, 0, 0, Sub13); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 70.0fx, 1, 0, 0, 0, Sub14); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 16.0fx, 1, 0, 0, 0, Sub10); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 96.0fx, 1, 0, 0, 0, Sub11); wait(10);
    _ = spawn_enemy((rand(384) - 192) as fx, 80.0fx, 1, 0, 0, 0, Sub12);
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
