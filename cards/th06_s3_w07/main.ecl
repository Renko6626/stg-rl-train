// th06_s3_w07 —— 东方红魔乡 Stage 3 道中 第 7 波（中 boss 击破后）
// 原文：ecldata3.ecl.txt timeline 帧 3536–3770（Sub2 / Sub3 / Sub7）。
const TIME_LIMIT: int = 714;
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI
const BALL: int = 48;    // TH06 弹型 3 BALL

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

// Sub2 / Sub3 的发弹：H 单发自机狙（shoot_interval(60)，+90 取消 ⇒ 只一发）
async sub shot_h() {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_angle(0, 0deg, 1365bam);
    wait(60);
    sh_fire(0);
}

// Sub2 / Sub3 的发弹：L 延迟自机狙 10 颗 × 2 层（shoot_interval_delayed(200)，+90 取消）
async sub shot_l() {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 3.0fx, -1.0fx);          // 层速 3.0 / 2.0，第 2 层再错开 1365bam
    sh_angle(0, 0deg, 1365bam);
    var first: int = 200 - rand(200);    // 首发 n − rand(n)
    if first > 90 { return; }            // +90 shoot_interval_delayed(0)
    wait(first);
    sh_fire(0);
}

// Sub2 / Sub3：y=192 侧边入场，−60° × 4.0，+30 起 2°/帧转 60 帧后直飞（左右交替 13 只）
async sub fairy(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                  // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn shot_h(); }
    else if rank >= RANK_LUNATIC { spawn shot_l(); }
    var ang: angle = -10923bam;          // move_velocity(-1.0471976f, 4.0f) ⇒ −60°
    var spd: fx = 4.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 364bam;                          // +30 move_angular_velocity(0.034906585f) ⇒ 2°/帧
    if mirror != 0 { w = -364bam; }
    for k1 in 0..60 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                            // +90 move_angular_velocity(0.0f)
    wait(9909);                          // 原文 +10000 enemy_delete；实际靠出界退场
}

// Sub7 双翼：y=−32 下落 1.5 → +40 起减速 −0.05 共 30 帧 → +70 停在 y≈50，逐发加速扇
async sub wing(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;              // move_velocity(1.5707964f, 1.5f)
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;                       // +40 move_acceleration(-0.05f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                           // +70 move_acceleration(0.0f)
    var f1: fx = 1.6fx;                  // set_float($F1, 1.6f)
    var n: int = 12;                     // !E set_int($I4, 12)
    var cnt: int = 1;
    var spread: angle = 1365bam;         // E/N a7 = 7.5°
    if rank >= RANK_NORMAL { n = 16; }   // !NHL set_int($I4, 16)
    if rank == RANK_HARD { spread = 4096bam; }              // !H a7 = 22.5°
    else if rank >= RANK_LUNATIC { cnt = 5; spread = 5461bam; }  // !L 5 颗、a7 = 30°
    if rank == RANK_HARD {
        // !H bullet_circle_aimed(3, 6, 16, 1, 1.6f, 0.0f, 90°, 0.3926991f, 4)
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, 90deg, 4096bam);
        sh_fire(0);
    }
    for k2 in 0..n {                     // Sub7_216 … jump_dec(70, Sub7_216, $I4)
        sh_reset(0);
        sh_sprite(0, KUNAI, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, cnt, 1);
        sh_speed(0, f1, 0fx);            // 每发 +0.3
        sh_angle(0, 90deg, spread);
        sh_fire(0);
        f1 = f1 + 0.3fx;
        wait(2);                         // Sub7_496 +2: //72
    }
    // set_float_rand_bound($F2, π/2); math_float_add($F2, π/4); move_velocity(%F2, -1.5f)
    var a2: angle = (rand(16384) as angle) + 8192bam;
    if mirror != 0 { a2 = 180deg - a2; }
    move_vel(0, a2, -1.5fx, 0);
    wait(9897);
}

// 导演：按 timeline 相对帧出怪。卡帧 = 120 + (原文帧 − 3536)。
async sub wave() {
    wait(120);
    // 3536：双翼 ×2（x −128 / +128）
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
    wait(30);
    // 3566：双翼 ×2（x −64 / +64）
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
    wait(30);
    // 3596：双翼 ×2（x 0 / 0）
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
    wait(8);
    // 3604–3700：Sub2 / Sub3 左右交替 13 只，每 8 帧一只
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3604 mirror Sub2
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3612 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3620 mirror Sub3
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3628 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3636 mirror Sub3
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3644 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3652 mirror Sub3
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3660 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3668 mirror Sub3
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3676 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3684 mirror Sub3
    wait(8);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy(0));  // 3692 Sub2
    wait(8);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy(1));   // 3700 mirror Sub3
    wait(10);
    // 3710：双翼 ×2（x −160 / +160）
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
    wait(30);
    // 3740：双翼 ×2（x −96 / +96）
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
    wait(30);
    // 3770：双翼 ×2（x −32 / +32）
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, wing(0));
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, wing(1));
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
