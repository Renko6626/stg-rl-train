// th06_s4_w22 —— 东方红魔乡 Stage 4 道中 第 22 波
// 原文：ecldata4 timeline 帧 9260–9530（Sub9）。两批各 12 只，镜像/正向横穿。
const TIME_LIMIT: int = 590;
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

// Sub9 的发弹：shoot_disable 期间配置好发射器，shoot_interval_delayed(50) 起自动开火，
// +100 处 shoot_interval_delayed(0) 停火（mapping §4.3 写法 A，until = 100）。
// 四档弹数/速度：!E(2,2.0) !N(3,2.0) !H(5,2.3) !L(9,2.3)，count2 = 2 层，a1=0°、a2=10°=1820bam。
async sub autoshoot() {
    var rank: int = global(GVAR_RANK);
    var n: int = 2;
    var s1: fx = 2.0fx;
    var s2: fx = 1.2fx;
    if rank == RANK_NORMAL { n = 3; }
    else if rank == RANK_HARD { n = 5; s1 = 2.3fx; }
    else if rank >= RANK_LUNATIC { n = 9; s1 = 2.3fx; }
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n, 2);
    sh_speed(0, s1, (s2 - s1) / 2);
    sh_angle(0, 0deg, 1820bam);
    // 原作自动射击（mapping §4.3）：设定帧 S 处执行 shoot_interval_delayed(50)，
    // 首发偏移 k = (n−1) − rand(n) = 49 − rand(50) ∈ [0,49]，之后每 50 帧一发的 k += 50；
    // +100 帧执行 shoot_interval(0) 停火，k < until=100 才发。伴生任务出生当帧不跑（首跑 S+1），
    // 所以 k > 0 时等 k−1 帧正好落在 S+k；k = 0 只能在 S+1 发（晚 1 帧，概率 1/50，契约已注明接受）。
    var k: int = 49 - rand(50);
    if k >= 100 { return; }
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        if k + 50 >= 100 { return; }
        wait(50);
        k = k + 50;
    }
}

// Sub9 本体：横穿场地。mirror=1 时水平速度取反（enemy_create_mirror，mapping §6.1）。
async sub sub9(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → 28/3
    set_enemy_flag(ENEMY_NO_BODY, 1);      // enemy_flag_collision(0)
    spawn oob_guard();
    spawn autoshoot();
    var ang: angle = 0deg;
    if mirror != 0 { ang = 180deg; }       // move_velocity(0.0f, 4.5f)，镜像 180°−0°
    move_vel(0, ang, 4.5fx, 0);
    wait(10000);                           // 原 +9900 enemy_delete(0)，实际靠 oob_guard 退场
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 9260)。前 12 只镜像 x=224,y=48，间隔 10；
// 隔 50 帧后 12 只正向 x=−224,y=96，间隔 10（最后一只在卡帧 120+270=390）。
async sub wave() {
    wait(120);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1)); wait(10);
    _ = spawn_enemy(224.0fx, 48.0fx, 1, 0, 0, 0, sub9(1));
    wait(50);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0)); wait(10);
    _ = spawn_enemy(-224.0fx, 96.0fx, 1, 0, 0, 0, sub9(0));
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
