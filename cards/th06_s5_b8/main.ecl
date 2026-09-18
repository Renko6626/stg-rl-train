// th06_s5_b8 —— 东方红魔乡 Stage 5 boss 符卡 メイド秘技「操りドール」（十六夜咲夜）
// 原文：ecldata5 Sub60 → Sub61（宣言 + 移到中央）+ Sub62（时停循环）+ Sub58/Sub59（两组自机狙扇），时限 1800。
// 逐段对照 / 近似见 report.md。
//
// 时停（ex_ins_call(4,1) 开 / (4,0) 关）用 mapping §10.1 的写法：弹自带 freeze xform，
// 停下 wait_signal(0)、放走 wait_signal(1)；中间的 ex_ins_call(4,2) 大弹随机改向挂弹任务 + 全局纪元。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 96;      // 原文 E 的 spellcard_start id（N 为 97）；纯脚本词汇，引擎不登记
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER（32px）
const EPOCH: int = 20;         // 脚本可写全局槽，用作 ex_ins_call(4,2) 的触发纪元

// 32px 弹色号查表：原文色号 3 → 我方 6（Sub58）、1 → 2（Sub59）（mapping §3）。
// 弹型节奏：飞到 wall 75 被时停冻住（bounce 的弹再等反弹），wall 153 放走、恢复原速。
// ⚠️ @N 是后置延迟；这里全 wait=0，靠 wait_signal 阻塞。
xformdef F58_E_15  { bounce_arm(7, 1); wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.5fx); }
xformdef F58_E_125 { bounce_arm(7, 1); wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.25fx); }
xformdef F58_N_20  { bounce_arm(7, 1); wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(2.0fx); }
xformdef F58_N_15  { bounce_arm(7, 1); wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.5fx); }
xformdef F59_E_18  { wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.8fx); }
xformdef F59_E_14  { wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.4fx); }
xformdef F59_N_28  { wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(2.8fx); }
xformdef F59_N_22  { wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(2.2fx); }
xformdef F59_N_16  { wait_signal(0); set_speed(0.0fx); wait_signal(1); set_speed(1.6fx); }

// ex_ins_call(4,2)：大弹（此符卡全为 32px DAGGER）1/4 概率改向，每颗最多改一次（改过色后原作不再选）。
// decomp：E/N 档新角 = 随机 ∈ [π/4, π) = [8192, 32768) bam；离自机 ≤128px 的分支近似为同一分布。
async sub redirect() {
    var seen: int = global(EPOCH);
    var done: int = 0;
    loop {
        var now: int = global(EPOCH);
        if now != seen {
            seen = now;
            if done == 0 {
                if rand(4) == 0 {
                    set_angle(0, (8192 + rand(24576)) as angle);
                    done = 1;
                }
            }
        }
        wait(1);
    }
}

// 原文 Sub58（E/N）：4 轮自机狙扇，wall 0/5/10/15，中心角在 Sub58 开始时取一次、E/N 不转。全程 wall 40。
sub burst58_e() {
    var a: angle = aim_player();
    for k in 0..4 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 3, 1);
        sh_speed(0, 1.5fx, 0fx);
        sh_angle(0, a, 1638bam);
        sh_xform(0, F58_E_15);
        sh_task(0, redirect);
        sh_fire(0);

        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 6);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, 3, 1);
        sh_speed(1, 1.25fx, 0fx);
        sh_angle(1, a, 1638bam);
        sh_xform(1, F58_E_125);
        sh_task(1, redirect);
        sh_fire(1);
        if k < 3 { wait(5); }
    }
    wait(25);          // 末轮 jump_dec 失败后块停在 5，再到 //25 ret 需 20 帧 → 全程 40
}

sub burst58_n() {
    var a: angle = aim_player();
    for k in 0..4 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 4, 1);
        sh_speed(0, 2.0fx, 0fx);
        sh_angle(0, a, 1638bam);
        sh_xform(0, F58_N_20);
        sh_task(0, redirect);
        sh_fire(0);

        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 6);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, 4, 1);
        sh_speed(1, 1.5fx, 0fx);
        sh_angle(1, a, 1638bam);
        sh_xform(1, F58_N_15);
        sh_task(1, redirect);
        sh_fire(1);
        if k < 3 { wait(5); }
    }
    wait(25);          // 同 burst58_e：全程 wall 40
}

// 原文 Sub59（E/N）：5 轮自机狙扇，相对 Sub59 入口 wall 0/3/6/9/12（Sub62 全程 wall 40/43/46/49/52），中心角在 Sub59 开始时取一次。
sub burst59_e() {
    var a: angle = aim_player();
    for j in 0..5 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 3, 1);
        sh_speed(0, 1.8fx, 0fx);
        sh_angle(0, a, 819bam);
        sh_xform(0, F59_E_18);
        sh_task(0, redirect);
        sh_fire(0);

        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 2);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, 3, 1);
        sh_speed(1, 1.4fx, 0fx);
        sh_angle(1, a, 819bam);
        sh_xform(1, F59_E_14);
        sh_task(1, redirect);
        sh_fire(1);
        if j < 4 { wait(3); }
    }
    wait(23);          // 末轮 jump_dec 失败后块停在 3，再到 //23 ret 需 20 帧 → 全程 35
}

sub burst59_n() {
    var a: angle = aim_player();
    for j in 0..5 {
        sh_reset(0);
        sh_sprite(0, ARROWHEAD, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 4, 1);
        sh_speed(0, 2.8fx, 0fx);
        sh_angle(0, a, 819bam);
        sh_xform(0, F59_N_28);
        sh_task(0, redirect);
        sh_fire(0);

        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 2);
        sh_aim(1, 0);
        sh_ring(1, 0);
        sh_count(1, 4, 1);
        sh_speed(1, 2.2fx, 0fx);
        sh_angle(1, a, 819bam);
        sh_xform(1, F59_N_22);
        sh_task(1, redirect);
        sh_fire(1);

        sh_reset(2);
        sh_sprite(2, ARROWHEAD, 2);
        sh_aim(2, 0);
        sh_ring(2, 0);
        sh_count(2, 4, 1);
        sh_speed(2, 1.6fx, 0fx);
        sh_angle(2, a, 819bam);
        sh_xform(2, F59_N_16);
        sh_task(2, redirect);
        sh_fire(2);
        if j < 4 { wait(3); }
    }
    wait(23);          // 同 burst59_e：全程 wall 35
}

// 发弹任务：一轮 253 帧 = Sub58(0–40) + Sub59(40–75) + 摆弹/时停(75–253)。
async sub fire_e() {
    loop {
        burst58_e();      // 0 -> 40
        burst59_e();      // 40 -> 75
        wait(178);        // 75 -> 253
    }
}

async sub fire_n() {
    loop {
        burst58_n();
        burst59_n();
        wait(178);
    }
}

// 原文 Sub62 的其余部分：时停开关 + 随机游走 + 7 次大弹改向。
// 原文 wall 253 一轮 = call Sub58(40) + call Sub59(35) + 后续 178（jump_dec 回跳使 wall 与块时间分离：
// 循环末 jump_dec 失败后块时间 24、+30→54→+60→114→+40→154，而 wall 已到 178）。
async sub driver() {
    loop {
        wait(75);                              // Sub58/Sub59 两段 call 占 75 wall 帧（40 + 35）
        pulse_signal(0);                       // ex_ins_call(4,1)：时停开始
        set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
        wander(2.5fx, 60);                     // move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(60)
        wait(20);                              // 75 -> 95
        for r in 0..7 {
            set_global(EPOCH, global(EPOCH) + 1);   // ex_ins_call(4,2)
            wait(4);                           // 95/99/…/119，之后到 123
        }
        wait(30);                              // 123 -> 153
        pulse_signal(1);                       // ex_ins_call(4,0)：时停结束，全场弹恢复
        set_enemy_flag(ENEMY_NO_BODY, 0);      // enemy_flag_interactable(1)
        wait(60);                              // 153 -> 213
        wait(40);                              // 213 -> 253
    }
}

// §7.3 boss 随机游走。原文 unit 未给 move_bounds（在前一段 sub 里），按 §7.3 惯例取 (-160,48)-(160,144)。
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

async sub pattern() {
    // 原文 Sub61：move_position_time_decelerate(120, 192.0f, 144.0f, 0.0f)
    move_to(120, 0.0fx, 144.0fx, 2);
    wait(120);
    var rank: int = global(GVAR_RANK);
    spawn driver();
    if rank == RANK_NORMAL { spawn fire_n(); }
    else { spawn fire_e(); }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    kill_all_enemies(KILL_SILENT);        // Sub61 enemy_kill_all()
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
