// th06_s4_b14 —— 东方红魔乡 Stage 4 boss 符卡 木符「シルフィホルン上級」
// 原文：ecldata4.ecl.txt Sub60（入口）→ Sub61（宣言 + 移到中央 + 120 帧前奏）+ Sub62（随机区域 + 放射循环），时限 2100。
const TIME_LIMIT: int = 2100;
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px，色号原样）

// flags 19 = 0x1|0x2|0x10：0x1 出生冲刺（16 帧内额外速度 5→0，§5）；0x2 出生特效不模拟（§4.2）；
// 0x10 前 i0 帧沿固定角 f1=π/4 加速度 f0=0.012（§5）。0x1 与 0x10 叠加：@(D−16) 接在冲刺之后。
// f0·cos45 = f0·sin45 = 0.012 × 0.70710678 = 0.008485fx。
xformdef BURST_PERM {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0.008485fx, 0.008485fx);
}
// Sub62_300 起：i0 = 60 → 加速度只持续 60 帧，@(60−16)=@44 后 stop_fx。
xformdef BURST_60 {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    @44 set_gravity(0.008485fx, 0.008485fx);
    stop_fx();
}

// Sub62_20 的放射：基准 15 颗（[ENHL] 全难度无条件执行）；!H 追加 20、!L 追加 12，
// 是基准「之上」的追加（二进制掩码 0xff00 / H=0x0400 / L=0x0800），H/L 档三条同帧全命中。
// 单任务一帧 35 次 fire（H 档 = 15 + 20）会烧穿 1024 条/帧预算，故拆成两个并行 emitter，
// 在放射轮的前一帧 spawn（出生当帧不跑），放射帧两个任务同时开火，整轮不跨帧（§2.4）。
async sub volley_base() {
    for k1 in 0..15 {
        var sp1: fx = 0.3fx + 1.7fx / 256 * rand(256);
        var an1: angle = rand(65536) as angle;
        _ = fire(SHARD, 13, $self_x, $self_y, sp1, an1, BURST_PERM, none);
    }
}

async sub volley_extra(n: int) {
    for k2 in 0..n {
        var sp2: fx = 0.3fx + 1.7fx / 256 * rand(256);
        var an2: angle = rand(65536) as angle;
        _ = fire(SHARD, 13, $self_x, $self_y, sp2, an2, BURST_PERM, none);
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    // !H 追加 20、!L 追加 12；E/N 只有基准 15。
    var n_extra: int = 0;
    if rank == RANK_HARD { n_extra = 20; } else if rank >= RANK_LUNATIC { n_extra = 12; }
    // Sub62_744 的散射：E 无（原文只挂 !N/!H/!L）、N/H 1 颗 1.2、L 2 颗 1.5。
    var n744: int = 1;
    var s744: fx = 1.2fx;
    if rank == RANK_EASY { n744 = 0; } else if rank >= RANK_LUNATIC { n744 = 2; s744 = 1.5fx; }

    // Sub61 前奏：清杂兵、从登场点移到中央 (192, 80)【我方 (0, 80)】、120 帧内不可伤。
    kill_all_enemies(KILL_SILENT);          // enemy_kill_all()（跳过调用者 boss）
    move_to(120, 0.0fx, 80.0fx, 2);         // move_position_time_decelerate(120, 192.0f, 80.0f, 0.0f)
    wait(119);
    // i0 = 0 的放射轮在帧 123：提前一帧 spawn，两个 emitter 在帧 123 同时开火。
    spawn volley_base();
    if n_extra > 0 { spawn volley_extra(n_extra); }
    wait(1);                                // 帧 123 = Sub62_20 的块时间 0

    var i0: int = 0;
    loop {                                  // Sub62_20
        // ---- 块时间 0（帧 F）----
        // Sub62_300：bullet_effects(60, …)；shoot_offset(rand[0,384)−SELF_X, 32−SELF_Y)
        // → 绝对点 y = 32、x = rand[0,384) − 192。
        var rx: fx = 384.0fx / 256 * rand(256) - 192.0fx;
        var sp3: fx = 0.3fx + 0.9fx / 256 * rand(256);
        var an3: angle = (5279 + rand(5826)) as angle;   // 29° + [0, 32°)
        _ = fire(SHARD, 10, rx, 32.0fx, sp3, an3, BURST_60, none);

        // math_int_mod($I5,$I0,2); cmp_int($I5,0); jump_neq(2, Sub62_652)
        if i0 % 2 == 0 {
            // 偶轮：跳到 +2（等 2 帧）后发 744（y ∈ [0,192)），再等 4 帧到 +6。
            wait(2);
            var ry0: fx = 192.0fx / 256 * rand(256);
            if n744 > 0 {
                for k3 in 0..n744 {
                    var sp4: fx = 0.3fx + (s744 - 0.3fx) / 256 * rand(256);
                    var an4: angle = (5279 + rand(5826)) as angle;
                    _ = fire(SHARD, 11, -204.0fx, ry0, sp4, an4, BURST_60, none);
                }
            }
            wait(4);
        } else {
            // 奇轮：jump_neq(2, Sub62_652) 把块时间直接设为 2，652/744 与 300 弹同帧（帧 F）发出，
            // 之后 +4: //6 只等 6 − 2 = 4 帧（§2.4）。
            var ry1: fx = 192.0fx + 192.0fx / 256 * rand(256);
            if n744 > 0 {
                for k4 in 0..n744 {
                    var sp5: fx = 0.3fx + (s744 - 0.3fx) / 256 * rand(256);
                    var an5: angle = (5279 + rand(5826)) as angle;
                    _ = fire(SHARD, 11, -204.0fx, ry1, sp5, an5, BURST_60, none);
                }
            }
            wait(3);
            // 下一轮 i0+1 若是放射轮（i0 % 6 == 5），提前一帧 spawn。
            if i0 % 6 == 5 {
                spawn volley_base();
                if n_extra > 0 { spawn volley_extra(n_extra); }
            }
            wait(1);
        }
        i0 = i0 + 1;                        // math_inc($I0)
        // jump(0, Sub62_20)
    }
}

async sub boss_main() {
    // 原文 spellcard_start(1, id, …)：E=−1 / N=50 / H=51 / L=52（仅 boss UI 公告板）。
    var rank: int = global(GVAR_RANK);
    var sid: int = 50;
    if rank == RANK_HARD { sid = 51; } else if rank >= RANK_LUNATIC { sid = 52; } else if rank == RANK_EASY { sid = -1; }
    set_invuln(65535);
    set_hitbox(16.0fx);                         // enemy_set_hitbox(48,56,32) → min/3 = 16（§6.1b/§8）
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
