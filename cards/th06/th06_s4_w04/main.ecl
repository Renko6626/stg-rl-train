// th06_s4_w04 —— 东方红魔乡 Stage 4 道中 第 4 波
// 原文：ecldata4.ecl.txt timeline 帧 1430–1494（Sub10 三对 + Sub1 子敌）
const TIME_LIMIT: int = 484;
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI

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

// Sub1：+30 起 12 轮环形弹，每轮随机出弹口偏移与随机初角；+156 退场
async sub sub1() {
    set_invuln(65535);
    set_hitbox(4.0fx);                       // 段内无 enemy_set_hitbox，TH06 默认 (12,12,12) → 12/3
    set_enemy_flag(ENEMY_NO_BODY, 1);        // enemy_flag_interactable(0)
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var n: int = 2;                          // !E
    if rank == RANK_NORMAL { n = 4; }        // !N
    else if rank == RANK_HARD { n = 8; }     // !H
    else if rank >= RANK_LUNATIC { n = 16; } // !L
    // 等效截止（mapping §4.2b）：Lunatic 无截止峰值 1038 > 1024，原作 640 池也会丢弃末段，
    // 故 Lunatic 只发前 11 轮，其余档照抄 12 轮。
    var rounds: int = 12;
    if rank >= RANK_LUNATIC { rounds = 11; }
    wait(30);
    for k in 0..12 {
        if k < rounds {
            var ox: fx = -40.0fx + 80.0fx / 256 * rand(256);   // set_float_rand_bound_min($F0, 80, -40)
            var oy: fx = -40.0fx + 80.0fx / 256 * rand(256);   // set_float_rand_bound_min($F1, 80, -40)
            var an: angle = rand(65536) as angle;              // set_float_rand_bound_min($F0, 2π, -π)
            var sp: fx = 1.0fx + 1.0fx / 256 * rand(256);      // set_float_rand_bound_min($F1, 1, 1) → [1,2)
            sh_reset(0);
            sh_sprite(0, KUNAI, 6);
            sh_offset(0, ox, oy);                              // shoot_offset(%F0, %F1, 0)
            sh_aim(0, 0);
            sh_ring(0, 1);
            sh_count(0, n, 1);
            sh_speed(0, sp, 0.3fx - sp);                       // s2 = 0.0f 按 0.3 钳
            sh_angle(0, an, 1024bam);                          // a1 = %F0，a2 = π/32
            sh_fire(0);
        }
        wait(6);                                           // jump_dec(30, Sub1_68, $I4)，12 轮
    }
    wait(120);                                             // +120: //156
    die();
}

// Sub10：水平直飞 40 帧 → 30 帧减速 → +70 在当前位置生成 Sub1，随机下向角 1.8 飞走
// 镜像只取反水平速度（mapping §6.1）
async sub sub10(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                      // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    var ang: angle = 0deg;                   // move_velocity(0.0f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                     // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70：enemy_create("Sub1", ...) 生成子敌（不继承父敌状态，mapping §6.1b）
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub1());
    acc = 0fx;                               // move_acceleration(0.0f)
    var an2: angle = 8192bam + rand(16384) as angle;   // set_float_rand_bound_min($F0, π/2, π/4) → [45°,135°)
    if mirror != 0 { an2 = 180deg - an2; }
    spd = 1.8fx;
    move_vel(0, an2, spd, 0);                // move_velocity(%F0, 1.8f)
    wait(10000);                             // +9930: //10000 enemy_delete；实际靠出界守卫退场
}

// 导演任务：卡帧 = 120（开场缓冲）+ (原文帧 − 1430)
async sub wave() {
    wait(120);
    // 1430：Sub10 三对之第一对（y=48）
    _ = spawn_enemy(-224.0fx, 48.0fx, 1, 0, 0, 0, sub10(0));
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub10(1));
    wait(32);
    // 1462：第二对（y=96）
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub10(0));
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub10(1));
    wait(32);
    // 1494：第三对（y=160）
    _ = spawn_enemy(-224.0fx, 160.0fx, 1, 0, 0, 0, sub10(0));
    _ = spawn_enemy(224.0fx, 160.0fx, 1, 0, 0, 0, sub10(1));
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
