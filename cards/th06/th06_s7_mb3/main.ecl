// th06_s7_mb3 —— 东方红魔乡 Stage 7(Extra) 中 boss（帕秋莉·诺蕾姬）符卡 火水木金土符「賢者の石」
// 原文：ecldata7.ecl.txt Sub19 → Sub28 → Sub29（宣言 + 移到中央 + 召 5 只使魔）+ Sub31–Sub35 各自攻击循环，时限 2400。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 2400;
const SPELL_ID: int = 120;   // 原文 spellcard_start(0, 120, …)，全难度同一 id；仅 UI/计分
const SHARD: int = 96;       // TH06 弹型 5 SHARD 鳞弹
const G_AIM: int = 16;       // 全局自由段槽：本发 0x100 的「定格自机角」，供弹上任务取

// Sub33：bullet_effects(120, 1, -1, -1, 0.012f, 2.3561945f, …) + flags 531(0x10|0x2|0x1)。
//   decomp 里 0x1 与 0x10 在同一个 else-if 链：前 16 帧只跑 0x1 冲刺，之后才轮到 0x10 恒定向量加速
//   （BulletManager.cpp:712-736）。映射 §5 的叠加写法：冲刺 + 定角加速。
//   固定角 135°：g = 0.012·(cos135°, sin135°) = (−0.008485, 0.008485)，@(120−16)=@104 接上。
xformdef S33_ACCEL {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    @104 set_gravity(-0.008485fx, 0.008485fx);
    stop_fx();
}

// Sub34：bullet_effects(60, 1, -1, -1, %PLAYER_ANGLE, 1.5f, …) + flags 769(0x100|0x2|0x1)。
//   0x1 被 0x100 分支每帧重算 velocity 覆盖（BulletManager.cpp:778-804），无实际效果，不加冲刺。
//   0x100 = 60 帧内速度线性减到 0，周期末「朝向设为 f0、速度设为 1.5」；f0 是发弹当帧的自机角快照。
xformdef S34_TURN {
    @60 step_speed(0fx, 60);
    set_speed(1.5fx);
}

// Sub35：bullet_effects(180, 1, -1, -1, %F0, 1.4f, …) + flags 579(0x40|0x2|0x1)。
//   0x1 同样被 0x40 覆盖。0x40 = 180 帧内速度线性减到 0，周期末「转 f0、速度设为 1.4」，
//   f0 每颗独立随机 ∈[−90°,90°) → 转向交给弹上任务（xformdef 参数必须编译期常量）。
xformdef S35_DECEL {
    @180 step_speed(0fx, 180);
    set_speed(1.4fx);
}

// Sub34 弹上任务：出生后第 1 帧读本发定格的自机角，第 60 帧设为该绝对角。
async sub s34_angle() {
    var a: angle = global(G_AIM) as angle;
    wait(59);
    set_angle(0, a);
}

// Sub35 弹上任务：出生后第 180 帧按自己那颗的随机角转向（原作 f0 逐颗随机、写在 bulletProps）。
async sub s35_turn() {
    var a: angle = (rand(32768) - 16384) as angle;
    wait(179);
    turn(0, a);
}

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

// Sub31（使魔，出生 (192,144)→(0,144)）：鳞弹 10 颗 × 2 层、速度 2.0→1.5，整周随机基准，
// 每 94 帧两发（间隔 4 帧）。
async sub fam31() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);                       // enemy_set_hitbox(28,28,32) → min(w,h)/3
    set_enemy_flag(ENEMY_NO_BODY, 1);         // enemy_flag_interactable(0)
    sh_reset(0);
    sh_sprite(0, SHARD, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 10, 2);
    sh_speed(0, 2.0fx, (1.0fx - 2.0fx) / 2);  // 逐层 −0.5
    wait(32);
    loop {                                    // Sub31_144 … +90 jump(32, …)，周期 94
        sh_angle(0, rand(65536) as angle, 0deg);
        sh_fire(0);
        wait(4);
        sh_angle(0, rand(65536) as angle, 0deg);
        sh_fire(0);
        wait(90);
    }
}

// Sub32（使魔，出生 (64,112)→(−128,112)）：自机狙扇 11 颗 × 2 层、速度 3.0→2.8、展开 15°，
// 每 50 帧一发。
async sub fam32() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    sh_reset(0);
    sh_sprite(0, SHARD, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 11, 2);
    sh_speed(0, 3.0fx, (2.6fx - 3.0fx) / 2);  // 逐层 −0.2
    sh_angle(0, 0deg, 2731bam);               // a1=0、a2=15°
    wait(64);
    loop {                                    // Sub32_144 … +50 jump(64, …)，周期 50
        sh_fire(0);
        wait(50);
    }
}

// Sub33（使魔，出生 (256,96)→(64,96)）：随机弹 10 颗、整周随机角、速度 [0.3,2.0)、
// 出生冲刺 + 135° 恒定向量加速，每 20 帧一发。
async sub fam33() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(16);
    loop {                                    // Sub33_144 … +20 jump(16, …)，周期 20
        for j1 in 0..10 {
            var sp1: fx = 0.3fx + 1.7fx / 256 * rand(256);   // [0.3, 2.0)
            var an1: angle = rand(65536) as angle;           // [−π, π)
            _ = fire(SHARD, 10, $self_x, $self_y, sp1, an1, S33_ACCEL, none);
        }
        wait(20);
    }
}

// Sub34（使魔，出生 (320,112)→(128,112)）：鳞弹 16 颗 1 层、整周（a1=%F0=0）、速度 4.0，
// 60 帧减速后全体定格转向发弹当帧的自机角、速度 1.5；每 70 帧一发。
async sub fam34() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(48);
    loop {                                    // Sub34_144 … +70 jump(48, …)，周期 70
        var av: int = aim_player() as int;     // %PLAYER_ANGLE 快照（发弹当帧）
        set_global(G_AIM, av);
        for j2 in 0..16 {
            var an2: angle = (j2 * 65536 / 16) as angle;     // i·2π/16，a1=0
            _ = fire(SHARD, 0, $self_x, $self_y, 4.0fx, an2, S34_TURN, s34_angle);
        }
        wait(70);
    }
}

// Sub35（使魔，出生 (128,96)→(−64,96)）：随机弹 1 颗、角度 [自机−90°, 自机+90°)、速度 [1.0,2.4)，
// 同帧连发 6 颗；每颗 180 帧减速后按自己的随机角转向、速度 1.4；每 40 帧一轮。
async sub fam35() {
    set_invuln(65535);
    spawn oob_guard();
    set_hitbox(9.33fx);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    wait(16);
    loop {                                    // Sub35_144 … +40 jump(16, …)，周期 40
        for k1 in 0..6 {
            var sp3: fx = 1.0fx + 1.4fx / 256 * rand(256);   // [1.0, 2.4)
            var lo: angle = aim_player() - 16384bam;         // f1 = 自机 − 90°
            var an3: angle = lo + (rand(32768)) as angle;    // [f1, f1+180°)
            _ = fire(SHARD, 13, $self_x, $self_y, sp3, an3, S35_DECEL, s35_turn);
        }
        wait(40);
    }
}

// Sub29：宣言 + 12 帧 move_position_time_decelerate(120, 192, 80) 移到中央，+120 时召 5 只使魔；
// Sub30 只是死等（+10000 jump 自循环），丢弃。Sub28 的 boss_timer_clear 由外壳接管。
async sub pattern() {
    move_to(120, 0.0fx, 80.0fx, 2);           // x=192−192=0，decelerate → 2（§7）
    wait(120);                                // 前 120 帧无弹，满足开场缓冲
    _ = spawn_enemy(0.0fx, 144.0fx, 1, 0, 0, 0, fam31);
    _ = spawn_enemy(-128.0fx, 112.0fx, 1, 0, 0, 0, fam32);
    _ = spawn_enemy(64.0fx, 96.0fx, 1, 0, 0, 0, fam33);
    _ = spawn_enemy(128.0fx, 112.0fx, 1, 0, 0, 0, fam34);
    _ = spawn_enemy(-64.0fx, 96.0fx, 1, 0, 0, 0, fam35);
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(13.33fx);                      // Sub19 enemy_set_hitbox(40,56,32) → min(w,h)/3
    kill_all_enemies(KILL_SILENT);             // Sub19/Sub29 enemy_kill_all()（跳过 boss 自己）
    clear_bullets_at(0.0fx, 224.0fx, 1024.0fx, 0);   // Sub19 bullet_cancel()
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
