// th06_s4_b7 —— 东方红魔乡 Stage 4 boss（帕秋莉）符卡 火＆土符「ラーヴァクロムレク」
// 原文：ecldata4.ecl.txt Sub39 → Sub81 → Sub82（宣言 + 移到中央）+ Sub83（攻击循环），时限 2400。
// 自机固定灵梦 A：ex_ins_call(3,0) 置 $I1=0 → call_equ 走 Sub81 分支，其余四个分支（Sub84–95）不转写。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 2400;
const SPELL_ID_E: int = 65;   // ST_ECLDATA4_SUB55_0 的 E/N/H/L 卡号
const SPELL_ID_N: int = 66;
const SPELL_ID_H: int = 67;
const SPELL_ID_L: int = 68;
const AMULET: int = 112;      // TH06 弹型 7 FIREBALL（32px，色 0 → 0）
const OUTLINE: int = 32;      // TH06 弹型 1 RING_BALL（16px，色号原样）
const EPOCH: int = 20;        // 脚本可写全局槽，存本波的随机转向角

// Sub83 后段 flags 67(0x43) = 0x40 | 0x2 | 0x1。
// decomp BulletManager.cpp:710-770：0x1 分支先写 velocity，但紧跟其后的 `if (exFlags & 0x40)`
// 不是 else-if，同帧再 sincosmul 覆盖 velocity ⇒ 0x1 的出生冲刺被 0x40 完全抹掉（实测 decomp 语义）。
// 0x40：i0=130 帧内速度自当前值线性缓到 0，周期末 angle += f0、speed = f1 = 1.4。
// f0 是每波运行期随机角，xformdef 参数须编译期常量 ⇒ 减速走 xformdef，转向交给每颗弹的私有任务，
// 转向角经全局槽 EPOCH 在「同一波」的所有弹之间共享（同一帧发弹、下一帧读，波间隔 10 帧无竞态）。
xformdef DECEL130 { @130 step_speed(0fx, 130); }

async sub scatter_turn() {
    var a: angle = global(EPOCH) as angle;
    wait(130);                 // task 出生当帧不跑：wait 130 落在弹龄 ~131，0x40 已结束
    turn(0, a);
    // 0x40 周期末速度 f1 按难度分档：E/N=1.4、H=1.6、L=2.0（source.txt:104-107）
    var rank: int = global(GVAR_RANK);
    var endsp: fx = 1.4fx;
    if rank == RANK_HARD { endsp = 1.6fx; }
    else if rank >= RANK_LUNATIC { endsp = 2.0fx; }
    set_speed(0, endsp);
}

// bullet_random 一笔要发 $I0 颗（L 档可到 ~50），逐颗 fire 会烧穿单任务 1024 op/帧的预算
// （E 档 n≈30 就 Fault BUDGET）。按 §10.1 的做法拆成同帧 spawn 的多个子任务，各自发 ≤16 颗。
async sub wave_fire(cnt: int) {
    for j in 0..cnt {
        var sp: fx = 1.0fx + 1.4fx / 256 * rand(256);   // 速度 [1.0, 2.4)
        var an: angle = rand(32768) as angle;           // 角度 [0, π)
        _ = fire(OUTLINE, 13, $self_x, $self_y, sp, an, DECEL130, scatter_turn);
    }
}

// move_rand_in_bounds(-π, π); move_speed(1.5); move_time_decelerate(90)
// Sub27 设下的 move_bounds_set(32, 48, 352, 144) → 我方 (-160, 48)-(160, 144)（§7.3）
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
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

async sub pattern() {
    // Sub82：spellcard_start 后移到中央 (192, 80) → (0, 80)，缓动 120 帧，末尾 +120 ret
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);

    var rank: int = global(GVAR_RANK);
    // Sub83_20 的 bullet_circle：E8/N12/H16/L20 路 × 2 层，s1=2.5、s2=0.7、a2=7.5°
    var burst_n: int = 8;
    var add_n: int = 4;                  // 后段 bullet_random 的 $I0 = $I7*2 + add
    if rank == RANK_NORMAL { burst_n = 12; add_n = 10; }
    else if rank == RANK_HARD { burst_n = 16; add_n = 16; }
    else if rank >= RANK_LUNATIC { burst_n = 20; add_n = 24; }

    sh_reset(0);
    sh_sprite(0, AMULET, 0);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, burst_n, 2);
    sh_speed(0, 2.5fx, -0.9fx);          // (0.7 − 2.5) / 2
    sh_angle(0, 0deg, 1365bam);          // 逐层 7.5°

    var i7: int = 0;                     // Sub81 set_int($I7, 0)
    loop {                               // Sub83_0
        // Sub83_20：set_int($I4, 8) + jump_dec(0, Sub83_20, $I4)，每 8 帧一圈、共 8 圈
        for k1 in 0..8 {
            var a0: angle = rand(65536) as angle;   // set_float_rand_bound_min($F0, 2π, -π)
            sh_angle(0, a0, 1365bam);
            sh_fire(0);
            wait(8);
        }
        wait(60);                        // +60: //68（循环后相对时间 8，再等 60）
        // +68: move_rand_in_bounds; move_speed(1.5); move_time_decelerate(90); math_inc($I7)
        wander(1.5fx, 90);
        i7 = i7 + 1;
        // Sub83_348：set_int($I4, 3) + jump_dec(68, Sub83_348, $I4)，每 10 帧一波、共 3 波
        for k2 in 0..3 {
            var f0i: int = -16384 + rand(32768);    // set_float_rand_bound_min($F0, π, -π/2)
            set_global(EPOCH, f0i);
            var n: int = i7 * 2 + add_n;            // math_int_mul($I0,$I7,2); math_int_add($I0,$I0,add)
            var done: int = 0;
            while done < n {                        // bullet_random(1, 13, n, 1, 2.4, 1.0, π, 0, 67)
                var chunk: int = n - done;
                if chunk > 16 { chunk = 16; }
                spawn wave_fire(chunk);
                done = done + chunk;
            }
            wait(10);
        }
        // jump(0, Sub83_0)：时间归 0，外循环周期 64 + 60 + 3×10 = 154 帧
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                  // enemy_set_hitbox(48, 56, 32) → 48/3
    var rank: int = global(GVAR_RANK);
    var sid: int = SPELL_ID_E;
    if rank == RANK_NORMAL { sid = SPELL_ID_N; }
    else if rank == RANK_HARD { sid = SPELL_ID_H; }
    else if rank >= RANK_LUNATIC { sid = SPELL_ID_L; }
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
