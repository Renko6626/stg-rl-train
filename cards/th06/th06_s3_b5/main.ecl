// th06_s3_b5 —— 东方红魔乡 Stage 3 boss 红美铃 非符 3
// 原文：ecldata3.ecl.txt Sub30（登场设置，+160 起 call Sub32/Sub31/Sub10）+ Sub32 + Sub31 + Sub10，
//       timer_callback_threshold(2400)。逐段对照见 report.md。
const TIME_LIMIT: int = 2400;
const KUNAI: int = 80;    // TH06 弹型 4 KUNAI（半边长 2.5；16px 弹色号原样）
const SHARD: int = 96;    // TH06 弹型 5 SHARD（半边长 2；16px 弹色号原样）

// ── Sub32：flags 66(0x42) = 0x40 | 0x2（0x2 出生特效按 §4.2 不模拟）────────────────
// 0x40：i0=60 帧内速度自当前值线性减到 0，周期末转 f0、速度设为 f1（i1=1 个周期；f1 是速度不是角）。
// bullet_effects 按难度分叉：前段(t=0) f0 = -166°/-166°/-156°/-150°、f1 = 3.0/3.0/4.0/4.0；
// 后段(t=+71) f0 = +166°/+166°/+156°/+140°、f1 同上。@N 是后置延迟：step_speed 先发射再等 60 帧。
xformdef TURN_EN_A { @60 step_speed(0fx, 60); turn(-30219bam); set_speed(3.0fx); }  // E/N 前段 f0=-166°
xformdef TURN_H_A  { @60 step_speed(0fx, 60); turn(-28399bam); set_speed(4.0fx); }  // H   前段 f0=-156°
xformdef TURN_L_A  { @60 step_speed(0fx, 60); turn(-27307bam); set_speed(4.0fx); }  // L   前段 f0=-150°
xformdef TURN_EN_B { @60 step_speed(0fx, 60); turn(30219bam); set_speed(3.0fx); }   // E/N 后段 f0=+166°
xformdef TURN_H_B  { @60 step_speed(0fx, 60); turn(28399bam); set_speed(4.0fx); }   // H   后段 f0=+156°
xformdef TURN_L_B  { @60 step_speed(0fx, 60); turn(25486bam); set_speed(4.0fx); }   // L   后段 f0=+140°

// ── Sub31：flags 19(0x13) = 0x10 | 0x2 | 0x1 ───────────────────────────────────
// 0x1 出生冲刺 5→0（16 帧）；0x10 i0=-1 视为永久，f1=π/2 是固定方向角（只有 ≤-999 才沿弹自身方向），
// 加速度矢量 = f0·(cos f1, sin f1) = (0, 0.027)，写 set_gravity；0x2 出生特效不模拟。
xformdef SHARD_ACCEL { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0fx, 0.027fx); }

// Sub30 move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)；Sub30 的
// move_rand_in_bounds(-π,π) + move_speed(4.0) + move_time_accelerate(80)：位移 4·80/2 = 160（§7.3）。
sub wander() {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                 // [−π, π)
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = 4.0fx * 80 / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(80, tx, ty, 1);                          // move_time_accelerate → QuadIn(1)
}

// Sub32 前段（t=0…+71）：6 发 KUNAI 整周环，速度 2.0 起每发 +0.6；bullet_circle count2=1 单层。
// 本 sub 只引用 3 个 xformdef（locals ×3），后段拆到 sub32_b，避免 6 个 xformdef 累加超 64 字。
sub sub32_a() {
    var rank: int = global(GVAR_RANK);
    var n: int = 16;                              // !E bullet_circle(4, 6, 16, …)
    if rank == RANK_NORMAL { n = 24; }            // !N 24
    else if rank == RANK_HARD { n = 35; }         // !H 35
    else if rank >= RANK_LUNATIC { n = 42; }      // !L 42
    var sp: fx = 2.0fx;                           // set_float($F0, 2.0f)
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    if rank >= RANK_LUNATIC { sh_xform(0, TURN_L_A); }
    else if rank == RANK_HARD { sh_xform(0, TURN_H_A); }
    else { sh_xform(0, TURN_EN_A); }
    for k1 in 0..6 {                              // set_int($I4, 6); jump_dec(0, Sub32_252, $I4)
        // bullet_rank_influence(-0.5, 0.8, 0, 0, 0, 0)，开局 rank 16 → 速度 +0.15（§4.6）
        sh_speed(0, sp + 0.15fx, 0fx);
        sh_fire(0);
        sp = sp + 0.6fx;                          // math_float_add($F0, %F0, 0.6f)
        wait(1);                                  // +1: //1
    }
    wait(20);                                     // +20: //21
    wait(50);                                     // +50: //71
}

// Sub32 后段（t=+71…+92）：同上，色号 2、速度基值重回 2.0。
sub sub32_b() {
    var rank: int = global(GVAR_RANK);
    var n: int = 16;
    if rank == RANK_NORMAL { n = 24; }
    else if rank == RANK_HARD { n = 35; }
    else if rank >= RANK_LUNATIC { n = 42; }
    var sp: fx = 2.0fx;
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    if rank >= RANK_LUNATIC { sh_xform(0, TURN_L_B); }
    else if rank == RANK_HARD { sh_xform(0, TURN_H_B); }
    else { sh_xform(0, TURN_EN_B); }
    for k2 in 0..6 {
        sh_speed(0, sp + 0.15fx, 0fx);
        sh_fire(0);
        sp = sp + 0.6fx;
        wait(1);                                  // +1: //72
    }
    wait(20);                                     // +20: //92
}

// Sub31：每 2 帧 1 发（E/N）/2 发（H）/3 发（L）随机鳞弹，角度 [-π,0)、速度 [0.3,1.0)，共 40 轮。
// bullet_rank_influence(0,0,…) → 无修正。
sub sub31() {
    var rank: int = global(GVAR_RANK);
    var n: int = 1;                               // !E/!N count1=1
    if rank == RANK_HARD { n = 2; }               // !H count1=2
    else if rank >= RANK_LUNATIC { n = 3; }       // !L count1=3
    for k3 in 0..40 {                             // set_int($I4, 40); jump_dec(0, Sub31_100, $I4)
        for j in 0..n {
            var sp: fx = 0.3fx + 0.7fx / 256 * rand(256);      // 速度 [0.3, 1.0)
            var an: angle = -32768bam + rand(32768) as angle;  // 角度 [-π, 0)
            _ = fire(SHARD, 6, $self_x, $self_y, sp, an, SHARD_ACCEL, none);
        }
        wait(2);                                  // +2: //2
    }
    wait(80);                                     // +80: //82
}

// Sub30 +160 起的主循环：Sub32（前后两段）→ Sub31 → 随机游走 → Sub10（80 帧纯表现时长）→ 等 120。
// Sub10 的 effect_particle/anm/音效按 §11 丢弃，只保留其 8×10 帧块时间（调用方块时间轴不变）。
async sub pattern() {
    wait(160);                                    // Sub30 +160：此前为登场设置（卡外壳接管）
    loop {
        sub32_a();
        sub32_b();
        sub31();
        wander();
        wait(80);                                 // call("Sub10", 80)：jump_dec(0,Sub10_40,$I5=8) ×10 帧
        wait(120);                                // +120: //280 jump(160, Sub30_396)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                          // Sub21 enemy_set_hitbox(56,56,32) → 56/3（§8）
    kill_all_enemies(KILL_SILENT);                // Sub30 enemy_kill_all()：跳过调用者自己
    set_enemy_flag(ENEMY_NO_BODY, 0);             // Sub30 enemy_flag_collision(1)+interactable(1)（§8）
    phase_begin(0, pattern, TIME_LIMIT, 0);       // 非符段（§9）
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 段起点未知，按 §13.2 默认 (0,96)
    loop { wait(600); }
}
