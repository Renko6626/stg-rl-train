// th06_s4_b10 —— 东方红魔乡 Stage 4 boss 符卡 火符「アグニレイディアンス」
// 原文：ecldata4.ecl.txt Sub48 → Sub49（宣言 + 移到中央）+ Sub50（攻击循环），时限 1800。
// 自机 shot2 的 H/L 分支（spell_key ST_ECLDATA4_SUB44_0），H/L 两档。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 42;       // 原作 H=42 / L=43，取 H 的卡号
const AMULET: int = 112;        // TH06 弹型 7 FIREBALL（32px 弹）
const LASERHEAD: int = 176;     // TH06 弹型 9 BUBBLE

// bullet_effects(128, -1, -1, -1, 0.0f, ±0.024543693f, -1.0f, -1.0f) + flags 32(0x20)
// 前 128 帧每帧 angle += ±256 BAM，到点停。spawn 当帧就设上（set_accel 的 wait=0）。
xformdef SPIN_R { set_accel(0fx); @128 set_ang_vel(256bam); stop_fx(); }
xformdef SPIN_L { set_accel(0fx); @128 set_ang_vel(-256bam); stop_fx(); }

// §7.3 boss 随机游走。边界取自 Sub26/Sub27 的 move_bounds_set(32,48,352,144)
// → 我方 (-160,48)-(160,144)。
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

async sub pattern() {
    // Sub49 开头：清杂兵
    kill_all_enemies(KILL_SILENT);
    // Sub49：move_position_time_decelerate(120, 192.0f, 80.0f, 0.0f) + 到 +120 ret
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);

    // Sub50：$I7=0（Sub48 设过），每轮 $I0 = $I7/5 + 7
    var rank: int = global(GVAR_RANK);
    var i7: int = 0;
    var i0: int = 7;
    var s1: fx = 1.5fx;         // !H bullet_circle speed1
    var s2: fx = 0.5fx;         // !H bullet_circle speed2
    var nrand: int = 2;         // !H bullet_random count1
    var shi: fx = 3.0fx;        // !H bullet_random speed1
    if rank >= RANK_LUNATIC { s1 = 2.0fx; s2 = 1.0fx; nrand = 6; shi = 4.0fx; }

    // 火弹环（自机不瞄、整周均分、两层）：$I0 颗 × 2 层，层间错开 7.5°=1365bam
    sh_reset(0);
    sh_sprite(0, AMULET, 0);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_speed(0, s1, (s2 - s1) / 2);

    loop {
        i0 = i7 / 5 + 7;
        sh_count(0, i0, 2);
        for k1 in 0..8 {                        // Sub50_68 循环体 8 次、每次隔 8 帧
            var a1: angle = rand(65536) as angle;
            sh_angle(0, a1, 1365bam);           // +7.5° 层偏
            sh_xform(0, SPIN_R);
            sh_fire(0);
            var a2: angle = rand(65536) as angle;
            sh_angle(0, a2, 1365bam);
            sh_xform(0, SPIN_L);
            sh_fire(0);
            for k2 in 0..nrand {                // bullet_random(9, 0, nrand, 1, shi, 0.7, ±π, 0)
                var ran: angle = rand(65536) as angle;
                var rsp: fx = 0.7fx + (shi - 0.7fx) / 256 * rand(256);
                _ = fire(LASERHEAD, 0, $self_x, $self_y, rsp, ran, none, none);
            }
            wait(8);
        }
        wait(120);                              // 循环体 8×8=64 帧后块时间为 8，move 块在 //128
        wander(1.5fx, 90);                      // move_rand_in_bounds + move_speed(1.5) + move_time_decelerate(90)
        wait(10);
        i7 = i7 + 1;
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                         // enemy_set_hitbox(48,56,32)：min/3 = 16
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
