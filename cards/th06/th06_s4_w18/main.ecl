// th06_s4_w18 —— 东方红魔乡 Stage 4 道中 第 18 波
// 原文：ecldata4.ecl.txt timeline 帧 7530–7680 + 小怪 sub Sub3（行 66–89）
const TIME_LIMIT: int = 520;
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

// Sub3 的发弹：shoot_disable 下写满 bulletProps，shoot_enable 后
// shoot_interval_delayed(50) 每 50 帧自动打一轮，+150 处 shoot_interval_delayed(0) 停。
// bullet_fan_aimed(2, 6, c1, 2, 1.8f, 1.0f, 0.0f, a2, 4)：自机狙扇，c1 / a2 按难度。
async sub fan_autoshoot(c1: int, spread: angle) {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, 2);
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);
    sh_angle(0, 0deg, spread);
    // shoot_interval_delayed(50) 设定帧 S=0：k = 49 − rand(50)，原作首发在 S+k，之后每 50 帧
    // （mapping §4.3：伴生任务首跑已在 S+1，等 k−1 正好落在 S+k）。until = 150（+150 处 shoot_interval_delayed(0)），
    // k < until 才开火，守卫比较 k 本身。
    var k: int = 50 - 1 - rand(50);
    if k >= 150 { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 150 { return; }
        wait(50);
        k = k + 50;
    }
}

// Sub3：从 (224, 170) 以 -60°（镜像 240°）飞出，+30 / +70 / +150 三次改角速度。
async sub sub3(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                 // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);   // enemy_flag_collision(0)
    spawn oob_guard();

    var rank: int = global(GVAR_RANK);
    var n: int = 1;                     // !E  bullet_fan_aimed(2, 6, 1, 2, …)
    var spread: angle = 1638bam;        // !E/N/H a2 = 9°
    if rank == RANK_NORMAL { n = 3; }   // !N  3 颗
    else if rank == RANK_HARD { n = 5; }  // !H  5 颗
    else if rank >= RANK_LUNATIC { n = 9; spread = 2731bam; }  // !L  9 颗、15°
    spawn fan_autoshoot(n, spread);

    var ang: angle = -60deg;            // move_velocity(-1.0471976f, 4.2f)
    var spd: fx = 4.2fx;
    if mirror != 0 { ang = 240deg; }    // 镜像只取反水平速度
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = 683bam;              // +30  move_angular_velocity(0.06544985f)
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                       // +70  move_angular_velocity(-0.1308997f)
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                           // +150 move_angular_velocity(0.0f)
    wait(9850);                         // +10000 enemy_delete(0)；实际靠出界退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 7530)，16 只每 10 帧
async sub wave() {
    wait(120);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1));
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
