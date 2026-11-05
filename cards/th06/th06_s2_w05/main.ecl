// th06_s2_w05 —— 东方红魔乡 Stage 2 道中 第 5 波
// 原文：ecldata2.ecl.txt timeline 帧 1962–2218（Sub6 横扫编队 + Sub0–Sub4 随机穿插；行 1288–1333, 2–129）
const TIME_LIMIT: int = 676;

const BULLET: int = 128;   // TH06 弹型 0 PELLET（小玉）
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI（苦无）

// TH06 敌「进过场地再出界」立即删除（mapping §6.2）
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

// Sub0/Sub2/Sub4 的 !N/!H 发弹：bullet_offset_circle_aimed(4, 11, 4, 1, 2.0, 0, 0, 0, 4)
// 苦无 × 色 11，4 颗、以自机方向 +π/4 起偏（层间不错开）、speed 2.0。
// shoot_interval_delayed(180) 后到 until（原文 +180/+200 的 shoot_interval(0)）为止；
// 同帧撞上 shoot_interval(0) 时不发（TH06 先跑块指令再 tick 射击计时器）。
async sub shot_offset_nh(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 11);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 4, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_angle(0, 8192bam, 0deg);            // a1 = 0；sh_ring 起偏 32768/c1 = π/4
    var t: int = 180 - rand(180);          // shoot_interval_delayed(180)
    if t >= until { return; }
    wait(t);
    loop {
        sh_fire(0);
        if t + 180 >= until { return; }
        wait(180);
        t = t + 180;
    }
}

// Sub0–Sub4 的 !L 发弹：bullet_circle_aimed(4, 11, 10, 2, 2.5, 0, 0, 0, 4)
// 苦无 × 色 11，10 颗整周 × 2 层（s2 = 0 按 0.3 钳 → step = (0.3 − 2.5) / 2）、aimed。
async sub shot_ring_l(until: int) {
    sh_reset(0);
    sh_sprite(0, KUNAI, 11);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 2.5fx, -1.1fx);
    sh_angle(0, 0deg, 0deg);
    var t: int = 180 - rand(180);
    if t >= until { return; }
    wait(t);
    loop {
        sh_fire(0);
        if t + 180 >= until { return; }
        wait(180);
        t = t + 180;
    }
}

// Sub6 的 !L 发弹：bullet_fan_aimed(0, 6, 3, 1, 2.5, 0, 0, 0.19634955, 4)
// 小玉 × 色 6，3 颗自机狙扇、间隔 11.25°（π/16）、speed 2.5；
// shoot_interval_delayed(120) 后每 120 帧一发，直到敌退场。
async sub fan_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_speed(0, 2.5fx, 0fx);
    sh_angle(0, 0deg, 2048bam);
    wait(120 - rand(120));
    loop {
        sh_fire(0);
        wait(120);
    }
}

// Sub0（原文行 2–21）：move_velocity(45°, 3.0) + move_acceleration(-0.015)，全程逐帧积分。
// !N/!H → 4 颗 offset 苦无环；!L → 10×2 苦无环；E 不发弹。until = +180。
async sub sub0() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_NORMAL || rank == RANK_HARD { spawn shot_offset_nh(180); }
    else if rank >= RANK_LUNATIC { spawn shot_ring_l(180); }
    var ang: angle = 45deg;                // a0 = 0.7853982f
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub1（原文行 23–40）：与 Sub0 同，a0 = 67.5°；只有 !L 发弹（!L shoot_interval_delayed），until = +200。
async sub sub1() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) >= RANK_LUNATIC { spawn shot_ring_l(200); }
    var ang: angle = 67.5deg;              // a0 = 1.1780972f
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub2（原文行 42–61）：a0 = 90°；!N/!H → 4 颗 offset 环，!L → 10×2 环；until = +200。
async sub sub2() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_NORMAL || rank == RANK_HARD { spawn shot_offset_nh(200); }
    else if rank >= RANK_LUNATIC { spawn shot_ring_l(200); }
    var ang: angle = 90deg;                // a0 = 1.5707964f
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub3（原文行 63–80）：a0 = 112.5°；只有 !L 发弹；until = +200。
async sub sub3() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) >= RANK_LUNATIC { spawn shot_ring_l(200); }
    var ang: angle = 112.5deg;             // a0 = 1.9634954f
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub4（原文行 82–101）：a0 = 135°；!N/!H → 4 颗 offset 环，!L → 10×2 环；until = +200。
async sub sub4() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    if rank == RANK_NORMAL || rank == RANK_HARD { spawn shot_offset_nh(200); }
    else if rank >= RANK_LUNATIC { spawn shot_ring_l(200); }
    var ang: angle = 135deg;               // a0 = 2.3561945f
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub6（原文行 113–129）：move_at_player(0°, 2.4)；+180 起以 -256bam/帧转 100 帧，+280 归零直飞。
// !L 才有 3 颗自机狙扇（shoot_interval_delayed(120)），E/N/H 一颗不发。
async sub sub6() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) >= RANK_LUNATIC { spawn fan_autoshoot(); }
    var ang: angle = aim_player();         // move_at_player(0.0f, 2.4f)
    var spd: fx = 2.4fx;
    move_vel(0, ang, spd, 0);
    wait(180);
    var w: angle = -256bam;                // +180 move_angular_velocity(-0.024543693f)
    for k1 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    loop { wait(1); }                      // +280 角速度归零，直飞；出界由守卫退场
}

// 导演：按 timeline 相对帧出怪。原文首帧 1962 → 卡帧 120（开场缓冲）。
// Sub6 横扫编队（x 160 → -112）每 16 帧一只；Sub0–Sub4 随机 x 穿插其中。
async sub wave() {
    wait(120);
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 1962
    wait(16);
    _ = spawn_enemy(144.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 1978
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub4());   // 1984 random
    wait(10);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 1994
    wait(16);
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2010
    wait(16);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2026
    wait(16);
    _ = spawn_enemy(80.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2042
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0());   // 2048 random
    wait(10);
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2058
    wait(16);
    _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2074
    wait(16);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2090
    wait(16);
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub6());    // 2106
    wait(16);
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub6());     // 2122
    wait(16);
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2138
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub1());   // 2144 random
    wait(10);
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2154
    wait(16);
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2170
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub2());   // 2176 random
    wait(10);
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2186
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub3());   // 2192 random
    wait(10);
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6());   // 2202
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub0());   // 2208 random
    wait(10);
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub6());  // 2218
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
