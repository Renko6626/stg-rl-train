// th06_s1_w04 —— 东方红魔乡 Stage 1 道中 第 4 波（中 boss 登场后的道中）
// 原文：ecldata1.ecl.txt timeline 帧 2282–4172（Sub3 / Sub4 交替，30 帧一只共 64 只）
const TIME_LIMIT: int = 2370;      // unit.json 的 time_limit
const OUTLINE: int = 32;           // TH06 弹型 1 RING_BALL

// flags 3 = 0x1|0x2：出生冲刺（mapping §5）；0x2 出生特效不模拟
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

// Sub3：下落 60 帧停住 → +70 自机狙扇（四档：3/7/9/11 颗）→ +130 加速回转飞走
async sub sub3(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_offset(0, 12.0fx, -12.0fx);         // shoot_offset(12.0f, -12.0f, 0.0f)，镜像不改
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)，镜像 180°−90° 仍是 90°
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                             // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 !E (3,1,s2=0,45°) / !N (7,1,36°) / !H (9,2,s2=0.5,22.5°) / !L (11,2,s2=0.5,9°)
    var rank: int = global(GVAR_RANK);
    var n: int = 3;
    var layers: int = 1;
    var s2: fx = 0.3fx;                    // s2 = 0.0f 按 0.3 钳
    var spread: angle = 8192bam;           // π/4
    if rank == RANK_NORMAL { n = 7; spread = 6554bam; }
    else if rank == RANK_HARD { n = 9; layers = 2; s2 = 0.5fx; spread = 4096bam; }
    else if rank >= RANK_LUNATIC { n = 11; layers = 2; s2 = 0.5fx; spread = 1638bam; }
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, layers);
    sh_speed(0, 1.4fx, (s2 - 1.4fx) / layers);
    sh_angle(0, 0deg, spread);
    sh_xform(0, BURST);
    sh_fire(0);
    wait(60);
    acc = 0.05fx;                          // +130 move_acceleration(0.05f); move_angular_velocity(0.05235988f)
    var w: angle = 546bam;
    if mirror != 0 { w = -546bam; }
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }   // +190 角速度归零，继续加速
}

// Sub4：与 Sub3 同构，仅 Lunatic 在 +70 发 5 颗自机狙扇
async sub sub4(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_offset(0, 12.0fx, -12.0fx);
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;
    move_vel(0, ang, spd, 0);
    wait(10);
    if global(GVAR_RANK) >= RANK_LUNATIC {
        // +70 !L (5, 1, s1=1.4, s2=0, 15°)
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, 5, 1);
        sh_speed(0, 1.4fx, (0.3fx - 1.4fx) / 1);
        sh_angle(0, 0deg, 2731bam);
        sh_xform(0, BURST);
        sh_fire(0);
    }
    wait(60);
    acc = 0.05fx;                          // +130
    var w: angle = 546bam;
    if mirror != 0 { w = -546bam; }
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    loop { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
}

// 导演任务：原文第一只在帧 2282 ⇒ 卡帧 = 120 + (原文帧 − 2282)
// 16 只一组的固定编队重复 4 次，间隔 30 帧：Sub3c, Sub4m, Sub4c, Sub3m, Sub4c, Sub4m, Sub3c, Sub4m,
// Sub4c, Sub3m, Sub4c, Sub4m, Sub3c, Sub4m, Sub3c, Sub3m
async sub wave() {
    wait(120);
    for rep in 0..4 {
        _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub3(0)); wait(30);
        _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(30);
        _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub4(0)); wait(30);
        _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub3(1)); wait(30);
        _ = spawn_enemy(-168.0fx, -32.0fx, 1, 0, 0, 0, sub4(0)); wait(30);
        _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(30);
        _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sub3(0)); wait(30);
        _ = spawn_enemy(152.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(30);
        _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub4(0)); wait(30);
        _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, sub3(1)); wait(30);
        _ = spawn_enemy(-168.0fx, -32.0fx, 1, 0, 0, 0, sub4(0)); wait(30);
        _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(30);
        _ = spawn_enemy(-48.0fx, -32.0fx, 1, 0, 0, 0, sub3(0)); wait(30);
        _ = spawn_enemy(152.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(30);
        _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub3(0)); wait(30);
        _ = spawn_enemy(48.0fx, -32.0fx, 1, 0, 0, 0, sub3(1)); wait(30);
    }
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
