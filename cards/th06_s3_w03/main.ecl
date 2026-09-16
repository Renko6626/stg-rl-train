// th06_s3_w03 —— 东方红魔乡 Stage 3 道中 第 3 波
// 原文：ecldata3.ecl.txt timeline 帧 1270–1310（Sub4 ×6，行 1544–1552）+ sub Sub4（行 82–114）
const TIME_LIMIT: int = 520;
const BALL: int = 48;    // TH06 弹型 3 BALL 中玉
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI 苦无

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

// Sub4：下落 40 帧 → 减速 30 帧停住 → +70 自机狙扇（速度 1.6 每发 +0.21，
// !E/N 1 颗、!H 3 颗、!L 5 颗，均 KUNAI；!HL 额外一圈 16 颗 BALL 自机狙环）
// → 循环 15/30 次后朝随机方向 [45°,135°) 飞走（出界由守卫退场）
async sub sub4() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 1.5f)
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 move_acceleration(-0.05f)：30 帧内减速到 0（+70 时 spd = 0）
    acc = -0.05fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 炮击准备：F0 = %PLAYER_ANGLE，F1 = 1.6，I4 = 15(E) / 30(NHL)
    var aim: angle = aim_player();
    var spd2: fx = 1.6fx;
    var n: int = 15;
    if rank >= RANK_NORMAL { n = 30; }
    var ways: int = 1;                     // !E / !N
    var spread: angle = 1365bam;           // 7.5°
    if rank == RANK_HARD { ways = 3; spread = 4096bam; }        // 22.5°
    else if rank >= RANK_LUNATIC { ways = 5; spread = 2731bam; } // 15°
    // +70 !HL bullet_circle_aimed(3, 6, 16, 1, 1.6, 0.0, F0, 0.3926991, 4)
    if rank >= RANK_HARD {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, aim, 0deg);
        sh_fire(0);
    }
    // Sub4_220 循环体：!E/N/H/L 的 bullet_fan(4, 6, ways, 1, F1, 0.0, F0, spread, 4)
    sh_reset(1);
    sh_sprite(1, KUNAI, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    for k2 in 0..n {
        sh_count(1, ways, 1);
        sh_speed(1, spd2, 0fx);
        sh_angle(1, aim, spread);
        sh_fire(1);
        spd2 = spd2 + 0.21fx;
        wait(2);
    }
    // +2 循环后 set_float_rand_bound(F2, π/2); F2 += π/4 ⇒ [45°, 135°)
    var fly: angle = 8192bam + rand(16384) as angle;
    move_vel(0, fly, 1.5fx, 0);
    wait(10000);                           // 原文 +9928 //10000 的 enemy_delete(0)
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 1270)
async sub wave() {
    wait(120);
    // 1270：x 256 / 128 → 64 / −64
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(20);
    // 1290：x 288 / 96 → 96 / −96
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(20);
    // 1310：x 320 / 64 → 128 / −128
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
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
