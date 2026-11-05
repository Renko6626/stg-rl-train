// th06_s4_w07 —— 东方红魔乡 Stage 4 道中 第 7 波
// 原文：ecldata4.ecl.txt timeline 帧 2304–2328（Sub11 / Sub13），子敌 Sub11(:225)、Sub13(:266)
const TIME_LIMIT: int = 444;
const RICE: int = 64;   // TH06 弹型 2 RICE

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

// Sub11：从上方下落（90°）减速停住 → 64 次螺旋环（每 8 帧一次，基角每发转 ±13.85°）
//   !E bullet_circle(2,6, 1,1, 2.6,1.8) / !N (3,2,2.6,1.8) / !H (5,3,3.0,1.8) / !L (9,3,3.2,1.8)
async sub sub11(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    if mirror != 0 { ang = 180deg - ang; }
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)

    var rank: int = global(GVAR_RANK);
    var n: int = 1;
    var layers: int = 1;
    var s1: fx = 2.6fx;
    var s2: fx = 1.8fx;
    if rank == RANK_NORMAL { n = 3; layers = 2; }
    else if rank == RANK_HARD { n = 5; layers = 3; s1 = 3.0fx; }
    else if rank >= RANK_LUNATIC { n = 9; layers = 3; s1 = 3.2fx; }

    var f0: angle = rand(65536) as angle;  // set_float_rand_bound_min($F0, 6.2831855f, -3.1415927f)
    var f1: angle = 2521bam;               // set_float($F1, 0.24166097f)
    if rand(2) != 0 { f1 = -2521bam; }     // set_int_rand_bound($I0,2) + jump_neq → 另一支 -0.24166097f

    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, layers);
    sh_speed(0, s1, (s2 - s1) / layers);
    for k2 in 0..64 {                      // $I4=64；jump_dec(70, Sub11_288)
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + f1;                      // math_float_add($F0, %F0, %F1)
        wait(8);
    }
    move_vel(0, 270deg, 2.0fx, 0);         // move_velocity(-1.5707964f, 2.0f)（镜像等价）
    wait(9922);                            // +9922 → enemy_delete(0)
}

// Sub13：从左右两侧横向飞入（0°，镜像 180°）减速停住 → 64 次螺旋环（全难度同一参数）
//   bullet_circle(2,6, 3,2, 2.1,1.4, %F0, 0.0f, 4)
async sub sub13(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 2.0f)
    if mirror != 0 { ang = 180deg - ang; }
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)

    var f0: angle = rand(65536) as angle;
    var f1: angle = 2521bam;
    if rand(2) != 0 { f1 = -2521bam; }

    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 3, 2);
    sh_speed(0, 2.1fx, (1.4fx - 2.1fx) / 2);
    for k2 in 0..64 {
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + f1;
        wait(8);
    }
    move_vel(0, 270deg, 2.0fx, 0);
    wait(9922);
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2304)
async sub wave() {
    wait(120);
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub11(0));    // 2304
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, sub11(1));
    wait(24);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub13(0));    // 2328
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub13(1));
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
