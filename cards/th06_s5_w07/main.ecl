// th06_s5_w07 —— 东方红魔乡 Stage 5 道中 第 7 波
// 原文：ecldata5.ecl.txt timeline 帧 3774–4959（每 15 帧一只，组间 90 帧；Sub1/Sub9/Sub10/Sub11）
const TIME_LIMIT: int = 1565;

const RICE: int = 64;     // TH06 弹型 2 RICE
const BALL: int = 48;     // TH06 弹型 3 BALL
const KUNAI: int = 80;    // TH06 弹型 4 KUNAI
const BULLET: int = 128;  // TH06 弹型 0 PELLET

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

// 小怪主任务公共移动：原文 move_velocity(0.0f, 2.5f) 第一参是角度、第二参是速度
// （EclManager.cpp:330-335），0° = +x 向右 → 以 2.5 px/帧水平穿越场地。
// enemy_create_mirror 的 invertX 只取反水平速度（mapping §6.1）→ 180° 向左。弹角度不镜像。
// Sub1（原文行 28–46）：shoot_interval_delayed 自动乱射。
//   !E bullet_random(2,6,3,1,1.8,0.8,π,0,516)  speed 60
//   !N bullet_random(2,6,3,2,1.8,0.8,π,0,516)  speed 60
//   !H bullet_random(2,6,4,2,1.8,0.8,π,0,516)  speed 40
//   !L bullet_random(2,6,5,2,1.8,0.8,π,0,516)  speed 30
// 角度区间 [0, π)（a1=π, a2=0），速度区间 [0.8, 1.8)；逐颗随机。
async sub sub1(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                 // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var a: angle = 0deg;               // move_velocity(0.0f, 2.5f)
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    var rank: int = global(GVAR_RANK);
    var total: int = 3;                 // !E: count1=3, count2=1
    var interval: int = 60;
    if rank == RANK_NORMAL { total = 6; }                              // !N: 3×2
    else if rank == RANK_HARD { total = 8; interval = 40; }            // !H: 4×2
    else if rank >= RANK_LUNATIC { total = 10; interval = 30; }        // !L: 5×2
    var k: int = 0;
    var sp: fx = 0fx;
    var an: angle = 0deg;
    wait(interval - rand(interval));    // shoot_interval_delayed
    loop {
        k = 0;
        while k < total {
            sp = 0.8fx + 1.0fx / 256 * rand(256);   // [0.8, 1.8)
            an = rand(32768) as angle;              // [0, π)
            _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
            k = k + 1;
        }
        wait(interval);
    }
}

// Sub9（原文行 245–257）：bullet_fan_aimed(0,6,6,1,1.5,0.8,0,π/16,516)，间隔 40
async sub sub9(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);                       // fan_aimed：中轴 = 自机方向 + a1
    sh_ring(0, 0);
    sh_count(0, 6, 1);
    sh_speed(0, 1.5fx, -0.7fx);         // (s2 − s1)/c2
    sh_angle(0, 0deg, 2048bam);         // a1=0, a2=π/16
    var interval: int = 40;
    wait(interval - rand(interval));
    loop {
        sh_fire(0);
        wait(interval);
    }
}

// Sub10（原文行 259–271）：bullet_fan_aimed(4,2,4,1,1.5,0.8,0,π/12,516)，间隔 30
async sub sub10(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 4, 1);
    sh_speed(0, 1.5fx, -0.7fx);
    sh_angle(0, 0deg, 2731bam);         // a2=15°
    var interval: int = 30;
    wait(interval - rand(interval));
    loop {
        sh_fire(0);
        wait(interval);
    }
}

// Sub11（原文行 273–285）：bullet_random(3,2,4,1,1.5,0.8,π,−π,516)，间隔 10
// 角度整周 [−π, π)，速度 [0.8, 1.5)；逐颗随机。
async sub sub11(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    var interval: int = 10;
    var k: int = 0;
    var sp: fx = 0fx;
    var an: angle = 0deg;
    wait(interval - rand(interval));
    loop {
        k = 0;
        while k < 4 {
            sp = 0.8fx + 0.7fx / 256 * rand(256);   // [0.8, 1.5)
            an = rand(65536) as angle;              // 整周
            _ = fire(BALL, 2, $self_x, $self_y, sp, an, none, none);
            k = k + 1;
        }
        wait(interval);
    }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 3774)。65 只，15 帧一只，组间 90 帧。
// x1 = −224 → enemy_create（mirror 0，向右）；x1 = +224 → enemy_create_mirror（mirror 1，向左）。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 80.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub10(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 72.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 32.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub10(0));
    wait(90);
    _ = spawn_enemy(224.0fx, 80.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub10(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 72.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 32.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub10(0));
    wait(90);
    _ = spawn_enemy(224.0fx, 80.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub10(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 72.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 32.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub10(0));
    wait(90);
    _ = spawn_enemy(224.0fx, 80.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub10(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 72.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 32.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub10(0));
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
