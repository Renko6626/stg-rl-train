// th06_s5_w08 —— 东方红魔乡 Stage 5 道中 第 8 波（长编队后半）
// 原文：ecldata5.ecl.txt timeline 帧 5049–6534（Sub1 / Sub9 / Sub10 / Sub11），接 w07 的同一长编队。
const TIME_LIMIT: int = 1865;
const RICE: int = 64;      // TH06 弹型 2 RICE（米弹）
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const KUNAI: int = 80;     // TH06 弹型 4 KUNAI
const BALL: int = 48;      // TH06 弹型 3 BALL

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

// ---- Sub1：bullet_random(RICE, 3/3/4/5 颗 × 1/2/2/2 层, 速度 [0.8,1.8) 随机,
//      角度 [0,π) 随机)，自动射击间隔 E/N 60、H 40、L 30 ----
async sub sub1_shot() {
    var rank: int = global(GVAR_RANK);
    var n1: int = 3;
    var n2: int = 1;
    var iv: int = 60;
    if rank == RANK_NORMAL { n2 = 2; }
    else if rank == RANK_HARD { n1 = 4; n2 = 2; iv = 40; }
    else if rank >= RANK_LUNATIC { n1 = 5; n2 = 2; iv = 30; }
    var total: int = n1 * n2;
    wait(iv - rand(iv));
    loop {
        for k in 0..total {
            var sp: fx = 0.8fx + 1.0fx / 256 * rand(256);
            var an: angle = rand(32768) as angle;
            _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
        }
        wait(iv);
    }
}

// ---- Sub9：bullet_fan_aimed(BULLET, 6 颗 × 1 层, 1.5→0.8, 中轴自机向, 间隔 π/16)，间隔 40 ----
async sub sub9_shot() {
    sh_reset(0);
    sh_sprite(0, BULLET, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 6, 1);
    sh_speed(0, 1.5fx, -0.7fx);
    sh_angle(0, 0deg, 2048bam);
    var iv: int = 40;
    wait(iv - rand(iv));
    loop {
        sh_fire(0);
        wait(iv);
    }
}

// ---- Sub10：bullet_fan_aimed(KUNAI, 4 颗 × 1 层, 1.5→0.8, 中轴自机向, 间隔 15°=2731bam)，间隔 30 ----
async sub sub10_shot() {
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 4, 1);
    sh_speed(0, 1.5fx, -0.7fx);
    sh_angle(0, 0deg, 2731bam);
    var iv: int = 30;
    wait(iv - rand(iv));
    loop {
        sh_fire(0);
        wait(iv);
    }
}

// ---- Sub11：bullet_random(BALL, 4 颗 × 1 层, 速度 [0.8,1.5) 随机, 角度整周随机)，间隔 10 ----
async sub sub11_shot() {
    var iv: int = 10;
    wait(iv - rand(iv));
    loop {
        for k in 0..4 {
            var sp: fx = 0.8fx + 0.7fx / 256 * rand(256);
            var an: angle = rand(65536) as angle;
            _ = fire(BALL, 2, $self_x, $self_y, sp, an, none, none);
        }
        wait(iv);
    }
}

// 小怪主任务：move_velocity(0, 2.5) 水平穿越场地。镜像只取反水平速度（mapping §6.1），弹角度不镜像。
async sub sub1(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    spawn sub1_shot();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    wait(10000);
}

async sub sub9(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    spawn sub9_shot();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    wait(10000);
}

async sub sub10(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    spawn sub10_shot();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    wait(10000);
}

async sub sub11(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);
    spawn oob_guard();
    spawn sub11_shot();
    var a: angle = 0deg;
    if mirror != 0 { a = 180deg - a; }
    move_vel(0, a, 2.5fx, 0);
    wait(10000);
}

// 一个 16 只的组（原文每 15 帧一只；Sub1/9/10/11 循环）。x 已按注释换算（x−192），mirror 只影响速度。
sub group_w08() {
    _ = spawn_enemy(224.0fx, 80.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub10(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 96.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 64.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub1(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub11(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 72.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub10(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 32.0fx, 1, 0, 0, 0, sub9(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 80.0fx, 1, 0, 0, 0, sub1(0));
    wait(15);
    _ = spawn_enemy(224.0fx, 64.0fx, 1, 0, 0, 0, sub11(1));
    wait(15);
    _ = spawn_enemy(-224.0fx, 128.0fx, 1, 0, 0, 0, sub10(0));
}

// 导演任务：原文第一只在帧 5049，卡帧 = 120（开场缓冲）+ (原文帧 − 5049)。
// 5 组，组内每 15 帧、组间 90；最后一只卡帧 1605，尾部 260 → 1865。
async sub wave() {
    wait(120);
    for g in 0..5 {
        group_w08();
        if g < 4 { wait(90); }
    }
    wait(260);
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
