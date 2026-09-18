// th06_s5_w05 —— 东方红魔乡 Stage 5 道中 第 5 波
// 原文：ecldata5.ecl.txt timeline 帧 2252–2432（Sub3 / Sub4 / Sub5，各一对顶部落下）
const TIME_LIMIT: int = 600;
const BALL: int = 48;   // TH06 弹型 3 BALL 中玉

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

// Sub3 / Sub4 / Sub5：结构完全相同，只差弹色（6 / 2 / 10）。
// 下落 → +40 起减速 30 帧到停 → +70 起自机狙环 → +85 move_velocity(90°, 1.8) 飞走。
//
// 640 弹池等效截止（TH06 弹池只有 640，见 report.md）：忠实转写 Lunatic 峰值 1223 > 观测上限 1024，
// 按全局 640 池离线拟合，三对可见发数约 11 / 7 / 6；本卡 Lunatic 取 11 / 6 / 6 留裕量
// （budget_l = 该对允许的开火发数）。E/N/H 总发数 ≤11，不受影响。被截的发照常推进 f0 与 wait。
async sub fairy(color: int, budget_l: int) {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                    // enemy_set_hitbox(28,28,32) → min(28,28)/3
    var rank: int = global(GVAR_RANK);
    var budget: int = 11;                  // 全难度总发数最多 11（H/L）
    if rank >= RANK_LUNATIC { budget = budget_l; }
    var sidx: int = 0;
    var ang: angle = 90deg;
    var spd: fx = 2.0fx;
    var acc: fx = 0fx;
    var f0: fx = 1.5fx;
    move_vel(0, ang, spd, 0);              // move_velocity(1.5707964f, 2.0f)
    wait(40);
    acc = -0.06666667fx;                   // +40 move_acceleration(-0.06666667f)
    for k1 in 0..30 { spd = spd + acc; move_vel(0, ang, spd, 0); wait(1); }
    acc = 0fx;                             // +70 move_acceleration(0.0f)，速度恰减到 0

    sh_reset(0);
    sh_sprite(0, BALL, color);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, 24, 1);
    sh_angle(0, 0deg, 0deg);

    // Sub3_220 / Sub3_280：Easy 由 cmp/jump 直接跳过；N=2 轮、H/L=4 轮。
    // Lunatic 该条 count2=2（首弹两层速度），其余 count2=1。
    var n1: int = 0;                       // !E：原文 jump(80, Sub3_484)，整段跳过
    if rank == RANK_NORMAL { n1 = 2; }     // !N
    else if rank == RANK_HARD { n1 = 4; }  // !H
    else if rank >= RANK_LUNATIC { n1 = 4; } // !L
    var layers: int = 1;
    for k2 in 0..n1 {
        layers = 1;
        if rank >= RANK_LUNATIC { layers = 2; }
        if sidx < budget {
            sh_count(0, 24, layers);
            sh_speed(0, f0, (1.0fx - f0) / layers);
            sh_angle(0, 1365bam, 0deg);    // a1 = 7.5°
            sh_fire(0);
        }
        sidx = sidx + 1;
        f0 = f0 + 0.2fx;
        wait(5);
        if sidx < budget {
            sh_count(0, 24, 1);
            sh_speed(0, f0, 0fx);
            sh_angle(0, 0deg, 0deg);
            sh_fire(0);
        }
        sidx = sidx + 1;
        f0 = f0 + 0.2fx;
        wait(5);
    }
    // Easy 原文 jump(80, Sub3_484) 当帧即到此处；N/H/L 循环结束时也在此帧。

    // Sub3_484 / Sub3_564：E=5 轮、N=4 轮、H/L=3 轮，每轮 5 帧。
    var n2: int = 3;                       // !H / !L
    if rank == RANK_EASY { n2 = 5; }       // !E
    else if rank == RANK_NORMAL { n2 = 4; } // !N
    sh_count(0, 24, 1);
    for k3 in 0..n2 {
        if sidx < budget {
            sh_speed(0, f0, 0fx);
            sh_angle(0, 0deg, 0deg);
            sh_fire(0);
        }
        sidx = sidx + 1;
        f0 = f0 + 0.25fx;
        wait(5);
    }
    move_vel(0, 90deg, 1.8fx, 0);          // +85 move_velocity(1.5707964f, 1.8f)
    wait(10000);                           // +10000 enemy_delete(0)（退场实际由出界守卫完成）
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 2252)
async sub wave() {
    wait(120);
    // 2252：Sub3 ×2（x=32/352 → −160/160），弹色 6，Lunatic 满发（11）
    _ = spawn_enemy(-160.0fx, -48.0fx, 1, 0, 0, 0, fairy(6, 11));
    _ = spawn_enemy(160.0fx, -48.0fx, 1, 0, 0, 0, fairy(6, 11));
    wait(90);
    // 2342：Sub4 ×2（x=128/256 → −64/64），弹色 2，Lunatic 截到 6 发
    _ = spawn_enemy(-64.0fx, -48.0fx, 1, 0, 0, 0, fairy(2, 6));
    _ = spawn_enemy(64.0fx, -48.0fx, 1, 0, 0, 0, fairy(2, 6));
    wait(90);
    // 2432：Sub5 ×2（x=160/224 → −32/32），弹色 10，Lunatic 截到 6 发
    _ = spawn_enemy(-32.0fx, -48.0fx, 1, 0, 0, 0, fairy(10, 6));
    _ = spawn_enemy(32.0fx, -48.0fx, 1, 0, 0, 0, fairy(10, 6));
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
