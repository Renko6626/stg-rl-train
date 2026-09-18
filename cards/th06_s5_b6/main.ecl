// th06_s5_b6 —— 东方红魔乡 Stage 5 boss 十六夜咲夜 符卡 幻世「ザ・ワールド」
// 原文：ecldata5.ecl.txt Sub55 → Sub56（宣言 + 移到中央）+ Sub57（时停 + 刀弧 + 大弹随机改向），时限 1800。
const TIME_LIMIT: int = 1800;
const AMULET: int = 112;      // TH06 弹型 7 FIREBALL（32px 弹，色 1→2）
const ARROWHEAD: int = 16;    // TH06 弹型 8 DAGGER（32px 弹，色 3→6）
const EPOCH: int = 20;        // 脚本可写全局槽：ex_ins_4(param 2) 的改向纪元计数

// Sub57 时停窗口内发的刀：速度 0 停驻，等 0 号信号统一放行到 2.0。
xformdef PARKED {
    wait_signal(0);
    set_speed(2.0fx);
}

// ---------------------------------------------------------------------------
// ex_ins_call(4, 2)：扫全场「大玉级」弹，每颗 1/4 概率重设角度（H/L 上限 52 颗/次）。
// 我方无「遍历全场弹」的内建，按 mapping §10.1② 给每颗大弹挂任务轮询纪元全局槽。
// 大弹还兼职时停：出生 +50 帧刹停、+170 帧恢复本层速率。四个任务对应四层速率。
// H/L 分支的距离 >128px 一律取随机整周角（近距分支需要弹自身坐标，我方无 getter，见 report）。
// ---------------------------------------------------------------------------
async sub bigball_a() {
    var seen: int = global(EPOCH);
    var red: int = 0;
    var now: int = 0;
    wait(50);
    set_speed(0, 0fx);
    for k in 0..120 {
        now = global(EPOCH);
        if now != seen {
            seen = now;
            if red == 0 && rand(4) == 0 {
                set_angle(0, rand(65536) as angle);
                red = 1;
            }
        }
        wait(1);
    }
    set_speed(0, 2.2fx);
    loop { wait(1); }
}

async sub bigball_b() {
    var seen: int = global(EPOCH);
    var red: int = 0;
    var now: int = 0;
    wait(50);
    set_speed(0, 0fx);
    for k in 0..120 {
        now = global(EPOCH);
        if now != seen {
            seen = now;
            if red == 0 && rand(4) == 0 {
                set_angle(0, rand(65536) as angle);
                red = 1;
            }
        }
        wait(1);
    }
    set_speed(0, 1.95fx);
    loop { wait(1); }
}

async sub bigball_c() {
    var seen: int = global(EPOCH);
    var red: int = 0;
    var now: int = 0;
    wait(50);
    set_speed(0, 0fx);
    for k in 0..120 {
        now = global(EPOCH);
        if now != seen {
            seen = now;
            if red == 0 && rand(4) == 0 {
                set_angle(0, rand(65536) as angle);
                red = 1;
            }
        }
        wait(1);
    }
    set_speed(0, 1.7fx);
    loop { wait(1); }
}

async sub bigball_d() {
    var seen: int = global(EPOCH);
    var red: int = 0;
    var now: int = 0;
    wait(50);
    set_speed(0, 0fx);
    for k in 0..120 {
        now = global(EPOCH);
        if now != seen {
            seen = now;
            if red == 0 && rand(4) == 0 {
                set_angle(0, rand(65536) as angle);
                red = 1;
            }
        }
        wait(1);
    }
    set_speed(0, 1.45fx);
    loop { wait(1); }
}

// Sub57 +20：bullet_circle(7, 1, n, 4, 2.2f, 1.2f, 0, 0, 512)。四层速度 2.2/1.95/1.7/1.45，
// 拆成四个发射器槽（每层一个）才能给每层配对的停驻/改向任务。
sub fire_ring(n: int) {
    sh_reset(0);
    sh_sprite(0, AMULET, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_speed(0, 2.2fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_task(0, bigball_a);
    sh_fire(0);

    sh_reset(1);
    sh_sprite(1, AMULET, 2);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, n, 1);
    sh_speed(1, 1.95fx, 0fx);
    sh_angle(1, 0deg, 0deg);
    sh_task(1, bigball_b);
    sh_fire(1);

    sh_reset(2);
    sh_sprite(2, AMULET, 2);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, n, 1);
    sh_speed(2, 1.7fx, 0fx);
    sh_angle(2, 0deg, 0deg);
    sh_task(2, bigball_c);
    sh_fire(2);

    sh_reset(3);
    sh_sprite(3, AMULET, 2);
    sh_aim(3, 0);
    sh_ring(3, 1);
    sh_count(3, n, 1);
    sh_speed(3, 1.45fx, 0fx);
    sh_angle(3, 0deg, 0deg);
    sh_task(3, bigball_d);
    sh_fire(3);
}

// ---------------------------------------------------------------------------
// ex_ins_repeat(5) = Stage5Func5：时停期间每 9 帧沿一段 90° 弧摆 9 个出弹点，
// 每点用 FAN_AIMED 发 3 颗 DAGGER（±π/6，速度 2.0，时停中速度 0 + PARKED）。
// 弧心/半径照 decomp EnemyEclInstr.cpp:655-733 的向量算法逐帧重算：
//   scale = 0.5 - p*0.5/9；seed = ±256（p 偶 +，奇 -）
//   bp = (player-enemy)*scale + seed*u ；base = atan2(player-enemy) + (偶?π:0)
//   pos_i = enemy + bp + 256*unit(base - π/4 + (i+1)*π/18)，i=0..8
// 其中 u 是敌→自机单位向量，π/4=45deg、π/18=10deg。
// ---------------------------------------------------------------------------
async sub lay_knives() {
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_angle(0, 0deg, 5461bam);       // π/6
    sh_speed(0, 0fx, 0fx);
    sh_xform(0, PARKED);

    var th: angle = 0deg;
    var dst: fx = 0fx;
    var sc: fx = 0fx;
    var sgn: fx = 0fx;
    var rad: fx = 0fx;
    var bx: fx = 0fx;
    var by: fx = 0fx;
    var base: angle = 0deg;
    var ang: angle = 0deg;
    var ox: fx = 0fx;
    var oy: fx = 0fx;
    var even: int = 1;
    for p in 0..7 {
        th = aim_player();
        dst = dist($player_x - $self_x, $player_y - $self_y);
        sc = 0.5fx - p * 0.5fx / 9;
        sgn = 1.0fx;
        if even == 0 { sgn = -1.0fx; }
        rad = dst * sc + sgn * 256.0fx;
        bx = rad * cos(th);
        by = rad * sin(th);
        base = th;
        if even == 1 { base = th + 180deg; }
        ang = base - 45deg;
        for i in 0..9 {
            ang = ang + 10deg;            // base - π/4 + (i+1)·π/18，π/18 = 10°
            ox = bx + 256.0fx * cos(ang);
            oy = by + 256.0fx * sin(ang);
            sh_offset(0, ox, oy);
            sh_fire(0);
        }
        if p != 6 { wait(9); }
        even = 1 - even;
    }
}

// §7.3 boss 随机游走：move_rand_in_bounds(-π,π) + move_speed + move_time_decelerate。
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
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
    var rank: int = global(GVAR_RANK);
    set_global(EPOCH, 0);
    kill_all_enemies(KILL_SILENT);            // Sub56 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);          // Sub56 move_position_time_decelerate(120, 192, 112)
    wait(120);                                 // ret → Sub57 起算
    loop {
        // Sub57_0：set_int($I4,32) + 32×4 帧的 effect_particle 循环（丢表现、留时序）→ t=128
        for k in 0..32 { wait(4); }
        wait(20);                              // +20 //24 → t=148（循环后从 t=4 再等 20 帧）
        fire_ring(12);                         // bullet_circle 12 颗 × 4 层（E/N/H）
        if rank >= RANK_LUNATIC { fire_ring(14); }   // !L 再补一环 14 颗 × 4 层
        wait(50);                              // +50 //74 → t=198
        // ex_ins_call(4,1)：时停开始
        set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
        spawn lay_knives();                    // ex_ins_repeat(5)
        wander(2.5fx, 60, -160.0fx, 48.0fx, 160.0fx, 132.0fx);
        wait(60);                              // +60 //134 → t=258；ex_ins_repeat(-1)
        for e in 0..6 {                        // ex_ins_call(4,2) ×6：t=258,263,…,283
            set_global(EPOCH, global(EPOCH) + 1);
            wait(5);
        }
        wait(30);                              // +30 //169 → t=318
        // ex_ins_call(4,0)：时停结束，全场放行
        pulse_signal(0);
        set_enemy_flag(ENEMY_NO_BODY, 0);      // enemy_flag_interactable(1)
        wait(60);                              // +60 //229 → t=378
        wait(40);                              // +40 //269 → t=418；jump(0, Sub57_0)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    var rank: int = global(GVAR_RANK);
    var sid: int = 94;                         // H
    if rank >= RANK_LUNATIC { sid = 95; }      // L
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 112.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
