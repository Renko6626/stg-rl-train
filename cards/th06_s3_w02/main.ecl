// th06_s3_w02 —— 东方红魔乡 Stage 3 道中第 2 波
// 原文：ecldata3.ecl.txt timeline 帧 910–1090（Sub4，行 1532–1543 / 82–114）。
const TIME_LIMIT: int = 660;
const BALL: int = 48;   // TH06 弹型 3 BALL
const KUNAI: int = 80;  // TH06 弹型 4 KUNAI

// 与 TH06 一致：小怪先进过场地、再出界就退场（mapping §6.2）
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

// 原文 Sub4：从上方直落 → +40 以 -0.05/frame 减速 → +70 停住，
// 先放自机狙环（仅 H/L），再放苦无扇，每 2 帧一轮共 I4 轮 → 随机方向 1.5 速离场。
async sub wing() {
    set_invuln(65535);
    set_hitbox(9.33fx);                  // enemy_set_hitbox(28,28,32) → min/3
    spawn oob_guard();

    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;              // move_velocity(π/2, 1.5)
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;                       // +40 move_acceleration(-0.05)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }

    // +70：F0 = %PLAYER_ANGLE，F1 = 1.6，I4 = 15(E) / 30(NHL)，move_acceleration(0)
    var a0: angle = aim_player();
    var f1: fx = 1.6fx;
    var i4: int = 30;                    // !NHL
    var nfan: int = 1;                   // !E / !N
    var spread: angle = 1365bam;         // !E / !N 7.5°
    if rank == RANK_EASY { i4 = 15; }
    else if rank == RANK_HARD { nfan = 3; spread = 4096bam; }   // 22.5°
    else if rank >= RANK_LUNATIC { nfan = 5; spread = 2731bam; } // 15°

    // !HL bullet_circle_aimed(3, 6, 16, 1, 1.6f, 0.0f, F0, 0.3926991f, 4)
    if rank >= RANK_HARD {
        sh_reset(1);
        sh_sprite(1, BALL, 6);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, 16, 1);
        sh_speed(1, 1.6fx, 0fx);
        sh_angle(1, a0, 0deg);           // 环中轴 = 当前自机方向 + a0
        sh_fire(1);
    }

    // Sub4_220 循环：每轮 bullet_fan(4, 6, nfan, 1, F1, 0.0f, F0, spread, 4)，之后 F1 += 0.21
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, nfan, 1);
    for k2 in 0..i4 {
        sh_angle(0, a0, spread);
        sh_speed(0, f1, 0fx);
        sh_fire(0);
        f1 = f1 + 0.21fx;
        wait(2);
    }

    // 循环后 set_float_rand_bound($F2, π/2) + π/4 → 角度 [45°,135°)；move_velocity(F2, 1.5)
    var a2: angle = 45deg + rand(16384) as angle;
    move_vel(0, a2, 1.5fx, 0);
    wait(9928);
    die();                               // +10000 enemy_delete(0)；实际多由出界守卫先删
}

// 卡帧 = 120（开场缓冲）+ (原文帧 − 910)；左右两翼同帧生成，每 60 帧一对由外向内收拢
async sub wave() {
    wait(120);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, wing());   // 910 Sub4 x=320
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, wing());  // 910 Sub4 x=64
    wait(60);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, wing());    // 970 Sub4 x=288
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, wing());   // 970 Sub4 x=96
    wait(60);
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, wing());    // 1030 Sub4 x=256
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, wing());   // 1030 Sub4 x=128
    wait(60);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, wing());    // 1090 Sub4 x=224
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, wing());   // 1090 Sub4 x=160
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
