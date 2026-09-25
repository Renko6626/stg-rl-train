// th06_s7_b12 —— 东方红魔乡 Stage 7 boss 符卡 禁弾「スターボウブレイク」
// 原文：ecldata7.ecl.txt Sub66 → Sub67（宣言 + 移到中央）+ Sub68（出怪循环），Sub69/Sub70 发弹；原时限 4200 → 3000。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 126;
const BALL: int = 48;          // TH06 弹型 3 BALL 中玉

// bullet_effects(180,-1,-1,-1, f2, 90°, -1,-1) + flags 19 = 0x10|0x2|0x1：
//   0x1  出生冲刺 +5，16 帧内线性衰减到 0；
//   0x10 前 180 帧沿固定角 +90°（下）加速度 f2。
//   f2 ∈ [0.015,0.025)（Sub69）/ [0.012,0.025)（Sub70）；xformdef 只能写常量，取中值近似。
xformdef STAR69 { add_speed(5.0fx); @16 set_accel(-0.3125fx); @164 set_gravity(0fx, 0.02fx); stop_fx(); }
xformdef STAR70 { add_speed(5.0fx); @16 set_accel(-0.3125fx); @104 set_gravity(0fx, 0.0185fx); stop_fx(); }

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

// 原文 Sub69：enemy_create 的 z 当出弹口/移动角；life%100 当色号；每 4 帧 1 颗 × 50，然后 enemy_delete
async sub Sub69(ang: angle, col: int) {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);            // invisible=1 / collision=0 / interactable=0
    set_hitbox(18.67fx);                         // enemy_set_hitbox(56,56,32)
    spawn oob_guard();
    sh_reset(0);
    sh_sprite(0, BALL, col);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_angle(0, -16384bam, 0deg);                // bullet_fan 中轴 a1 = -π/2
    sh_offset(0, 0.0fx, -12.0fx);                // shoot_offset(0,-12,0)
    sh_xform(0, STAR69);
    move_vel(0, ang, 5.8fx, 0);                  // move_velocity(%F0, 5.8f)
    for k in 0..50 {
        var sp: fx = 1.0fx / 256 * rand(256);    // set_float_rand_bound($F1, 1.0f)
        if sp > 0fx && sp < 0.3fx { sp = 0.3fx; }  // s1≠0 钳到 ≥0.3（§4.2，EclManager.cpp:387-393）
        sh_speed(0, sp, 0fx);
        sh_fire(0);
        wait(4);
    }
    die();
}

// 原文 Sub70：速度 5.0；每轮把朝向 +0.014959965f（156bam）后重设速度（螺旋）
async sub Sub70(ang0: angle, col: int) {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_hitbox(18.67fx);
    spawn oob_guard();
    var ang: angle = ang0;
    sh_reset(0);
    sh_sprite(0, BALL, col);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_angle(0, -16384bam, 0deg);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_xform(0, STAR70);
    move_vel(0, ang, 5.0fx, 0);
    for k in 0..50 {
        var sp: fx = 1.0fx / 256 * rand(256);
        if sp > 0fx && sp < 0.3fx { sp = 0.3fx; }  // s1≠0 钳到 ≥0.3
        sh_speed(0, sp, 0fx);
        sh_fire(0);
        ang = ang + 156bam;
        move_vel(0, ang, 5.0fx, 0);
        wait(4);
    }
    die();
}

// 原文 Sub68 的 boss 游走：move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(90)。
// 边界沿用 Sub65 的 move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)。
sub wander() {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
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
    var d: fx = 2.5fx * 90 / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(90, tx, ty, 2);
}

// 原文 Sub68：Sub68_16 起的一段 + 末尾 jump(0, Sub68_16) 的循环体（一轮 717 帧）
sub attack_cycle() {
    // Sub68_16：effect_particle × 30（丢弃）→ 60 帧
    for k1 in 0..30 { wait(2); }
    // 在 boss 位置朝下半周铺 6 只 Sub69（角度=z，色=life%100）
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(24576bam, 2));
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(28672bam, 14));
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(32768bam, 13));
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(8192bam, 4));
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(4096bam, 8));
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, Sub69(0bam, 11));
    wait(60);
    // +62：游走
    wander();
    // Sub68_420：effect_particle × 30（丢弃）→ 60 帧
    for k2 in 0..30 { wait(2); }
    // +64：左列（x=192 换算后 -224）
    _ = spawn_enemy(-224.0fx, 336.0fx, 1, 0, 0, 0, Sub69(-6144bam, 4));
    wait(10);
    _ = spawn_enemy(-224.0fx, 304.0fx, 1, 0, 0, 0, Sub70(-6144bam, 6));
    wait(10);
    _ = spawn_enemy(-224.0fx, 272.0fx, 1, 0, 0, 0, Sub69(-6144bam, 8));
    wait(10);
    _ = spawn_enemy(-224.0fx, 240.0fx, 1, 0, 0, 0, Sub70(-6144bam, 11));
    wait(10);
    _ = spawn_enemy(-224.0fx, 208.0fx, 1, 0, 0, 0, Sub69(-6144bam, 13));
    wait(10);
    _ = spawn_enemy(-224.0fx, 176.0fx, 1, 0, 0, 0, Sub70(-6144bam, 14));
    wait(10);
    _ = spawn_enemy(-224.0fx, 144.0fx, 1, 0, 0, 0, Sub69(-6144bam, 2));
    wait(90);
    // +214：游走
    wander();
    wait(60);
    // +274：右列（x=416 换算后 224）
    _ = spawn_enemy(224.0fx, 336.0fx, 1, 0, 0, 0, Sub69(34816bam, 4));
    wait(10);
    _ = spawn_enemy(224.0fx, 304.0fx, 1, 0, 0, 0, Sub70(34816bam, 6));
    wait(10);
    _ = spawn_enemy(224.0fx, 272.0fx, 1, 0, 0, 0, Sub69(34816bam, 8));
    wait(10);
    _ = spawn_enemy(224.0fx, 240.0fx, 1, 0, 0, 0, Sub70(34816bam, 11));
    wait(10);
    _ = spawn_enemy(224.0fx, 208.0fx, 1, 0, 0, 0, Sub69(34816bam, 13));
    wait(10);
    _ = spawn_enemy(224.0fx, 176.0fx, 1, 0, 0, 0, Sub70(34816bam, 14));
    wait(10);
    _ = spawn_enemy(224.0fx, 144.0fx, 1, 0, 0, 0, Sub69(34816bam, 2));
    wait(140);
    // +474：左右交替的单列
    _ = spawn_enemy(-224.0fx, 336.0fx, 1, 0, 0, 0, Sub69(0bam, 4));
    wait(10);
    _ = spawn_enemy(224.0fx, 304.0fx, 1, 0, 0, 0, Sub69(32768bam, 6));
    wait(10);
    _ = spawn_enemy(-224.0fx, 272.0fx, 1, 0, 0, 0, Sub69(0bam, 8));
    wait(10);
    _ = spawn_enemy(224.0fx, 240.0fx, 1, 0, 0, 0, Sub69(32768bam, 11));
    wait(10);
    _ = spawn_enemy(-224.0fx, 208.0fx, 1, 0, 0, 0, Sub69(0bam, 13));
    wait(10);
    _ = spawn_enemy(224.0fx, 176.0fx, 1, 0, 0, 0, Sub69(32768bam, 14));
    wait(10);
    _ = spawn_enemy(-224.0fx, 144.0fx, 1, 0, 0, 0, Sub69(0bam, 2));
    // +534：move_position_time_decelerate(60, 192, 224)；Sub65 的 move_bounds_set 每帧把 y 夹在 ≤120（§7），目标点先夹成 (0,120)
    move_to(60, 0.0fx, 120.0fx, 2);
    wait(60);
    wait(7);            // +601 jump(0, Sub68_16)
}

async sub pattern() {
    // Sub67
    kill_all_enemies(KILL_SILENT);
    set_enemy_flag(ENEMY_NO_BODY, 0);            // enemy_flag_collision(1)
    move_to(120, 0.0fx, 80.0fx, 2);              // move_position_time_decelerate(120,192,80)
    wait(120);                                   // +120 ret
    // Sub68 的无限循环
    loop { attack_cycle(); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
