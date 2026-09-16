// th06_s3_b6 —— 东方红魔乡 Stage 3 boss（帕秋莉·诺蕾姬）符卡 彩符「彩雨」（E/N 版）
// 原文：ecldata3.ecl.txt Sub39(:973-981) → Sub40(:983-998) → Sub10(:276-288) → Sub41(:1000-1037)，
//       时限 2160（Sub40 的 timer_callback_threshold）。逐段对照见 report.md。
const TIME_LIMIT: int = 2160;
const SPELL_ID: int = 30;   // 原文 spellcard_start(0, 30/31, …)：E=30、N=31；rank 下界为 E，取 30（仅 UI/计分）
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px，色号原样）

// flags 19 = 0x1 | 0x2 | 0x10（mapping §5）：
//   0x1  出生冲刺：出生 16 帧内额外速度 5 → 0 线性衰减（add_speed(5) + @16 set_accel(-0.3125)）；
//   0x10 加速度：i0 = -1 视为永久；f1 是固定方向角（只有 f1 ≤ -999 才沿弹自身方向），
//        加速度矢量 = f0·(cos f1, sin f1)，写成 set_gravity；
//   0x2  出生特效（TH06 出生后短暂以 1/3 速移动），按 §4.2 不模拟。
xformdef DRIFT_DOWN  { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.0fx, 0.027fx); }             // f0=0.027, f1=π/2（下）
xformdef DRIFT_LEFT  { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(-0.024fx, 0.0fx); }            // f0=0.024, f1=π（左）
xformdef DRIFT_RIGHT { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.024fx, 0.0fx); }             // f0=0.024, f1=0（右）
xformdef DRIFT_DOWNL { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(-0.0169706fx, 0.0169706fx); }  // f1=3π/4（左下，仅 N）
xformdef DRIFT_DOWNR { add_speed(5.0fx); @16 set_accel(-0.3125fx); set_gravity(0.0169706fx, 0.0169706fx); }   // f1=π/4（右下，仅 N）

// Sub41 的 move_rand_in_bounds(-π,π); move_speed(3.0f); move_time_accelerate(80)。
// 边界取 Sub30 move_bounds_set(32,48,352,144) 的残留态 → 我方 (-160,48)-(160,144)（§7.3）。
sub wander(spd: fx, t: int) {
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
    var d: fx = spd * t / 2;                          // move_time：位移 s·t/2（§7.1）
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 1);                            // move_time_accelerate → QuadIn(1)
}

// Sub41_456（+24 起）：第二阶段每 3 帧一发。$I4 = 20（E/N），!H/!L 为 40（本单元 H/L 走 b7，属死代码但照原文翻）。
async sub burst_b() {
    var rank: int = global(GVAR_RANK);
    var n4: int = 20;
    if rank >= RANK_HARD { n4 = 40; }
    for kb in 0..n4 {
        var sp1: fx = 0.3fx + 0.7fx / 256 * rand(256);
        var an1: angle = rand(65536) as angle;
        _ = fire(SHARD, 2, $self_x, $self_y, sp1, an1, DRIFT_LEFT, none);
        var sp2: fx = 0.3fx + 0.7fx / 256 * rand(256);
        var an2: angle = rand(65536) as angle;
        _ = fire(SHARD, 4, $self_x, $self_y, sp2, an2, DRIFT_RIGHT, none);
        if rank == RANK_NORMAL {
            var sp3: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var an3: angle = rand(65536) as angle;
            _ = fire(SHARD, 13, $self_x, $self_y, sp3, an3, DRIFT_DOWNL, none);
            var sp4: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var an4: angle = rand(65536) as angle;
            _ = fire(SHARD, 14, $self_x, $self_y, sp4, an4, DRIFT_DOWNR, none);
        }
        wait(3);
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    kill_all_enemies(KILL_SILENT);                    // Sub40 enemy_kill_all()
    move_to(120, 0.0fx, 64.0fx, 2);                   // Sub40 move_position_time_decelerate(120, 192, 64)
    wait(120);                                        // Sub40 call("Sub10", 120) 的 120 帧前奏
    loop {                                            // Sub41_20
        // 第一阶段 Sub41_84：每 4 帧 4 颗（色 6/10/11/8），共 20 轮 = 80 帧。
        // bullet_effects(0.027, π/2) 粘滞到本阶段所有 bullet_random（flags 19 → DRIFT_DOWN）。
        for ka in 0..20 {
            var sa1: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var aa1: angle = rand(65536) as angle;
            _ = fire(SHARD, 6, $self_x, $self_y, sa1, aa1, DRIFT_DOWN, none);
            var sa2: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var aa2: angle = rand(65536) as angle;
            _ = fire(SHARD, 10, $self_x, $self_y, sa2, aa2, DRIFT_DOWN, none);
            var sa3: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var aa3: angle = rand(65536) as angle;
            _ = fire(SHARD, 11, $self_x, $self_y, sa3, aa3, DRIFT_DOWN, none);
            var sa4: fx = 0.3fx + 0.7fx / 256 * rand(256);
            var aa4: angle = rand(65536) as angle;
            _ = fire(SHARD, 8, $self_x, $self_y, sa4, aa4, DRIFT_DOWN, none);
            wait(4);
        }
        // move_rand_in_bounds + move_speed(3.0) + move_time_accelerate(80)，同帧 call("Sub10", 80)
        // （纯表现 80 帧），随后 +20 才到第二阶段。
        wander(3.0fx, 80);
        wait(100);
        // Sub41_456：第二阶段并行任务（每帧 fire 读的是 boss 当时位置，与移动解耦）。
        spawn burst_b();
        if rank >= RANK_HARD { wait(120); } else { wait(60); }   // 40 轮 / 20 轮 × 3 帧
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                              // Sub21 enemy_set_hitbox(56,56,32) → 56/3（§8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 段起点未知，按 §13.2 取 (0,96)
    loop { wait(600); }
}
