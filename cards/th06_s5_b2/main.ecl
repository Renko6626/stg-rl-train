// th06_s5_b2 —— 东方红魔乡 Stage 5 boss（十六夜咲夜）符卡「幻在「クロックコープス」」
// 原文：ecldata5.ecl.txt Sub46（行 1179–1184）→ Sub47（1186–1203，宣言 + 移到中央）→ Sub48（1205–1255，攻击循环），
//       时限 1800；E id88 / N id89。逐段对照见 report.md。
// 结构：Sub48 每 400 帧一轮 —— 先随机札 (E32/N128)、再时停 (ex_ins_4 参数 1)、
//       时停中每 9 帧沿弧线摆 9 把刀、结束时全部同时启动 (ex_ins_4 参数 0)，再回跳。
//
// 【时停窗口压平】原作那 152 帧 `isTimeStopped=1`：自机与全场弹整帧早退（Player.cpp:158 /
// BulletManager.cpp:668），对玩家纯空转 ⇒ 等价于瞬间摆弹。按 mapping §10.1 压成 1 帧：
// boss 按滑行曲线的 10 个采样点定位摆刀、刀直接以 2.0 真速出生；札不再需要冻结。
// 符卡时限因此不烧这 152 帧，与原作 bossTimer 不 tick（EnemyManager.cpp:735）一致。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 88;          // E=88；N 为 89（见 report）
const RICE: int = 64;              // TH06 弹型 2 RICE（16px）
const ARROWHEAD: int = 16;         // TH06 弹型 8 DAGGER（32px），色号 3 → 6

// 初始随机札（bullet_random type2 color6 min1.2 max4 整周）：由弹任务自己取随机角/速。
// 压平后窗口不占时间，札一路直飞，抽完就退（不占任务槽）。
async sub rice_rand() {
    set_angle(0, rand(65536) as angle);
    set_speed(0, 1.2fx + 2.8fx / 256 * rand(256));
}

// Stage5Func5（EnemyEclInstr.cpp:655）单波：以玩家方向为基准，在半径 256 的弧上摆 9 把刀。
// p 为波号（var2/9）；偶数波 m0 反向，奇数波 m0 正向且 angle1 从 -45° 每颗 +10°。
// `aimMode = FAN_AIMED` ⇒ 弹角 = **出弹点处的自机狙 + angle1**（旧版漏了自机狙那一项）。
// 压平后「敌位置」取滑行曲线上的采样点 (sx, sy)，boss 实体已瞬移到终点。
async sub place_wave(sx: fx, sy: fx, p: int) {
    var pdx: fx = $player_x - sx;
    var pdy: fx = $player_y - sy;
    var mag: fx = dist(pdx, pdy);
    if mag < 0.001fx { mag = 0.001fx; }
    var ux: fx = pdx / mag;
    var uy: fx = pdy / mag;
    var base_u: angle = atan2(pdy, pdx);
    var even: int = 0;
    if (p / 2) * 2 == p { even = 1; }
    var seed: fx = 0.5fx - p * 0.5fx / 9;
    var bx: fx = sx + pdx * seed;
    var by: fx = sy + pdy * seed;
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
        var fang: angle = atan2($player_y - py, $player_x - px);   // FAN_AIMED 的自机狙
        if even == 0 { fang = fang + ((-8192 + i * 1820) as angle); }   // + angle1 = -π/4 + i·π/18
        _ = fire(ARROWHEAD, 6, px, py, 2.0fx, fang, none, none);
        pang = pang + 1820bam;               // π/18
    }
}

async sub pattern() {
    kill_all_enemies(KILL_SILENT);           // Sub47 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);         // Sub47 move_position_time_decelerate(120,192,112)
    wait(120);                               // Sub47 +120 ret → Sub48 开始
    var rank: int = global(GVAR_RANK);
    var v: int = 0;
    var d: fx = 0fx;
    var ex: fx = 0fx;
    var ey: fx = 0fx;
    var tx: fx = 0fx;
    var ty: fx = 0fx;
    var t: fx = 0fx;
    var u: fx = 0fx;
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
            sh_task(0, rice_rand);
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
            sh_task(1, rice_rand);
            sh_fire(1);
        }
        wait(50);                            // 块 44 → 块 94：ex_ins_call(4,1) 时停开始

        // ══ 时停窗口（原作 152 帧）压平成这 1 帧 ══
        set_enemy_flag(ENEMY_NO_BODY, 1);    // enemy_flag_interactable(0)
        // §7.3 move_rand_in_bounds(-π,π) + move_speed(2.5) + move_time_decelerate(90) 的终点；
        // 压平后不真的滑，只用它的曲线定位 10 波的出弹原点。边界 Sub24 (32,48,352,132) → (-160,48)-(160,132)
        v = rand(65536);
        if v >= 32768 { v = v - 65536; }
        if $self_x < -64.0fx {
            if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
        }
        if $self_x > 64.0fx {
            if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
        }
        if $self_y < 96.0fx && v < 0 { v = 0 - v; }
        if $self_y > 84.0fx && v > 0 { v = 0 - v; }
        d = 2.5fx * 90 / 2;
        ex = $self_x;
        ey = $self_y;
        tx = ex + cos(v as angle) * d;
        ty = ey + sin(v as angle) * d;
        if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
        if ty < 48.0fx { ty = 48.0fx; } else if ty > 132.0fx { ty = 132.0fx; }
        for w in 0..10 {                     // 原作每 9 帧一波、共 10 波，滑行 90 帧
            t = w * 9.0fx / 90;              // move_to(…, easing 2 = QuadOut)：e = 1 − (1−t)²
            u = 1.0fx - t;
            spawn place_wave(ex + (tx - ex) * (1.0fx - u * u), ey + (ty - ey) * (1.0fx - u * u), w);
        }
        move_to(0, tx, ty, 0);               // boss 瞬移到滑行终点
        wait(1);                             // 让 10 个波次任务当帧落弹
        set_enemy_flag(ENEMY_NO_BODY, 0);    // enemy_flag_interactable(1)
        // ══ 窗口结束 ══

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
