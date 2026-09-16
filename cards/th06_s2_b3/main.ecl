// th06_s2_b3 —— 东方红魔乡 Stage 2 boss（琪露诺）符卡 雹符「ヘイルストーム」
// 原文：ecldata2.ecl.txt Sub33 → Sub34（宣言 + 移到中央 + timer 2100）→ Sub35（8 波 × 8 连环弹：
// 每发环量固定、60 帧减速到 0 后集体转向当发方向并恢复 $F0 速），时限 2100。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 11;   // Sub34 的 H 档 id（ranks 下界 = Hard）
const SHARD: int = 96;      // TH06 弹型 5 SHARD（半边长 2）

// 全局槽（>= GLOBALS_SYS_SEGMENT=16）：把每发的最终朝向与波号传给弹上任务。
const G_ANGLE: int = 16;    // 本发最终朝向（BAM，位穿透）
const G_WAVE: int = 17;     // 当前波号 $I7 → 任务算 $F0 = 1.4 + 0.15·波号

// Sub35：bullet_effects(60, 1, -1, -1, %F2, %F0, -1, -1) + flags 260(0x100|0x4)。
// 0x100 = 每 60 帧一周期：速度从当前值线性减到 0，周期末朝向设为 f0、速度设为 f1（i1=1 次）
// ——mapping §5 的 xformdef 写法。f0/f1 每发/每波都不同，xformdef 参数必须编译期常量，
// 所以减速交给共用的 xform（2 物理槽），最终「定向 + 定速」交给弹上任务，任务从全局槽取参数。
xformdef HAIL_DECEL { @60 step_speed(0fx, 60); }

async sub hail_turn() {
    var w: int = global(G_WAVE);
    var a: int = global(G_ANGLE);
    var f1: fx = 1.4fx + 0.15fx * w;
    wait(60);                       // xform 的 60 帧减速走完（末帧速度精确为 0）
    set_angle(0, a as angle);       // TH06 curBullet->angle = dirChangeRotation
    set_speed(0, f1);               // TH06 curBullet->speed = dirChangeSpeed
}

// move_bounds_set(32.0f, 48.0f, 352.0f, 134.0f)（Sub42 boss 初始化）→ 我方 (-160,48)-(160,134)
// 对应 Sub35 的 move_rand_in_bounds(-π, π); move_speed(1.0f); move_time_decelerate(120)。
sub wander(spd: fx, t: int) {
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
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var wave: int = 0;              // $I7
    var f2: int = 0;                // $F2（BAM 累加器），每发 ±4096
    move_to(120, 0.0fx, 96.0fx, 2); // Sub34 move_position_time_decelerate(120, 192, 96)
    wait(120);                      // Sub34 +120 ret → Sub35
    loop {                          // Sub35_60
        var n: int = wave + 8;      // H：$I2 = $I7 + 8
        if rank >= RANK_LUNATIC { n = wave + 13; }   // L：$I2 = $I7 + 13
        sh_reset(0);
        sh_sprite(0, SHARD, 6);
        sh_offset(0, 0.0fx, -12.0fx);              // Sub42 shoot_offset(0.0f, -12.0f, 0.0f)
        sh_aim(0, 0);
        sh_ring(0, 1);                             // bullet_circle：整周均分、不瞄
        sh_count(0, n, 3);                         // count1=n，count2=$I3=3
        sh_speed(0, 5.0fx, (1.5fx - 5.0fx) / 3);   // s1=5.0, s2=1.5，逐层 (s2-s1)/c2
        sh_xform(0, HAIL_DECEL);
        sh_task(0, hail_turn);
        for k in 0..8 {             // Sub35_80 … jump_dec(0, Sub35_80, $I4=8)
            if wave % 2 == 0 { f2 = f2 + 4096; } else { f2 = f2 - 4096; }  // math_int_mod($I1,$I7,2)
            var f1: angle = (rand(65536) - 32768) as angle;   // $F1：环基准角，随机 [-π, π)
            set_global(G_WAVE, wave);
            set_global(G_ANGLE, f2);        // 转向角 = $F2
            sh_angle(0, f1, 0deg);
            sh_fire(0);
            wait(20);               // +20
        }
        wander(1.0fx, 120);         // move_rand_in_bounds + move_speed(1.0) + move_time_decelerate(120)
        wait(120);                  // +120；$F0 += 0.15 由波号在任务里体现
        wave = wave + 1;            // math_int_add($I7, $I7, 1); jump(0, Sub35_60)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);             // Sub42 enemy_set_hitbox(48, 56, 32) → min(48,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
