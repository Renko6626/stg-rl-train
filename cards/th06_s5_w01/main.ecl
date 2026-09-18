// th06_s5_w01 —— 东方红魔乡 Stage 5 道中 第 1 波
// 原文：ecldata5.ecl.txt timeline 帧 310（enemy_create ×2）+ sub Sub0（行 2–26）

const TIME_LIMIT: int = 420;
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

// 原文 Sub0（行 9–33）：
//   move_velocity(90°, 2.0) → +40 move_acceleration(-0.06666667) 减速 30 帧 → +70 停住
//   $I4=8、$F0=1.5；每 5 帧一发自机狙环弹，$F0 += 0.38（L 再 +0.1）
//   → move_velocity(90°, 1.8) 继续下坠，+10000 enemy_delete(0)
async sub sub0() {
    set_invuln(65535);
    set_hitbox(9.33fx);                     // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();

    var rank: int = global(GVAR_RANK);
    var n: int = 16;                        // !E bullet_circle_aimed count1
    var addf: fx = 0.38fx;                  // !* math_float_add
    if rank == RANK_NORMAL { n = 30; }      // !N
    else if rank == RANK_HARD { n = 40; }   // !H
    else if rank >= RANK_LUNATIC { n = 40; addf = 0.48fx; }   // !L 40 颗 + 额外 +0.1

    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40: move_acceleration(-0.06666667f)
    acc = -0.06666667fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70: move_acceleration(0.0f) → 停住（积分后 spd≈0）
    acc = 0fx;
    spd = 0fx;
    move_vel(0, ang, spd, 0);

    // +70 Sub0_148: bullet_circle_aimed(3, 6, n, 1, $F0, 1.0f, 0, 0, 516)
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    var f0: fx = 1.5fx;                     // set_float($F0, 1.5f)
    for k2 in 0..8 {                        // jump_dec(70, Sub0_148, $I4) 循环 8 次
        sh_speed(0, f0, 0fx);
        sh_fire(0);
        f0 = f0 + addf;
        wait(5);
    }
    // 原文 move_velocity(90°, 1.8f)（循环结束后落下），其后靠出界退场
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);
    wait(10000);
    die();
}

// 导演任务：卡帧 120 起按 timeline 出怪（原文帧 310 同帧两只）
async sub wave() {
    wait(120);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub0());
    _ = spawn_enemy(32.0fx, -48.0fx, 1, 0, 0, 0, sub0());
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
