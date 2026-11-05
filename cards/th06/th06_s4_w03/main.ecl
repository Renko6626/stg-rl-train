// th06_s4_w03 —— 东方红魔乡 Stage 4 道中 第 3 波
// 原文：ecldata4.ecl.txt timeline 帧 1150–1280（enemy_create/enemy_create_mirror 调 Sub3，行 66–89），E–L 四档
const TIME_LIMIT: int = 500;
const RICE: int = 64;          // TH06 弹型 2 RICE（米弹）

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

// 原文 Sub3 的自动射击：shoot_disable() 期间只配参数，shoot_enable() + shoot_interval_delayed(50)
// 起后台自动开火；+150 处 shoot_interval_delayed(0) 停火。写法 A（mapping §4.3），until = 150。
// 原著首发 = S + k，k = (n−1) − rand(n)（delayed）；伴生任务出生当帧不跑，首跑已在 S+1，
// 所以 wait(k−1) 正好落在 S+k（k=0 时只能在 S+1 发，晚 1 帧，概率 1/n）。停火守卫用 k >= until。
async sub autoshoot(interval: int, delayed: int, until: int, n: int, spread: angle) {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, 2);
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);   // 两层：1.8 / 1.4
    sh_angle(0, 0deg, spread);
    var k: int = interval - 1;
    if delayed != 0 { k = interval - 1 - rand(interval); }
    if k >= until { return; }
    if k > 0 { wait(k - 1); }          // k == 0：只能在 S+1 发，晚 1 帧
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// 原文 Sub3（行 66–89）：
//   命中框 (28,28,32) → 28/3；无敌；enemy_flag_collision(0) ⇒ 无体碰。
//   四档都发自机狙扇：count1 E/N/H/L = 1/3/5/9，层数 2，速度 1.8→1.0；
//   张角 E/N/H = π/32 = 1638bam，L = π/12 = 2731bam。
//   移动：-60° 4.2 → +30 角速度 +683 → +70 角速度 -1365 → +150 归零，之后直飞。
async sub sub3(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                // enemy_set_hitbox(28,28,32) → min/3（mapping §8）
    set_enemy_flag(ENEMY_NO_BODY, 1);  // enemy_flag_collision(0)
    spawn oob_guard();

    var rank: int = global(GVAR_RANK);
    var n: int = 1;                    // !E
    var spread: angle = 1638bam;       // !E/N/H：π/32
    if rank == RANK_NORMAL { n = 3; }  // !N
    else if rank == RANK_HARD { n = 5; }                       // !H
    else if rank >= RANK_LUNATIC { n = 9; spread = 2731bam; }  // !L：π/12
    spawn autoshoot(50, 1, 150, n, spread);

    var ang: angle = -10923bam;        // move_velocity(-1.0471976f, 4.2f)
    var spd: fx = 4.2fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }   // 镜像只取反水平速度（§6.1）
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 683bam;                        // +30 move_angular_velocity(0.06544985f)
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                      // +70 move_angular_velocity(-0.1308997f)
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                          // +150 角速度归零
    wait(9850);                        // 实际靠出界守卫退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 1150)；原文 1150–1280 每 10 帧一对镜像，共 7 对 14 只
async sub wave() {
    wait(120);
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub3(0));
        wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1));
        if i < 6 { wait(10); }
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
