// th06_s5_b9 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）终符「メイド秘技「殺人ドール」」H/L
// 原文：ecldata5.ecl.txt Sub60 → Sub61（宣言 + 移到中央）+ Sub62（攻击循环：call Sub58/Sub59 + ex_ins_call(4,1/2/0)）。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 98;      // 原文 spellcard_start(2, H=98 / L=99, "ST_ECLDATA5_SUB50_1")；本卡取 H 的 98（仅 UI/计分）
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER（32px）；§3 色表：Sub58 色号 3→6、Sub59 色号 1→2
const EPOCH: int = 20;         // 大弹改向纪元（§10.1②，脚本可写全局槽 ≥16）

// 【时停窗口压平】原作 Sub62 里 `ex_ins_call(4,1)`→`(4,0)` 那 78 帧 `isTimeStopped=1`：
// 自机与全场弹整帧早退（Player.cpp:158 / BulletManager.cpp:668），对玩家纯空转；窗口内不摆新弹，
// 只有 boss 滑行 + 7 次随机改向 ⇒ 按 mapping §10.1 压成 1 帧。
// 这一刀顺带**销掉本卡最大的近似**：旧版把刀刃「出生即 0 速挂在平均冻结半径」（sh_dist 152/127/…），
// 因为原作里刀是先从 boss 飞出去、被时停就地冻住的。窗口不占时间之后，刀按各层真速正常飞，
// 半径由飞行时间自然决定，不再需要 sh_dist 与停驻变换。一轮 268 → 191 帧，符卡时限也不烧那 78 帧。

// §10.1② 大弹随机改向（ex_ins_call(4,2)）：原作一个窗口调 7 次、每次扫全场 32px 弹、每颗 1/4、
// 每次最多 52 颗（H/L）、每颗最多改一次 ⇒ 模拟得总改向数 H≈318/400、L≈364/584；H/L 档远距分支 = 整周随机
// （EnemyEclInstr.cpp:564-648）。任务池 256 装不下 584 颗，故按 (轮,层) 交错挑约 220 颗挂任务、
// 被挂的一律改向（p=1），其余不改。压平后抽完即退。
async sub redirect() {
    var seen: int = global(EPOCH);
    while global(EPOCH) == seen { wait(1); }
    set_angle(0, rand(65536) as angle);
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
    sh_speed(0, 2.0fx, 0fx);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 6);
    sh_ring(1, 1);
    sh_aim(1, 0);
    sh_count(1, n, 1);
    sh_speed(1, 1.6666667fx, 0fx);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_reset(2);
    sh_sprite(2, ARROWHEAD, 6);
    sh_ring(2, 1);
    sh_aim(2, 0);
    sh_count(2, n, 1);
    sh_speed(2, 1.3333333fx, 0fx);          // bullet_circle 三层速 2.0 − j/3
    sh_offset(2, 0.0fx, 0.0fx);
    var md: int = 2;                       // 挂改向任务的 (轮+层) 交错周期：H 1/2（120 颗）
    if rank >= RANK_LUNATIC { md = 3; }    // L 1/3（120 颗）
    for b in 0..8 {
        for j in 0..3 {
            if (b + j) % md == 0 { sh_task(j, redirect); } else { sh_task(j, none); }
        }
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
    sh_speed(0, 2.8fx, 0fx);          // bullet_fan 四层速 2.8 − 0.45j
    sh_offset(0, 0.0fx, 0.0fx);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 2);
    sh_ring(1, 0);
    sh_aim(1, 0);
    sh_count(1, n, 1);
    sh_speed(1, 2.35fx, 0fx);          // bullet_fan 四层速 2.8 − 0.45j
    sh_offset(1, 0.0fx, 0.0fx);
    sh_reset(2);
    sh_sprite(2, ARROWHEAD, 2);
    sh_ring(2, 0);
    sh_aim(2, 0);
    sh_count(2, n, 1);
    sh_speed(2, 1.9fx, 0fx);          // bullet_fan 四层速 2.8 − 0.45j
    sh_offset(2, 0.0fx, 0.0fx);
    sh_reset(3);
    sh_sprite(3, ARROWHEAD, 2);
    sh_ring(3, 0);
    sh_aim(3, 0);
    sh_count(3, n, 1);
    sh_speed(3, 1.45fx, 0fx);          // bullet_fan 四层速 2.8 − 0.45j
    sh_offset(3, 0.0fx, 0.0fx);
    var fd: int = 8;                       // 改向任务：(4·轮+层) % fd < ft；H 20 发射 ×5 = 100 颗
    var ft: int = 5;
    if rank >= RANK_LUNATIC { fd = 16; ft = 7; }   // L 14 发射 ×7 = 98 颗
    for b in 0..8 {
        for j in 0..4 {
            if (4 * b + j) % fd < ft { sh_task(j, redirect); } else { sh_task(j, none); }
        }
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
    move_to(0, tx, ty, 0);                           // 窗口压平：直接瞬移到滑行终点
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
        // ══ 时停窗口（原作 78 帧）压平成这 1 帧 ══
        set_enemy_flag(ENEMY_NO_BODY, 1);   // enemy_flag_interactable(0)
        wander(2.5fx, 60);                  // 原作窗口里滑行 60 帧 ⇒ 自机冻结期间等价于瞬移
        set_global(EPOCH, global(EPOCH) + 1);   // ex_ins_call(4,2) ×7 → 一次抽签
        wait(1);                            // 让各刀任务当帧抽完
        set_enemy_flag(ENEMY_NO_BODY, 0);   // enemy_flag_interactable(1)
        // ══ 窗口结束 ══
        wait(60);                           // +60：local 54 → 114
        wait(40);                           // +40：local 114 → 154，jump(0, Sub62_0)（压平后 191 帧一轮）
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
