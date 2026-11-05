// th06_s3_w05 —— 东方红魔乡 Stage 3 道中 第 5 波
// 原文：ecldata3.ecl.txt timeline 帧 1986–2322（Sub5 随机散兵 + Sub6 自机狙连射），E–L 四档
const TIME_LIMIT: int = 816;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

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

// Sub5：下落 → +40 减速（-0.05/帧 ×30 帧）→ +70 自机狙扇 → +100 沿随机方向 -1.5 飞走
async sub sub5() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 1.5f)
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;                         // +40 move_acceleration(-0.05f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70：set_float_rand_bound($F1, 1.0f); math_float_add($F1, %F1, 1.0f) → 速度 [1, 2)
    var f1: fx = 1.0fx + 1.0fx / 256 * rand(256);
    var rank: int = global(GVAR_RANK);
    // bullet_fan_aimed(1, 2, c1, c2, %F1, s2, 0.0f, a2, 4)：OUTLINE 色 2、自机狙对称扇
    var n: int = 8;                        // !E
    var layers: int = 1;
    var s2: fx = 0fx;
    var spread: angle = 5461bam;           // 30°
    if rank == RANK_NORMAL { n = 16; spread = 2731bam; }                                // 15°
    else if rank == RANK_HARD { n = 24; s2 = 1.0fx; spread = 2185bam; }                 // 12°
    else if rank >= RANK_LUNATIC { n = 24; layers = 3; s2 = 1.0fx; spread = 2341bam; }  // 12.86°
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, f1, (s2 - f1) / layers);
    sh_angle(0, 0deg, spread);
    sh_fire(0);
    // set_float_rand_bound($F2, π/2); math_float_add($F2, %F2, π/4) → 角 [45°, 135°)
    var a1: angle = 45deg + rand(16384) as angle;
    wait(30);
    // +100：move_velocity(%F2, -1.5f)，负速度 = 反向飞回屏幕上方退场
    spd = -1.5fx;
    move_vel(0, a1, spd, 0);
    wait(9900);
}

// Sub6 的自动射击：原文 bullet_* 只配参数（shoot_disable 期间），随后 shoot_interval_delayed(n) 自动开火；
// +220 处 shoot_interval_delayed(0) 停。参数在 [0,220) 内不变，故用伴生任务（mapping §4.3 写法 A）。
async sub autoshoot(n: int, s1: fx, spread: angle, interval: int, until: int) {
    sh_reset(0);
    sh_sprite(0, BULLET, 1);
    sh_aim(0, 1);
    sh_count(0, n, 1);
    sh_speed(0, s1, 0fx);
    sh_angle(0, 0deg, spread);
    var t: int = 0;
    var next: int = interval - rand(interval);   // 首发在 interval − rand(interval) 帧后
    loop {
        // TH06 在 until 帧执行 shoot_interval_delayed(0)，当帧不再开火：到点即停，不发这一轮
        if next >= until { return; }
        wait(next - t);
        t = next;
        sh_fire(0);
        next = next + interval;
    }
}

// Sub6：下落 → +40/−256bam → +120/+205bam → +220 角速度归零，自机狙连射在 +220 停
async sub sub6(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    var rank: int = global(GVAR_RANK);
    // bullet_fan_aimed(0, 1, c1, 1, s1, 0.0f, 0.0f, a2, 4)：PELLET 色 1、自机狙
    var n: int = 1;                        // !E
    var s1: fx = 1.5fx;
    var spread: angle = 546bam;            // 3°
    var interval: int = 300;               // !E shoot_interval_delayed(300)
    if rank == RANK_NORMAL { n = 3; interval = 190; }                                   // !N
    else if rank == RANK_HARD { n = 3; s1 = 2.5fx; interval = 120; }                    // !H
    else if rank >= RANK_LUNATIC { n = 7; s1 = 2.5fx; spread = 364bam; interval = 90; } // !L
    spawn autoshoot(n, s1, spread, interval, 220);
    wait(40);
    // +40 move_angular_velocity(-0.024543693f)；镜像翻角速度（mapping §6.1）
    var w: angle = -256bam;
    if mirror != 0 { w = 256bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +120 move_angular_velocity(0.019634955f)
    w = 205bam;
    if mirror != 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +220 move_angular_velocity(0.0f); shoot_interval_delayed(0)
    w = 0deg;
    wait(9780);
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 1986)
async sub wave() {
    wait(120);
    // 1986–2066：enemy_create_random("Sub5") ×5
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(6);
    // 2072–2144：enemy_create("Sub6") 左 x=64/96（我方 −128/−96）成对 ×7
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(12);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub6(0));
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub6(0)); wait(20);
    // 2164–2244：enemy_create_random("Sub5") ×5
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(20);
    _ = spawn_enemy((rand(384) - 192) as fx, -32.0fx, 1, 0, 0, 0, sub5()); wait(6);
    // 2250–2322：enemy_create_mirror("Sub6") 右 x=320/288（我方 128/96）成对 ×7
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1)); wait(12);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub6(1));
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
