// th06_s4_w01 —— 东方红魔乡 Stage 4 道中 第 1 波
// 原文：ecldata4.ecl.txt timeline 帧 330–410（Sub0） + sub Sub0（:2）/ Sub1（:18）
const TIME_LIMIT: int = 500;
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

// Sub1（行 18–41）：+30 起每 6 帧放一圈 KUNAI（每轮随机出弹口 / 角度 / 速度），12 轮后退场。
// 原文 bullet_circle 颗数：!E 2 / !N 4 / !H 8 / !L 16
async sub sub1() {
    set_invuln(65535);
    set_hitbox(4.0fx);                     // 段内无 enemy_set_hitbox → TH06 默认 (12,12,12)/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_interactable(0)
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ways: int = 2;                     // !E
    if rank == RANK_NORMAL { ways = 4; }   // !N
    else if rank == RANK_HARD { ways = 8; } // !H
    else if rank >= RANK_LUNATIC { ways = 16; } // !L
    wait(30);
    for k1 in 0..12 {
        var ox: fx = 80.0fx / 256 * rand(256) - 40.0fx;   // set_float_rand_bound_min($F0,80,-40)
        var oy: fx = 80.0fx / 256 * rand(256) - 40.0fx;   // set_float_rand_bound_min($F1,80,-40)
        var an: angle = rand(65536) as angle;             // set_float_rand_bound_min($F0,2π,-π) 整周
        var sp: fx = 1.0fx / 256 * rand(256) + 1.0fx;     // set_float_rand_bound_min($F1,1,1) → [1,2)
        sh_reset(0);
        sh_sprite(0, KUNAI, 6);
        sh_offset(0, ox, oy);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, ways, 1);
        sh_speed(0, sp, 0fx);
        sh_angle(0, an, 1024bam);
        sh_fire(0);
        wait(6);                          // jump_dec(30, …) 把时间设回 30 ⇒ 每轮 6 帧
    }
    wait(120);                            // +120: //156（末轮 jump_dec 落在 //36）
    die();
}

// Sub0（行 2–16）：以 90°、2.0 下冲 → +40 起 -0.06666667/帧 减速 30 帧到停 →
// +70 原地造 Sub1，然后以 [45°,135°) 随机角、1.8 飘出（出界由守卫退场）。
async sub sub0() {
    set_invuln(65535);
    set_hitbox(9.33fx);                   // enemy_set_hitbox(28,28,32) → min(28,32)/3
    spawn oob_guard();
    var ang: angle = 90deg;               // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                  // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub1);   // +70 enemy_create("Sub1", %SELF_X, %SELF_Y, …)
    acc = 0fx;                            // move_acceleration(0.0f)
    ang = 45deg + rand(16384) as angle;   // set_float_rand_bound_min($F0, π/2, π/4) → [45°,135°)
    spd = 1.8fx;                          // move_velocity(%F0, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9930);                           // +9930: //10000
    die();
}

// 导演任务：卡帧 = 120（开场缓冲） + (原文帧 − 330)；三对，每 40 帧一对
async sub wave() {
    wait(120);
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub0);   // 330
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub0);
    wait(40);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub0);   // 370
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub0);
    wait(40);
    _ = spawn_enemy(-64.0fx, -16.0fx, 1, 0, 0, 0, sub0);    // 410
    _ = spawn_enemy(64.0fx, -16.0fx, 1, 0, 0, 0, sub0);
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
