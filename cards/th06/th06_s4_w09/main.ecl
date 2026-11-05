// th06_s4_w09 —— 东方红魔乡 Stage 4 道中 第 9 波
// 原文：ecldata4.ecl.txt timeline 帧 2858–2988（Sub4），E–L 四档；小怪 14 只 = 7 对镜像，每 10 帧一对。
const TIME_LIMIT: int = 500;
const RICE: int = 64;      // TH06 弹型 2 RICE

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

// 原文 Sub4：shoot_disable(); (!E/!N/!H/!L) bullet_fan_aimed(2, 6, c1, c2, 1.5, 0.7, 0, a2, 4);
//          shoot_enable(); shoot_interval_delayed(128); … +40 shoot_interval_delayed(0)
// disable 期的 bullet_* 只配置不发（mapping §4.5），首发来自自动射击；+40（帧 70）停火。
async sub fan_autoshoot() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;                 // !E: count1 = 1
    var layers: int = 1;             // !E: count2 = 1
    var spread: angle = 1820bam;     // a2 = 0.17453292f = 10°
    if rank == RANK_NORMAL { layers = 3; }                       // !N: (1, 3)
    else if rank == RANK_HARD { c1 = 3; layers = 2; }            // !H: (3, 2)
    else if rank >= RANK_LUNATIC { c1 = 5; layers = 3; spread = 2731bam; }  // !L: (5, 3), a2 = 15°
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, layers);
    sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / layers);
    sh_angle(0, 0deg, spread);
    // 原文 shoot_interval_delayed(128)，设定帧 S = sub4 首帧；+40(块帧 70) 处 shoot_interval_delayed(0) 停火。
    // §4.3 写法 A：k = (128 − 1) − rand(128) ∈ [0,127]；伴生任务首跑已在 S+1，wait(k − 1) 正好落在 S+k。
    // 停火守卫比较 k 本身：k >= until(=70) 就不发。k + 128 > 70 恒真，故本段最多发一轮。
    var k: int = 127 - rand(128);
    if k >= 70 { return; }
    if k > 0 { wait(k - 1); }
    sh_fire(0);
}

// 原文 Sub4：下落横飞 → +30 起 -3.75°/帧 转 40 帧 → +70 角速度归零直飞
async sub sub4(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    spawn fan_autoshoot();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 4.2f)
    var spd: fx = 4.2fx;
    if mirror != 0 { ang = 180deg; }       // 镜像只取反水平速度（§6.1）
    move_vel(0, ang, spd, 0);
    wait(30);
    var w: angle = -683bam;                // +30 move_angular_velocity(-0.06544985f)
    if mirror != 0 { w = 683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                              // +70 move_angular_velocity(0.0f); shoot_interval_delayed(0)
    wait(9930);                            // +10000 enemy_delete(0)；实际由出界守卫退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2858)。14 只小怪，每 10 帧一只，镜像成对。
async sub wave() {
    wait(120);
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub4(0)); wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub4(1)); wait(10);
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
