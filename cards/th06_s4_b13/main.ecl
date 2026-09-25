// th06_s4_b13 —— 东方红魔乡 Stage 4 boss（魔理沙）符卡 木符「シルフィホルン」（自机 shot2 版）
// 原文：ecldata4.ecl.txt Sub57 → Sub58（宣言 + 移到中央 + 暂不可伤，120 帧）+ Sub59（攻击循环），时限 2100。
// 逐段对照见 out/report.md。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 48;   // 原文 spellcard_start(1, E=48 / N=49, "ST_ECLDATA4_SUB47_0")；仅 UI/计分，取 E 的 48
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px 弹，色号原样）

// flags 19 = 0x1|0x2|0x10 + bullet_effects(-1,-1,-1,-1, 0.012f, 2.3561945f, -1,-1)：
//   0x1  出生冲刺：+5 速度，16 帧线性衰减到 0
//   0x10 i0=-1（永久）沿固定角 f1=135° 的直角加速度 0.012 → set_gravity(0.012·cos135°, 0.012·sin135°)
//   0x2 出生特效不模拟（§4.2）
xformdef SHARD_ACCEL {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(-0.0084853fx, 0.0084853fx);
}

// Sub58：宣言后移到 (192, 80) 并暂不可伤 120 帧；Sub59 的攻击循环。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // Sub58 enemy_kill_all()（跳过调用者 = boss）
    move_to(120, 0.0fx, 80.0fx, 2);         // move_position_time_decelerate(120, 192, 80)，decelerate → easing 2
    wait(120);                              // +120: 前奏结束，进入 Sub59

    // Sub59：i0 为轮次。i0%6==0 时先来一发随机环（E 4 颗 / N 10 颗），
    // 然后固定两发鳞弹：第 1 发出现在 (随机 x, 32)，第 2 发出现在 (204, 随机 y)（y 按奇偶分上下半屏）。
    // 一轮长短看奇偶（§2.4 条件跳转设绝对时间）：
    //   偶数轮不跳，走 +2: //2 → 先 wait(2) 再发第 2 发，再到 +4: //6 ⇒ 6 帧；
    //   奇数轮 jump_neq(2, Sub59_588) 命中，块时间直接设为 2、不耗帧，第 2 发与第 1 发同帧出，
    //   再由 +4: //6 只等 4 帧 ⇒ 4 帧。两轮合计 10 帧，随机环（i0%6==0 都落在偶数轮）每 30 帧一次。
    var rank: int = global(GVAR_RANK);
    var ways: int = 0;                      // 原文该环只有 !E / !N 两行，H/L 无
    if rank == RANK_EASY { ways = 4; }
    else if rank == RANK_NORMAL { ways = 10; }
    var i0: int = 0;
    var sp: fx = 0fx;
    var an: angle = 0deg;
    var rx: fx = 0fx;
    var ry: fx = 0fx;
    loop {
        if i0 % 6 == 0 {
            // bullet_random(5, 11, 4/10, 1, 2.0, 0.3, π, -π, 19)，出弹口 (0,0)
            for j in 0..ways {
                sp = 0.3fx + 1.7fx / 256 * rand(256);
                an = rand(65536) as angle;
                _ = fire(SHARD, 11, $self_x, $self_y, sp, an, SHARD_ACCEL, none);
            }
        }
        // bullet_random(5, 10, 1, 1, 1.2, 0.3, 151°, 119°, 19)
        // 出弹口 = (rand384 - self_x, 32 - self_y) → 绝对 (rand384 - 192, 32)
        rx = 1.5fx * rand(256);
        sp = 0.3fx + 0.9fx / 256 * rand(256);
        an = 21663bam + rand(5826) as angle;
        _ = fire(SHARD, 10, rx - 192.0fx, 32.0fx, sp, an, SHARD_ACCEL, none);
        // +2: //2 / Sub59_588：出弹口 = (396 - self_x, ry_abs - self_y) → 绝对 (204, ry_abs)
        if i0 % 2 == 0 {
            wait(2);                                                // +2: //2（偶数轮等 2 帧）
            ry = 0.75fx * rand(256);                                // set_float_rand_bound(192) → [0,192)
        } else {
            ry = 192.0fx + 0.75fx * rand(256);                      // set_float_rand_bound_min(192,192) → [192,384)
        }
        sp = 0.3fx + 0.9fx / 256 * rand(256);
        an = 21663bam + rand(5826) as angle;
        _ = fire(SHARD, 11, 204.0fx, ry, sp, an, SHARD_ACCEL, none);
        i0 = i0 + 1;
        wait(4);                            // +4: //6，jump(0, Sub59_20)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
