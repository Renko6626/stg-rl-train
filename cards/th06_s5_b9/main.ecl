// th06_s5_b9 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）终符「メイド秘技「殺人ドール」」H/L
// 原文：ecldata5.ecl.txt Sub60 → Sub61（宣言 + 移到中央）+ Sub62（攻击循环：call Sub58/Sub59 + ex_ins_call(4,1/2/0)）。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 98;      // 原文 spellcard_start(2, H=98 / L=99, "ST_ECLDATA5_SUB50_1")；本卡取 H 的 98（仅 UI/计分）
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER（32px）；§3 色表：Sub58 色号 3→6、Sub59 色号 1→2
const EPOCH: int = 20;         // 大弹改向纪元（§10.1②，脚本可写全局槽 ≥16）

// 时停（ex_ins_call(4,1)→(4,0)）：刀刃出生即 0 速挂在冻结半径，Sub62 时停结束时 pulse 放行（§10.1①）。
// 每个层速一个 xformdef，半径由 sh_dist 近似冻结时的平均飞行距离（见 report「近似」）。
xformdef PARK58_0 { wait_signal(0); set_speed(2.0fx); }
xformdef PARK58_1 { wait_signal(0); set_speed(1.6666667fx); }   // 2.0 − 1.0/3
xformdef PARK58_2 { wait_signal(0); set_speed(1.3333333fx); }   // 2.0 − 2.0/3
xformdef PARK59_0 { wait_signal(0); set_speed(2.8fx); }
xformdef PARK59_1 { wait_signal(0); set_speed(2.35fx); }        // 2.8 − 0.45
xformdef PARK59_2 { wait_signal(0); set_speed(1.9fx); }         // 2.8 − 0.90
xformdef PARK59_3 { wait_signal(0); set_speed(1.45fx); }        // 2.8 − 1.35

// §10.1② 大弹随机改向（ex_ins_call(4,2)）：刀刃挂任务轮询纪元，纪元一变按 1/4 概率重设角度。
// H/L 档远距分支 = 整周随机（EnemyEclInstr.cpp:564-648）；命中一次后退出（原作置 spriteOffset=5 不再重复）。
async sub redirect() {
    var seen: int = global(EPOCH);
    for k in 0..7 {
        var got: int = 0;
        while got == 0 {
            if global(EPOCH) != seen { seen = global(EPOCH); got = 1; }
            else { wait(1); }
        }
        if rand(4) == 0 {
            set_angle(0, rand(65536) as angle);
            return;
        }
    }
}

// Sub58（行 1489–1507）：H/L 档 I4=8 轮 bullet_circle，每轮 F0 += 45°。
// 8 轮 × 4 帧 + 收尾 21 帧 = 53 帧（jump_dec 把块时间设回 0，等待只有 4 帧/轮）。
sub blades_circle() {
    var rank: int = global(GVAR_RANK);
    var n: int = 10;                       // !H bullet_circle(8,3,10,3,…)
    if rank >= RANK_LUNATIC { n = 15; }    // !L 15
    var f0: angle = aim_player();          // 原文 set_int($F0,$PLAYER_ANGLE) 只在入口取一次
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 6);
    sh_ring(0, 1);                         // bullet_circle
    sh_aim(0, 0);
    sh_count(0, n, 1);
    sh_speed(0, 0fx, 0fx);                 // 0 速：等 0 号信号
    sh_offset(0, 0.0fx, 0.0fx);
    sh_dist(0, 152.0fx);
    sh_xform(0, PARK58_0);
    sh_task(0, redirect);                  // 层 0 作为改向候选（见 report）
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 6);
    sh_ring(1, 1);
    sh_aim(1, 0);
    sh_count(1, n, 1);
    sh_speed(1, 0fx, 0fx);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_dist(1, 127.0fx);
    sh_xform(1, PARK58_1);
    sh_reset(2);
    sh_sprite(2, ARROWHEAD, 6);
    sh_ring(2, 1);
    sh_aim(2, 0);
    sh_count(2, n, 1);
    sh_speed(2, 0fx, 0fx);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_dist(2, 102.0fx);
    sh_xform(2, PARK58_2);
    for b in 0..8 {
        sh_angle(0, f0, 0deg); sh_fire(0);
        sh_angle(1, f0, 0deg); sh_fire(1);
        sh_angle(2, f0, 0deg); sh_fire(2);
        f0 = f0 + 8192bam;                 // math_float_add 0.7853982f = 45°
        wait(4);
    }
    wait(21);                              // 收尾 +20：local 4 → 25
}

// Sub59（行 1509–1527）：H/L 档 I4=8 轮 bullet_fan，每轮 F0 −= 45°，每轮 2 帧。
// 8 轮 × 2 帧 + 收尾 21 帧 = 37 帧。
sub blades_fan() {
    var rank: int = global(GVAR_RANK);
    var n: int = 5;                        // !H bullet_fan(8,1,5,4,…)
    if rank >= RANK_LUNATIC { n = 7; }     // !L 7
    var f0: angle = aim_player();
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 2);            // Sub59 色号 1 → 我方 2（§3 32px 表）
    sh_ring(0, 0);                         // bullet_fan：以 f0 为中轴对称展开
    sh_aim(0, 0);
    sh_count(0, n, 1);
    sh_speed(0, 0fx, 0fx);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_dist(0, 84.0fx);
    sh_xform(0, PARK59_0);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 2);
    sh_ring(1, 0);
    sh_aim(1, 0);
    sh_count(1, n, 1);
    sh_speed(1, 0fx, 0fx);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_dist(1, 70.0fx);
    sh_xform(1, PARK59_1);
    sh_reset(2);
    sh_sprite(2, ARROWHEAD, 2);
    sh_ring(2, 0);
    sh_aim(2, 0);
    sh_count(2, n, 1);
    sh_speed(2, 0fx, 0fx);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_dist(2, 57.0fx);
    sh_xform(2, PARK59_2);
    sh_reset(3);
    sh_sprite(3, ARROWHEAD, 2);
    sh_ring(3, 0);
    sh_aim(3, 0);
    sh_count(3, n, 1);
    sh_speed(3, 0fx, 0fx);
    sh_offset(3, 0.0fx, 0.0fx);
    sh_dist(3, 44.0fx);
    sh_xform(3, PARK59_3);
    for b in 0..8 {
        sh_angle(0, f0, 410bam); sh_fire(0);   // a7 = 2.25° = 410bam
        sh_angle(1, f0, 410bam); sh_fire(1);
        sh_angle(2, f0, 410bam); sh_fire(2);
        sh_angle(3, f0, 410bam); sh_fire(3);
        f0 = f0 - 8192bam;                     // math_float_sub 0.7853982f = 45°
        wait(2);
    }
    wait(21);                                  // 收尾 +20：local 2 → 23
}

// Sub62 帧 0：move_rand_in_bounds(-π,π) + move_speed(2.5) + move_time_decelerate(60)。
// 边界本单元切片不含 move_bounds_set，沿用 Stage boss 常用的 (32,48)-(352,144) → (-160,48)-(160,144)。
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                 // (-π, π)
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
    move_to(t, tx, ty, 2);                           // decelerate → easing 2
}

// Sub60 → Sub61（宣言 + 移到中央）→ Sub62（无限循环；Sub62 wall 178 帧 + 两个 call 90 帧 = 268 帧/轮）。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // Sub61 enemy_kill_all()（跳过调用者自己 = boss）
    move_to(120, 0.0fx, 144.0fx, 2);        // Sub61 move_position_time_decelerate(120, 192.0, 144.0)
    wait(120);                              // Sub61 +120 ret
    set_global(EPOCH, 0);
    loop {
        blades_circle();                    // Sub62 call("Sub58")：53 帧
        blades_fan();                       // Sub62 call("Sub59")：37 帧
        // —— Sub62 local 0：时停开始（刀刃已 0 速停驻）、boss 暂不可交互 ——
        set_enemy_flag(ENEMY_NO_BODY, 1);   // enemy_flag_interactable(0)
        wander(2.5fx, 60);                  // move_rand_in_bounds / move_speed(2.5) / move_time_decelerate(60)
        wait(20);
        for k in 0..7 {                     // jump_dec(20, Sub62_224, $I4)，$I4=7
            set_global(EPOCH, global(EPOCH) + 1);   // ex_ins_call(4,2)
            wait(4);
        }
        wait(30);                           // +30：jump_dec 退出在 local 24（跳转把块时间设回 20），等 54−24=30
        pulse_signal(0);                    // ex_ins_call(4,0)：时停结束，放行全部停驻刀刃
        set_enemy_flag(ENEMY_NO_BODY, 0);   // enemy_flag_interactable(1)
        wait(60);                           // +60：local 54 → 114
        wait(40);                           // +40：local 114 → 154，jump(0, Sub62_0)
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
