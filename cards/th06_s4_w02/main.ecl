// th06_s4_w02 —— 东方红魔乡 Stage 4 道中 第 2 波
// 原文：ecldata4.ecl.txt timeline 帧 920–1050（Sub2），四档 E–L。
const TIME_LIMIT: int = 500;
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

// Sub2 的发弹：原文 `!E/!N/!H/!L bullet_fan_aimed(2, 6, c1, 2, 1.8, 1.0, 0, a2, 4)`
//   c1 = 1/3/5/8，a2 = 9°/9°/9°/15°；shoot_disable 期间只配置，此处由自动射击开火。
//   原文 shoot_interval_delayed(50)，到块帧 70 时 shoot_interval_delayed(0) 停火 ⇒ until = 70。
async sub autoshoot_ring() {
    var rank: int = global(GVAR_RANK);
    var ways: int = 1;                 // !E
    var spread: angle = 1638bam;       // 9°
    if rank == RANK_NORMAL { ways = 3; }                       // !N
    else if rank == RANK_HARD { ways = 5; }                    // !H
    else if rank >= RANK_LUNATIC { ways = 8; spread = 2731bam; } // !L = 15°
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, ways, 2);
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);
    sh_angle(0, 0deg, spread);
    // delayed 首发 k = 50 − 1 − rand(50) = 49 − rand(50)；伴生任务首跑已在 S+1，
    // 所以等 k−1 帧正好落在 S+k（mapping §4.3）。k 摇到 0 时只能在 S+1 发（晚 1 帧，概率 1/50）。
    var k: int = 49 - rand(50);
    if k >= 70 { return; }             // until = 70；k >= until 不发
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 70 { return; }    // 原 until 帧先 shoot_interval(0) 再计时 ⇒ k < until 才开火
        wait(50);
        k = k + 50;
    }
}

// Sub2：原点 0° 水平 4.2 入场 → +30 起 -3.75°/帧 转 40 帧 → +70 直飞；
// 镜像敌只取反水平速度与角速度，弹角度不镜像（mapping §6.1）。
async sub sub2(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    spawn autoshoot_ring();
    set_enemy_flag(ENEMY_NO_BODY, 1);  // enemy_flag_collision(0)
    var ang: angle = 0deg;
    var spd: fx = 4.2fx;
    if mirror != 0 { ang = 180deg; }   // move_velocity(0.0f, 4.2f)，镜像 180°−0°
    var w: angle = 0deg;
    move_vel(0, ang, spd, 0);
    wait(30);
    // +30 move_angular_velocity(-0.06544985f) = -3.75° = -683bam
    w = -683bam;
    if mirror != 0 { w = 683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    // +70 move_angular_velocity(0.0f); shoot_interval_delayed(0)
    w = 0deg;
    wait(9930);                        // +10000 enemy_delete(0)
    die();
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 920)。14 只，每 10 帧一只，左右交替。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 920
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 930
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 940
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 950
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 960
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 970
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 980
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 990
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 1000
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 1010
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 1020
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);    // 1030
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);   // 1040
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1));              // 1050
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
