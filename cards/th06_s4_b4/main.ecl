// th06_s4_b4 —— 东方红魔乡 Stage 4 boss 帕秋莉 非符 2
// 原文：ecldata4.ecl.txt Sub37（入口 +120 起主循环）+ 模式 Sub32/28/33/29/34/30/35/31 + Sub38（随机移动环弹）

const TIME_LIMIT: int = 2400;
const BALL: int = 48;      // TH06 弹型 3 BALL 中玉（16px，色号原样）

// ───────────────────────── 发射参数 ─────────────────────────
// k = 发射器槽号（模式任务用槽 1 走 ex_ins_call(12)，调度任务用槽 0 走背景自动射击）
// 背景自动射击与 ex_ins_call(12) 在原作里共用一份 bulletProps，这里两份配置逐字相同。

// call_equ 模式 sub 开头的 bullet_*：速写/环数按档 + i7 奇偶
sub cfg_mode(k: int, rank: int, i7: int) {
    sh_reset(k);
    sh_sprite(k, BALL, 2);                 // bullet_*(3, 2, …) 色 2
    sh_offset(k, 0.0fx, -12.0fx);          // Sub37 shoot_offset(0, -12, 0)
    sh_aim(k, 1);
    if i7 % 2 == 0 {
        // Sub32(E)/Sub33(N)/Sub34(H)/Sub35(L)：circle_aimed(1×2) / fan_aimed(2×2)
        if rank == RANK_HARD {
            sh_ring(k, 0);
            sh_count(k, 2, 2);
            sh_angle(k, 0deg, 1024bam);    // a7 = π/32
            sh_speed(k, 2.0fx, (1.2fx - 2.0fx) / 2);
        } else if rank >= RANK_LUNATIC {
            sh_ring(k, 0);
            sh_count(k, 2, 2);
            sh_angle(k, 0deg, 1024bam);
            sh_speed(k, 2.5fx, (1.2fx - 2.5fx) / 2);
        } else {
            sh_ring(k, 1);
            sh_count(k, 1, 2);
            sh_angle(k, 0deg, 0deg);
            sh_speed(k, 2.0fx, (1.2fx - 2.0fx) / 2);
        }
    } else {
        // Sub28(E)/Sub29(N)/Sub30(H)/Sub31(L)：circle_aimed
        if rank == RANK_NORMAL {
            sh_ring(k, 1);
            sh_count(k, 10, 1);
            sh_angle(k, 0deg, 0deg);
            sh_speed(k, 2.0fx, 0fx);
        } else if rank == RANK_HARD {
            sh_ring(k, 1);
            sh_count(k, 14, 1);
            sh_angle(k, 0deg, 0deg);
            sh_speed(k, 2.4fx, 0fx);
        } else if rank >= RANK_LUNATIC {
            sh_ring(k, 1);
            sh_count(k, 10, 2);
            sh_angle(k, 0deg, 0deg);
            sh_speed(k, 3.0fx, (1.2fx - 3.0fx) / 2);
        } else {
            sh_ring(k, 1);
            sh_count(k, 8, 1);
            sh_angle(k, 0deg, 0deg);
            sh_speed(k, 1.5fx, 0fx);
        }
    }
}

// Sub38 开头：circle_aimed(3, 6, $I0, E2/N3/H4/L5, E/N4.0 H/L5.5, 1.5)
sub cfg_sub38a(k: int, rank: int, i7: int) {
    var n: int = i7 + 10;                  // math_int_add($I0, $I7, 10)
    var layers: int = 2;
    var s1: fx = 4.0fx;
    if rank == RANK_NORMAL {
        layers = 3;
    } else if rank == RANK_HARD {
        layers = 4;
        s1 = 5.5fx;
    } else if rank >= RANK_LUNATIC {
        layers = 5;
        s1 = 5.5fx;
    }
    sh_reset(k);
    sh_sprite(k, BALL, 6);
    sh_offset(k, 0.0fx, -12.0fx);
    sh_aim(k, 1);
    sh_ring(k, 1);
    sh_count(k, n, layers);
    sh_angle(k, 0deg, 0deg);
    sh_speed(k, s1, (1.5fx - s1) / layers);
}

// Sub38 末尾：circle_aimed(3, 6, E6/N12/H16/L20, 1, 1.0/1.5, 1.0)
sub cfg_sub38c(k: int, rank: int) {
    var n: int = 6;
    var s1: fx = 1.0fx;
    if rank == RANK_NORMAL {
        n = 12;
        s1 = 1.5fx;
    } else if rank == RANK_HARD {
        n = 16;
        s1 = 1.5fx;
    } else if rank >= RANK_LUNATIC {
        n = 20;
        s1 = 1.5fx;
    }
    sh_reset(k);
    sh_sprite(k, BALL, 6);
    sh_offset(k, 0.0fx, -12.0fx);
    sh_aim(k, 1);
    sh_ring(k, 1);
    sh_count(k, n, 1);
    sh_angle(k, 0deg, 0deg);
    sh_speed(k, s1, 0fx);
}

// ex_ins_call(12)：每条活激光，在 敌位置 + 64·方向 处用当前 bulletProps 开一次火
sub ex_fire(lz: int) {
    if lz_alive(lz) == 1 {
        var a: angle = lz_angle(lz);
        sh_offset(1, 64.0fx * cos(a), 64.0fx * sin(a));
        sh_fire(1);
        sh_offset(1, 0.0fx, -12.0fx);      // 发完恢复原出弹口
    }
}

// call_equ 模式 sub：建 4 根旋转激光、I0==tr2 再建 4 根，逐帧转 + 周期性 ex_ins
sub mode_fire(rank: int, i7: int) {
    var warn: int = 30;
    var active: int = 70;                  // 0-3 号 T1（E/N 70）
    var active2: int = 90;                 // 4-7 号 T1（E/N 90，原作第二组单独给）
    var fade: int = 20;
    var w: fx = 12.0fx;                    // 原作宽 24.0 → 12.0（四档全相同）
    var rot: angle = 63bam;                // 0.0060415245 rad
    var tr1: int = 120;                    // 0-3 号激光转动帧数
    var tr2: int = 60;                     // 4-7 号激光建立帧
    var dur: int = 180;
    var mod: int = 60;
    if rank == RANK_NORMAL {
        rot = 71bam;                       // 0.006829549
        mod = 50;
    } else if rank == RANK_HARD {
        rot = 85bam;                       // 0.008195459
        warn = 25;
        active = 58;
        active2 = 75;
        fade = 16;
        tr1 = 100;
        tr2 = 50;
        dur = 150;
        mod = 40;
    } else if rank >= RANK_LUNATIC {
        rot = 92bam;                       // 0.008780849
        warn = 23;
        active = 54;
        active2 = 70;
        fade = 15;
        tr1 = 93;
        tr2 = 46;
        dur = 140;
        mod = 40;
    }
    cfg_mode(1, rank, i7);
    // laser_create(sprite=1, color=2|6, a=±π/4/±3π/4, sp=0, st=64, en=500, sl=500, w, T0, T1, T2, …)
    // 原点 = 敌位置 + 当时生效的 shoot_offset(0, -12)；求值 start = max(64, 500-500) = 64
    var lz0: int = laser(2, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, w, warn, active, fade);
    lz_start(lz0, 64.0fx);
    var lz1: int = laser(2, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, w, warn, active, fade);
    lz_start(lz1, 64.0fx);
    var lz2: int = laser(2, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, w, warn, active, fade);
    lz_start(lz2, 64.0fx);
    var lz3: int = laser(2, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, w, warn, active, fade);
    lz_start(lz3, 64.0fx);
    var lz4: int = -1;
    var lz5: int = -1;
    var lz6: int = -1;
    var lz7: int = -1;
    // Sub32/33/34/35（i7 偶）0-3 负转、4-7 正转；Sub28/29/30/31（i7 奇）相反
    var d0: angle = 0bam - rot;
    var d1: angle = rot;
    if i7 % 2 != 0 {
        d0 = rot;
        d1 = 0bam - rot;
    }
    var i0: int = 0;
    while i0 < dur {
        if i0 < tr1 {
            if lz_alive(lz0) == 1 { lz_rotate(lz0, d0); }
            if lz_alive(lz1) == 1 { lz_rotate(lz1, d0); }
            if lz_alive(lz2) == 1 { lz_rotate(lz2, d0); }
            if lz_alive(lz3) == 1 { lz_rotate(lz3, d0); }
        }
        if i0 == tr2 {
            lz4 = laser(2, $self_x, $self_y - 12.0fx, 8192bam, 500.0fx, w, warn, active2, fade);
            lz_start(lz4, 64.0fx);
            lz5 = laser(2, $self_x, $self_y - 12.0fx, 24576bam, 500.0fx, w, warn, active2, fade);
            lz_start(lz5, 64.0fx);
            lz6 = laser(2, $self_x, $self_y - 12.0fx, -24576bam, 500.0fx, w, warn, active2, fade);
            lz_start(lz6, 64.0fx);
            lz7 = laser(2, $self_x, $self_y - 12.0fx, -8192bam, 500.0fx, w, warn, active2, fade);
            lz_start(lz7, 64.0fx);
        }
        if i0 >= tr2 {
            if lz_alive(lz4) == 1 { lz_rotate(lz4, d1); }
            if lz_alive(lz5) == 1 { lz_rotate(lz5, d1); }
            if lz_alive(lz6) == 1 { lz_rotate(lz6, d1); }
            if lz_alive(lz7) == 1 { lz_rotate(lz7, d1); }
        }
        if i7 != 0 && i0 % mod == 0 {
            ex_fire(lz0);
            ex_fire(lz1);
            ex_fire(lz2);
            ex_fire(lz3);
            ex_fire(lz4);
            ex_fire(lz5);
            ex_fire(lz6);
            ex_fire(lz7);
        }
        i0 = i0 + 1;
        wait(1);
    }
}

// ───────────────────── 背景自动射击（shoot_interval）─────────────────────
// TH06 的 shoot_interval 是敌身后台计时器，跨 sub 持续；这里用一个调度任务复现：
//   Sub38 帧 0（开头）interval=E20/N15/H15/L10 → 每 interval 帧用当时的 bulletProps 开一次火；
//   帧 180 改 E70/N60/H/L60，同时换末段低环 props（cfg_sub38c）。
async sub autoshoot(rank: int) {
    var D: int = 180;
    var ivA: int = 20;
    var ivB: int = 70;
    if rank == RANK_NORMAL {
        ivA = 15;
        ivB = 60;
    } else if rank == RANK_HARD {
        D = 150;
        ivA = 15;
        ivB = 60;
    } else if rank >= RANK_LUNATIC {
        D = 140;
        ivA = 10;
        ivB = 60;
    }
    var P: int = D + 240;                  // 一个模式周期
    var t: int = 0;
    var i7: int = 0;
    var iv: int = 0;
    var nf: int = 999999;
    var F: int = 0;
    var G: int = 0;
    wait(180);                             // 原 time 0 → 120（前奏）→ 180（首个模式）
    t = 180;
    loop {
        F = 180 + P * i7;                  // 模式 sub 起始帧
        cfg_mode(0, rank, i7);
        // 边界帧 t = F+D 也先判开火（原作那一发在 Sub38 前 1 帧、用模式 props；我方统一晚 1 帧落在边界上）
        loop {
            if iv > 0 && t >= nf {
                sh_fire(0);
                nf = nf + iv;
            } else if t >= F + D {
                break;
            } else {
                wait(1);
                t = t + 1;
            }
        }
        G = F + D;                         // Sub38 起始帧
        cfg_sub38a(0, rank, i7);
        iv = ivA;                          // Sub38 帧 0：shoot_interval(ivA)
        nf = G + iv;
        // 原作最后一发 ivA 在 Sub38 帧 179；+1 帧对齐后落在 G+180 那帧（§4.3 写法 A）
        loop {
            if t >= nf {
                sh_fire(0);
                nf = nf + iv;
            }
            if t >= G + 180 {
                break;
            }
            wait(1);
            t = t + 1;
        }
        cfg_sub38c(0, rank);               // Sub38 帧 180：换末段 props
        iv = ivB;                          // 同帧 shoot_interval(ivB)
        nf = G + 180 + iv;
        // 边界帧 t = G+240 先判开火再换模式 props：N/H/L 的 ivB=60 首发原作在 Sub38 帧 239（模式前 1 帧），
        // 用的是末段 props；我方晚 1 帧落在 G+240，必须在 cfg_mode 之前打出。E 的 ivB=70 首发在模式内，不受影响。
        loop {
            if t >= nf {
                sh_fire(0);
                nf = nf + iv;
            } else if t >= G + 240 {
                break;
            } else {
                wait(1);
                t = t + 1;
            }
        }
        i7 = i7 + 1;
    }
}

// §7.3 boss 随机游走：move_rand_in_bounds(-π,π) + move_speed + move_time_decelerate
// Sub27 设 move_bounds_set(32,48,352,144) → 我方 (-160,48)-(160,144)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
    var v: int = rand(65536);
    if v >= 32768 {
        v = v - 65536;
    }
    if $self_x < bx0 + 96.0fx {
        if v > 16384 {
            v = 32768 - v;
        } else if v < -16384 {
            v = -32768 - v;
        }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 {
            v = 32768 - v;
        } else if v > -16384 && v <= 0 {
            v = -32768 - v;
        }
    }
    if $self_y < by0 + 48.0fx && v < 0 {
        v = 0 - v;
    }
    if $self_y > by1 - 48.0fx && v > 0 {
        v = 0 - v;
    }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 {
        tx = bx0;
    } else if tx > bx1 {
        tx = bx1;
    }
    if ty < by0 {
        ty = by0;
    } else if ty > by1 {
        ty = by1;
    }
    move_to(t, tx, ty, 2);
}

// Sub38：90 帧随机减速滑行 + 90 帧减速移动到 (0,128)
sub wander_phase() {
    wander(2.5fx, 90);
    wait(90);
    move_to(90, 0.0fx, 128.0fx, 2);
    wait(90);
}

// Sub37 +120 起的主循环：等 60 → 模式 sub（180/150/140 帧）→ Sub38（180 帧）→ 等 60
async sub pattern() {
    var rank: int = global(GVAR_RANK);
    spawn autoshoot(rank);
    wait(120);                             // Sub37 的 +120 前奏（原 time 0 → 120），兼作开场缓冲
    wait(60);                              // 到 +60（原 time 180）
    var i7: int = 0;
    loop {
        mode_fire(rank, i7);
        wander_phase();
        i7 = i7 + 1;
        wait(60);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                    // Sub98 enemy_set_hitbox(48,56,32) → min/3 = 16
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // Sub98 move_position(192,128) → (0,128)；本段从 +120 的中段接上，位置取该值
    _ = spawn_enemy(0.0fx, 128.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
