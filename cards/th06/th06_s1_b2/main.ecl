// th06_s1_b2 —— 东方红魔乡 Stage 1 boss（露米娅）符卡 夜符「ナイトバード」
// 原文：ecldata1.ecl.txt Sub26 → Sub27（宣言 + 移到中央 + timer 1500）→ Sub28（四段自机狙摆动扇），时限 1500。
const TIME_LIMIT: int = 1500;
const SPELL_ID: int = 2;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// move_bounds_set(32.0f, 48.0f, 352.0f, 144.0f) → 我方 (-160, 48)-(160, 144)
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

// bullet_fan_aimed：TH06 速度钳位（s1≠0 时 ≥0.3，s2 恒 ≥0.3）+ 层速公式（mapping §4.2）
// 本单元 count1 恒 1（扇只有中轴一颗），count2 = 层数，层间同角、速度按 (s2−s1)/layers 递减。
sub fan_aimed(color: int, n: int, layers: int, s1: fx, s2: fx, a1: angle, spread: angle) {
    var t1: fx = s1;
    var t2: fx = s2;
    if t1 != 0fx && t1 < 0.3fx { t1 = 0.3fx; }
    if t2 < 0.3fx { t2 = 0.3fx; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, color);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub13 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, t1, (t2 - t1) / layers);
    sh_angle(0, a1, spread);
    sh_fire(0);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    // count2：E/N 1 层；H 2 层；L 3 层。s2：E/N 0（被钳到 0.3 但不用），H/L 0.8。
    var layers: int = 1;
    var sp2: fx = 0fx;
    // F1 增量：四段各自按难度取。
    var dA: angle = 1489bam;   // Sub28_100 !N/H/L（!E 2048）
    var dB: angle = 1489bam;   // Sub28_436 !N/H/L（!E 2048）
    var dC: angle = 2048bam;   // Sub28_884 !N/H（!E 2731，!L 1638）
    var dD: angle = 2048bam;   // Sub28_1220 !N/H（!E 2731，!L 1638）
    if rank == RANK_EASY {
        dA = 2048bam; dB = 2048bam; dC = 2731bam; dD = 2731bam;
    } else if rank == RANK_HARD {
        layers = 2; sp2 = 0.8fx;
    } else if rank >= RANK_LUNATIC {
        layers = 3; sp2 = 0.8fx; dC = 1638bam; dD = 1638bam;
    }

    var f0: fx = 0fx;
    var f1: angle = 0deg;

    // Sub27：宣言 + boss_timer 已由外壳表达；移到中央 + +120 ret（我方出生即在 (0,96)）
    move_to(120, 0.0fx, 96.0fx, 2);
    wait(120);

    // Sub28：每轮 = 四段 16 连（每 2 帧一发）+ 60/40 帧停顿 + 随机游走，共 356 帧
    loop {
        for pass in 0..2 {                 // jump_dec(0, Sub28_40, $I5)
            // Sub28_100：色 5，F1 自 -5958bam 每发 +dA
            f0 = 1.0fx;
            f1 = -5958bam;
            for k1 in 0..16 {
                wait(2);
                fan_aimed(5, 1, layers, f0, sp2, f1, 683bam);
                f0 = f0 + 0.2fx;
                f1 = f1 + dA;
            }
            // Sub28_436：色 7，F1 自 +5958bam 每发 -dB
            f0 = 1.0fx;
            f1 = 5958bam;
            for k2 in 0..16 {
                wait(2);
                fan_aimed(7, 1, layers, f0, sp2, f1, 683bam);
                f0 = f0 + 0.2fx;
                f1 = f1 - dB;
            }
            // Sub28_884：色 6，F1 自 -8192bam 每发 +dC
            f0 = 1.0fx;
            f1 = -8192bam;
            for k3 in 0..16 {
                wait(2);
                fan_aimed(6, 1, layers, f0, sp2, f1, 683bam);
                f0 = f0 + 0.2fx;
                f1 = f1 + dC;
            }
            // Sub28_1220：色 8，F1 自 +8192bam 每发 -dD
            f0 = 1.0fx;
            f1 = 8192bam;
            for k4 in 0..16 {
                wait(2);
                fan_aimed(8, 1, layers, f0, sp2, f1, 683bam);
                f0 = f0 + 0.2fx;
                f1 = f1 - dD;
            }
        }
        wait(60);                          // +68（anm_set_main 丢弃）
        wait(40);                          // +108
        wander(2.0fx, 120);                // move_rand_in_bounds + move_speed(2.0) + move_time_decelerate(120)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                    // Sub13 enemy_set_hitbox(48, 56, 32) → min(48,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
