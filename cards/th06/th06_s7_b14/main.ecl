// th06_s7_b14 —— 东方红魔乡 Stage 7(Extra) 芙兰朵露 符卡 禁弾「カタディオプトリック」
// 原文：ecldata7.ecl.txt Sub72 → Sub73（宣言 + 移到中央）+ Sub74（攻击循环）+ Sub75（一轮扇形发弹），时限 4200（本卡钳 3000）。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 127;
const LASERHEAD: int = 176;   // TH06 弹型 6 BIG_BALL / 9 BUBBLE
const OUTLINE: int = 32;      // TH06 弹型 1 RING_BALL

xformdef BOUNCE1 { bounce_arm(7, 1); }   // bullet_effects(1, …) + flags 0x800
xformdef BOUNCE2 { bounce_arm(7, 2); }   // bullet_effects(2, …) + flags 0x800

// 原文 Sub75(%F2=base)：一轮发弹 = 1 颗大玉 + 9/3/5/8 颗随机弹，
// 角度都绕 base 对称、速度随机；flags 2048(0x800) 表示碰左右上反弹。
sub f75_b2(base: angle) {
    var sp: fx = 0fx;
    var an: angle = 0deg;
    // bullet_fan(9, 1, 1, 1, 5.2f, 1.2f, %F2, 0.0f, 2048)：BUBBLE 1 颗、速 5.2
    _ = fire(LASERHEAD, 1, $self_x, $self_y, 5.2fx, base, BOUNCE2, none);
    // bullet_random(6, 3, 9, 1, 5.0f, 3.5f, %F2∓256bam, 2048)：9 颗、速度 [3.5,5.0)
    for i1 in 0..9 {
        sp = 3.5fx + 1.5fx / 256 * rand(256);
        an = base - 256bam + (rand(512) as angle);
        _ = fire(LASERHEAD, 6, $self_x, $self_y, sp, an, BOUNCE2, none);
    }
    // bullet_random(6, 3, 3, 1, 3.5f, 2.5f, %F2∓683bam, 2048)：3 颗、速度 [2.5,3.5)
    for i2 in 0..3 {
        sp = 2.5fx + 1.0fx / 256 * rand(256);
        an = base - 683bam + (rand(1366) as angle);
        _ = fire(LASERHEAD, 6, $self_x, $self_y, sp, an, BOUNCE2, none);
    }
    // bullet_random(1, 6, 5, 1, 2.5f, 1.5f, %F2∓819bam, 2048)：5 颗、速度 [1.5,2.5)
    for i3 in 0..5 {
        sp = 1.5fx + 1.0fx / 256 * rand(256);
        an = base - 819bam + (rand(1638) as angle);
        _ = fire(OUTLINE, 6, $self_x, $self_y, sp, an, BOUNCE2, none);
    }
    // bullet_random(1, 6, 8, 1, 1.5f, 0.5f, %F2∓1024bam, 2048)：8 颗、速度 [0.5,1.5)
    for i4 in 0..8 {
        sp = 0.5fx + 1.0fx / 256 * rand(256);
        an = base - 1024bam + (rand(2048) as angle);
        _ = fire(OUTLINE, 6, $self_x, $self_y, sp, an, BOUNCE2, none);
    }
}

// 同上，但 bounce 只 1 次（bullet_effects(1, …)）
sub f75_b1(base: angle) {
    var sp: fx = 0fx;
    var an: angle = 0deg;
    _ = fire(LASERHEAD, 1, $self_x, $self_y, 5.2fx, base, BOUNCE1, none);
    for i1 in 0..9 {
        sp = 3.5fx + 1.5fx / 256 * rand(256);
        an = base - 256bam + (rand(512) as angle);
        _ = fire(LASERHEAD, 6, $self_x, $self_y, sp, an, BOUNCE1, none);
    }
    for i2 in 0..3 {
        sp = 2.5fx + 1.0fx / 256 * rand(256);
        an = base - 683bam + (rand(1366) as angle);
        _ = fire(LASERHEAD, 6, $self_x, $self_y, sp, an, BOUNCE1, none);
    }
    for i3 in 0..5 {
        sp = 1.5fx + 1.0fx / 256 * rand(256);
        an = base - 819bam + (rand(1638) as angle);
        _ = fire(OUTLINE, 6, $self_x, $self_y, sp, an, BOUNCE1, none);
    }
    for i4 in 0..8 {
        sp = 0.5fx + 1.0fx / 256 * rand(256);
        an = base - 1024bam + (rand(2048) as angle);
        _ = fire(OUTLINE, 6, $self_x, $self_y, sp, an, BOUNCE1, none);
    }
}

// 一轮 26 颗同步执行会烧穿 1024 op/任务/帧，所以一波派一个 spawn（mapping §10.1 口径）。
async sub t75_b2(base: angle) { f75_b2(base); }
async sub t75_b1(base: angle) { f75_b1(base); }

async sub pattern() {
    kill_all_enemies(KILL_SILENT);              // Sub73 enemy_kill_all()
    move_to(120, 0.0fx, 80.0fx, 2);             // Sub73 move_position_time_decelerate(120, 192, 80)
    wait(120);                                  // Sub73 +120 ret
    // Sub74：原文靠 spell 计时（4200）收段；t=528 的 jump_dec(0, Sub74_52) 每轮必然跳回，
    // 其后的 7 连发块与 t=655 的 jump(0, Sub74_16) 是死代码，本卡不复现。
    loop {
        wait(60);                               // Sub74_52 粒子循环 30×2 帧（effect_particle 丢弃）
        // +2: bullet_effects(2, …) → bounce 2 次；5 连发（-135°…-45°）
        spawn t75_b2(-24576bam);
        spawn t75_b2(-20480bam);
        spawn t75_b2(-16384bam);
        spawn t75_b2(-12288bam);
        spawn t75_b2(-8192bam);
        move_to(10, $self_x, $self_y + 20.0fx, 2);      // move_dir_time_decelerate(10, 90°, 4)
        wait(60);                                        // +62
        move_to(90, 96.0fx, 96.0fx, 2);                  // move_position_time_decelerate(90, 288, 96)
        wait(110);                                       // +172
        // bullet_effects(1, …) → bounce 1 次；5 连发（45°…-45°）
        spawn t75_b1(8192bam);
        spawn t75_b1(4096bam);
        spawn t75_b1(0bam);
        spawn t75_b1(-4096bam);
        spawn t75_b1(-8192bam);
        move_to(10, $self_x - 20.0fx, $self_y, 2);       // move_dir_time_decelerate(10, 180°, 4)
        wait(60);                                        // +232
        move_to(60, -96.0fx, 96.0fx, 2);                 // move_position_time_decelerate(60, 96, 96)
        wait(60);                                        // +292
        // 5 连发（135°…-135°）
        spawn t75_b1(24576bam);
        spawn t75_b1(28672bam);
        spawn t75_b1(32768bam);
        spawn t75_b1(-28672bam);
        spawn t75_b1(-24576bam);
        move_to(10, $self_x + 20.0fx, $self_y, 2);       // move_dir_time_decelerate(10, 0°, 4)
        wait(60);                                        // +352
        move_to(60, -160.0fx, 128.0fx, 2);               // move_position_time_decelerate(60, 32, 128)
        wait(60);                                        // +412
        move_to(120, 160.0fx, 128.0fx, 0);               // move_position_time_linear(120, 352, 128)
        // Sub74_1144：set_int($I4, 5)；jump_dec(412, Sub74_1144) → 每 24 帧一发、共 5 次
        for r1 in 0..5 {
            spawn t75_b1(-16384bam);
            wait(24);                                    // +436
        }
        wait(30);                                        // +466
        move_to(60, 0.0fx, 128.0fx, 2);                  // move_position_time_decelerate(60, 192, 128)
        wait(60);                                        // +526 → 下一轮粒子循环
    }
}

async sub boss_main() {
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
