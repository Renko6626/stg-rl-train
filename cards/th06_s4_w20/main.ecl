// th06_s4_w20 —— 东方红魔乡 Stage 4 道中 第 20 波
// 原文：ecldata4.ecl.txt timeline 帧 7930–8080（Sub3 ×16，每 10 帧一只）+ sub Sub3
const TIME_LIMIT: int = 520;
const RICE: int = 64;   // TH06 弹型 2 RICE（色号 6）

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

// 原文：shoot_disable(); bullet_fan_aimed(...); shoot_enable(); shoot_interval_delayed(50);
// 自动射击参数在 +150 的 shoot_interval_delayed(0) 之前不变 → 写法 A 伴生任务。
// 四档：E(1 颗 ×2 层, 步 1638) / N(3, 1638) / H(5, 1638) / L(9, 2731)。
async sub autoshoot() {
    var rank: int = global(GVAR_RANK);
    var n: int = 1;                 // !E
    var step: angle = 1638bam;      // 0.15707964f = 9°
    if rank == RANK_NORMAL { n = 3; }                                        // !N
    else if rank == RANK_HARD { n = 5; }                                     // !H
    else if rank >= RANK_LUNATIC { n = 9; step = 2731bam; }                  // !L 0.2617994f = 15°
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, 2);
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);
    sh_angle(0, 0deg, step);
    // 帧对齐（mapping §4.3，2026-09-25 口径）：S = sub3 帧 0 执行 shoot_interval_delayed(50)，
    // 首发相对 S 的偏移 k = 49 − rand(50)；伴生任务首跑已在 S+1，等 k−1 帧正好落在 S+k。
    // 原作 +150 先执行 shoot_interval_delayed(0) 再计时 → k < 150 才开火（守卫用 k 本身、`>=`）。
    var k: int = 49 - rand(50);
    if k >= 150 { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 150 { return; }
        wait(50);
        k = k + 50;
    }
}

// 原文 Sub3：自左下外 (-32,170)→我方 (-224,170) 以 -60°、4.2 飞入
//   +30 角速度 3.75°/帧  → +70 角速度 -7.5°/帧 → +150 角速度归零
async sub sub3() {
    set_invuln(65535);
    set_hitbox(9.33fx);                          // enemy_set_hitbox(28,28,32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);            // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot();
    var ang: angle = -10923bam;                  // move_velocity(-1.0471976f, 4.2f) = -60°
    var spd: fx = 4.2fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(30);
    // +30: move_angular_velocity(0.06544985f) = 683bam
    w = 683bam;
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +70: move_angular_velocity(-0.1308997f) = -1365bam
    w = -1365bam;
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +150: move_angular_velocity(0.0f) + shoot_interval_delayed(0)
    w = 0deg;
    move_vel(0, ang, spd, 0);
    wait(9850);                                  // +10000 enemy_delete(0)；实际由 oob_guard 先退场
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 7930)。16 只每 10 帧，x 全为 -224、y=170。
async sub wave() {
    wait(120);
    for i in 0..16 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub3());
        if i < 15 { wait(10); }
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
