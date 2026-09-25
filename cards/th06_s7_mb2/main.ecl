// th06_s7_mb2 —— 东方红魔乡 Extra（Stage 7）中 boss 帕秋莉 符卡「日符「ロイヤルフレア」」
// 原文：ecldata7.ecl.txt Sub18（行 474–495，登场设置）→ Sub25（600–606）→
//        Sub26（608–625，spellcard_start + 移到中央）+ Sub27（627–696，攻击循环）。
//        Extra 档（ranks [4,4]），无难度分叉；timer_callback_threshold(2880)。

const TIME_LIMIT: int = 2880;
const SPELL_ID: int = 119;
const OUTLINE: int = 32;        // TH06 弹型 1 RING_BALL（mapping §3）

// bullet_effects(100, -1, -1, -1, 0.015f, -999.0f, …) + flags 536(0x10|0x8|0x200)：
// 0x10 → 出生后 100 帧内沿弹初始方向加速 0.015（mapping §5）；0x8 出生特效 / 0x200 音效丢弃。
// `@N` 是后置延迟：本 op 先执行、再等 N 帧走下一 op，故 set_accel 当帧生效、100 帧后 stop_fx。
xformdef ACCEL15 { @100 set_accel(0.015fx); stop_fx(); }
// Sub27_1220 段前的 bullet_effects(…, 0.02f, …)：同样 100 帧、加速度 0.02。
xformdef ACCEL20 { @100 set_accel(0.02fx); stop_fx(); }

// Sub27：ex_ins_call(13, N) 以场地中心为圆心、$F3 为半径的 N 个点开火，
// $I3 % 6 == 0 时（每 6 帧）一批；每点用当时 bulletProps 打一个 fan。
async sub pattern() {
    // Sub18：enemy_flag_interactable(1)/collision(1) → 可体碰；enemy_kill_all()/bullet_cancel()
    set_enemy_flag(ENEMY_NO_BODY, 0);
    kill_all_enemies(KILL_SILENT);
    clear_bullets_at(0.0fx, 224.0fx, 1024.0fx, 0);   // bullet_cancel → §4.4

    // Sub26：shoot_interval(0) → 无自动射击；shoot_offset(0,0,0) → 出弹口归零；
    //        move_position_time_decelerate(120, 192, 80) → 我方 (0, 80)；+120 ret。
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);

    // ── Sub27 ──
    var v3: int = 0;            // $I3：ex_ins_call 计数（var3）
    var c6: int = 0;            // $I3 % 6，用计数器等价表达
    var f0: fx = 0.2fx;         // $F0：speed1，每段配置前 +0.1
    var spd: fx = 0fx;          // 钳位后的有效 speed1
    var f1: angle = 0deg;       // $F1：角度偏移
    var f2: angle = 0deg;       // $F2：环基准角
    var f3: fx = 0fx;           // $F3：环半径（每帧 +1）
    var a: angle = 0deg;

    loop {
        // ── Sub27_192：段 A 配置（OUTLINE 双弹扇形 ±15°，speed1=0.2→钳 0.3，加速 0.015）──
        f3 = 0fx;
        spd = f0;
        if spd < 0.3fx { spd = 0.3fx; }
        sh_reset(0);
        sh_sprite(0, OUTLINE, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 2, 1);
        sh_speed(0, spd, 0fx);
        sh_xform(0, ACCEL15);

        // Sub27_344：ex_ins_call(13, 3)，280 帧；F2 += 256bam，F1 -= 256bam
        for k1 in 0..280 {
            if c6 == 0 {
                a = f2;
                for j1 in 0..3 {
                    sh_offset_abs(0, cos(a) * f3, 224.0fx + sin(a) * f3);
                    sh_angle(0, a + f1, 5461bam);
                    sh_fire(0);
                    a = a + 21845bam;          // 2π/3
                }
            }
            c6 = c6 + 1;
            if c6 == 6 { c6 = 0; }
            f3 = f3 + 1.0fx;
            f2 = f2 + 256bam;
            f1 = f1 - 256bam;
            wait(1);
        }

        // ── 段 B 配置：+0.1 → speed1=0.3；OUTLINE 双弹 ±15°，加速 0.015 ──
        f0 = f0 + 0.1fx;
        f3 = 0fx;
        spd = f0;
        if spd < 0.3fx { spd = 0.3fx; }
        sh_count(0, 2, 1);
        sh_speed(0, spd, 0fx);
        sh_xform(0, ACCEL15);

        // Sub27_636：ex_ins_call(13, 5)，280 帧；F2 -= 256bam，F1 += 256bam
        for k2 in 0..280 {
            if c6 == 0 {
                a = f2;
                for j2 in 0..5 {
                    sh_offset_abs(0, cos(a) * f3, 224.0fx + sin(a) * f3);
                    sh_angle(0, a + f1, 5461bam);
                    sh_fire(0);
                    a = a + 13107bam;          // 2π/5
                }
            }
            c6 = c6 + 1;
            if c6 == 6 { c6 = 0; }
            f3 = f3 + 1.0fx;
            f2 = f2 - 256bam;
            f1 = f1 + 256bam;
            wait(1);
        }

        // ── 段 C 配置：+0.1；单弹、speed1=0（不钳）、±30°（step 记在层间位，单颗不展开），加速 0.015 ──
        f0 = f0 + 0.1fx;
        f3 = 0fx;
        sh_count(0, 1, 1);
        sh_speed(0, 0fx, 0fx);
        sh_xform(0, ACCEL15);

        // Sub27_928：ex_ins_call(13, 6)，180 帧；F2 -= 256bam，F1 += 102bam
        for k3 in 0..180 {
            if c6 == 0 {
                a = f2;
                for j3 in 0..6 {
                    sh_offset_abs(0, cos(a) * f3, 224.0fx + sin(a) * f3);
                    sh_angle(0, a + f1, 10923bam);
                    sh_fire(0);
                    a = a + 10923bam;          // 2π/6
                }
            }
            c6 = c6 + 1;
            if c6 == 6 { c6 = 0; }
            f3 = f3 + 1.0fx;
            f2 = f2 - 256bam;
            f1 = f1 + 102bam;
            wait(1);
        }

        // ── 段 D 配置：+0.1 → speed1=0.5；单弹 ±15°，加速 0.02 ──
        f0 = f0 + 0.1fx;
        f3 = 0fx;
        spd = f0;
        if spd < 0.3fx { spd = 0.3fx; }
        sh_count(0, 1, 1);
        sh_speed(0, spd, 0fx);
        sh_xform(0, ACCEL20);

        // Sub27_1220：ex_ins_call(13, 5)，200 帧；F2 += 256bam，F1 -= 683bam
        for k4 in 0..200 {
            if c6 == 0 {
                a = f2;
                for j4 in 0..5 {
                    sh_offset_abs(0, cos(a) * f3, 224.0fx + sin(a) * f3);
                    sh_angle(0, a + f1, 5461bam);
                    sh_fire(0);
                    a = a + 13107bam;          // 2π/5
                }
            }
            c6 = c6 + 1;
            if c6 == 6 { c6 = 0; }
            f3 = f3 + 1.0fx;
            f2 = f2 + 256bam;
            f1 = f1 - 683bam;
            wait(1);
        }

        // math_inc($I7) 丢弃；//64 jump(0, Sub27_192)：原地等 60 帧后回到段首
        wait(60);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(13.33fx);        // enemy_set_hitbox(40,56,32) → min(40,56)/3（mapping §8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
