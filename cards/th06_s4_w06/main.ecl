// th06_s4_w06 —— 东方红魔乡 Stage 4 道中 第 6 波
// 原文：ecldata4.ecl.txt timeline 帧 2024–2154 + 小怪 sub Sub2（行 43–64）
const TIME_LIMIT: int = 500;
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

// 原文 Sub2 开头（shoot_disable 期间配置，随后 shoot_enable + shoot_interval_delayed(50)）：
//   bullet_fan_aimed(2, 6, c1, 2, 1.8f, 1.0f, 0.0f, a2, 4)
//   !E c1=1 a2=9°=1638bam / !N c1=3 / !H c1=5 / !L c1=8 a2=15°=2731bam
// 参数粘滞，之后每 50 帧自动开火一次；sub 帧 70 处 shoot_interval_delayed(0) 停火
// → mapping §4.3 写法 A 的伴生任务（until=70 停火守卫）。
async sub autoshoot() {
    var rank: int = global(GVAR_RANK);
    var n: int = 1;               // !E
    var step: angle = 1638bam;    // !E a2 = 0.15707964f
    if rank == RANK_NORMAL { n = 3; }
    else if rank == RANK_HARD { n = 5; }
    else if rank >= RANK_LUNATIC { n = 8; step = 2731bam; }   // !L a2 = 0.2617994f
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);                 // fan 以自机方向为中轴
    sh_ring(0, 0);
    sh_count(0, n, 2);            // c1 颗 × 2 层
    sh_speed(0, 1.8fx, -0.4fx);   // speed(j) = 1.8 − 0.4 j
    sh_angle(0, 0deg, step);
    // §4.3 新口径：设定帧 S = sub 帧 0，delayed 首发 k = (n−1) − rand(n)；
    // 伴生任务首跑已在 S+1，故 wait(k−1) 落在 S+k（k==0 只能在 S+1 发，晚 1 帧，概率 1/n）。
    var interval: int = 50;       // shoot_interval_delayed(50)
    var until: int = 70;          // sub 帧 70 的 shoot_interval_delayed(0) 停火
    var k: int = interval - 1 - rand(interval);
    if k >= until { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + interval >= until { return; }
        wait(interval);
        k = k + interval;
    }
}

// Sub2：move_velocity(0.0f, 4.2f) 平飞 → +30 起角速度 -0.06544985f 转 40 帧 → +70 归零 → +10000 退场
async sub sub2(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                 // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);   // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot();
    var ang: angle = 0deg;
    var spd: fx = 4.2fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = -683bam;                        // +30 move_angular_velocity(-0.06544985f)
    if mirror != 0 { w = 683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                           // +70 move_angular_velocity(0.0f)
    wait(9930);                         // +10000 enemy_delete(0)
}

// 导演任务：原文第一只 timeline 帧 2024 ⇒ 卡帧 120（开场缓冲）。七对镜像每 10 帧。
async sub wave() {
    wait(120);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1)); wait(10);
    _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub2(0)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub2(1));   // 卡帧 250
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
