// th06_s7_b6：东方红魔乡 Stage 7(Extra) boss 符卡 3「禁忌「フォーオブアカインド」」
// 原文：ecldata7.ecl.txt Sub49 → Sub50 → Sub51（本体攻击 + Sub52/53/54 三只分身），原作时限 3900 钳至 3000。

const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 123;
const RICE: int = 64;        // TH06 弹型 2 RICE
const LASERHEAD: int = 176;  // TH06 弹型 6 BIG_BALL（32px 弹，色号按 §3 查表）

// flags 0x1：出生后 16 帧额外速度 5→0 线性衰减（mapping §5）
xformdef DASH {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    stop_fx();
}

// Sub51_492 / Sub52_396 等：move_rand_in_bounds + move_speed(1.2) + move_time_decelerate(90)
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
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

// 写法 A（mapping §4.3）：配置一次随机基准角环形米弹（flags 0x1 冲刺），按 interval 自动开火。
// 在原作 shoot_interval(_delayed)(n) 的设定帧 S spawn；k = 原作开火帧相对 S 的偏移：
// 首发 k = n − 1（delayed：n − 1 − rand(n)），此后每 n 帧；until = 原作 shoot_interval(0) 相对 S 的帧，k >= until 不发。
// 基准角 a0 由调用方抽一次（与后续大玉共用原作 %F0）。
async sub rice_autoshoot(count: int, interval: int, delayed: int, until: int, oy: fx, a0: angle) {
    sh_reset(0);
    sh_sprite(0, RICE, 2);
    sh_offset(0, 0.0fx, oy);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, count, 1);
    sh_speed(0, 2.0fx, -1.0fx);       // s1=2.0, s2=1.0, c2=1
    sh_angle(0, a0, 0deg);
    sh_xform(0, DASH);
    var k: int = interval - 1;
    if delayed != 0 { k = interval - 1 - rand(interval); }
    if k >= until { return; }
    if k > 0 {
        wait(k - 1);
    } else {
        // k == 0：只能在 S+1 发；后续仍按 S+interval 对齐
        sh_fire(0);
        k = interval;
        if k >= until { return; }
        wait(interval - 1);
    }
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// 原文 Sub52：从 (-192,0) 出生 → 瞬移 (-224,96) → 滑到 (-128,96)；每 580 帧一轮：
// 随机角米弹环（interval_delayed 60，直到 L=450）+ 40 颗大玉环（s 3→1）。
async sub clone52() {
    set_invuln(65535);
    set_hitbox(18.67fx);
    move_to(0, -224.0fx, 96.0fx, 0);
    move_to(60, -128.0fx, 96.0fx, 2);
    wait(60);
    var f0: angle = 0deg;
    loop {
        f0 = rand(65536) as angle;
        spawn rice_autoshoot(32, 60, 1, 390, -12.0fx, f0);
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(300);
        wait(90);
        wait(100);
        sh_reset(1);
        sh_sprite(1, LASERHEAD, 6);
        sh_offset(1, 0.0fx, -12.0fx);
        sh_aim(1, 0);
        sh_ring(1, 1);
        sh_count(1, 40, 3);
        sh_speed(1, 3.0fx, (1.0fx - 3.0fx) / 3);
        sh_angle(1, f0, 0deg);
        sh_fire(1);
        wait(90);
    }
}

// 原文 Sub53：瞬移 (64,-32) → 滑到 (64,96)；每 480 帧一轮：
// 随机角米弹环（interval_delayed 40，直到 L=350）+ 8 颗 × 10 层大玉环（s 5→1）。
async sub clone53() {
    set_invuln(65535);
    set_hitbox(18.67fx);
    move_to(0, 64.0fx, -32.0fx, 0);
    move_to(60, 64.0fx, 96.0fx, 2);
    wait(60);
    var f0: angle = 0deg;
    loop {
        f0 = rand(65536) as angle;
        spawn rice_autoshoot(32, 40, 1, 290, -12.0fx, f0);
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(200);
        wait(90);
        wait(100);
        sh_reset(1);
        sh_sprite(1, LASERHEAD, 13);
        sh_offset(1, 0.0fx, -12.0fx);
        sh_aim(1, 0);
        sh_ring(1, 1);
        sh_count(1, 8, 10);
        sh_speed(1, 5.0fx, (1.0fx - 5.0fx) / 10);
        sh_angle(1, 0deg, 0deg);
        sh_fire(1);
        wait(90);
    }
}

// 原文 Sub54：瞬移 (224,96) → 滑到 (128,96)；每 530 帧一轮：
// 随机角米弹环（interval_delayed 40，直到 L=400）+ 7 颗 × 5 层自机狙扇（s 3.2→1，±9° 展开）。
async sub clone54() {
    set_invuln(65535);
    set_hitbox(18.67fx);
    move_to(0, 224.0fx, 96.0fx, 0);
    move_to(60, 128.0fx, 96.0fx, 2);
    wait(60);
    var f0: angle = 0deg;
    loop {
        f0 = rand(65536) as angle;
        spawn rice_autoshoot(32, 40, 1, 340, -12.0fx, f0);
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(250);
        wait(90);
        wait(100);
        sh_reset(1);
        sh_sprite(1, LASERHEAD, 10);
        sh_offset(1, 0.0fx, -12.0fx);
        sh_aim(1, 1);
        sh_ring(1, 0);
        sh_count(1, 7, 5);
        sh_speed(1, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(1, 0deg, 3277bam);   // a2 = 18°
        sh_fire(1);
        wait(90);
    }
}

// 原文 Sub50（宣言 + 移到中央 (192,80)）+ Sub51（本体：三只分身 + 每 760 帧一轮的
// 随机角米弹环（interval_delayed 40，直到 L=726）+ 40 颗 × 3 层大玉环，a2 = 3.6°）。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);    // Sub50 enemy_kill_all()
    move_to(120, 0.0fx, 80.0fx, 2);   // Sub50 move_position_time_decelerate(120, 192, 80)
    wait(120);
    for k1 in 0..32 { wait(3); }      // Sub51_52：effect_particle 丢弃，32×3 = 96 帧
    _ = spawn_enemy(-192.0fx, 0.0fx, 1, 0, 0, 0, clone52);
    _ = spawn_enemy(-192.0fx, 0.0fx, 1, 0, 0, 0, clone53);
    _ = spawn_enemy(-192.0fx, 0.0fx, 1, 0, 0, 0, clone54);
    move_to(60, -64.0fx, 96.0fx, 2);  // Sub51 move_position_time_decelerate(60, 128, 96)
    wait(60);
    var f0: angle = 0deg;
    loop {
        // Sub51_364
        f0 = rand(65536) as angle;
        spawn rice_autoshoot(48, 40, 1, 570, 0.0fx, f0);
        // Sub51_492：本体随机游走，每 190 帧一次，共 3 次
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(190);
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(190);
        wander(1.2fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(190);
        wait(100);                    // +100：大玉环
        sh_reset(1);
        sh_sprite(1, LASERHEAD, 6);
        sh_offset(1, 0.0fx, 0.0fx);
        sh_aim(1, 0);
        sh_ring(1, 1);
        sh_count(1, 40, 3);
        sh_speed(1, 3.0fx, (1.0fx - 3.0fx) / 3);
        sh_angle(1, f0, 655bam);      // a2 = 3.6°
        sh_fire(1);
        wait(90);                     // +90 → jump(63, Sub51_364)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 80.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
