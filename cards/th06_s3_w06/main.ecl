// th06_s3_w06 —— 东方红魔乡 Stage 3 道中 第 6 波
// 原文：ecldata3.ecl.txt timeline 帧 2622–3304（Sub0/Sub1/Sub2/Sub3 左右列 + Sub4 双翼 + Sub5 随机散兵），E–L 四档
const TIME_LIMIT: int = 1162;
const BALL: int = 48;     // TH06 弹型 3 BALL 中玉
const KUNAI: int = 80;    // TH06 弹型 4 KUNAI 苦无
const OUTLINE: int = 32;  // TH06 弹型 1 RING_BALL 环玉

// TH06 敌进过场地再出界即删（mapping §6.2）
async sub oob_guard() {
    var been_in: int = 0;
    loop {
        var inside: int = 0;
        if $self_x > -208.0fx && $self_x < 208.0fx && $self_y > -16.0fx && $self_y < 464.0fx { inside = 1; }
        if inside == 1 { been_in = 1; }
        if been_in == 1 && inside == 0 { die(); }
        wait(1);
    }
}

// Sub0/Sub1/Sub2/Sub3 的 !H 粘滞段：shoot_disable → bullet_fan_aimed(4,6,1,1,2.0,0.0,0.0,7.5°,4)
// → shoot_enable → shoot_interval(60)。单发自机狙 KUNAI，速度 2.0；+115/+90 被
// shoot_interval_delayed(0) 停掉（只发一发）。参数在自动射击期间不变，用伴生任务复刻（mapping §4.3）。
async sub autoshoot_h(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_angle(0, 0deg, 1365bam);           // a7 = 7.5°（单颗无展开）
    var t: int = 60;
    if t >= until { return; }
    wait(60);
    loop {
        sh_fire(0);
        t = t + 60;
        if t >= until { return; }
        wait(60);
    }
}

// Sub0/Sub1/Sub2/Sub3 的 !L 粘滞段：shoot_disable → bullet_circle_aimed(4,6,10,2,3.0,1.0,0.0,7.5°,4)
// → shoot_enable → shoot_interval_delayed(200)。10 路自机狙环 × 2 层、层偏移 7.5°，
// 速度 3.0/2.0；首发在 200−rand(200) 帧，+115/+90 被 shoot_interval_delayed(0) 停掉（最多一发）。
async sub autoshoot_l(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 3.0fx, -1.0fx);           // (s2−s1)/c2 = (1.0−3.0)/2
    sh_angle(0, 0deg, 1365bam);           // a7 = 7.5° 逐层偏移
    var first: int = 200 - rand(200);
    if first >= until { return; }
    wait(first);
    loop {
        sh_fire(0);
        first = first + 200;
        if first >= until { return; }
        wait(200);
    }
}

// Sub0 / Sub1：左列（镜像即右列）y=64，move_velocity(30°, 4.5)；+30 起角速度 −3.75°/帧转 85 帧；
// +115 角速度归零直线飞出。E/N 不发弹；H 单发；L 环。镜像只取反角速度，弹角不镜像（mapping §6.1）。
async sub fairy_a(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn autoshoot_h(115); }
    else if rank >= RANK_LUNATIC { spawn autoshoot_l(115); }
    var ang: angle = 5461bam;              // 0.5235988f = 30°
    var spd: fx = 4.5fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = -683bam;                           // +30 move_angular_velocity(-0.06544985f) = −3.75°/帧
    if mirror != 0 { w = 683bam; }
    for k1 in 0..85 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +115 move_angular_velocity(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10000);                           // +10000 enemy_delete（实际出界守卫先退场）
}

// Sub2 / Sub3：左列（镜像即右列）y=192，move_velocity(−60°, 4.0)；+30 起角速度 +2°/帧转 60 帧；
// +90 角速度归零直线飞出。发弹难度分支同 fairy_a，只是停止帧是 +90。
async sub fairy_b(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_HARD { spawn autoshoot_h(90); }
    else if rank >= RANK_LUNATIC { spawn autoshoot_l(90); }
    var ang: angle = -10923bam;            // -1.0471976f = −60°
    var spd: fx = 4.0fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 364bam;                            // +30 move_angular_velocity(0.034906585f) = +2°/帧
    if mirror != 0 { w = -364bam; }
    for k1 in 0..60 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +90 move_angular_velocity(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10000);
}

// Sub4：下落 40 帧 → 减速 30 帧停住 → +70 自机狙扇（速度 1.6 每发 +0.21，
// !E/N 1 颗、!H 3 颗、!L 5 颗，均 KUNAI；!HL 额外一圈 16 颗 BALL 自机狙环）
// → 循环 15/30 次后朝随机方向 [45°,135°) 飞走（出界由守卫退场）
async sub sub4() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 1.5f)
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 move_acceleration(-0.05f)：30 帧内减速到 0（+70 时 spd = 0）
    acc = -0.05fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 炮击准备：F0 = %PLAYER_ANGLE，F1 = 1.6，I4 = 15(E) / 30(NHL)
    var aim: angle = aim_player();
    var spd2: fx = 1.6fx;
    var n: int = 15;
    if rank >= RANK_NORMAL { n = 30; }
    var ways: int = 1;                     // !E / !N
    var spread: angle = 1365bam;           // 7.5°
    // 原作 TH06 弹池上限 640（BulletManager.hpp:125；池满时 SpawnBulletPattern 中止该发）。
    // E/N 每只 30 颗、H 每只 106 颗都在 640 以内；L 每只 166 颗会让 6 只一起冲到 ~996，
    // 原作里超出的 fan 会被池满丢掉、玩家看不到。本引擎无此上限，故按「一次 6 只共享 640」
    // 折算 L 的实际可见 fan 轮数 ≈ (640 − 6×16 圈弹) / (6×5) ≈ 18，超出部分只走时间不发射。
    var fire_n: int = 30;
    if rank == RANK_HARD { ways = 3; spread = 4096bam; }         // 22.5°
    else if rank >= RANK_LUNATIC { ways = 5; spread = 2731bam; fire_n = 18; } // 15°
    // +70 !HL bullet_circle_aimed(3, 6, 16, 1, 1.6, 0.0, F0, 0.3926991, 4)
    if rank >= RANK_HARD {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, aim, 0deg);            // CIRCLE_AIMED 的「自机 + a1」两项都保留 ⇒ 基准 2×自机角
        sh_fire(0);
    }
    // Sub4_220 循环体：!E/N/H/L 的 bullet_fan(4, 6, ways, 1, F1, 0.0, F0, spread, 4)
    sh_reset(1);
    sh_sprite(1, KUNAI, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    for k2 in 0..n {
        if k2 < fire_n {
            sh_count(1, ways, 1);
            sh_speed(1, spd2, 0fx);
            sh_angle(1, aim, spread);
            sh_fire(1);
        }
        spd2 = spd2 + 0.21fx;
        wait(2);
    }
    // +2 循环后 set_float_rand_bound(F2, π/2); F2 += π/4 ⇒ [45°, 135°)
    var fly: angle = 8192bam + rand(16384) as angle;
    move_vel(0, fly, 1.5fx, 0);
    wait(10000);                           // 原文 +9928 //10000 的 enemy_delete(0)
}

// Sub5：move_velocity(90°, 1.5) 下落；+40 起 move_acceleration(-0.05) 减速 30 帧到零；
// +70 发一轮自机狙扇（E 8 / N 16 / H 24 单层 / L 24×3 层，环玉，速度 1+rand[0,1)）；
// $F2 = [0,π/2)+π/4，+100 以该角、速度 −1.5 反向漂出（原文 move_velocity(%F2, -1.5f)）。
async sub sub5() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;                         // +40 move_acceleration(-0.05f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)
    var s1: fx = 1.0fx + 1.0fx / 256 * rand(256);   // set_float_rand_bound($F1,1) + 1 → [1,2)
    var c1: int = 8;
    var c2: int = 1;
    var s2: fx = 0.3fx;                    // speed2 = 0 钳到 0.3（单层无影响）
    var a7: angle = 5461bam;               // a2 = 30°
    if rank == RANK_NORMAL { c1 = 16; a7 = 2731bam; }
    else if rank == RANK_HARD { c1 = 24; s2 = 1.0fx; a7 = 2185bam; }
    else if rank >= RANK_LUNATIC { c1 = 24; c2 = 3; s2 = 1.0fx; a7 = 2341bam; }
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, c2);
    sh_speed(0, s1, (s2 - s1) / c2);
    sh_angle(0, 0deg, a7);
    sh_fire(0);
    var a2: angle = 45deg + (rand(16384) as angle); // $F2 = [0,π/2) + π/4 → [45°,135°)
    wait(30);
    ang = a2;                              // +100 move_velocity(%F2, -1.5f)
    spd = -1.5fx;
    move_vel(0, ang, spd, 0);
    wait(9900);                            // +10000 enemy_delete（实际出界守卫先退场）
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 2622)
async sub wave() {
    wait(120);
    // 2622–2726：Sub0/Sub1 左列交替 14 只（y=64, x=−224），每 8 帧
    for i1 in 0..14 {
        _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, fairy_a(0));
        wait(8);
    }
    wait(2);                                // 循环末尾已等 8：232 → 234
    // 2736–2776：Sub5 随机 x∈[0,384) ×5，每 10 帧
    for i2 in 0..5 {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5());
        if i2 < 4 { wait(10); }
    }
    wait(8);                                // 274 → 282
    // 2784–2888：右镜像 Sub1/Sub0 ×14（y=64, x=224）
    for i3 in 0..14 {
        _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, fairy_a(1));
        wait(8);
    }
    wait(2);                                // 394 → 396
    // 2898/2908/2918：Sub4 双翼 ×3 批（共 6 只）
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(10);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(10);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(90);                               // 416 → 506
    // 3008–3112：Sub2/Sub3 左列交替 14 只（y=192, x=−224），每 8 帧
    for i4 in 0..14 {
        _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, fairy_b(0));
        wait(8);
    }
    wait(2);                                // 618 → 620
    // 3122–3162：Sub5 随机 x ×5，每 10 帧
    for i5 in 0..5 {
        _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5());
        if i5 < 4 { wait(10); }
    }
    wait(8);                                // 660 → 668
    // 3170–3274：右镜像 Sub2/Sub3 ×14（y=192, x=224）
    for i6 in 0..14 {
        _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, fairy_b(1));
        wait(8);
    }
    wait(2);                                // 780 → 782
    // 3284/3294/3304：Sub4 双翼 ×3 批（共 6 只）
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(10);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    wait(10);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub4());
    loop { wait(1); }
}

async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, wave, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
