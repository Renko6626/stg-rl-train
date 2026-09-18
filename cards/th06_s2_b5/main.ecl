// th06_s2_b5 —— 东方红魔乡 Stage 2 boss 琪露诺 符卡 凍符「パーフェクトフリーズ」
// 原文 ecldata2.ecl.txt Sub36 → Sub37（宣言 + 移到中央 + bullet_rank_influence(-0.3,1.0,-1,5,0,0)）
//   + Sub38（随机环 → ex_ins_0 冻结；扇形循环 → ex_ins_0 随机加速），时限 2400。
// 逐段对照见 report.md。

const TIME_LIMIT: int = 2400;
const SPELL_ID: int = 13;      // 原作 !E 的 id（N/H/L 为 14/15/16；本卡单 id，仅 UI/计分）
const OUTLINE: int = 32;       // TH06 弹型 1 RING_BALL → OUTLINE=32
const BALL: int = 48;          // TH06 弹型 3 BALL → BALL=48

// ex_ins_0 param0：全场弹变色 + 速度清零（等 0 号脉冲）
// ex_ins_0 param1：每颗弹以 0.01 px/帧² 加速 220 帧（等 1 号脉冲；沿各自当前朝向近似原作随机方向）
xformdef ICE_FREEZE {
    wait_signal(0);
    set_color(15);
    set_speed(0fx);
    wait_signal(1);
    @220 set_accel(0.01fx);
    stop_fx();
}
// 冻结窗口内出生的扇形弹（错过 0 号脉冲，只等散开脉冲）
xformdef ICE_SCATTER {
    wait_signal(1);
    @220 set_accel(0.01fx);
    stop_fx();
}

// Sub38 的 boss 游走：move_rand_in_bounds(-π,π); move_speed(2.0); move_time_decelerate(120)
// 边界取 Sub21 move_bounds_set(32,48,352,134) → 我方 (-160,48)-(160,134)
sub wander() {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 134.0fx;
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
    var d: fx = 120.0fx;                         // spd 2.0 * t 120 / 2
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(120, tx, ty, 2);
}

// 扇形：bullet_fan_aimed(3, 6, c1, 3, s1, s2, 0.0f, step, 4)（rank 16 下 c1 +2、s1 +0.35、s2 +0.175）
sub fan(c1: int, s1: fx, step: angle) {
    sh_xform(0, ICE_SCATTER);
    sh_count(0, c1, 3);
    sh_speed(0, s1, (2.175fx - s1) / 3);
    sh_angle(0, 0deg, step);
    sh_fire(0);
}

async sub pattern() {
    // ---- Sub37：宣言 + move_position_time_decelerate(120, 192, 96) ----
    move_to(120, 0.0fx, 96.0fx, 2);
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_offset(0, 0.0fx, 8.0fx);                    // Sub37 shoot_offset(0, 8, 0)
    wait(120);

    // ---- Sub38 ----
    var rank: int = global(GVAR_RANK);
    var base: int = 4;                              // !E
    if rank == RANK_NORMAL { base = 7; }            // !N
    else if rank == RANK_HARD { base = 10; }        // !H
    else if rank >= RANK_LUNATIC { base = 16; }     // !L
    var i7: int = 0;
    loop {
        // Sub38_20
        wander();
        // Sub38_92：6 轮 × 5 次 bullet_random（count1 = $I7 + base + 2）
        for r1 in 0..6 {
            var i0: int = i7 + base;
            var c1: int = i0 + 2;
            for b1 in 0..5 {
                wait(5);
                for i1 in 0..c1 {
                    var sp1: fx = 1.175fx + (4.35fx - 1.175fx) / 256 * rand(256);
                    var an1: angle = rand(65536) as angle;
                    _ = fire(OUTLINE, 6, $self_x, $self_y + 8.0fx, sp1, an1, ICE_FREEZE, none);
                }
            }
        }
        wait(60);
        pulse_signal(0);                            // ex_ins_call(0,0)：全场冻住 + 变白
        wait(60);
        // 第二轮游走 + 扇形循环（Sub38_604，6 轮 × 30 帧）
        wander();
        for r2 in 0..6 {
            if i7 < 3 {
                wait(10);
                fan(5, 4.35fx, 4096bam);
                wait(20);
            } else if i7 < 6 {
                wait(20);
                fan(7, 4.35fx, 4096bam);
                wait(10);
            } else {
                wait(30);
                fan(7, 5.35fx, 2048bam);
            }
        }
        wait(120);
        pulse_signal(1);                            // ex_ins_call(0,1)：每颗 0.01 加速（近似）
        i7 = i7 + 1;
        wait(180);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                             // Sub21 enemy_set_hitbox(48,56,32) → min/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
