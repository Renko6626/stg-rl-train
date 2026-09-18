// th06_s6_b12 —— 东方红魔乡 Stage 6 boss（十六夜咲夜）符卡 紅符「スカーレットマイスタ」
// 原文：ecldata6.ecl.txt Sub55（入口）→ Sub56（宣言 + 移到中央 + timer 1800）→ Sub57（攻击循环，212 帧块 × 周期 368）+ Sub51（单发自机狙）
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 113;      // Sub56 的 H 档 id（ranks 下界 = Hard）
const LASERHEAD: int = 176;     // TH06 弹型 9 BUBBLE（半边长 16）
const SPIRAL_STEP: angle = 4096bam;  // 22.5° = 0.3926991f

// Sub17 的 move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160,48)-(160,120)。
// 对应 Sub57 的 move_rand_in_bounds(-π, π); move_speed(2.5f); move_time_decelerate(90)。
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

// Sub57：一个周期 368 帧。每发 = Sub51 的 bullet_fan(9,0,1,1,6.2f,1.2f,%F2,0,2)：
// 单颗 BUBBLE 以 6.2 速度、朝当时的 F2（自机方向）射出，从敌中心（shoot_offset 全 0）发出。
// Sub51 内部对 $F0/$F1 的减法/加法在 TH06 call 按值语义下不回传，是死代码，未转写。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // Sub56 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);        // Sub56 move_position_time_decelerate(120, 192, 112)
    wait(120);                              // Sub56 +120 ret
    var f2: angle = 0deg;
    loop {
        wait(64);                           // Sub57_36 的 16 次 effect_particle 循环（4 帧 × 16，无弹）
        // Sub57 +4..+28：5 发自机狙，间隔 6 帧，第 5 发同时起一次随机游走（90 帧减速）
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none); wait(6);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none); wait(6);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none); wait(6);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none); wait(6);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none);
        wander(2.5fx, 90); wait(6);
        // Sub57_476：17 连发，每 3 帧一发，自机方向起每发 +22.5°
        f2 = aim_player();
        for k1 in 0..17 {
            _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none);
            f2 = f2 + SPIRAL_STEP;
            wait(3);
        }
        // Sub57 +80..：等 80 帧后 2 发自机狙，第 2 发起随机游走
        wait(80);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none); wait(6);
        f2 = aim_player(); _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none);
        wander(2.5fx, 90); wait(6);
        // Sub57_792：17 连发，每 3 帧一发，自机方向起每发 −22.5°
        f2 = aim_player();
        for k2 in 0..17 {
            _ = fire(LASERHEAD, 0, $self_x, $self_y, 6.2fx, f2, none, none);
            f2 = f2 - SPIRAL_STEP;
            wait(3);
        }
        wait(80);                           // Sub57 +80 jump(0, Sub57_0)：回到周期开头
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 0);       // Sub56 enemy_flag_interactable(1)
    set_hitbox(18.67fx);                    // Sub17 enemy_set_hitbox(56, 56, 32) → min/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
