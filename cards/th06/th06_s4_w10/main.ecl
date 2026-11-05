// th06_s4_w10 —— 东方红魔乡 Stage 4 道中 第 10 波
// 原文：ecldata4 timeline 帧 3088–3178（Sub3，行 66–89），E–L 四档
const TIME_LIMIT: int = 460;
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

// 原文 Sub3 开局：shoot_disable(); bullet_fan_aimed(...); shoot_enable(); shoot_interval_delayed(50);
// 到 +150（//150）shoot_interval_delayed(0) 停火。flags=4 是出生特效，我方不模拟。
// bullet_fan_aimed(2, 6, c1, 2, 1.8f, 1.0f, 0.0f, a2, 4)，c1/a2 按难度：
//   !E c1=1 a2=1638bam  !N c1=3 a2=1638bam  !H c1=5 a2=1638bam  !L c1=9 a2=2731bam
async sub autoshoot() {
    var rank: int = global(GVAR_RANK);
    var n: int = 1;
    var spread: angle = 1638bam;
    if rank == RANK_NORMAL { n = 3; }
    else if rank == RANK_HARD { n = 5; }
    else if rank >= RANK_LUNATIC { n = 9; spread = 2731bam; }
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, 2);
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);   // 层速 1.8 / 1.4
    sh_angle(0, 0deg, spread);
    // shoot_interval_delayed(50) 于设定帧 S；原作首发在 S + (50−1) − rand(50)，
    // 到 +150（//150）的 shoot_interval_delayed(0) 停火（§4.3 新口径）。
    // 伴生任务出生当帧不跑（S+1 首跑），故 wait(k−1) 正好落在 S+k。
    var k: int = 49 - rand(50);
    if k >= 150 { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 150 { return; }
        wait(50);
        k = k + 50;
    }
}

// 原文 Sub3：开局 move_velocity(-1.0471976f, 4.2f) = -60°，速度 4.2；
// +30 move_angular_velocity(0.06544985f)=683bam，+40（//70）−1365bam，+80（//150）归零。
// 镜像只取反水平速度：角 → 180°−a，角速度 → −w。
async sub sub3(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot();
    var ang: angle = -10923bam;            // -60°
    var spd: fx = 4.2fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 683bam;                            // +30 move_angular_velocity(0.06544985f)
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                          // +40 move_angular_velocity(-0.1308997f)
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    wait(10000);                           // +150 角速度归零直飞；出界由守卫退场（原文 +10000 enemy_delete）
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 3088)。原文 10 只，每 10 帧交替出左/右镜像。
async sub wave() {
    wait(120);
    for i in 0..5 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub3(0));
        wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1));
        if i < 4 { wait(10); }
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
