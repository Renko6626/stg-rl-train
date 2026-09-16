// th06_s2_b6 —— 东方红魔乡 Stage 2 boss（琪露诺）符卡 雪符「ダイアモンドブリザード」
// 原文：ecldata2.ecl.txt Sub39 → Sub40（宣言 + bullet_random 配置 + move_position_time_decelerate(120,192,96)）+ Sub41（随机区域散射循环），时限 1980。
const TIME_LIMIT: int = 1980;
const SPELL_ID: int = 17;   // 原文 spellcard_start(0, 17/18/19, …)：N/H/L；本卡取 Normal 的 17（仅 UI/计分）
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px，色号原样）

// flags 5 = 0x1|0x4：0x1 出生冲刺（16 帧内额外速度 5→0 线性衰减，§5）；0x4 出生特效不模拟（§4.2）
xformdef SPAWN_DASH { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// Sub41 的 move_rand_in_bounds(-π,π); move_speed(1.2); move_time_decelerate(120)
// 边界 = Sub21 的 move_bounds_set(32, 48, 352, 134) → 我方 (-160, 48)-(160, 134)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 134.0fx;
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
    var d: fx = spd * t / 2;                         // move_time_decelerate：位移 s·t/2（§7.1）
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);                           // 缓动 decelerate → QuadOut(2)
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    // Sub40 set_int($I0, 6/10/14/24)：每「发」的颗数。Sub39 的
    // bullet_rank_influence(-0.5,0.3,0,4,0,0) 已被 Sub40 spellcard_start 重置为默认（§4.6），不加修正。
    var n: int = 6;
    if rank == RANK_NORMAL { n = 10; } else if rank == RANK_HARD { n = 14; } else if rank >= RANK_LUNATIC { n = 24; }

    wait(60);                                        // Sub39 +60 → call Sub40
    move_to(120, 0.0fx, 96.0fx, 2);                  // Sub40 move_position_time_decelerate(120, 192, 96)
    wait(120);                                       // Sub40 +120 ret
    loop {                                           // Sub41_20
        wander(1.2fx, 120);                          // move_rand_in_bounds; move_speed(1.2); move_time_decelerate(120)
        for k in 0..12 {                             // Sub41_92：每 10 帧一发，共 12 发
            wait(10);
            // ex_ins_call(1, 128) = ShootAtRandomArea：在敌周围 ±128/2 × ±(128·0.75)/2 的随机点开一「发」
            var rx: fx = $self_x - 64.0fx + 128.0fx / 256 * rand(256);
            var ry: fx = $self_y - 48.0fx + 96.0fx / 256 * rand(256);
            // bullet_random(5, 6, $I0, 1, 2.0f, 0.4f, π, −π, 5)：角度 [−π,π)、速度 [0.4,2.0) 逐颗随机
            for j in 0..n {
                var sp: fx = 0.4fx + 1.6fx / 256 * rand(256);
                var an: angle = rand(65536) as angle;
                _ = fire(SHARD, 6, rx, ry, sp, an, SPAWN_DASH, none);
            }
        }
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                              // Sub21 enemy_set_hitbox(48,56,32) → min/3（§8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
