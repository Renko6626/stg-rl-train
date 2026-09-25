// th06_s4_w08 —— 东方红魔乡 Stage 4 道中 第 8 波（Sub5，七对镜像小怪）
// 原文：ecldata4.ecl.txt timeline 帧 2628–2758（行 3294–3321）+ sub Sub5（行 114–137）
const TIME_LIMIT: int = 500;
const RICE: int = 64;   // TH06 弹型 2 RICE（米弹）

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

// 原文在敌出生帧（块时间 0）shoot_disable() → 配置 bullet_fan_aimed → shoot_enable()
// → shoot_interval_delayed(128)；到 +150 再 shoot_interval_delayed(0) 停火。
// 写法 A（mapping §4.3 新口径）：delayed 首发 k = n − 1 − rand(n)，此后 k += n，k < until 才开火；
// 伴生任务出生当帧不跑，首跑已在 S+1，故 wait(k − 1) 落在 S + k（k = 0 时只能在 S+1 发，晚 1 帧，概率 1/n）。
async sub autoshoot(n: int, spread: angle) {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);                          // bullet_fan_aimed：自机方向 + a1 为中轴
    sh_ring(0, 0);
    sh_count(0, n, 3);                     // count1 × count2=3 层
    sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / 3);
    sh_angle(0, 0deg, spread);
    var interval: int = 128;
    var until: int = 150;
    var k: int = interval - 1 - rand(interval);
    if k >= until { return; }
    if k > 0 { wait(k - 1); }              // k == 0：首跑即 S+1 发，晚 1 帧
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// Sub5：进场 −60° 4.5 速 → +30 左转 683bam/帧 40 帧 → +70 右转 −1365bam/帧 80 帧
//       → +150 角速度归零直飞；出界由守卫退场
async sub fairy(mirror: int, n: int, spread: angle) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min(28,28)/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot(n, spread);
    var ang: angle = -10923bam;            // move_velocity(-1.0471976f, 4.5f) = −60°
    var spd: fx = 4.5fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; } // 镜像只取反水平速度（mapping §6.1）
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 683bam;                            // +30 move_angular_velocity(0.06544985f) = 3.75°
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                          // +70 move_angular_velocity(-0.1308997f) = −7.5°
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(9850);                            // +150 角速度归零；出界由守卫退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2628)
async sub wave() {
    var rank: int = global(GVAR_RANK);
    var n: int = 1;                        // !E / !N：1 颗
    var spread: angle = 1820bam;           // 10°
    if rank == RANK_HARD { n = 2; }        // !H：2 颗
    else if rank >= RANK_LUNATIC { n = 5; spread = 2731bam; }  // !L：5 颗、15°
    wait(120);
    // 2628–2758：左右各一只、每 10 帧一对，共 14 只（x 减 192 后 ±224）
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, fairy(0, n, spread)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, fairy(1, n, spread));
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
