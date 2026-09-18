// th06_s5_b5 —— 东方红魔乡 Stage 5 boss 符卡 幻象「ルナクロック」（原文 ecldata5 Sub52/53/54，E/N）
// 原文：Sub53 宣言 + 移到中央，Sub54 循环：bullet_circle(2,6,32,4,3.0,1.2) → ex_ins_call(4,1) 时停
//       + ex_ins_repeat(5)（Stage5Func5 每 9 帧沿自机方向铺 9 颗弧形弹）→ ex_ins_call(4,2) → 时停解除。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 92;      // 原作 !E 的 id（N 为 93；单 id 常量取 E）
const RICE: int = 64;          // TH06 弹型 2 RICE
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER
const EPOCH: int = 20;         // 脚本可写全局槽：ex_ins_call(4,2) 的纪元计数
const CNT: int = 21;           // 每个纪元已改向颗数（上限 14）

// —— 时停：窗口内/窗口前发射的弹速度归零停驻，关时停那一帧 pulse_signal(0) 全场放行 ——
// 大玉环：出生后按原速直飞 50 帧（T=24→T=74），再冻结 120 帧，放行时恢复本层原速。
// 4 层速度各一个 xformdef（3.0 / 2.55 / 2.1 / 1.65），拆成两个 sub 免得 locals 超限。
xformdef RING_A { @50 set_speed(3.0fx); set_speed(0fx); wait_signal(0); set_speed(3.0fx); }
xformdef RING_B { @50 set_speed(2.55fx); set_speed(0fx); wait_signal(0); set_speed(2.55fx); }
xformdef RING_C { @50 set_speed(2.1fx); set_speed(0fx); wait_signal(0); set_speed(2.1fx); }
xformdef RING_D { @50 set_speed(1.65fx); set_speed(0fx); wait_signal(0); set_speed(1.65fx); }
// Stage5Func5 的弧形弹：时停窗口里出生，直接停驻，放行时恢复 2.0 原速（角度逐颗自带）。
xformdef PARK { wait_signal(0); set_speed(2.0fx); }

// 旋转常量：cos/sin(π/18)、cos/sin(π/4)
const C18: fx = 0.98480775fx;
const S18: fx = 0.17364818fx;
const C45: fx = 0.70710678fx;
const S45: fx = 0.70710678fx;

// —— Sub53 的移到中央（move_position_time_decelerate(120,192,112)）用的是 §7.3 的 boss 随机游走 ——
// 边界 move_bounds_set(32,48,352,132) → 我方 (-160,48)-(160,132)
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
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
    move_to(t, tx, ty, 2);
}

// bullet_circle(2, 6, 32, 4, 3.0f, 1.2f, 0, 0, 512) → 32 向 × 4 层；每层单发射器槽 + 本层 xform。
sub ring_fire_a() {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 32, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, RING_A);
    sh_fire(0);
    sh_reset(1);
    sh_sprite(1, RICE, 6);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 32, 1);
    sh_speed(1, 2.55fx, 0fx);
    sh_angle(1, 0deg, 0deg);
    sh_xform(1, RING_B);
    sh_fire(1);
}

sub ring_fire_b() {
    sh_reset(2);
    sh_sprite(2, RICE, 6);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, 32, 1);
    sh_speed(2, 2.1fx, 0fx);
    sh_angle(2, 0deg, 0deg);
    sh_xform(2, RING_C);
    sh_fire(2);
    sh_reset(3);
    sh_sprite(3, RICE, 6);
    sh_offset(3, 0.0fx, 0.0fx);
    sh_aim(3, 0);
    sh_ring(3, 1);
    sh_count(3, 32, 1);
    sh_speed(3, 1.65fx, 0fx);
    sh_angle(3, 0deg, 0deg);
    sh_xform(3, RING_D);
    sh_fire(3);
}

// ex_ins_call(4,2)：对全场 heightPx ≥ 30 的弹按 1/4 概率改向（EnemyEclInstr.cpp:552-648）。
// 本卡够格的只有 Stage5Func5 的 32px DAGGER；RICE(16px) 不够格。E/N 每次上限 14 颗、
// 已改向者跳过；>128px 取 [π/4, π) 随机角，≤128px 取「自机→弹方向 + π/2 + 随机全周」。
// 每颗弧弹挂本任务，boss 每次 ex_ins_call(4,2) 抬一次 EPOCH 纪元 = 全体掷一次骰。
async sub big_random() {
    var seen: int = global(EPOCH);
    var changed: int = 0;
    loop {
        var now: int = global(EPOCH);
        if now != seen {
            seen = now;
            if changed == 0 {
                if rand(4) == 0 {
                    var cnt: int = global(CNT);
                    if cnt < 14 {
                        set_global(CNT, cnt + 1);
                        changed = 1;
                        var dx: fx = $self_x - $player_x;
                        var dy: fx = $self_y - $player_y;
                        if dist(dx, dy) > 128.0fx {
                            set_angle(0, 16384bam + (rand(49152) as angle));   // [π/4, π)
                        } else {
                            set_angle(0, atan2(dy, dx) + 16384bam + (rand(65536) as angle));
                        }
                    }
                }
            }
        }
        wait(1);
    }
}

// ex_ins_repeat(5) = Stage5Func5（EnemyEclInstr.cpp:655）：pp = 第几次铺弹（var2/9）。
// 沿「敌→自机」方向取单位向量 u，弧心 C = E + (P−E)·(9−pp)/18 ± u·256，
// 9 颗弹沿半径 256 的弧均分（每次转 −π/18）；pp 为奇数时（E/N）每颗弹角度沿 −π/4…递增，偶数时全为 0。
sub stage5_fire(pp: int, odd: int) {
    var dx: fx = $player_x - $self_x;
    var dy: fx = $player_y - $self_y;
    var dir: angle = atan2(dy, dx);
    var ux: fx = cos(dir);
    var uy: fx = sin(dir);
    var seed: fx = 256.0fx;
    if odd != 0 { seed = -256.0fx; }
    var n9: int = 9 - pp;
    var ms: fx = (n9 as fx) / 18.0fx;
    var offx: fx = dx * ms + ux * seed;
    var offy: fx = dy * ms + uy * seed;
    var mix: fx = 0fx - ux * seed;
    var miy: fx = 0fx - uy * seed;
    var tx: fx = mix * C45 + miy * S45;
    var ty: fx = 0fx - mix * S45 + miy * C45;
    mix = tx;
    miy = ty;
    var ba: angle = -16384bam;                        // −π/4
    var bx: fx = 0fx;
    var by: fx = 0fx;
    var bl: angle = 0deg;
    for i9 in 0..9 {
        tx = mix * C18 - miy * S18;                   // 转 −π/18
        ty = mix * S18 + miy * C18;
        mix = tx;
        miy = ty;
        bx = $self_x + offx + mix;
        by = $self_y + offy + miy;
        bl = 0deg;
        if odd != 0 { bl = ba; }
        _ = fire(ARROWHEAD, 6, bx, by, 0fx, bl, PARK, big_random);
        ba = ba + 1820bam;                            // π/18 ≈ 1820 bam
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var odd: int = 0;
    move_to(120, 0.0fx, 112.0fx, 2);                  // Sub53 move_position_time_decelerate(120,192,112)
    wait(120);                                        //          +120 ret
    loop {
        // Sub54: effect 循环 32×4=128 帧，再 +20 到 T=24（bullet_circle）
        wait(148);
        if rank == RANK_NORMAL { ring_fire_a(); ring_fire_b(); }   // !N bullet_circle
        wait(50);                                     // T=74：ex_ins_call(4,1) 时停开始
        set_enemy_flag(ENEMY_NO_BODY, 1);              // enemy_flag_interactable(0)
        wander(2.5fx, 60, -160.0fx, 48.0fx, 160.0fx, 132.0fx);     // move_rand_in_bounds+move_speed+decelerate(60)
        odd = 0;
        for k5 in 0..7 {                              // Stage5Func5：var2 = 0,9,…,54 共 7 次
            stage5_fire(k5, odd);
            if k5 < 6 { wait(9); }
            odd = 1 - odd;
        }
        wait(6);                                      // 卡帧 381：第 1 次 ex_ins_call(4,2)
        for k6 in 0..6 {
            set_global(CNT, 0);                       // 每次上限 14 颗
            set_global(EPOCH, global(EPOCH) + 1);     // 纪元 +1 → 全体弧弹各掷 1/4
            if k6 < 5 { wait(5); }                    // 6 次，间隔 5 帧（卡帧 381/386/…/406）
        }
        wait(35);                                     // T=169（卡帧 441）：ex_ins_call(4,0) 时停结束
        pulse_signal(0);                              // 全场停驻弹同帧放行
        set_enemy_flag(ENEMY_NO_BODY, 0);              // enemy_flag_interactable(1)
        wait(60);                                     // T=229
        wait(40);                                     // T=269 → jump(0, Sub54_0)
    }
}

async sub boss_main() {
    set_hitbox(18.67fx);   // 段外继承：boss 初始化 Sub23 (56,56,32) → §6.1b
    set_invuln(65535);
    set_global(EPOCH, 0);
    set_global(CNT, 0);
    kill_all_enemies(KILL_SILENT);                    // Sub53 enemy_kill_all()
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
