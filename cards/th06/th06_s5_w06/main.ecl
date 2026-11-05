// th06_s5_w06：Stage 5 道中 第 6 波
// 原文：ecldata5.ecl.txt timeline 帧 2552–2872（Sub6，行 208–231）
const TIME_LIMIT: int = 700;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL

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

// Sub6：顶部落下、减速悬停，3 帧一轮扇形弹（Sub6_148 循环）
async sub sub6() {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min(28,28)/3
    spawn oob_guard();

    var rank: int = global(GVAR_RANK);
    var i4: int = 40;                      // set_int($I4, 40)（!ENHL）
    if rank == RANK_EASY { i4 = 20; }      // !E set_int($I4, 20)

    var ang: angle = 90deg;                // move_velocity(1.5707964f, 2.0f) → 90°=16384bam
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)

    // bullet_fan：EN 5 颗×1 层、H 5×2、L 7×2，弹型 1 RING_BALL 色 6，a2=0.03926991f=410bam
    var c1: int = 5;
    var c2: int = 1;
    if rank == RANK_HARD { c2 = 2; }
    else if rank >= RANK_LUNATIC { c1 = 7; c2 = 2; }

    sh_reset(0);
    sh_sprite(0, OUTLINE, 6);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, c1, c2);

    // TH06 原作靠 640 发弹池压画面（BulletManager.hpp:125）；本引擎弹池 8192、无此上限，
    // 且出界回收更晚。仅 L 按离线复现的 640 池拟合出静态截止规则（见 report.md / pool640/）：
    // 越到后面越稀疏，保留弹幕曲线；只 gate sh_fire，wait 与随机抽样照旧。
    var capped: int = 0;
    if rank >= RANK_LUNATIC { capped = 1; }

    // Sub6_148：set_float_rand_bound_min($F0/$F1) → bullet_fan → +3: jump_dec(70,…,$I4)
    for k in 0..i4 {
        var f1: fx = 1.0fx + 2.0fx / 256 * rand(256);          // [1, 3)
        var a0: angle = -4096bam + rand(40960) as angle;        // [-22.5°, 202.5°)
        sh_speed(0, f1, (1.0fx - f1) / c2);                    // s1=%F1, s2=1.0f
        sh_angle(0, a0, 410bam);                               // %F0 为中轴，a2=%…=2.25°
        var gate: int = 1;
        if capped != 0 {
            if $frame >= 400 { if k % 6 == 5 { gate = 0; } }
            if $frame >= 460 { if k % 5 == 4 { gate = 0; } }
            if $frame >= 520 { if k % 4 == 3 { gate = 0; } }
        }
        if gate != 0 { sh_fire(0); }
        wait(3);
    }

    spd = 1.8fx;                           // move_velocity(1.5707964f, 1.8f)
    move_vel(0, ang, spd, 0);
    wait(9927);                            // +9927 → //10000
    die();                                 // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2552)
async sub wave() {
    wait(120);
    _ = spawn_enemy(0.0fx, -48.0fx, 1, 0, 0, 0, sub6()); wait(110);    // 2552
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, sub6()); wait(110); // 2662
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, sub6()); wait(100);  // 2772
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, sub6());             // 2872
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
