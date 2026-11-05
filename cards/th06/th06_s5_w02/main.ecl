// th06_s5_w02 —— 东方红魔乡 Stage 5 道中 第 2 波
// 原文：ecldata5.ecl.txt timeline 帧 590–750（Sub1 左侧纵队 ×8 / Sub2 顶部落下双翼 ×2），行 1799-1817, 28-46, 48-74。

const TIME_LIMIT: int = 580;
const RICE: int = 64;    // TH06 弹型 2 RICE（米弹）
const BALL: int = 48;    // TH06 弹型 3 BALL（中玉）

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

// Sub1 的自动射击：每 interval 帧发一轮 bullet_random。
//   原文 bullet_random(2, 6, c1, c2, 1.8f, 0.8f, π, 0, 516)：逐颗 fired，
//   角度 [a2, a1) = [0°, 180°)、速度 [s2, s1) = [0.8, 1.8) 随机；总数 = c1×c2。
//   shoot_interval_delayed：E/N 60、H 40、L 30（写法 A：first = interval − rand(interval)）。
async sub sub1_shoot(n: int, interval: int) {
    var first: int = interval - rand(interval);
    wait(first);
    loop {
        for k in 0..n {
            var sp: fx = 0.8fx + 1.0fx / 256 * rand(256);
            var an: angle = rand(32768) as angle;
            _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
        }
        wait(interval);
    }
}

// Sub1：左侧 x=-224 入场，向右直飞 2.5/frame，边飞边随机散射，出界即删。
//   bullet_random 总数 c1×c2 = E 3 / N 6 / H 8 / L 10。
async sub sub1() {
    set_invuln(65535);
    set_hitbox(9.33fx);                                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var n: int = 3;                                        // !E
    var interval: int = 60;                                // !E / !N
    if rank == RANK_NORMAL { n = 6; }                      // !N
    else if rank == RANK_HARD { n = 8; interval = 40; }    // !H
    else if rank >= RANK_LUNATIC { n = 10; interval = 30; } // !L
    spawn sub1_shoot(n, interval);
    move_vel(0, 0deg, 2.5fx, 0);                           // move_velocity(0.0f, 2.5f)
    wait(10000);
}

// Sub2：从上方 y=-48 落下 2.0/frame；+40 起以 -0.06666667 减速 30 帧到停；
//   +70 起每 4 帧发一轮自机狙环（BALL，速度从 1.5 起每轮 +0.55，L 再 +0.2），共 5 轮；
//   之后 +74 起以 1.8 继续下落，出界即删。
//   bullet_circle_aimed 环数 = E 12 / N 24 / H 32 / L 32。
async sub sub2() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var n: int = 12;                                       // !E
    var inc: fx = 0.55fx;                                  // !* math_float_add($F0, %F0, 0.55f)
    if rank == RANK_NORMAL { n = 24; }                     // !N
    else if rank == RANK_HARD { n = 32; }                  // !H
    else if rank >= RANK_LUNATIC { n = 32; inc = 0.75fx; } // !L 额外 +0.2
    var ang: angle = 90deg;                                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                                             // +70 move_acceleration(0.0f)
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    var f0: fx = 1.5fx;                                    // set_float($F0, 1.5f)
    for k2 in 0..5 {                                       // set_int($I4, 5) + jump_dec 循环
        sh_speed(0, f0, 0fx);
        sh_fire(0);
        f0 = f0 + inc;
        wait(4);
    }
    move_vel(0, 90deg, 1.8fx, 0);                          // +74 move_velocity(1.5707964f, 1.8f)
    wait(9926);
}

async sub wave() {
    wait(120);                                             // 开场缓冲
    // 原文帧 590/610/…/730：x=-32 → -224，y 128→184，每 20 帧一只
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 136.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 144.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 152.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 160.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 168.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 176.0fx, 1, 0, 0, 0, sub1()); wait(20);
    _ = spawn_enemy(-224.0fx, 184.0fx, 1, 0, 0, 0, sub1()); wait(20);
    // 原文帧 750：x=32 → -160 与 x=352 → 160，y=-48，同时出现
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
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
