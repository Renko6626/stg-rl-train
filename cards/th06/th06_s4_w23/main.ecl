// th06_s4_w23 —— 东方红魔乡 Stage 4 道中 第 23 波
// 原文：ecldata4.ecl.txt timeline 帧 9730–10080（Sub11 三只 + Sub9 双侧 25 对）
const TIME_LIMIT: int = 720;

const RICE: int = 64;   // TH06 弹型 2 RICE 米弹

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

// Sub11（原文行 225–257）：y=-32 下落 2.0 → +40 减速 30 帧停在 y≈77 →
// +70 起每 8 帧发一次旋转环，共 64 发 → 发完 -90° 上飞 2.0，出界由守卫删除。
// bullet_circle(2, 6, c1, c2, s1, 1.8f, %F0, 0.0f, 4)：角度 i·2π/c1 + %F0；
// %F0 每发累加 ±2521bam（±13.85°），构成旋转；flags 4 出生特效不模拟（mapping §4.2）。
async sub sub11() {
    set_invuln(65535);
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;                   // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    // +40 move_acceleration(-0.06666667f)：30 帧内 2.0 → 0.0
    acc = -0.06666667fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;
    // +70：随机整周起始角；随机正负每发偏转 2521bam
    var f0: angle = rand(65536) as angle;     // set_float_rand_bound_min($F0, 2π, -π)
    var f1: angle = 2521bam;
    var i0: int = rand(2);                    // set_int_rand_bound($I0, 2)
    if i0 != 0 { f1 = -2521bam; }             // cmp_int + jump_neq：i0!=0 → 负
    var c1: int = 1;                          // !E
    var c2: int = 1;
    var s1: fx = 2.6fx;
    // H/L 的层级按 §4.2b 640 等效截止折减（见 report）
    if rank == RANK_NORMAL { c1 = 3; c2 = 2; }                              // !N
    else if rank == RANK_HARD { c1 = 5; c2 = 2; s1 = 3.0fx; }               // !H（原 c2=3）
    else if rank >= RANK_LUNATIC { c1 = 9; c2 = 1; s1 = 3.2fx; }            // !L（原 c2=3）
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, c1, c2);
    sh_speed(0, s1, (1.8fx - s1) / c2);
    // jump_dec(70, Sub11_288, $I4=64)：循环体 8 帧一轮，共 64 轮
    for k2 in 0..64 {
        sh_angle(0, f0, 0deg);
        sh_fire(0);
        f0 = f0 + f1;                         // math_float_add($F0, %F0, %F1)
        wait(8);
    }
    move_vel(0, -90deg, 2.0fx, 0);            // move_velocity(-1.5707964f, 2.0f)
    wait(9922);                               // +9922: //10000
}

// Sub9（原文行 189–207）的自动射击（shoot_interval_delayed(50)，+100 停）。
// bullet_fan_aimed(2, 6, c1, 2, s1, 1.2f, 0.0f, 10°, 4)：自机方向中轴、间隔 1820bam 对称扇。
// 写法 A（mapping §4.3）：原作首发偏移 k = (50−1) − rand(50)；停火守卫比较 k 本身。
async sub autoshoot9() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 2;                          // !E
    var c2: int = 2;
    var s1: fx = 2.0fx;
    if rank == RANK_NORMAL { c1 = 3; }                                      // !N
    else if rank == RANK_HARD { c1 = 3; c2 = 2; s1 = 2.3fx; }               // !H（Sub9 颗数折减，c2 保原）
    else if rank >= RANK_LUNATIC { c1 = 9; c2 = 1; s1 = 2.3fx; }            // !L（原 c2=2）
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, c2);
    sh_speed(0, s1, (1.2fx - s1) / c2);
    sh_angle(0, 0deg, 1820bam);               // a1=0° / a2=10°
    // 原文在设定帧 S 执行 shoot_interval_delayed(50)，until = S+100；k 从 S 起算。
    // delayed 首发 k = 49 − rand(50)；伴生任务出生当帧不跑（首跑 S+1），故 wait(k−1) 落在 S+k。
    var until: int = 100;
    var k: int = 50 - 1 - rand(50);
    if k >= until { return; }
    if k > 0 { wait(k - 1); }                 // k==0 只能在 S+1 发，晚 1 帧，概率 1/50
    loop {
        sh_fire(0);
        if k + 50 >= until { return; }
        wait(50);
        k = k + 50;
    }
}

// Sub9：x1=-224（非镜像）或 160（镜像），y=96，水平 4.5 穿过场地；
// shoot_disable → 配参数 → shoot_enable → 每 50 帧自机狙扇，+100 停；enemy_flag_collision(0)。
async sub sub9(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28,28,32)
    set_enemy_flag(ENEMY_NO_BODY, 1);         // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot9();
    var ang: angle = 0deg;                    // move_velocity(0.0f, 4.5f)
    if mirror != 0 { ang = 180deg - ang; }    // 镜像只取反水平速度
    move_vel(0, ang, 4.5fx, 0);
    wait(100);                                // +100 shoot_interval_delayed(0)
    wait(9900);                               // +9900: //10000
}

// timeline：卡帧 = 120（开场缓冲）+ (原文帧 − 9730)
async sub wave() {
    wait(120);
    // 9730–9750：Sub11 三只（x1 = 0 / -128 / +128，y=-32）
    _ = spawn_enemy(0.0fx, -32.0fx, 1, 0, 0, 0, sub11()); wait(10);
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub11()); wait(10);
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub11()); wait(90);
    // 9840–10080：Sub9 双侧 25 对（x1 = -224 与镜像 +160，y=96），每 10 帧一对
    for k3 in 0..25 {
        _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
        _ = spawn_enemy(160.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
        if k3 < 24 { wait(10); }
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
