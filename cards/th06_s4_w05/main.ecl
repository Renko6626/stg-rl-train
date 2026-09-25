// th06_s4_w05 —— 东方红魔乡 Stage 4 道中 第 5 波
// 原文：ecldata4.ecl.txt timeline 帧 1794–1924（Sub3，行 3232–3259 / 66–89）
const TIME_LIMIT: int = 500;
const RICE: int = 64;                 // TH06 弹型 2 RICE

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

// 原文 Sub3 开头（shoot_disable 期间配置、shoot_enable 后 delayed 自动射击）：
//   !E bullet_fan_aimed(2,6,1,2,1.8,1.0,0,9°,4) / !N c1=3 / !H c1=5 / !L c1=9, 15°
//   shoot_interval_delayed(50)；+150 shoot_interval_delayed(0) 停火
async sub autoshoot(n: int, spread: angle) {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, 2);
    sh_speed(0, 1.8fx, -0.4fx);        // s1=1.8, s2=1.0, c2=2 → (s2-s1)/c2 = -0.4
    sh_angle(0, 0deg, spread);
    // §4.3 写法 A：在原作执行 shoot_interval_delayed(50) 的帧 S spawn，子任务 S+1 才起跑，
    // 所以 wait(k−1) 正好让首发落在 S+k。delayed 首发 k = 49 − rand(50)；until = +150 的 shoot_interval_delayed(0)。
    var k: int = 49 - rand(50);
    if k >= 150 { return; }
    if k > 0 { wait(k - 1); }          // k == 0：只能在 S+1 发，晚 1 帧（概率 1/50）
    loop {
        sh_fire(0);
        if k + 50 >= 150 { return; }
        wait(50);
        k = k + 50;
    }
}

// 原文 Sub3：move_velocity(-60°, 4.2)；+30 角速度 +3.75°/帧；+70 角速度 -7.5°/帧；+150 归零；+10000 删除
async sub sub3(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                // enemy_set_hitbox(28,28,32) → 28/3
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);  // enemy_flag_collision(0)

    var rank: int = global(GVAR_RANK);
    var n: int = 1;                    // !E
    var spread: angle = 1638bam;       // 9°
    if rank == RANK_NORMAL { n = 3; }
    else if rank == RANK_HARD { n = 5; }
    else if rank >= RANK_LUNATIC { n = 9; spread = 2731bam; }   // 15°
    spawn autoshoot(n, spread);

    var ang: angle = -10923bam;        // move_velocity(-1.0471976f, 4.2f) = -60°
    var spd: fx = 4.2fx;
    if mirror != 0 { ang = 180deg - ang; }   // 镜像只取反水平速度
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = 683bam;             // +30 move_angular_velocity(0.06544985f) = 3.75°
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                      // +70 move_angular_velocity(-0.1308997f) = -7.5°
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9850);                        // +150 角速度归零；+10000 enemy_delete(0)
    die();
}

// 导演任务：原文 timeline 帧 1794 起每 10 帧一对，共 7 对 14 只（卡帧 = 120 + 原文帧 − 1794）
async sub wave() {
    wait(120);
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub3(0));   // enemy_create(-32) → x−192
        wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1));     // enemy_create_mirror(416) → x−192
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
