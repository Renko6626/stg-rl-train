// th06_s5_w09 —— Stage 5 关底前 双翼 3 对
// 原文：ecldata5.ecl.txt timeline 帧 6734/6824/6914（Sub2，:48-74）
const TIME_LIMIT: int = 600;
const BALL: int = 48;   // TH06 弹型 3 BALL 中玉

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

// Sub2：直落 2.0 → +40 减速 0.06666667/帧（30 帧到 0）→ +70 起每 4 帧一发
// 自机狙环，速度从 1.5 起每发 +0.55（L 额外 +0.2）→ 循环 5 发 → 1.8 继续下落
async sub sub2() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)
    // bullet_circle_aimed：!E 12 / !N 24 / !H 32 / !L 32 颗，单层，速度 %F0→1.0
    var n: int = 12;
    if rank == RANK_NORMAL { n = 24; }
    else if rank >= RANK_HARD { n = 32; }
    var f0: fx = 1.5fx;                    // set_float($F0, 1.5f)
    for k2 in 0..5 {                       // set_int($I4, 5) + jump_dec(70, Sub2_180)
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, 1);
        sh_speed(0, f0, 1.0fx - f0);
        sh_angle(0, 0deg, 0deg);
        sh_fire(0);
        f0 = f0 + 0.55fx;                  // math_float_add($F0, %F0, 0.55f)
        if rank == RANK_LUNATIC { f0 = f0 + 0.2fx; }   // !L
        wait(4);
    }
    spd = 1.8fx;                           // move_velocity(1.5707964f, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(10000);                           // 出界由 oob_guard 退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 6734)
async sub wave() {
    wait(120);
    // 6734：x = ∓160
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    wait(90);
    // 6824：x = ∓128
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    wait(90);
    // 6914：x = ∓96
    _ = spawn_enemy(-96.0fx, -48.0fx, 1, 0, 0, 0, sub2());
    _ = spawn_enemy(96.0fx, -48.0fx, 1, 0, 0, 0, sub2());
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
