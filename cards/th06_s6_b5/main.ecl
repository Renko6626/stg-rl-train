// th06_s6_b5 —— 东方红魔乡 Stage 6 boss 符卡 冥符「紅色の冥界」
// 原文：ecldata6.ecl.txt Sub38 → Sub39（宣言 + 移到中央）+ Sub40（多层环绕弹环），时限 2400。E/N 版。
// 逐段对照见 report.md。

const TIME_LIMIT: int = 2400;
const SPELL_ID_N: int = 106; // 原文 spellcard_start(2, id)：!N=106、!E（!H/!L）=-1；按 rank 取值（仅 UI/计分，引擎不登记）
const RICE: int = 64;        // TH06 弹型 2 RICE
const SHARD: int = 96;       // TH06 弹型 5 SHARD

// bullet_effects(128, -1, -1, -1, 0.0f, +0.024543693f, …) + flags 544(0x200|0x20)：
// 前 128 帧每帧 angle += +256bam（f0=0，无切向加速），之后停
xformdef RICE_CW  { @128 set_ang_vel(256bam); stop_fx(); }
// 第二条 RICE 环：f1 = -0.024543693f = -256bam
xformdef RICE_CCW { @128 set_ang_vel(-256bam); stop_fx(); }
// bullet_effects(240, -1, -1, -1, 0.02f, 1.5707964f, …) + flags 528(0x200|0x10)：
// 前 240 帧沿固定角 90°（正下方）加速度 0.02
xformdef SHARD_G  { @240 set_gravity(0fx, 0.02fx); stop_fx(); }

// Sub40 +21：move_rand_in_bounds(-π, π) + move_speed(1.5f) + move_time_decelerate(90)。
// 边界来自 b4/Sub21 的 move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)，跨 sub 持续；
// 位移 d = 1.5×90/2 = 67.5，缓动 decelerate = 2。反射阈值 x=lower.x+96=-64 / upper.x-96=64、
// y=lower.y+48=96 / upper.y-48=72，目标点夹到框内（Enemy::ClampPos）。
sub wander_move() {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                       // (-π, π)
    if $self_x < -64.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > 64.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < 96.0fx && v < 0 { v = 0 - v; }
    if $self_y > 72.0fx && v > 0 { v = 0 - v; }
    var d: fx = 67.5fx;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
    if ty < 48.0fx { ty = 48.0fx; } else if ty > 120.0fx { ty = 120.0fx; }
    move_to(90, tx, ty, 2);
}

async sub pattern() {
    var a: angle = 0deg;                     // 原文 %F0：环的基准角，逐环 +1024bam
    kill_all_enemies(KILL_SILENT);           // Sub39 enemy_kill_all()（跳过调用者 boss；本卡无杂兵，等价 no-op）
    // Sub39 move_position_time_decelerate(120, 192.0f, 144.0f, 0.0f)（x 减 192；
    // y=144 超出持续 move_bounds 上限 120，按 Enemy::ClampPos 每帧夹紧 → 终点 y=120）
    move_to(120, 0.0fx, 120.0fx, 2);
    wait(120);                               // Sub39 +120 ret 之后才进 Sub40

    // Sub39 shoot_offset(0.0f, 0.0f, 0.0f) = 默认出弹口，无需设置。
    // Sub39 的 shoot_interval_delayed(0) 停自动射击、bullet_rank_influence(0,0,0,0,0,0) 无修正，均无效果。

    // 三个发射器：RICE 顺时针环 / RICE 逆时针环 / SHARD 下坠环（参数粘滞，配一次）
    sh_reset(0);
    sh_sprite(0, RICE, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 24, 1);
    sh_speed(0, 1.8fx, 0fx);
    sh_xform(0, RICE_CW);
    sh_reset(1);
    sh_sprite(1, RICE, 2);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 24, 1);
    sh_speed(1, 1.8fx, 0fx);
    sh_xform(1, RICE_CCW);
    sh_reset(2);
    sh_sprite(2, SHARD, 2);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, 16, 1);
    sh_speed(2, 2.2fx, 0fx);
    sh_xform(2, SHARD_G);

    loop {
        // Sub40_0: set_int($I4, 6); set_float_rand_bound_min($F0, 2π, -π) = 整周随机
        a = rand(65536) as angle;
        // Sub40_44 + jump_dec(0, Sub40_44, $I4)：循环体共 6 次
        for k in 0..6 {
            sh_angle(0, a, -164bam); sh_fire(0); a = a + 1024bam;   // +0  RICE 顺转环
            wait(4);
            sh_angle(1, a, -164bam); sh_fire(1); a = a + 1024bam;   // +4  RICE 逆转环
            wait(4);
            sh_angle(2, a, -164bam); sh_fire(2); a = a + 1024bam;   // +8  SHARD 下坠环
            wait(4);
            sh_angle(2, a, -164bam); sh_fire(2); a = a + 1024bam;   // +12 SHARD 下坠环
            wait(9);                                                // +21 jump_dec
        }
        // jump_dec 计数耗尽后：move_rand_in_bounds(-π, π); move_speed(1.5f); move_time_decelerate(90)
        wander_move();                                              // +21 随机游走（含边界反射 / 目标夹紧）
        wait(90);                                                   // +111 jump(0, Sub40_0)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    var rank: int = global(GVAR_RANK);
    var spell_id: int = -1;                     // !E（及 !H/!L）
    if rank == RANK_NORMAL { spell_id = SPELL_ID_N; }   // !N
    spell_begin(0, spell_id, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
