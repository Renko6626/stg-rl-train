// th06_s4_w21 —— 东方红魔乡 Stage 4 道中 第 21 波（Sub8/Sub9 交替六段）
// 原文：ecldata4.ecl.txt timeline 帧 8300–9210（Sub8 :169–187 / Sub9 :189–207），E–L 四档
const TIME_LIMIT: int = 1230;
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

// Sub8 / Sub9 的自动射击：
//   shoot_disable(); bullet_fan_aimed(2, 6, c1, 2, s1, 1.2f, 0.0f, 0.17453292f, 4); shoot_enable();
//   shoot_interval_delayed(50);  +100: shoot_interval_delayed(0);
// bullet_fan_aimed 在 shoot_disable 期间只写参数、不发弹，所以首轮是延迟自动射击。
// flags 4 = 出生特效，我方有意不模拟（mapping §4.2）。a2 = 10° = 1820bam。
async sub fan_autoshoot() {
    var rank: int = global(GVAR_RANK);
    var ways: int = 2;                     // !E
    var s1: fx = 2.0fx;                    // !E
    if rank == RANK_NORMAL { ways = 3; }   // !N
    else if rank == RANK_HARD { ways = 5; s1 = 2.3fx; }        // !H
    else if rank >= RANK_LUNATIC { ways = 9; s1 = 2.3fx; }     // !L
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, ways, 2);
    sh_speed(0, s1, (1.2fx - s1) / 2);
    sh_angle(0, 0deg, 1820bam);
    // 原作 delayed 首发 = S + (n−1) − rand(n) = S + 49 − rand(50)。伴生任务在 S 帧 spawn、
    // 首跑已在 S+1，所以等 k−1 正好落在 S+k；停火守卫用 k >= until（mapping §4.3）。
    // 原作 +100 处 shoot_interval_delayed(0) ⇒ until = 100。
    var k: int = 49 - rand(50);
    if k >= 100 { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 100 { return; }
        wait(50);
        k = k + 50;
    }
}

// Sub8：move_velocity(π/2, 4.5) 竖直下冲；Sub9：move_velocity(0, 4.5) 水平冲入。
// 镜像只取反水平速度，弹角度不镜像（mapping §6.1）。
async sub fairy(ang0: angle, mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn fan_autoshoot();
    var a: angle = ang0;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 4.5fx, 0);
    wait(10000);                           // +10000 enemy_delete(0)，实际靠出界删除
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 8300)
async sub wave() {
    wait(120);
    // 8300–8410：Sub8 ×12，x = 96 → -96，每 10 帧
    _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0));
    for k1 in 1..12 { wait(10); _ = spawn_enemy(-96.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0)); }
    wait(50);
    // 8460–8570：Sub8 ×12，x = 196 → 4
    _ = spawn_enemy(4.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0));
    for k2 in 1..12 { wait(10); _ = spawn_enemy(4.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0)); }
    wait(50);
    // 8620–8730：Sub9 ×12，x = -32 → -224，水平冲入
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, fairy(0deg, 0));
    for k3 in 1..12 { wait(10); _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, fairy(0deg, 0)); }
    wait(50);
    // 8780–8890：Sub9 镜像 ×12，x = 416 → 224（坐标不镜像，水平速度取反）
    _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, fairy(0deg, 1));
    for k4 in 1..12 { wait(10); _ = spawn_enemy(224.0fx, 128.0fx, 1, 0, 0, 0, fairy(0deg, 1)); }
    wait(50);
    // 8940–9050：Sub8 ×12，x = 288 → 96
    _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0));
    for k5 in 1..12 { wait(10); _ = spawn_enemy(96.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0)); }
    wait(50);
    // 9100–9210：Sub8 ×12，x = 188 → -4
    _ = spawn_enemy(-4.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0));
    for k6 in 1..12 { wait(10); _ = spawn_enemy(-4.0fx, -32.0fx, 1, 0, 0, 0, fairy(90deg, 0)); }
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
