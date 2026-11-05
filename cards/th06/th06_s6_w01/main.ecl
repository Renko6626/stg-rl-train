// th06_s6_w01 —— 东方红魔乡 Stage 6 道中 第 1 波
// 原文：ecldata6.ecl.txt timeline 帧 340–1164（Sub1 / Sub3 / Sub2 / Sub4），E–L 四档
const TIME_LIMIT: int = 1244;
const RICE_T: int = 64;      // TH06 弹型 2 RICE

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

// 自动射击（shoot_interval_delayed，mapping §4.3 写法 A）。
// kind 0 = 原文 Sub1/Sub2：bullet_random(2,6,6,2,1.6,1.0,π,-π,4) → 6×2=12 颗，角度整周、速度 [1.0,1.6)
// kind 1 = 原文 Sub3/Sub4：bullet_random(2,2,9,1,2.0,1.0,π,-π,4) → 9×1=9 颗，角度整周、速度 [1.0,2.0)
// 原文在 +115（Sub1/2）或 +90（Sub3/4）处 shoot_interval_delayed(0) 停火。
async sub autoshoot(kind: int) {
    var rank: int = global(GVAR_RANK);
    var interval: int = 160;                       // !E
    if rank == RANK_NORMAL { interval = 80; }      // !N
    else if rank == RANK_HARD { interval = 50; }   // !H
    else if rank >= RANK_LUNATIC { interval = 30; }// !L
    // 原作 kind0 在 +115、kind1 在 +90 停火。为满足弹数峰值 ≤1024，
    // kind0 停火帧取 114（仅少打原作 k=114 那一轮；见 report 近似）。
    var until: int = 114;
    if kind == 1 { until = 90; }
    var first: int = interval - rand(interval);    // delayed：初值随机 [0,n)
    if first > until { return; }
    wait(first);
    var t: int = first;
    loop {
        if kind == 0 {
            for i1 in 0..12 {
                var sp1: fx = 1.0fx + 0.6fx / 256 * rand(256);
                var an1: angle = rand(65536) as angle;
                _ = fire(RICE_T, 6, $self_x, $self_y, sp1, an1, none, none);
            }
        } else {
            for i2 in 0..9 {
                var sp2: fx = 1.0fx + 1.0fx / 256 * rand(256);
                var an2: angle = rand(65536) as angle;
                _ = fire(RICE_T, 2, $self_x, $self_y, sp2, an2, none, none);
            }
        }
        if t + interval > until { return; }
        wait(interval);
        t = t + interval;
    }
}

// 小怪：kind 0 = Sub1/Sub2（move_velocity 30°,4.5；+30 起 -3.75°/帧 ×85）
//        kind 1 = Sub3/Sub4（move_velocity -60°,4.0；+30 起 +2°/帧 ×60）
// mirror != 0：水平速度取反 ⇒ 角度 180°−a、角速度取反（弹角度不镜像）
async sub fairy(kind: int, mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                            // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    spawn autoshoot(kind);
    var ang: angle = 5461bam;                      // move_velocity(0.5235988f, 4.5f)
    var spd: fx = 4.5fx;
    if kind == 1 { ang = -10923bam; spd = 4.0fx; } // move_velocity(-1.0471976f, 4.0f)
    if mirror != 0 { ang = 32768bam - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = -683bam;                        // move_angular_velocity(-0.06544985f)
    if kind == 1 { w = 364bam; }                   // move_angular_velocity(0.034906585f)
    if mirror != 0 { w = 0deg - w; }
    var dur: int = 85;
    if kind == 1 { dur = 60; }
    for k1 in 0..dur { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    loop { wait(1); }                              // +10000 enemy_delete；实际由 oob_guard 退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 340)。每 8 帧一只、4 只一循环（Sub1,Sub3,Sub2,Sub4），共 104 只。
async sub wave() {
    wait(120);
    for c in 0..26 {
        _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, fairy(0, 0)); wait(8);   // Sub1
        _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1, 0)); wait(8);   // Sub3
        _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, fairy(0, 1)); wait(8);    // Sub2 (mirror)
        _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1, 1)); wait(8);    // Sub4 (mirror)
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
