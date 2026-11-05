// th06_s4_w16 —— 东方红魔乡 Stage 4 道中第 16 波
// 原文：ecldata4.ecl.txt timeline 帧 6482–6870（Sub16 / Sub18 / Sub20 / Sub7）
const TIME_LIMIT: int = 808;
const BALL: int = 48;    // TH06 弹型 3 BALL
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI

// flags 0x1 出生冲刺（mapping §5）
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

// Sub16：定点，+30 开体碰后 10 轮环形自机狙（jump_dec 30, Sub16_144, $I4=10）
async sub sub16() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);          // enemy_flag_interactable(1)
    var rank: int = global(GVAR_RANK);
    var n: int = 8;                            // !E
    var layers: int = 1;
    var s1: fx = 1.4fx;
    var s2: fx = 1.0fx;
    if rank == RANK_NORMAL { n = 16; }                                  // !N
    else if rank == RANK_HARD { n = 24; layers = 2; s1 = 2.4fx; }       // !H
    else if rank >= RANK_LUNATIC { n = 32; layers = 3; s1 = 3.0fx; }    // !L
    for k1 in 0..10 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, s1, (s2 - s1) / layers);
        sh_angle(0, 0deg, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        wait(50);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);
    die();                                     // +110 enemy_delete(0)
}

// Sub18：下落到 +70 停下，原地留一只站桩的 Sub20，再随机角 [45°,135°) 1.8 速飞走
async sub sub18() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32)
    var ang: angle = 90deg;                    // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                       // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70 -0.06666667 * 30 恰好把速度降到 0
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub20());   // enemy_create("Sub20", %SELF_X, %SELF_Y, …)
    acc = 0fx;                                 // move_acceleration(0.0f)
    ang = 45deg + rand(16384) as angle;        // set_float_rand_bound_min($F0, π/2, π/4)
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);
    wait(9930);
}

// Sub20：不可交互的站桩激光（+120 建 90° 下射激光；H/L 追加环形苦无）
async sub sub20() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(4.0fx);                         // 未设 hitbox ⇒ TH06 默认 12/3
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
    wait(120);
    var rank: int = global(GVAR_RANK);
    // laser_create(sprite 0, color 6, a=π/2, sp=0, st=0, en=500, sl=500, w=32, T0=90, T1=120, T2=16, …)
    // 原点 = 敌位置 + shoot_offset(0,0)；sprite 0 → 8 色表 [6] = 13；宽 32/2 = 16
    var lz: int = laser(13, $self_x, $self_y, 16384bam, 500.0fx, 16.0fx, 90, 120, 16);
    var n: int = 0;                            // !E / !N 不发弹
    var layers: int = 1;
    if rank == RANK_HARD { n = 16; }                                    // !H
    else if rank >= RANK_LUNATIC { n = 32; layers = 2; }                // !L
    if n > 0 {
        sh_reset(0);
        sh_sprite(0, KUNAI, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, 1.2fx, (0.3fx - 1.2fx) / layers);   // s2=0.0f 按 0.3 钳
        sh_angle(0, 0deg, 1024bam);                     // a2 = 5.625°
        sh_fire(0);                                     // flags 4 = 出生特效，不模拟
    }
    wait(200);
    wait(120);
    die();                                     // +440 enemy_delete(0)
}

// Sub7：斜射入场的转圈小怪（不体碰，弹角度不镜像）
async sub sub7(mirror: int) {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32)
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_collision(0)
    var ang: angle = -60deg;                   // move_velocity(-1.0471976f, 4.5f)
    var spd: fx = 4.5fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }     // 镜像只取反水平速度
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 683bam;                                // +30 move_angular_velocity(0.06544985f)
    if mirror != 0 { w = -683bam; }
    for k1 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                                  // +110 角速度归零
    wait(9890);
    die();
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 6482)
async sub wave() {
    wait(120);
    // 6482：Sub16 ×2
    _ = spawn_enemy(-144.0fx, 96.0fx, 1, 0, 0, 0, sub16());
    _ = spawn_enemy(144.0fx, 96.0fx, 1, 0, 0, 0, sub16());
    wait(60);
    // 6542：Sub18 ×2
    _ = spawn_enemy(-144.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(144.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 6574：Sub18 ×2
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 6606：Sub18 ×2
    _ = spawn_enemy(-32.0fx, -16.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(32.0fx, -16.0fx, 1, 0, 0, 0, sub18());
    wait(60);
    // 6666–6796：Sub7 左右交替 ×14（每 10 帧一只，末只后仍等 10）
    for i1 in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub7(0));
        wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub7(1));
        wait(10);
    }
    // 6806：Sub18 ×2
    _ = spawn_enemy(-168.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(168.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 6838：Sub18 ×2
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 6870：Sub18 ×2
    _ = spawn_enemy(-48.0fx, -16.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(48.0fx, -16.0fx, 1, 0, 0, 0, sub18());
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
