// th06_s4_w15 —— 东方红魔乡 Stage 4 道中第 15 波
// 原文：ecldata4.ecl.txt timeline 帧 5698–6012（Sub3 / Sub16 / Sub18 / Sub20），E–L 四档
const TIME_LIMIT: int = 734;     // unit.json time_limit
const BALL: int = 48;            // TH06 弹型 3 BALL
const RICE: int = 64;            // TH06 弹型 2 RICE
const KUNAI: int = 80;           // TH06 弹型 4 KUNAI

// flags 0x1 出生冲刺（mapping §5）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

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

// 原文 Sub3：shoot_disable(); (!E/!N/!H/!L) bullet_fan_aimed(2, 6, c1, 2, 1.8, 1.0, 0, a2, 4);
//          shoot_enable(); shoot_interval_delayed(50); … +150 shoot_interval_delayed(0)
// disable 期的 bullet_* 只配置不发（mapping §4.5），首发来自自动射击；+150（帧 150）停火。
async sub fan_autoshoot() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;                  // !E: count1 = 1
    var spread: angle = 1638bam;      // a2 = 0.15707964f = 9°
    if rank == RANK_NORMAL { c1 = 3; }                              // !N
    else if rank == RANK_HARD { c1 = 5; }                           // !H
    else if rank >= RANK_LUNATIC { c1 = 9; spread = 2731bam; }      // !L, a2 = 15°
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, c1, 2);               // count2 = 2 层
    sh_speed(0, 1.8fx, (1.0fx - 1.8fx) / 2);
    sh_angle(0, 0deg, spread);
    // shoot_interval_delayed(50)：原作首发 k = 49 − rand(50) ∈ [0, 49]，
    // 之后每 50 帧；原作 +150 执行 shoot_interval_delayed(0)，k < 150 才开火（mapping §4.3 写法 A）。
    // 伴生任务出生在 S 帧、首跑在 S+1，所以等 k−1 正好落在 S+k；k==0 只能在 S+1 发（晚 1 帧，概率 1/50）。
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

// 原文 Sub3：斜向入场，-60° 4.2 速；+30 起 +3.75°/帧 转 40 帧 → +70 起 -7.5°/帧 转 80 帧 → +150 角速度归零
async sub sub3(mirror: int) {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_collision(0)
    spawn fan_autoshoot();
    var ang: angle = -10923bam;                // move_velocity(-1.0471976f, 4.2f) = -60°
    var spd: fx = 4.2fx;
    var w: angle = 0deg;
    if mirror != 0 { ang = 180deg - ang; }     // 镜像只取反水平速度（§6.1）
    move_vel(0, ang, spd, 0);
    wait(30);
    w = 683bam;                                // +30 move_angular_velocity(0.06544985f) = +3.75°
    if mirror != 0 { w = -683bam; }
    for k1 in 0..40 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = -1365bam;                              // +70 move_angular_velocity(-0.1308997f) = -7.5°
    if mirror != 0 { w = 1365bam; }
    for k2 in 0..80 { ang = ang + w; move_vel(0, ang, spd, 0); wait(1); }
    w = 0deg;                                  // +150 move_angular_velocity(0.0f); shoot_interval_delayed(0)
    wait(9850);                                // +10000 enemy_delete(0)；实际由出界守卫退场
}

// 原文 Sub16：定点，+30 开体碰后 10 轮环形自机狙（jump_dec 30, Sub16_144, $I4=10）
async sub sub16() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);          // enemy_flag_interactable(1)
    var rank: int = global(GVAR_RANK);
    var n: int = 8;                            // !E
    var layers: int = 1;
    var s1: fx = 1.4fx;
    var s2: fx = 1.0fx;
    if rank == RANK_NORMAL { n = 16; }                                  // !N
    else if rank == RANK_HARD { n = 24; layers = 2; s1 = 2.4fx; }       // !H
    // !L 原 count1 = 32；rank 3 按 TH06 640 池等效颗数折减（§4.2b，见 report）→ 24
    else if rank >= RANK_LUNATIC { n = 24; layers = 3; s1 = 3.0fx; }
    for k1 in 0..10 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, s1, (s2 - s1) / layers);
        sh_angle(0, 0deg, 0deg);
        sh_xform(0, BURST);                    // flags 5 = 0x1|0x4
        sh_fire(0);
        wait(50);                              // +50 jump_dec(30, Sub16_144, $I4)
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);          // 循环结束后 enemy_flag_interactable(0)
    wait(30);                                  // +30 → 帧 560
    die();                                     // enemy_delete(0)
}

// 原文 Sub18：下落到 +70 停下，原地留一只站桩的 Sub20，再随机角 [45°,135°) 1.8 速飞走
async sub sub18() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32)
    var ang: angle = 90deg;                    // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                       // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    // +70：-0.06666667 * 30 恰好把速度降到 0
    _ = spawn_enemy($self_x, $self_y, 1, 0, 0, 0, sub20());   // enemy_create("Sub20", %SELF_X, %SELF_Y, …)
    acc = 0fx;                                 // move_acceleration(0.0f)
    ang = 45deg + rand(16384) as angle;        // set_float_rand_bound_min($F0, π/2, π/4) → [45°,135°)
    spd = 1.8fx;
    move_vel(0, ang, spd, 0);
    wait(9930);
}

// 原文 Sub20：不可交互的站桩激光（+120 建 90° 下射激光；H/L 追加环形苦无）
async sub sub20() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(4.0fx);                         // 未设 hitbox ⇒ TH06 默认 12/3
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
    wait(120);
    var rank: int = global(GVAR_RANK);
    // laser_create(sprite 0, color 6, a=π/2, sp=0, st=0, en=500, sl=500, w=32, T0=90, T1=120, T2=16, …)
    // 原点 = 敌位置 + shoot_offset(0,0)；sprite 0 → 8 色表 [6] = 13；宽 32/2 = 16；start = max(0,500−500,0)=0
    var lz: int = laser(13, $self_x, $self_y, 16384bam, 500.0fx, 16.0fx, 90, 120, 16);
    var n: int = 0;                            // !E / !N 不发弹
    var layers: int = 1;
    if rank == RANK_HARD { n = 16; }                                    // !H
    else if rank >= RANK_LUNATIC { n = 32; layers = 2; }                // !L
    if n > 0 {
        sh_reset(0);
        sh_sprite(0, KUNAI, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layers);
        sh_speed(0, 1.2fx, (0.3fx - 1.2fx) / layers);   // s2=0.0f 按 0.3 钳
        sh_angle(0, 0deg, 1024bam);                     // a2 = 5.625°
        sh_fire(0);                                     // flags 4 = 出生特效，不模拟
    }
    wait(200);                                 // +200 anm_interrupt_main(1)（丢弃）
    wait(120);                                 // +120 → 帧 440 enemy_delete(0)
    die();
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 5698)
async sub wave() {
    wait(120);
    // 5698–5828：Sub3 ×14，每 10 帧一只，镜像成对（×7）
    for i in 0..7 {
        _ = spawn_enemy(-224.0fx, 170.0fx, 1, 0, 0, 0, sub3(0)); wait(10);
        _ = spawn_enemy(224.0fx, 170.0fx, 1, 0, 0, 0, sub3(1)); wait(10);
    }
    wait(50);                                  // 到相对 190 = 原文 5888
    // 5888：Sub16 ×2
    _ = spawn_enemy(-144.0fx, 96.0fx, 1, 0, 0, 0, sub16());
    _ = spawn_enemy(144.0fx, 96.0fx, 1, 0, 0, 0, sub16());
    wait(60);
    // 5948：Sub18 ×2
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 5980：Sub18 ×2
    _ = spawn_enemy(-128.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(128.0fx, -32.0fx, 1, 0, 0, 0, sub18());
    wait(32);
    // 6012：Sub18 ×2
    _ = spawn_enemy(-64.0fx, -16.0fx, 1, 0, 0, 0, sub18());
    _ = spawn_enemy(64.0fx, -16.0fx, 1, 0, 0, 0, sub18());
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
