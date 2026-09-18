// th06_s5_w10 —— 东方红魔乡 Stage 5 道中第 10 波
// 原文：ecldata5.ecl.txt timeline 帧 7114–7204 的 5 对小怪收拢（行 2227–2246）+ Sub2（行 48–74）
const TIME_LIMIT: int = 510;
const BALL: int = 48;              // TH06 弹型 3 BALL 中玉

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

// Sub2：下落 2.0 → +40 减速 30 帧到 0 → +70 起 5 轮自机狙环
// 每轮 4 帧、速度每轮 +0.55（Lunatic 再 +0.2）；5 轮后改 1.8 直落
//
// 640 弹池等效截止（mapping 未收、见 report.md）：本波 H/L 忠实转写弹峰值 1235/1178 > 1024，
// 根因是 TH06 弹池只有 640 发（BulletManager.hpp:125，池满时 SpawnBulletPattern 整批放弃）。
// 离线拟合静态截止：全弹种同一类，按「开火帧 ≥ 265 的轮次不发」近似 640 池曲线
// （fire = 123 + 10*idx + 70 + 4*v ⇒ 10*idx + 4*v ≥ 72）。非 EASY 才截止（EASY 峰值 463 < 640）。
// 被截的轮次照常推进 f0 与 wait(4)，只不发弹。
async sub sub2(idx: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min/3
    spawn oob_guard();
    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f)
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)

    var rank: int = global(GVAR_RANK);
    var n: int = 12;                       // !E bullet_circle_aimed(... 12 ...)
    if rank == RANK_NORMAL { n = 24; }     // !N
    else if rank == RANK_HARD { n = 32; }  // !H
    else if rank >= RANK_LUNATIC { n = 32; }  // !L

    var f0: fx = 1.5fx;                    // set_float($F0, 1.5f)
    // bullet_circle_aimed(3, 6, n, 1, %F0, 1.0f, 0, 0, 516)：BALL 色 6、自机狙整周环
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_angle(0, 0deg, 0deg);
    for k2 in 0..5 {                       // jump_dec(70, Sub2_180, $I4) 共 5 轮
        if rank == RANK_EASY || 10 * idx + 4 * k2 < 72 {
            sh_speed(0, f0, 0fx);
            sh_fire(0);
        }
        f0 = f0 + 0.55fx;                  // !* math_float_add($F0, %F0, 0.55f)
        if rank >= RANK_LUNATIC { f0 = f0 + 0.2fx; }  // !L math_float_add($F0, %F0, 0.2f)
        wait(4);
    }
    spd = 1.8fx;                           // 循环结束后 move_velocity(1.5707964f, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9910);                            // +9926: //10000
    die();                                 // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 7114)，每 10 帧一对双翼收拢（x 从 ∓160 收到 ∓48）
// idx 0..9 供 640 池截止用（开火帧 = 123 + 10*idx + 70 + 4*v）
async sub wave() {
    wait(120);
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub2(0));  // 32 → -160
    wait(10);
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub2(1));   // 352 → 160
    wait(10);
    _ = spawn_enemy(-128.0fx, -48.0fx, 1, 0, 0, 0, sub2(2));  // 64 → -128
    wait(10);
    _ = spawn_enemy(128.0fx, -48.0fx, 1, 0, 0, 0, sub2(3));   // 320 → 128
    wait(10);
    _ = spawn_enemy(-96.0fx, -48.0fx, 1, 0, 0, 0, sub2(4));   // 96 → -96
    wait(10);
    _ = spawn_enemy(96.0fx, -48.0fx, 1, 0, 0, 0, sub2(5));    // 288 → 96
    wait(10);
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, sub2(6));   // 128 → -64
    wait(10);
    _ = spawn_enemy(64.0fx, -48.0fx, 1, 0, 0, 0, sub2(7));    // 256 → 64
    wait(10);
    _ = spawn_enemy(-48.0fx, -48.0fx, 1, 0, 0, 0, sub2(8));   // 144 → -48
    wait(10);
    _ = spawn_enemy(48.0fx, -48.0fx, 1, 0, 0, 0, sub2(9));    // 240 → 48
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
