// th06_s4_b9 —— 东方红魔乡 Stage 4 boss 帕秋莉·诺蕾姬 符卡 木＆火符「フォレストブレイズ」
// 原文：ecldata4.ecl.txt Sub41 → Sub84 → Sub85（宣言 + 移到中央，timer 2400）+ Sub86（攻击循环）；仅 H/L 到达。
// 逐段对照见 out/report.md。
const TIME_LIMIT: int = 2400;
const SPELL_ID: int = 71;   // 原文 spellcard_start(1, H=71 / L=72, "ST_ECLDATA4_SUB56_0")；取 H 的 71（仅 boss UI）
const AMULET: int = 112;    // TH06 弹型 7 FIREBALL（32px 弹，色号 0 → 0）
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px 弹，色号原样）

// flags 19 = 0x1|0x2|0x10 + bullet_effects(-1,-1,-1,-1, 0.012f, 2.3561945f, -1,-1)：
//   0x1  出生冲刺：+5 速度，16 帧内线性衰减到 0（§5）；
//   0x2  出生特效不模拟（§4.2）；
//   0x10 i0=-1（永久）沿固定角 f1=135° 直角加速度 0.012 → set_gravity(0.012·cos135°, 0.012·sin135°)，
//        0.012 × 0.70710678 = 0.0084853fx。永久加速无收尾，不写 stop_fx。
xformdef FIREBALL_PERM {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(-0.0084853fx, 0.0084853fx);
}
// Sub86_344 的 bullet_effects(60,-1,-1,-1, 0.012f, 2.3561945f, -1,-1)：加速度只持续 60 帧，
// 0x1 冲刺先行，0x10 从出生算起 → @(60−16)=@44 后收尾。
xformdef SHARD_BURST {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    @44 set_gravity(-0.0084853fx, 0.0084853fx);
    stop_fx();
}

// Sub86_20 的火弹环整圈由 bullet_random 一发调用内完成；逐颗 fire 时 32 颗会烧穿
// 单任务 1024 条/帧指令预算（H 档实测 FAULT_BUDGET），拆成两个并行 emitter 各发一半。
async sub ring_part(n: int) {
    for j in 0..n {
        var sp_f: fx = 0.3fx + 2.2fx / 256 * rand(256);
        var an_f: angle = rand(65536) as angle;
        _ = fire(AMULET, 0, $self_x, $self_y, sp_f, an_f, FIREBALL_PERM, none);
    }
}

async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // Sub85 enemy_kill_all()（跳过调用者 boss）
    move_to(120, 0.0fx, 80.0fx, 2);         // Sub85 move_position_time_decelerate(120, 192, 80)，QuadOut
    wait(120);                              // Sub85 +120 ret → Sub86 攻击循环

    var rank: int = global(GVAR_RANK);
    // Sub86_20 的火弹环：!H 32 颗、!L 22 颗（E/N 不在本卡范围）
    var n_fire: int = 32;
    if rank >= RANK_LUNATIC { n_fire = 22; }
    // Sub86_748 的侧边鳞弹：!H 1 颗、!L 2 颗，速度上限 1.6（top 的是 1.2）
    var n_side: int = 1;
    if rank >= RANK_LUNATIC { n_side = 2; }

    var i0: int = 0;                        // Sub86 set_int($I0, 0)
    loop {                                  // Sub86_20，一轮：偶 12 / 奇 10 帧
        // 块时间 0：i0 % 4 == 0 时先放一圈随机火弹
        if i0 % 4 == 0 {                    // math_int_mod($I5,$I0,4); jump_neq(0, Sub86_344)
            // shoot_offset(0,0,0) + bullet_effects(-1, …)
            // bullet_random(7, 0, 32/22, 1, 2.5, 0.3, π, −π, 19)：整周、速度 [0.3, 2.5)
            var half: int = n_fire / 2;
            spawn ring_part(half);
            spawn ring_part(n_fire - half);
        }
        // Sub86_344：bullet_effects(60, …)；shoot_offset(rand[0,384)−SELF_X, 32−SELF_Y)
        // → 绝对点 y = 32、x = rand[0,384) − 192；bullet_random(5, 2, 1, 1, 1.2, 0.3, 151°, 119°, 19)
        var rx: fx = 384.0fx / 256 * rand(256) - 192.0fx;
        var sp_t: fx = 0.3fx + 0.9fx / 256 * rand(256);
        var an_t: angle = 21663bam + rand(5826) as angle;
        _ = fire(SHARD, 2, rx, 32.0fx, sp_t, an_t, SHARD_BURST, none);

        // Sub86_344 尾的 jump_neq(2, Sub86_676)：偶数轮条件不成立，落到 `+2:` 等 2 帧；
        // 奇数轮跳转命中，块时间被直接设为 2、不耗帧（§2.4），侧边鳞弹与顶上鳞弹同帧发出。
        // 故一轮：偶数轮 2+10 = 12 帧、奇数轮 0+10 = 10 帧，两轮 22 帧；火弹环每 4 轮（44 帧）一圈。
        if i0 % 2 == 0 { wait(2); }

        // Sub86_676（奇数轮，块时间 2）/ Sub86_748（偶数轮，块时间 2）：i0 偶 → y ∈ [0,192)；
        // 奇 → y ∈ [192,384)；x 恒 380 → 我方 188。
        var ry: fx = 0.0fx;
        if i0 % 2 == 0 { ry = 192.0fx / 256 * rand(256); }
        else { ry = 192.0fx + 192.0fx / 256 * rand(256); }
        // bullet_random(5, 2, 1/2, 1, 1.6, 0.3, 151°, 119°, 19)
        for k in 0..n_side {
            var sp_s: fx = 0.3fx + 1.3fx / 256 * rand(256);
            var an_s: angle = 21663bam + rand(5826) as angle;
            _ = fire(SHARD, 2, 188.0fx, ry, sp_s, an_s, SHARD_BURST, none);
        }

        i0 = i0 + 1;                        // math_inc($I0)
        wait(10);                           // +10: //12
        // jump(0, Sub86_20)
    }
}

async sub boss_main() {
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
