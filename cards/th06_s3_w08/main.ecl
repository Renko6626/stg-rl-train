// th06_s3_w08 —— 东方红魔乡 Stage 3 道中 第 8 波
// 原文：ecldata3.ecl.txt timeline 帧 3898–4062（Sub8 双翼 ×3 批 + Sub2/Sub3 高速交替 26 只）
const TIME_LIMIT: int = 604;
const BALL: int = 48;      // TH06 弹型 3 BALL 中玉
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI 苦无

// Sub8 的 bullet_random flags 25 = 0x1|0x8|0x10，配 bullet_effects(-1,-1,-1,-1, 0.025f, π/2, -1, -1)：
// 0x1 出生冲刺（+5 速度、16 帧线性衰减），随后 0x10 永久沿固定角 90°（下）加速度 0.025（mapping §5）
xformdef SUB8_FIRE {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    stop_fx();
    set_gravity(0.0fx, 0.025fx);
}

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

// Sub8（原文 :201-224）：y=-32 下落，+40→+70 减速到 0，+70 一次随机散射
// （角度 [-180°,0)、速度 [0.3,2.0)，E/N/H/L 弹数 8/14/20/22），随后以 1.5 随机角逃离。
// 镜像 Sub8 的 move_velocity(90°) 不变；随机逃离角镜像后分布同区间。
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var n: int = 8;                            // !E bullet_random(3,15,8,…)
    if rank == RANK_NORMAL { n = 14; }         // !N
    else if rank == RANK_HARD { n = 20; }      // !H
    else if rank >= RANK_LUNATIC { n = 22; }   // !L
    var ang: angle = 90deg;                    // move_velocity(1.5707964f, 2.5f)
    var spd: fx = 2.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.083333336fx;                      // +40 move_acceleration(-0.083333336f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70：bullet_random(3, 15, n, 1, 2.0f, 0.3f, 0.0f, -π, 25)
    acc = 0fx;
    for k2 in 0..n {
        var sp: fx = 0.3fx + 1.7fx / 256 * rand(256);
        var an: angle = -32768bam + (rand(32768) as angle);
        _ = fire(BALL, 15, $self_x, $self_y, sp, an, SUB8_FIRE, none);
    }
    var esc: angle = 8192bam + (rand(16384) as angle);   // set_float_rand_bound(F2, π/2) + π/4 → [45°,135°)
    if mirror != 0 { esc = 180deg - esc; }               // 镜像只取反水平速度
    move_vel(0, esc, 1.5fx, 0);
    wait(10000);
}

// Sub2/Sub3 的 H 粘滞段（原文 :71-76 / :92-97）：
//   shoot_disable → bullet_fan_aimed(4,6,1,1, 2.0, 0.0, 0, 7.5°, 4) → shoot_enable → shoot_interval(60)
// +90 的 shoot_interval_delayed(0) 停火，故只发一次（60 帧）。
async sub autofire_fan() {
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

// Sub2/Sub3 的 L 粘滞段：
//   bullet_circle_aimed(4,6,10,2, 3.0, 1.0, 0, 7.5°, 4)，shoot_interval_delayed(200)
//   首发在 200−rand(200) 帧后；+90 停火 ⇒ 首发落在 (0,90] 才发。
async sub autofire_circle() {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 3.0fx, -1.0fx);                // 层 0 速 3.0、层 1 速 2.0
    sh_angle(0, 0deg, 1365bam);
    var first: int = 200 - rand(200);
    if first > 90 { return; }
    wait(first);
    sh_fire(0);
}

// Sub2 / Sub3（原文 :42-60 / :62-80，两者逐字相同）：从左右两侧 (−224/224, 192) 以 4.0 速度进场，
// 初角 ∓60°，+30→+90 以 ±2°/帧 转 120°，之后直飞。E/N 没有任何发弹指令（`!HL`/`!H`/`!L` 粘滞）：
// 一颗弹都不发。
async sub attacker(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn autofire_fan(); }
    else if rank >= RANK_LUNATIC { spawn autofire_circle(); }
    var ang: angle = -10923bam;                // move_velocity(-1.0471976f, 4.0f) = -60°
    var spd: fx = 4.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 364bam;                                // +30 move_angular_velocity(0.034906585f) = +2°/帧
    if mirror != 0 { w = -364bam; }
    for k1 in 0..60 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                                  // +90 move_angular_velocity(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10000);
}

// 导演：卡帧 = 123 + (原文帧 − 3898)，其中 3 = main/导演/pattern 的启动帧，120 = 开场缓冲。
async sub wave() {
    wait(120);
    // 3898：Sub8 双翼（x 64/320 → -128/128）
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(30);
    // 3928：Sub8 双翼（x 128/256 → -64/64）
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(30);
    // 3958：Sub8 双翼（x 192/192 → 0/0）
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(4);
    // 3962–4062：Sub2/Sub3 从左右两侧交替，每 4 帧一只，共 26 只（mirror 只影响水平速度）
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 3962 Sub2 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 3966 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 3970 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 3974 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 3978 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 3982 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 3986 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 3990 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 3994 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 3998 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4002 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4006 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4010 Sub3 mirror
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4014 Sub2 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4018 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4022 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4026 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4030 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4034 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4038 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4042 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4046 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4050 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4054 Sub3 mirror
    wait(4);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, attacker(0));   // 4058 Sub2
    wait(4);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, attacker(1));    // 4062 Sub3 mirror
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
