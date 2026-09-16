// th06_s3_w10 —— 东方红魔乡 Stage 3 道中 第 10 波（双翼怪 Sub7 / Sub8）
// 原文：ecldata3 timeline 帧 5054–5174（Sub7 :167-199 / Sub8 :201-224），E–L 四档。
const TIME_LIMIT: int = 600;
const BALL: int = 48;      // TH06 弹型 3 BALL
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI

// flags 25 = 0x1|0x8|0x10 + bullet_effects(-1,-1,-1,-1, 0.025f, π/2, -1, -1)：
// 出生冲刺 16 帧（额外 +5 线性衰减到 0），此后永久沿 90°（向下）加速 0.025（mapping §5）。
// 0x8 的出生 1/3 速不模拟；0x10 的 i0 = -1 视为永久，故不写 stop_fx。
xformdef DASH_GRAV {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0fx, 0.025fx);
}

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

// Sub8（原文 :201-224）：2.5 下落 → +40 起 30 帧减速到停（acc −1/12）→
// +70 随机散弹 N 颗（BALL 色 15，角度 [−180°,0°)，速度 [0.3,2.0)，flags 0x19）→
// 随机方向 1.5 飞走；镜像只取反水平速度。
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var ang: angle = 90deg;
    var spd: fx = 2.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -1.0fx / 12;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 bullet_random(3, 15, 8/14/20/22, 1, 2.0f, 0.3f, 0.0f, -π, 25)
    var rank: int = global(GVAR_RANK);
    var n: int = 8;                        // !E
    if rank == RANK_NORMAL { n = 14; }      // !N
    else if rank == RANK_HARD { n = 20; }   // !H
    else if rank >= RANK_LUNATIC { n = 22; }// !L
    var sp: fx = 0fx;
    var an: angle = 0deg;
    for k2 in 0..n {
        sp = 0.3fx + 1.7fx / 256 * rand(256);      // [0.3, 2.0)
        an = -180deg + rand(32768) as angle;       // [-180°, 0°)
        _ = fire(BALL, 15, $self_x, $self_y, sp, an, DASH_GRAV, none);
    }
    // 收尾 move_velocity(%F2, 1.5f)，%F2 = [0,π/2)+π/4 = [45°,135°)；镜像 180°−a
    var a2: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a2 = 180deg - a2; }
    move_vel(0, a2, 1.5fx, 0);
    wait(9800);
    die();
}

// Sub7（原文 :167-199）：1.5 下落 → +40 起 30 帧减速到停（acc −0.05）→
// +70 起每 2 帧一发 KUNAI 扇（速度 1.6 起每轮 +0.3）；H 额外先发一圈 16 向自机狙环；
// 循环 12(E) / 16(NHL) 轮后随机方向 −1.5 飞走；镜像只取反水平速度。
async sub sub7(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 set_float($F0, π/2); set_float($F1, 1.6); set_int($I4, 12/16); move_acceleration(0)
    var rank: int = global(GVAR_RANK);
    var f1: fx = 1.6fx;
    var i4: int = 12;                      // !E
    var step: angle = 1365bam;             // !E/!N 7.5°（单发时无关）
    var n_fan: int = 1;
    var hcircle: int = 0;
    if rank == RANK_NORMAL { i4 = 16; }                              // !N
    else if rank == RANK_HARD { i4 = 16; step = 4096bam; hcircle = 1; }  // !H
    else if rank >= RANK_LUNATIC { i4 = 16; step = 5461bam; n_fan = 5; } // !L
    // !H bullet_circle_aimed(3, 6, 16, 1, 1.6f, 0, π/2, π/8, 4)：16 向自机狙环（0 号槽）
    if hcircle != 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, 90deg, 4096bam);
        sh_fire(0);
    }
    // 每 2 帧一发 fan（1 号槽）：!E/!N 1 发、!H 1 发、!L 5 发 × 1 层
    sh_reset(1);
    sh_sprite(1, KUNAI, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    sh_count(1, n_fan, 1);
    sh_angle(1, 90deg, step);
    for k2 in 0..i4 {
        sh_speed(1, f1, 0fx);
        sh_fire(1);
        f1 = f1 + 0.3fx;
        wait(2);
    }
    // 收尾 move_velocity(%F2, -1.5f)，%F2 = [45°,135°)；镜像 180°−a
    var a2: angle = 45deg + rand(16384) as angle;
    if mirror != 0 { a2 = 180deg - a2; }
    move_vel(0, a2, -1.5fx, 0);
    wait(9800);
    die();
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5054)。原文 5054 第一对 Sub8，5134 起五对 Sub7，
// 5174 第五对 Sub7 同帧再补一对 Sub8。
async sub wave() {
    wait(120);
    // 5054 (+0)：Sub8 双翼 x 60 / 324 → −132 / +132
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
    wait(80);
    // 5134 (+80)：Sub7 双翼 x 32 / 352 → −160 / +160
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(10);
    // 5144 (+90)：x 80 / 304 → −112 / +112
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(10);
    // 5154 (+100)：x 128 / 256 → −64 / +64
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(10);
    // 5164 (+110)：x 176 / 208 → −16 / +16
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    wait(10);
    // 5174 (+120)：Sub7 双翼 x 224 / 160 → +32 / −32；同帧 Sub8 双翼 x 120 / 264 → −72 / +72
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
    _ = spawn_enemy(-72.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(72.0fx, -32.0fx, 1, 0, 0, 0, sub8(1));
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
