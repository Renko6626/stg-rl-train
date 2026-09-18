// th06_s5_b2 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）符卡「幻在「クロックコープス」」
// 原文：ecldata5.ecl.txt Sub46（行 1179–1184）→ Sub47（1186–1203，宣言 + 移到中央）→ Sub48（1205–1255，攻击循环），
//       时限 1800；E id88 / N id89。逐段对照见 report.md。
// 结构：Sub48 每 400 帧一轮 —— 先随机札 (E32/N128)、再时停 (ex_ins_4 参数 1)、
//       时停中每 9 帧沿弧线摆 9 把刀、结束时全部同时启动 (ex_ins_4 参数 0)，再回跳。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 88;          // E=88；N 为 89（见 report）
const RICE: int = 64;              // TH06 弹型 2 RICE（16px）
const ARROWHEAD: int = 16;         // TH06 弹型 8 DAGGER（32px），色号 3 → 6

// 时停期间发出的弹：速度 0 停在落位，等 0 号信号统一启动（mapping §10.1）
xformdef PARKED {
    wait_signal(0);
    set_speed(2.0fx);
}

// 初始随机札（bullet_random type2 color6 min1.2 max4 整周）：由弹任务自己取随机角/速，
// 飞到第 70 帧（N 50 帧）时停冻结，时停结束（+152 帧）按原速恢复。
async sub rice_freeze_e() {
    var v: fx = 1.2fx + 2.8fx / 256 * rand(256);
    set_angle(0, rand(65536) as angle);
    set_speed(0, v);
    wait(69);
    set_speed(0, 0fx);
    wait(152);
    set_speed(0, v);
}

async sub rice_freeze_n() {
    var v: fx = 1.2fx + 2.8fx / 256 * rand(256);
    set_angle(0, rand(65536) as angle);
    set_speed(0, v);
    wait(49);
    set_speed(0, 0fx);
    wait(152);
    set_speed(0, v);
}

// move_rand_in_bounds(-π,π); move_speed(spd); move_time_decelerate(t)（mapping §7.3/§7.1）
// 场地边界 Sub24 move_bounds_set(32,48,352,132) → 我方 (-160,48)-(160,132)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 132.0fx;
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

// Stage5Func5（EnemyEclInstr.cpp:655）单波：以玩家方向为基准，在半径 256 的弧上摆 9 把刀。
// p 为波号（var2/9）；偶数波 m0 反向、飞行角全 0°，奇数波 m0 正向、飞行角 -45°..+35°。
sub place_wave(p: int) {
    var pdx: fx = $player_x - $self_x;
    var pdy: fx = $player_y - $self_y;
    var mag: fx = dist(pdx, pdy);
    if mag < 0.001fx { mag = 0.001fx; }
    var ux: fx = pdx / mag;
    var uy: fx = pdy / mag;
    var base_u: angle = atan2(pdy, pdx);
    var even: int = 0;
    if (p / 2) * 2 == p { even = 1; }
    var seed: fx = 0.5fx - p * 0.5fx / 9;
    var bx: fx = $self_x + pdx * seed;
    var by: fx = $self_y + pdy * seed;
    var a0: angle = base_u;
    if even != 0 {
        a0 = base_u + 32768bam;
        bx = bx + ux * 256.0fx;
        by = by + uy * 256.0fx;
    } else {
        bx = bx - ux * 256.0fx;
        by = by - uy * 256.0fx;
    }
    var pang: angle = a0 - 6372bam;          // a0 - 7π/36
    for i in 0..9 {
        var px: fx = bx + cos(pang) * 256.0fx;
        var py: fx = by + sin(pang) * 256.0fx;
        var fang: angle = 0deg;
        if even == 0 { fang = (-8192 + i * 1820) as angle; }   // -π/4 + i·π/18
        _ = fire(ARROWHEAD, 6, px, py, 0fx, fang, PARKED, none);
        pang = pang + 1820bam;               // π/18
    }
}

async sub pattern() {
    kill_all_enemies(KILL_SILENT);           // Sub47 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);         // Sub47 move_position_time_decelerate(120,192,112)
    wait(120);                               // Sub47 +120 ret → Sub48 开始
    var rank: int = global(GVAR_RANK);
    loop {
        // Sub48 的粒子循环（32×4 帧，纯表现）已删，只保留墙钟偏移：Sub48 起 148 帧处发初始札
        wait(148);                           // 块 0 → 块 24（本波 E 随机札）
        if rank != RANK_NORMAL {
            // !E bullet_random(2,6,32,1,4.0,1.2,π,-π,512)：逐颗挂任务取随机角/速
            sh_reset(0);
            sh_sprite(0, RICE, 6);
            sh_count(0, 32, 1);
            sh_speed(0, 0fx, 0fx);
            sh_angle(0, 0deg, 0deg);
            sh_task(0, rice_freeze_e);
            sh_fire(0);
        }
        wait(20);                            // 块 24 → 块 44
        if rank == RANK_NORMAL {
            // !N bullet_random(2,6,128,1,4.0,1.2,π,-π,512)
            sh_reset(1);
            sh_sprite(1, RICE, 6);
            sh_count(1, 128, 1);
            sh_speed(1, 0fx, 0fx);
            sh_angle(1, 0deg, 0deg);
            sh_task(1, rice_freeze_n);
            sh_fire(1);
        }
        wait(50);                            // 块 44 → 块 94：时停开始
        set_enemy_flag(ENEMY_NO_BODY, 1);    // enemy_flag_interactable(0)
        wander(2.5fx, 90);                   // 时停期间边摆弹边游走
        for w in 0..10 {                     // 每 9 帧一波，共 10 波（块 94..175）
            place_wave(w);
            wait(9);
        }
        wait(62);                            // 块 184 的粒子循环 + 到块 218（墙钟 308 → 370）
        pulse_signal(0);                     // ex_ins_call(4,0)：时停结束，全场同时启动
        set_enemy_flag(ENEMY_NO_BODY, 0);    // enemy_flag_interactable(1)
        wait(30);                            // 块 218 → 块 248 → jump(0, Sub48_0)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                     // Sub23 enemy_set_hitbox(56,56,32) → 56/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 112.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
