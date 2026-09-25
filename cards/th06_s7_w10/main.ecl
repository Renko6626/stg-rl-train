// th06_s7_w10 —— 东方红魔乡 Stage 7(Extra) 道中第 10 波
// 原文：ecldata7 timeline 帧 4763–5253（Sub6 / Sub7 混编，共 31 只）；Extra 档
const TIME_LIMIT: int = 910;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const BALL: int = 48;      // TH06 弹型 3 BALL

// flags 3 = 0x1|0x2：0x1 出生冲刺（mapping §5），0x2 出生特效不模拟
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

// Sub6：move_velocity(π/2, 2.0) 下落 60 帧停住 → +70 两扇自机狙 RING_BALL → +130 加速 + 角速度(π/32/帧) 曲线飞走
async sub sub6(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // 镜像 180°−90° 仍是 90°
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                             // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 bullet_fan_aimed(1, 2, 3, 4, 6.0f, 2.0f, 0.0f, 0.06544985f, 3)
    sh_reset(0);
    sh_sprite(0, OUTLINE, 2);
    sh_offset(0, 12.0fx, -12.0fx);         // shoot_offset(12, -12, 0)，镜像不改
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 4);
    sh_speed(0, 6.0fx, (2.0fx - 6.0fx) / 4);
    sh_angle(0, 0deg, 683bam);             // a2 = 3.75°
    sh_xform(0, BURST);
    sh_fire(0);
    // +70 bullet_fan_aimed(1, 2, 2, 3, 6.6f, 2.1f, 0.0f, 0.06544985f, 3)
    sh_reset(1);
    sh_sprite(1, OUTLINE, 2);
    sh_offset(1, 12.0fx, -12.0fx);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 2, 3);
    sh_speed(1, 6.6fx, (2.1fx - 6.6fx) / 3);
    sh_angle(1, 0deg, 683bam);
    sh_xform(1, BURST);
    sh_fire(1);
    wait(60);
    // +130 move_acceleration(0.05f); move_angular_velocity(0.009817477f)
    acc = 0.05fx;
    w = 102bam;
    if mirror != 0 { w = -102bam; }
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +190 角速度 / 加速度归零，继续直飞
    acc = 0fx;
    loop { wait(1); }
}

// Sub7：move_velocity(0, 2.0) 水平入场 60 帧停住 → +70 两扇自机狙 BALL → +130 加速 + 角速度曲线飞走
async sub sub7(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 0deg;                 // 镜像 180°−0° = 180°
    var spd: fx = 2.0fx;
    var w: angle = 0deg;
    var acc: fx = 0fx;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(60);
    spd = 0fx;                             // +60 move_speed(0.0f)
    move_vel(0, ang, spd, 0);
    wait(10);
    // +70 bullet_fan_aimed(3, 2, 7, 4, 5.0f, 1.0f, 0.0f, 0.06544985f, 3)
    sh_reset(0);
    sh_sprite(0, BALL, 2);
    sh_offset(0, 12.0fx, -12.0fx);         // shoot_offset(12, -12, 0)，镜像不改
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 7, 4);
    sh_speed(0, 5.0fx, (1.0fx - 5.0fx) / 4);
    sh_angle(0, 0deg, 683bam);             // a2 = 3.75°
    sh_xform(0, BURST);
    sh_fire(0);
    // +70 bullet_fan_aimed(3, 2, 6, 3, 4.6f, 1.1f, 0.0f, 0.06544985f, 3)
    sh_reset(1);
    sh_sprite(1, BALL, 2);
    sh_offset(1, 12.0fx, -12.0fx);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 6, 3);
    sh_speed(1, 4.6fx, (1.1fx - 4.6fx) / 3);
    sh_angle(1, 0deg, 683bam);
    sh_xform(1, BURST);
    sh_fire(1);
    wait(60);
    // +130 move_acceleration(0.05f); move_angular_velocity(0.009817477f)
    acc = 0.05fx;
    w = 102bam;
    if mirror != 0 { w = -102bam; }
    for k1 in 0..60 { ang = ang + w; spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +190 角速度 / 加速度归零，继续直飞
    acc = 0fx;
    loop { wait(1); }
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文 timeline 帧 − 4763)
async sub wave() {
    wait(120);
    // 4763–4823：Sub6 三连（-128 / +128mirror / 0）
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(30);
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(30);
    _ = spawn_enemy(0.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(90);
    // 4913–4943：Sub7 对 + Sub6 对
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub7(0)); wait(10);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(64.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(10);
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(90);
    // 5033–5063：Sub7 四连（y = 128 / 128 / 64 / 64）
    _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub7(0)); wait(10);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub7(0)); wait(10);
    // 5073–5083：Sub6 对
    _ = spawn_enemy(48.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(10);
    _ = spawn_enemy(-48.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(60);
    // 5143–5178：Sub6 八连，间隔 5 帧，左右交替向中心收拢
    _ = spawn_enemy(32.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(5);
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(5);
    _ = spawn_enemy(64.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(5);
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(5);
    _ = spawn_enemy(96.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(5);
    _ = spawn_enemy(-96.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(5);
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub6(1)); wait(5);
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub6(0)); wait(30);
    // 5208–5253：Sub7 十连，y = 96 起每两步 +32
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub7(1)); wait(5);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub7(0)); wait(5);
    _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, sub7(1)); wait(5);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub7(0)); wait(5);
    _ = spawn_enemy(224.0fx, 160.0fx, 1, 0, 0, 0, sub7(1)); wait(5);
    _ = spawn_enemy(-224.0fx, 160.0fx, 1, 0, 0, 0, sub7(0)); wait(5);
    _ = spawn_enemy(224.0fx, 192.0fx, 1, 0, 0, 0, sub7(1)); wait(5);
    _ = spawn_enemy(-224.0fx, 192.0fx, 1, 0, 0, 0, sub7(0)); wait(5);
    _ = spawn_enemy(224.0fx, 224.0fx, 1, 0, 0, 0, sub7(1)); wait(5);
    _ = spawn_enemy(-224.0fx, 224.0fx, 1, 0, 0, 0, sub7(0));
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
