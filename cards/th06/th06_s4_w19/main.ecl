// th06_s4_w19 —— 东方红魔乡 Stage 4 道中 第 19 波
// 原文：ecldata4.ecl.txt timeline 帧 7780（Sub11 + Sub17×2）
const TIME_LIMIT: int = 420;
const RICE: int = 64;      // TH06 弹型 2
const BALL: int = 48;      // TH06 弹型 3
const BULLET: int = 128;   // TH06 弹型 0

// flags 0x1：出生后 16 帧额外速度 5→0（mapping §5）
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

// Sub11：从 (96,-32) 以 90°、2.0 下冲，+40 起减速 30 帧（-0.0667/帧）到 +70 停住；
// 之后原地发 64 轮旋转环（基准角每轮 ±2521bam = ±13.85°，每 8 帧一轮）；发完掉头上升。
async sub sub11() {
    set_invuln(65535);
    set_hitbox(9.33fx);                     // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                 // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                    // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                              // +70 move_acceleration(0.0f)

    // 四档弹数/速度：!E(1,1,2.6) !N(3,2,2.6) !H(5,3,3.0) !L(9,3,3.2)，s2 恒 1.8
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;
    var c2: int = 1;
    var s1: fx = 2.6fx;
    if rank == RANK_NORMAL { c1 = 3; c2 = 2; }
    else if rank == RANK_HARD { c1 = 5; c2 = 3; s1 = 3.0fx; }
    else if rank >= RANK_LUNATIC { c1 = 9; c2 = 3; s1 = 3.2fx; }

    var f0: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π)
    var i0: int = rand(2);                  // set_int_rand_bound($I0, 2)
    var f1: angle = 2521bam;                // set_float($F1, 0.24166097f)
    if i0 != 0 { f1 = -2521bam; }           // cmp+jump_neq(70,Sub11_268)：跳转设时间 70（= 当前块时间，不耗帧）

    // §2.4：jump_dec(70,…,I4) 每轮把块时间设回 70，+8 块 → 每轮等 78 − 70 = 8；
    // 64 轮后计数归零落空，块时间停在 jump_dec 的静态时间 78（不是 582）。
    for k2 in 0..64 {                       // set_int($I4, 64); +8 jump_dec(70, Sub11_288)
        sh_reset(0);
        sh_sprite(0, RICE, 6);
        sh_aim(0, 0);                       // bullet_circle 不瞄
        sh_ring(0, 1);
        sh_count(0, c1, c2);
        sh_speed(0, s1, (1.8fx - s1) / c2);
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + f1;                       // math_float_add($F0, %F0, %F1)
        wait(8);
    }
    move_vel(0, -90deg, 2.0fx, 0);          // move_velocity(-1.5707964f, 2.0f)
    wait(9922);                             // +9922: //10000 → 10000 − 78（松开后的块时间）；实际先出界被守卫删
    die();
}

// Sub17：静止在 (-96,48)/(-64,48)，+30 起 6 轮双环（PELLET 偏移环 + BALL 环），每 50 帧一轮；
// 6 轮后收回体碰，再 30 帧退场。
async sub sub17() {
    set_invuln(65535);
    set_hitbox(9.33fx);                     // enemy_set_hitbox(28,28,32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);       // enemy_flag_interactable(0)
    spawn oob_guard();
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);       // enemy_flag_interactable(1)
    // §2.4：每轮 jump_dec(30,…,I4) 把块时间设回 30，+50 块 → 等待 80 − 30 = 50；6 轮后落空，块时间停在 80。
    for k1 in 0..6 {                        // set_int($I4, 6); +50 jump_dec(30, Sub17_144)
        // bullet_offset_circle_aimed(0, 10, 11, 1, 1.2f, 1.0f, 0.0f, 0.0f, 5)
        sh_reset(0);
        sh_sprite(0, BULLET, 10);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 11, 1);
        sh_speed(0, 1.2fx, -0.2fx);
        sh_angle(0, 2978bam, 0deg);         // a1(0) + π/11
        sh_xform(0, BURST);                 // flags 5 = 0x1|0x4
        sh_fire(0);
        // bullet_circle_aimed(3, 10, 11, 1, 1.2f, 1.0f, %F1, 0.0f, 5)，$F1 未设 = 0
        sh_reset(1);
        sh_sprite(1, BALL, 10);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, 11, 1);
        sh_speed(1, 1.2fx, -0.2fx);
        sh_angle(1, 0deg, 0deg);
        sh_xform(1, BURST);
        sh_fire(1);
        wait(50);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);       // enemy_flag_interactable(0)
    wait(30);                               // +30: //110 → 110 − 80（松开后的块时间）
    die();
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 7780)
async sub wave() {
    wait(120);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub11);    // 288.0f
    _ = spawn_enemy(-96.0fx, 48.0fx, 1, 0, 0, 0, sub17);    // 96.0f
    _ = spawn_enemy(-64.0fx, 48.0fx, 1, 0, 0, 0, sub17);    // 128.0f
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
