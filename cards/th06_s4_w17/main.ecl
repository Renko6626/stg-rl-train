// th06_s4_w17 —— 东方红魔乡 Stage 4 道中 第 17 波
// 原文：ecldata4.ecl.txt timeline 帧 7380（Sub11 / Sub17），E–L 四档；每只小怪无敌（D8）。
const TIME_LIMIT: int = 420;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const RICE: int = 64;      // TH06 弹型 2 RICE
const BALL: int = 48;      // TH06 弹型 3 BALL

// flags 5 = 0x1|0x4：出生冲刺（mapping §5）保留；0x4 出生特效有意不模拟（§4.2）
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

// Sub11：单只（原 x=96 → −96，y=−32）。下落 → 减速悬停 → 旋转米弹环 ×64（每 8 帧）→ 上飞离场。
// 原文全 [ENHL]，难度只改环的颗数 / 层数 / 基准速度。
async sub sub11() {
    set_invuln(65535);
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28,28,32) → 28/3（§8）
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;                   // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    var n: int = 1;                           // !E bullet_circle(2, 6, 1, 1, 2.6f, 1.8f, %F0, 0.0f, 4)
    var layers: int = 1;
    var s1: fx = 2.6fx;
    if rank == RANK_NORMAL { n = 3; layers = 2; }            // !N (3, 2, 2.6)
    else if rank == RANK_HARD { n = 5; layers = 3; s1 = 3.0fx; }  // !H (5, 3, 3.0)
    else if rank >= RANK_LUNATIC { n = 9; layers = 3; s1 = 3.2fx; }  // !L (9, 3, 3.2)
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                      // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }   // 30 帧后 spd≈0
    acc = 0fx;                                // +70 move_acceleration(0.0f)
    var f0: angle = rand(65536) as angle;     // set_float_rand_bound_min($F0, 2π, −π)
    var dir: angle = 2521bam;                 // set_int_rand_bound($I0,2); cmp_int; jump_neq
    var i0: int = rand(2);
    if i0 != 0 { dir = -2521bam; }
    for k2 in 0..64 {                         // set_int($I4, 64); jump_dec(70, Sub11_288, $I4)
        sh_reset(0);
        sh_sprite(0, RICE, 6);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, s1, (1.8fx - s1) / layers);
        sh_angle(0, f0, 0deg);
        sh_fire(0);                           // bullet_circle(2, 6, …)
        f0 = f0 + dir;                        // math_float_add($F0, %F0, %F1)
        wait(8);                              // +8
    }
    ang = -90deg;                             // move_velocity(-1.5707964f, 2.0f)
    spd = 2.0fx;
    move_vel(0, ang, spd, 0);
    wait(9922);                               // +9922 //10000
    die();                                    // enemy_delete(0)；实际先被 oob_guard 回收
}

// Sub17：两只（原 x=286/254 → 94/62，y=48）。原地不动，每 50 帧两圈自机狙环 ×6。
// 环 1 = bullet_offset_circle_aimed(0, 10, 11, 1, 1.2f, 1.0f, 0.0f, 0.0f, 5)：自机 + π/11 偏移
// 环 2 = bullet_circle_aimed(3, 10, 11, 1, 1.2f, 1.0f, %F1, 0.0f, 5)：%F1 未赋值（新敌 memset 0）
async sub sub17() {
    set_invuln(65535);
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28,28,32) → 28/3（§8）
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);         // enemy_flag_interactable(0)
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);         // +30 enemy_flag_interactable(1)
    var f1: angle = 0deg;                     // 原文 %F1 无 set_float，新敌默认 0
    for k in 0..6 {                           // set_int($I4, 6); jump_dec(30, Sub17_144, $I4)
        sh_reset(0);                          // 小玉环（半格偏移）
        sh_sprite(0, BULLET, 10);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 11, 1);
        sh_speed(0, 1.2fx, (1.0fx - 1.2fx) / 1);
        sh_angle(0, f1 + 2979bam, 0deg);      // 32768/11 = 2978.9 → 2979bam
        sh_xform(0, BURST);
        sh_fire(0);
        sh_reset(1);                          // 中玉环
        sh_sprite(1, BALL, 10);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, 11, 1);
        sh_speed(1, 1.2fx, (1.0fx - 1.2fx) / 1);
        sh_angle(1, f1, 0deg);
        sh_xform(1, BURST);
        sh_fire(1);
        wait(50);                             // +50
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);         // 循环结束 enemy_flag_interactable(0)
    wait(30);                                 // +30 //110
    die();                                    // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 7380)。三只同帧出场。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, sub11);   // 7380 Sub11
    _ = spawn_enemy(94.0fx, 48.0fx, 1, 0, 0, 0, sub17);     // 7380 Sub17
    _ = spawn_enemy(62.0fx, 48.0fx, 1, 0, 0, 0, sub17);     // 7380 Sub17
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
