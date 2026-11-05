// th06_s2_w02 —— 东方红魔乡 Stage 2 道中第 2 波（Sub6 横扫编队 + Sub0–Sub4 随机小怪）
// 原文：ecldata2.ecl.txt timeline 帧 894–1150；Sub0(:2) / Sub1(:23) / Sub2(:42) / Sub3(:63) / Sub4(:82) / Sub6(:113)
const TIME_LIMIT: int = 676;
const BULLET: int = 128;   // TH06 弹型 0 PELLET 小玉
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI 苦无

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

// 自动射击伴生任务（mapping §4.3 写法 A）。原文的 bullet_* 在 shoot_disable 期间只写参数不发弹，
// 真正出弹全部来自 shoot_interval(_delayed)，所以这里只按 props 配置 + 定时 sh_fire。
//   kind 0：!N/!H 的 bullet_offset_circle_aimed(4, 11, 4, 1, 2.0, 0, 0, 0, 4)
//   kind 1：!L 的 bullet_circle_aimed(4, 11, 10, 2, 2.5, 0, 0, 0, 4)
//   kind 2：Sub6 !L 的 bullet_fan_aimed(0, 6, 3, 1, 2.5, 0, 0, 2048bam, 4)
async sub autoshoot(kind: int, interval: int, until: int) {
    sh_reset(0);
    if kind == 0 {
        sh_sprite(0, KUNAI, 11);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 4, 1);
        sh_speed(0, 2.0fx, (0.3fx - 2.0fx));
        sh_angle(0, 8192bam, 0deg);        // a1 + pi/c1 = 0 + 45°
    } else if kind == 1 {
        sh_sprite(0, KUNAI, 11);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 10, 2);
        sh_speed(0, 2.5fx, (0.3fx - 2.5fx) / 2);
        sh_angle(0, 0deg, 0deg);
    } else {
        sh_sprite(0, BULLET, 6);
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, 3, 1);
        sh_speed(0, 2.5fx, (0.3fx - 2.5fx));
        sh_angle(0, 0deg, 2048bam);        // a2 = 11.25°
    }
    // shoot_interval_delayed(interval)：计时器初值随机 [0, interval)，首发在第 interval-rand(interval) 帧。
    // 直到 until 帧 shoot_interval(0) 之前都保持自动射击；TH06 在该帧先执行 shoot_interval(0) 再 tick，
    // 所以「开火帧 >= until」的那一发被吞掉（Sub1/2/3/4 的 stop=200，first<=19 时会多打一轮）。
    var t: int = 0;
    var next: int = interval - rand(interval);
    loop {
        if next >= until { return; }
        wait(next - t);
        t = next;
        sh_fire(0);
        next = next + interval;
    }
}

// Sub0 / Sub2 / Sub4（l_only = 0）与 Sub1 / Sub3（l_only = 1）：同一套结构。
// l_only 只区分自动射击的难度范围（前者 !NHL，后者 !L）；stop 是原文 +N shoot_interval(0)
// 的停止帧（Sub0 = 180，Sub1/2/3/4 = 200），与难度范围互相独立，不能由 l_only 推出。
async sub popcorn(a: angle, l_only: int, stop: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = a;
    var spd: fx = 3.0fx;
    var acc: fx = -0.015fx;
    move_vel(0, ang, spd, 0);
    if rank >= RANK_LUNATIC { spawn autoshoot(1, 180, stop); }
    else if rank != RANK_EASY && l_only == 0 { spawn autoshoot(0, 180, stop); }
    // +stop 之后原文只等 enemy_delete；加速继续，出界由守卫退场
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// Sub6：move_at_player(0.0f, 2.4f) → +180 起以 -256bam/帧 转向 → +280 停（!L 粘滞使其仅 Lunatic 发弹）
async sub sub6() {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = aim_player();
    var spd: fx = 2.4fx;
    move_vel(0, ang, spd, 0);
    if rank >= RANK_LUNATIC { spawn autoshoot(2, 120, 10000); }
    wait(180);
    var w: angle = -256bam;                // +180 move_angular_velocity(-0.024543693f)
    for k1 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +280 move_angular_velocity(0.0f)
    loop { wait(1); }
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 894)。原始 timeline 894–1150。
async sub wave() {
    wait(120);
    // 894–1150：Sub6 横扫编队（每 16 帧一只，x 由 −160 递增到 +112），穿插 6 只随机 Sub0–Sub4
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub6());            // 894
    wait(16);
    _ = spawn_enemy(-144.0fx, -32.0fx, 1, 0, 0, 0, sub6());            // 910
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(24576bam, 0, 200));  // 916 Sub4 (!NHL, stop 200)
    wait(10);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6());            // 926
    wait(16);
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub6());            // 942
    wait(16);
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 958
    wait(16);
    _ = spawn_enemy(-80.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 974
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(8192bam, 0, 180));   // 980 Sub0 (!NHL, stop 180)
    wait(10);
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 990
    wait(16);
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 1006
    wait(16);
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 1022
    wait(16);
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 1038
    wait(16);
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub6());               // 1054
    wait(16);
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub6());              // 1070
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(12288bam, 1, 200));  // 1076 Sub1 (!L, stop 200)
    wait(10);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub6());              // 1086
    wait(16);
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub6());              // 1102
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(16384bam, 0, 200));  // 1108 Sub2 (!NHL, stop 200)
    wait(10);
    _ = spawn_enemy(80.0fx, -32.0fx, 1, 0, 0, 0, sub6());              // 1118
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(20480bam, 1, 200));  // 1124 Sub3 (!L, stop 200)
    wait(10);
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6());              // 1134
    wait(6);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, popcorn(8192bam, 0, 180));   // 1140 Sub0 (!NHL, stop 180)
    wait(10);
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub6());             // 1150
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
