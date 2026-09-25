// th06_s4_b17 —— 东方红魔乡 Stage 4 boss 帕秋莉 符卡 金符「メタルファティーグ」
// 原文：ecldata4.ecl.txt Sub75 → Sub76（宣言 + 移到中央）/ Sub77（攻击循环），时限 2100，仅 N 档。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 62;
const LASERHEAD: int = 176;   // TH06 弹型 6 BIG_BALL
const COLOR: int = 13;        // 32px 弹色 6 → [0,2,4,6,8,10,13,15][6]

// 原文 Sub77 每轮：F0/F1 各取整周随机；bullet_circle 用 F0 作初向（8 颗均分整周），
// bullet_effects(60,1,-1,-1,%F1,2.0f,…) + flags 257(0x100|0x1) 让每环 60 帧内速率
// 4.0→0，周期末朝向 F1+k·45°、速率 2.0（k = 内层第几次 jump_dec 的环号）。
// decomp BulletManager.cpp:710-830：0x1 冲刺先写 velocity，随后 0x100 分支每帧整写
// velocity，冲刺被覆盖 → 略去。
// 终向是运行时随机角，xformdef 参数须编译期常量，故用挂在弹上的任务：任务首帧把
// F1（暂存 globals 自由段 16）读进 local，每环 btask_k 再加 k·45°。
const SLOT_F1: int = 16;

async sub btask_0() {
    var tgt: angle = global(SLOT_F1) as angle;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_1() {
    var tgt: angle = (global(SLOT_F1) as angle) + 45deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_2() {
    var tgt: angle = (global(SLOT_F1) as angle) + 90deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_3() {
    var tgt: angle = (global(SLOT_F1) as angle) + 135deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_4() {
    var tgt: angle = (global(SLOT_F1) as angle) + 180deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_5() {
    var tgt: angle = (global(SLOT_F1) as angle) + 225deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_6() {
    var tgt: angle = (global(SLOT_F1) as angle) + 270deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}
async sub btask_7() {
    var tgt: angle = (global(SLOT_F1) as angle) + 315deg;
    set_accel(0, -0.06666667fx);
    wait(59);
    stop_fx(0);
    set_angle(0, tgt);
    set_speed(0, 2.0fx);
}

async sub pattern() {
    // 原文 Sub76：enemy_kill_all() + shoot_offset(0,0,0) + move_position_time_decelerate(120, 192, 80)
    kill_all_enemies(KILL_SILENT);
    move_to(120, 0.0fx, 80.0fx, 2);      // TH06 (192,80) → (0,80)
    wait(120);                            // Sub76 +120 ret → Sub77 起

    sh_reset(0);
    sh_sprite(0, LASERHEAD, COLOR);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 8, 1);
    sh_speed(0, 4.0fx, 0fx);

    // 原文 Sub77：每 40 帧一轮；内层 jump_dec 8 次 = 同帧 8 环 × 8 颗 = 64 颗。
    // 环 k 的 8 颗共用一个终向 F1+k·45°（对应原文同一次 bullet_effects）。
    var f0: angle = 0deg;
    loop {
        f0 = rand(65536) as angle;
        set_global(SLOT_F1, rand(65536));
        sh_angle(0, f0, 0deg);
        sh_task(0, btask_0); sh_fire(0);
        sh_task(0, btask_1); sh_fire(0);
        sh_task(0, btask_2); sh_fire(0);
        sh_task(0, btask_3); sh_fire(0);
        sh_task(0, btask_4); sh_fire(0);
        sh_task(0, btask_5); sh_fire(0);
        sh_task(0, btask_6); sh_fire(0);
        sh_task(0, btask_7); sh_fire(0);
        wait(40);
    }
}

async sub boss_main() {
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 80.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
