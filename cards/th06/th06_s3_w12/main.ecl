// th06_s3_w12 —— 东方红魔乡 Stage 3 道中 第 12 波
// 原文：ecldata3.ecl.txt timeline 帧 5494–5794（Sub4 / Sub8 / Sub7），行 2192–2230 + sub 82–114 / 201–224 / 167–199
const TIME_LIMIT: int = 780;
const BALL: int = 48;    // TH06 弹型 3 BALL（中玉）
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI（苦无）

// flags 0x19 = 0x1|0x8|0x10：出生冲刺 5→0（16 帧）+ 出生特效（不模拟）+ 永久沿 90° 加速 0.025
xformdef SPAWN_DASH_ACCEL {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0fx, 0.025fx);
}

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

// Sub4（原文行 82–114）：下落 → +40 减速 → +70 停住发弹 → 随机方向飞走
//   +70 !HL bullet_circle_aimed(3,6,16,1,1.6,0,%PLAYER_ANGLE,22.5°,4)
//   +70 起每 2 帧 !E/!N bullet_fan(4,6,1|1|3|5,1,%F1,0,%F0,spread,4)，%F1 每轮 +0.21
async sub sub4(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    // H/L 按 TH06 640 弹池等效截止（feedback 2026-09-17）：只截扇形苦无的“轮次”，
    // 圆弹 ring、Sub8、E/N 一律不动。截止比较用 $frame（首次出现帧口径，见 report 自检）。
    var cut4: int = 100000;                // E/N：不截止
    if rank == RANK_HARD { cut4 = 250; }   // H：Sub4 苦无首次出现帧 ≥ 250 的轮次不发
    else if rank >= RANK_LUNATIC { cut4 = 234; }  // L：≥ 234 的轮次不发
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;
    // +70
    var f0: angle = aim_player();          // math_float_add($F0, %PLAYER_ANGLE, 0.0f)
    var f1: fx = 1.6fx;
    var ways: int = 1;
    var spread: angle = 1365bam;           // 7.5°
    var i4: int = 30;
    if rank == RANK_EASY { i4 = 15; }
    else if rank == RANK_HARD { ways = 3; spread = 4096bam; }        // 22.5°
    else if rank >= RANK_LUNATIC { ways = 5; spread = 2731bam; }     // 15°
    if rank == RANK_HARD || rank >= RANK_LUNATIC {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, f0, 4096bam);
        sh_fire(0);
    }
    sh_reset(1);
    sh_sprite(1, KUNAI, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    sh_count(1, ways, 1);
    sh_angle(1, f0, spread);
    for k2 in 0..i4 {
        // 被截掉的轮次仍 wait(2) 占时；f1 照轮次递增，保证保留下来的轮次速度与原文一致
        if $frame < cut4 {
            sh_speed(1, f1, 0fx);
            sh_fire(1);
        }
        f1 = f1 + 0.21fx;
        wait(2);
    }
    var f2: angle = rand(16384) as angle;  // set_float_rand_bound($F2, π/2) → [0, 90°)
    f2 = f2 + 8192bam;                     // math_float_add($F2, %F2, π/4) → [45°, 135°)
    if mirror != 0 { f2 = 180deg - f2; }   // 镜像只取反水平速度
    move_vel(0, f2, 1.5fx, 0);
    wait(9900);
}

// Sub8（原文行 201–224）：下落 → +40 减速 → +70 一次随机散弹 → 随机方向飞走
//   bullet_random(3,15,8|14|20|22,1,2.0,0.3,0,-180°,25)：角度 [-180°,0)、速度 [0.3,2.0)
async sub sub8(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    var ang: angle = 90deg;
    var spd: fx = 2.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.083333336fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;
    // +70
    var n: int = 14;
    if rank == RANK_EASY { n = 8; }
    else if rank == RANK_HARD { n = 20; }
    else if rank >= RANK_LUNATIC { n = 22; }
    for k2 in 0..n {
        var an: angle = (-32768 + rand(32768)) as angle;
        var sp: fx = 0.3fx + 1.7fx / 256 * rand(256);
        _ = fire(BALL, 15, $self_x, $self_y, sp, an, SPAWN_DASH_ACCEL, none);
    }
    var f2: angle = rand(16384) as angle;
    f2 = f2 + 8192bam;
    if mirror != 0 { f2 = 180deg - f2; }
    move_vel(0, f2, 1.5fx, 0);
    wait(9930);
}

// Sub7（原文行 167–199）：下落 → +40 减速 → +70 停住发弹 → 反向随机方向飞回
//   +70 !H bullet_circle_aimed(3,6,16,1,1.6,0,90°,22.5°,4)
//   +70 起每 2 帧 !E/!N/!H/!L bullet_fan(4,6,1|1|1|5,1,%F1,0,90°,spread,4)，%F1 每轮 +0.3
async sub sub7(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    var rank: int = global(GVAR_RANK);
    // L 按 TH06 640 弹池等效截止：Sub7 扇形苦无首次出现帧 ≥ 508 的轮次不发（H/E/N 不截止）。
    var cut7: int = 100000;
    if rank >= RANK_LUNATIC { cut7 = 508; }
    var ang: angle = 90deg;
    var spd: fx = 1.5fx;
    var acc: fx = 0fx;
    move_vel(0, ang, spd, 0);
    wait(40);
    acc = -0.05fx;
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;
    // +70
    var f0: angle = 90deg;                 // set_float($F0, 1.5707964f)
    var f1: fx = 1.6fx;
    var ways: int = 1;
    var spread: angle = 1365bam;           // E/N 7.5°
    var i4: int = 16;
    if rank == RANK_EASY { i4 = 12; }
    else if rank == RANK_HARD { spread = 4096bam; }                  // 22.5°
    else if rank >= RANK_LUNATIC { ways = 5; spread = 5461bam; }     // 30°
    if rank == RANK_HARD {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, 16, 1);
        sh_speed(0, 1.6fx, 0fx);
        sh_angle(0, f0, 4096bam);
        sh_fire(0);
    }
    sh_reset(1);
    sh_sprite(1, KUNAI, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    sh_count(1, ways, 1);
    sh_angle(1, f0, spread);
    for k2 in 0..i4 {
        if $frame < cut7 {
            sh_speed(1, f1, 0fx);
            sh_fire(1);
        }
        f1 = f1 + 0.3fx;
        wait(2);
    }
    var f2: angle = rand(16384) as angle;
    f2 = f2 + 8192bam;
    if mirror != 0 { f2 = 180deg - f2; }
    move_vel(0, f2, -1.5fx, 0);            // 负速 → 反向飞回上方
    wait(9870);
}

// 导演任务：按 timeline 相对帧出怪。卡帧 = 120（开场缓冲）+ (原文帧 − 5494)
async sub wave() {
    wait(120);
    // 5494–5534：Sub4 双翼 ×5（x 由外向内收）
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub4(0));
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(10);
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub4(0));
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(10);
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub4(0));
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(10);
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub4(0));
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(10);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub4(0));
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub4(1)); wait(80);
    // 5614–5674：Sub8 双翼 ×3（左翼外→内，右翼内→外）
    _ = spawn_enemy(-132.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(132.0fx, -32.0fx, 1, 0, 0, 0, sub8(1)); wait(30);
    _ = spawn_enemy(-72.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(72.0fx, -32.0fx, 1, 0, 0, 0, sub8(1)); wait(30);
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub8(0));
    _ = spawn_enemy(164.0fx, -32.0fx, 1, 0, 0, 0, sub8(1)); wait(80);
    // 5754–5794：Sub7 双翼 ×5
    _ = spawn_enemy(-160.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(160.0fx, -32.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(-112.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(112.0fx, -32.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(-64.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(64.0fx, -32.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(-16.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(16.0fx, -32.0fx, 1, 0, 0, 0, sub7(1)); wait(10);
    _ = spawn_enemy(32.0fx, -32.0fx, 1, 0, 0, 0, sub7(0));
    _ = spawn_enemy(-32.0fx, -32.0fx, 1, 0, 0, 0, sub7(1));
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
