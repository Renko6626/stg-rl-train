// th06_s1_w01 —— 东方红魔乡 Stage 1 道中第 1 波
// 原文：ecldata1 timeline 帧 100–1064（Sub0 / Sub2 / Sub3 / Sub4）。转写范例，逐段对照见 notes.md。
const TIME_LIMIT: int = 1400;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

// flags 3 = 0x1|0x2：出生冲刺（mapping §5）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

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

// Sub0 / Sub2 的 Lunatic 段（`!L` 粘滞到 +40）：
//   shoot_disable(); bullet_fan_aimed(0, 6, 1, 1, 3.0f, 0.0f, 0.0f, 0.0f, 4); shoot_enable(); shoot_interval_delayed(120);
async sub pellet_autoshoot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_count(0, 1, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    wait(120 - rand(120));
    loop {
        sh_fire(0);
        wait(120);
    }
}

// Sub0：下落 → +40 左转（-π/128/帧）→ +120 右转（π/160/帧）→ +220 直飞
async sub sub0(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)；镜像 180°−90° 仍是 90°
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(40);
    w = -256bam;                           // +40 move_angular_velocity(-0.024543693f)
    if mirror != 0 { w = 256bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 205bam;                            // +120 move_angular_velocity(0.019634955f)
    if mirror != 0 { w = -205bam; }
    for k2 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9780);                            // +220 角速度归零直飞；出界由守卫退场
}

// Sub2：下落 → +100 右转（π/160/帧）→ +200 直飞
async sub sub2(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    if global(GVAR_RANK) == RANK_LUNATIC { spawn pellet_autoshoot(); }
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var w: angle = 205bam;
    if mirror != 0 { w = -205bam; }
    move_vel(0, ang, spd, 0);
    wait(100);
    for k1 in 0..100 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9800);
}

// Sub3 / Sub4：下落 60 帧停住 → +70 自机狙扇 → +130 加速回转飞走
// Sub3 四档都发；Sub4 只有 Lunatic 发（原文 `!L bullet_fan_aimed(1, 2, 5, 1, 1.4f, 0.0f, 0.0f, 0.2617994f, 3)`）
async sub popcorn(mirror: int, kind: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                             // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    var rank: int = global(GVAR_RANK);
    var n: int = 0;
    var layers: int = 1;
    var s2: fx = 0.3fx;                    // s2 = 0.0f 按 0.3 钳（单层时无影响）
    var spread: angle = 0deg;
    if kind == 3 {
        // +70 !E (1, 2, 3, 1, 1.4, 0.0, 0, π/4) !N (7, 1, π/5) !H (9, 2, s2 0.5, π/8) !L (11, 2, s2 0.5, π/20)
        n = 3;
        spread = 45deg;
        if rank == RANK_NORMAL { n = 7; spread = 36deg; }
        else if rank == RANK_HARD { n = 9; layers = 2; s2 = 0.5fx; spread = 22.5deg; }
        else if rank >= RANK_LUNATIC { n = 11; layers = 2; s2 = 0.5fx; spread = 9deg; }
    } else {
        if rank >= RANK_LUNATIC { n = 5; spread = 15deg; }
    }
    if n > 0 {
        sh_reset(0);
        sh_sprite(0, OUTLINE, 2);
        sh_offset(0, 12.0fx, -12.0fx);     // shoot_offset(12.0f, -12.0f, 0.0f)，镜像不改
        sh_aim(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, 1.4fx, (s2 - 1.4fx) / layers);
        sh_angle(0, 0deg, spread);
        sh_xform(0, BURST);
        sh_fire(0);
    }
    wait(60);
    acc = 0.05fx;                          // +130 move_acceleration(0.05f); move_angular_velocity(0.05235988f)
    var w: angle = 546bam;
    if mirror != 0 { w = -546bam; }
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }   // +190 角速度归零，继续加速
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 100)
async sub wave() {
    wait(120);
    // 100–164：Sub0 ×5（x 60..92）
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    _ = spawn_enemy(-124.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    _ = spawn_enemy(-116.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    _ = spawn_enemy(-108.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(16);
    _ = spawn_enemy(-100.0fx, -32.0fx, 1, 0, 0, 0, sub0(0)); wait(64);
    // 228–340：镜像 Sub0 ×8（x 324..268）
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(124.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(116.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(108.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(100.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(92.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(84.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(16);
    _ = spawn_enemy(76.0fx, -32.0fx, 1, 0, 0, 0, sub0(1)); wait(50);
    // 390–534：Sub2 左右成对 ×10
    for i in 0..10 {
        var off: fx = (i * 16) as fx;
        _ = spawn_enemy(-160.0fx + off, -32.0fx, 1, 0, 0, 0, sub2(0));
        _ = spawn_enemy(160.0fx - off, -32.0fx, 1, 0, 0, 0, sub2(1));
        if i < 9 { wait(16); }
    }
    wait(60);
    // 594–1064：Sub3 / Sub4 交替
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 3)); wait(60);   // 594
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 4)); wait(50);     // 654
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 4)); wait(50);    // 704
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 3)); wait(50);    // 754
    _ = spawn_enemy(-168.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 4)); wait(40);   // 804
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 4)); wait(40);    // 844
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 3)); wait(30);    // 884
    _ = spawn_enemy(152.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 4)); wait(30);    // 914
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 4)); wait(30);   // 944
    _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 3)); wait(20);     // 974
    _ = spawn_enemy(-168.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 4)); wait(20);   // 994
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 4)); wait(20);    // 1014
    _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 3)); wait(10);    // 1034
    _ = spawn_enemy(152.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 4)); wait(10);    // 1044
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, popcorn(0, 3)); wait(10);   // 1054
    _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, popcorn(1, 3));               // 1064
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
