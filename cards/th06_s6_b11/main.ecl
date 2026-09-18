// th06_s6_b11 —— 东方红魔乡 Stage 6 boss（蕾米莉亚）符卡 紅符「スカーレットシュート」
// 原文：ecldata6.ecl.txt Sub52（入口）→ Sub53（宣言 + 移到中央 + timer 1800）→ Sub54（攻击循环，周期 484 帧）+ Sub50（单发自机狙）。E/N 版。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 112;      // 原文 spellcard_start(2, id)：E=-1、N=112（H/L 亦为 -1）；本卡取 N 的 112（仅 UI/计分，引擎不登记）
const LASERHEAD: int = 176;     // TH06 弹型 9 BUBBLE（半边长 16，引擎判定偏小）

// 调用方 Sub28 的 move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160,48)-(160,120)。
// 对应 Sub54 的 move_rand_in_bounds(-π, π); move_speed(2.5f); move_time_decelerate(...)。
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
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

// Sub50：bullet_fan(9, 0, 1, 1, 6.2f, 1.2f, %F2, 0.0f, 2) = 单颗 BUBBLE、速度 6.2、朝当时的 F2，从敌中心（shoot_offset 全 0）发出。
// Sub50 内对 $F0/$F1 的减法/加法在 TH06 call 按值语义下不回传、且无任何指令读取，是死代码，未转写。
sub shot(a: angle) {
    _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, a, none, none);
}

// 周期 484 帧，逐字对照见 report.md。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);           // Sub53 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);         // Sub53 move_position_time_decelerate(120, 192, 112)（x 减 192）
    wait(120);                               // Sub53 +120 ret 之后才进 Sub54
    loop {
        wait(64);                            // Sub54_36 的 16 次 effect_particle 循环（4 帧 × 16，无弹）
        // //4 块：5 发自机狙（0 / ±45° / ±90°）
        shot(aim_player()); shot(aim_player() + 8192bam); shot(aim_player() - 8192bam);
        shot(aim_player() + 16384bam); shot(aim_player() - 16384bam);
        wait(60);                            // +60 //64
        // //64 块：同样 5 发，发完起一次 60 帧减速随机游走
        shot(aim_player()); shot(aim_player() + 8192bam); shot(aim_player() - 8192bam);
        shot(aim_player() + 16384bam); shot(aim_player() - 16384bam);
        wander(2.5fx, 60);                   // move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(60)
        wait(90);                            // +90 //154（游走 60 帧内跑完）
        // //154 块：3 发自机狙（0 / ±4.5°）
        shot(aim_player()); shot(aim_player() + 819bam); shot(aim_player() - 819bam);
        wait(120);                           // +120 //274
        // //274 块：5 发（0 / ±45° / ±90°）
        shot(aim_player()); shot(aim_player() + 8192bam); shot(aim_player() - 8192bam);
        shot(aim_player() + 16384bam); shot(aim_player() - 16384bam);
        wait(30);                            // +30 //304
        // //304 块：5 发（0 / ±60° / ±120°），之后 set_int($I4, 24)、math_inc($I7) 与本段弹型无关
        shot(aim_player()); shot(aim_player() + 10923bam); shot(aim_player() - 10923bam);
        shot(aim_player() + 21845bam); shot(aim_player() - 21845bam);
        wait(120);                           // +120 //424 jump(0, Sub54_0)：回到周期开头
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);        // Sub53 enemy_flag_interactable(1)
    set_hitbox(16.0fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
