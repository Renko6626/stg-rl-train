// th06_s1_mb1 —— 东方红魔乡 Stage 1 中 boss（露米娅）非符
// 原文：ecldata1 Sub9（攻击从 +160 起）+ Sub5 + Sub6，timer_callback_threshold(1440)。逐段对照见 notes.md。
const TIME_LIMIT: int = 1440;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const RICE: int = 64;      // TH06 弹型 2 RICE

// flags 9 / 5（含 0x1）：出生冲刺
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }
// flags 21 = 0x10|0x4|0x1 + bullet_effects(-1, -1, -1, -1, 0.02f, -999.0f, …)：冲刺后沿自身方向永久加速 0.02
xformdef BURST_ACCEL { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_accel(0.02fx); }

// bullet_circle_aimed(1, color, 16, E1/N3/H5/L7, 2.0f, E1.5/N1.5/H1.2/L1.0, 0.0f, 0.0f, 9)
sub ring_aimed(color: int) {
    var rank: int = global(GVAR_RANK);
    var layers: int = 1;
    var s2: fx = 1.5fx;
    if rank == RANK_NORMAL { layers = 3; }
    else if rank == RANK_HARD { layers = 5; s2 = 1.2fx; }
    else if rank >= RANK_LUNATIC { layers = 7; s2 = 1.0fx; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, color);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub9 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 16, layers);
    sh_speed(0, 2.0fx, (s2 - 2.0fx) / layers);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, BURST);
    sh_fire(0);
}

// Sub5($I0 = 色, $F0 = 角)：bullet_circle(0, $I0, E8/N14/H20/L28, 1, 0.0f, 0.0f, %F0, 0.0f, 21)
sub sub5(i0: int, f0: angle) {
    var rank: int = global(GVAR_RANK);
    var n: int = 8;
    if rank == RANK_NORMAL { n = 14; }
    else if rank == RANK_HARD { n = 20; }
    else if rank >= RANK_LUNATIC { n = 28; }
    sh_reset(1);
    sh_sprite(1, BULLET, i0);
    sh_offset(1, 0.0fx, -12.0fx);
    sh_ring(1, 1);
    sh_count(1, n, 1);
    sh_speed(1, 0fx, 0fx);                 // speed1 = 0 不钳
    sh_angle(1, f0, 0deg);
    sh_xform(1, BURST_ACCEL);
    sh_fire(1);
}

// Sub6($I0 = 色)：两个随机相位、随机速度 [0.5, 3.5) 的环，先小玉后米弹；flags 5（冲刺）
sub sub6(i0: int) {
    var rank: int = global(GVAR_RANK);
    var n: int = 4;
    if rank == RANK_NORMAL { n = 8; }
    else if rank == RANK_HARD { n = 12; }
    else if rank >= RANK_LUNATIC { n = 24; }
    sh_reset(2);
    sh_offset(2, 0.0fx, -12.0fx);
    sh_ring(2, 1);
    sh_count(2, n, 1);
    sh_xform(2, BURST);
    var f1: fx = 0.5fx + 3.0fx / 256 * rand(256);   // set_float_rand_bound($F1, 3.0f); += 0.5
    var f0: angle = rand(65536) as angle;          // set_float_rand_bound($F0, 2π); −= π
    sh_sprite(2, BULLET, i0);
    sh_speed(2, f1, 0fx);
    sh_angle(2, f0, 0deg);
    sh_fire(2);
    f1 = 0.5fx + 3.0fx / 256 * rand(256);
    f0 = rand(65536) as angle;
    sh_sprite(2, RICE, i0);
    sh_speed(2, f1, 0fx);
    sh_angle(2, f0, 0deg);
    sh_fire(2);
}

async sub pattern() {
    move_to(60, 128.0fx, 128.0fx, 2);      // move_position_time_decelerate(60, 320.0f, 128.0f, 0.0f)
    wait(160);
    ring_aimed(6);                         // +160
    wait(32);                              // +192：set_int($I4, 2)
    for it in 0..2 {                       // Sub9_712 … jump_dec(192, Sub9_712, $I4)
        wait(10);                          // +202
        move_to(60, 0.0fx, 64.0fx, 2);
        wait(60);                          // +262
        sub5(6, 0deg);
        wait(8);
        sub5(2, 683bam);                  // 0.06544985f
        wait(8);
        sub5(10, 1365bam);                 // 0.1308997f
        wait(8);
        sub5(13, 2048bam);                 // 0.19634955f
        wait(8);
        sub5(14, 2731bam);                 // +294  0.2617994f
        wait(90);                          // +384
        move_to(60, -128.0fx, 96.0fx, 2);
        wait(30);                          // +414
        ring_aimed(10);
        wait(30);                          // +444
        ring_aimed(13);
        wait(82);                          // +526
        move_to(60, 0.0fx, 80.0fx, 2);
        wait(60);                          // +586
        sub6(6);
        wait(8);
        sub6(2);
        wait(8);
        sub6(10);
        wait(8);
        sub6(13);
        wait(8);
        sub6(14);                          // +618
        wait(90);                          // +708
        move_to(60, 128.0fx, 96.0fx, 2);
        wait(30);                          // +738
        ring_aimed(6);
        wait(30);                          // +768
        ring_aimed(2);
        wait(72);                          // +840
    }
    // 两轮共 1488 帧，原文 1440 帧超时先到（timer_callback_sub("Sub8")）；以下只在时限外才会跑到
    wait(10);
    move_to(60, 0.0fx, -64.0fx, 2);
    wait(60);
    die();
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                    // enemy_set_hitbox(48, 56, 32) → min(48,56)/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, -32.0fx, 1000, 0, 0, 1, boss_main);   // move_position(192.0f, -32.0f, 0.0f)
    loop { wait(600); }
}
