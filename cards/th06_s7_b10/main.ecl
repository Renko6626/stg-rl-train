// th06_s7_b10 —— 东方红魔乡 Extra boss 芙兰朵露 符卡 禁忌「恋の迷路」
// 原文：ecldata7.ecl.txt Sub62 → Sub63（宣言 + 移到 (192,80) → (192,224)）+ Sub64（攻击循环），原时限 3600。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 3000;   // unit.json 的 time_limit（原 3600 钳到 3000）
const SPELL_ID: int = 125;      // spellcard_start(3, 125, "ST_ECLDATA7_SUB48_0")
const RICE: int = 64;           // TH06 弹型 2 RICE
const BALL: int = 48;           // TH06 弹型 3 BALL

async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // Sub63 enemy_kill_all()（跳过调用者 boss）

    // Sub63 前奏：move_position_time_decelerate(120, 192, 80) → (30, 192, 224)
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);
    // +120: 第 2 段移动（30 帧，non-blocking）与 Sub64 攻击同帧起跑：
    // Sub62 在 Sub63 ret() 后立刻 call Sub64，故攻击不再等待移动结束。
    move_to(30, 0.0fx, 224.0fx, 2);

    // Sub64 发射器初始参数（shoot_offset(0,0,0) 即默认出弹口）
    sh_reset(0);
    sh_sprite(0, RICE, 8);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_speed(0, 1.4fx, 0fx);
    sh_reset(1);
    sh_sprite(1, BALL, 6);
    sh_aim(1, 0);
    sh_ring(1, 0);
    sh_speed(1, 3.4fx, (1.8fx - 3.4fx) / 3); // 3 层：3.4 → 2.8667 → 2.3333

    // F0/F1/F2/F3 用 int 存 BAM 整数：原作是未归一浮点差，角度类型减法会回绕，
    // 这里手动归一 + 取圆距离，触发帧与原作逐帧一致（见 report.md）。
    var f0: int = 0;
    var f1: int = 0;
    var f2: int = 0;
    var f3: int = 0;
    var i3: int = 0;
    var i7: int = 0;

    loop {
        // Sub64_16：每轮重置
        f0 = 16384;                           // 1.5707964f = 90°
        f1 = 16640;                           // 1.59534f = 91.41°
        i3 = 0;

        // 第一段（+0 起）：F1 每 2 帧 +0.27161688f，300 次
        for k1 in 0..300 {
            sh_sprite(0, RICE, 8);
            sh_count(0, 4, 1);
            sh_angle(0, f1 as angle, 683bam); // 0.06544985f = 3.75°
            sh_fire(0);
            f1 = f1 + 2833;                   // +0.27161688f（15.56°）
            if f1 >= 65536 { f1 = f1 - 65536; }
            f2 = f1 - f0;
            if f2 < 0 { f2 = 0 - f2; }
            if f2 > 32768 { f2 = 65536 - f2; }// |F1 - F0| 的圆距离
            if f2 < 2731 {                    // < 0.2617994f = 15°
                f1 = f1 + 4096;               // +0.3926991f = 22.5°
                if f1 >= 65536 { f1 = f1 - 65536; }
                f0 = f0 - 6554;               // −0.62831855f = −36°
                if f0 < 0 { f0 = f0 + 65536; }
                f3 = f1 + 32768;              // +180°
                if f3 >= 65536 { f3 = f3 - 65536; }
                sh_sprite(1, BALL, 6);
                sh_count(1, 24, 3);
                sh_angle(1, f3 as angle, 2048bam); // 0.19634955f = 11.25°
                sh_fire(1);
            }
            i3 = i3 + 1;
            wait(2);
        }
        wait(60);                             // +60: //62

        // 第二段（//62 起）：F1 每 2 帧 −0.27161688f，180 次
        f0 = 16384;
        for k2 in 0..180 {
            sh_sprite(0, RICE, 14);
            sh_count(0, 4, 1);
            sh_angle(0, f1 as angle, 683bam);
            sh_fire(0);
            f1 = f1 - 2833;
            if f1 < 0 { f1 = f1 + 65536; }
            f2 = f1 - f0;
            if f2 < 0 { f2 = 0 - f2; }
            if f2 > 32768 { f2 = 65536 - f2; }
            if f2 < 2731 {
                f1 = f1 - 4096;
                if f1 < 0 { f1 = f1 + 65536; }
                f0 = f0 + 7646;               // +0.7330383f = 42°
                if f0 >= 65536 { f0 = f0 - 65536; }
                f3 = f1 + 32768;
                if f3 >= 65536 { f3 = f3 - 65536; }
                sh_sprite(1, BALL, 2);
                sh_count(1, 24, 3);
                sh_angle(1, f3 as angle, 2048bam);
                sh_fire(1);
            }
            i3 = i3 + 1;
            wait(2);
        }
        i7 = i7 + 1;                          // Sub64 末尾 math_inc($I7)
        wait(7);                              // +7: //71
        // jump(0, Sub64_16) → 外层 loop
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    set_enemy_flag(ENEMY_NO_BODY, 0);         // Sub63 enemy_flag_collision(1)
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
