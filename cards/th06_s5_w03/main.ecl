// th06_s5_w03 —— 东方红魔乡 Stage 5 道中第 3 波
// 原文：ecldata5 timeline 帧 942–1082（Sub1）。镜像敌从右侧 off-field 入场，8 只每 20 帧一只。
const TIME_LIMIT: int = 560;
const RICE: int = 64;   // TH06 弹型 2 RICE（米弹）

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

// Sub1 的自动射击：每 interval 帧打一轮随机米弹
//   bullet_random(2, 6, c1, c2, 1.8f, 0.8f, 3.1415927f, 0.0f, 516)
//   → 角度 [0, π)（a7=0 → a6=π），速度 [0.8, 1.8)，共 c1*c2 颗。
//   flags 516 = 0x200|0x4：音效 + 出生特效，均按 §4.2 丢弃。
//   出弹口为敌中心（原文无 shoot_offset），弹角度不镜像（§6.1）。
async sub random_autoshoot(interval: int, n: int) {
    wait(interval - rand(interval));       // shoot_interval_delayed(interval) 的随机初值
    loop {
        for i in 0..n {
            var an: angle = rand(32768) as angle;            // [0, π) = [0°, 180°)
            var sp: fx = 0.8fx + 1.0fx / 256 * rand(256);    // [0.8, 1.8)
            _ = fire(RICE, 6, $self_x, $self_y, sp, an, none, none);
        }
        wait(interval);
    }
}

async sub sub1(mirror: int) {
    set_invuln(65535);
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28, 28, 32) → min(28,28)/3
    spawn oob_guard();
    var ang: angle = 0deg;                 // move_velocity(0.0f, 2.5f)
    var spd: fx = 2.5fx;
    if mirror != 0 { ang = 180deg - ang; } // 镜像只取反水平速度（§6.1）
    move_vel(0, ang, spd, 0);
    // 难度：颗数 c1*c2 / 自动射击间隔
    var n: int = 3;                        // !E bullet_random(3,1) / shoot_interval_delayed(60)
    var interval: int = 60;
    var rank: int = global(GVAR_RANK);
    if rank == RANK_NORMAL { n = 6; }                              // !N (3,2) / 60
    else if rank == RANK_HARD { n = 8; interval = 40; }            // !H (4,2) / 40
    else if rank >= RANK_LUNATIC { n = 10; interval = 30; }        // !L (5,2) / 30
    spawn random_autoshoot(interval, n);
    wait(10000);                           // 实际靠出界退场（原文 +10000 enemy_delete）
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 942)；每 20 帧一只，y 从 128 递增到 184
async sub wave() {
    wait(120);
    for i in 0..8 {
        var y: fx = (128 + i * 8) as fx;
        _ = spawn_enemy(224.0fx, y, 1, 0, 0, 0, sub1(1));
        if i < 7 { wait(20); }
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
