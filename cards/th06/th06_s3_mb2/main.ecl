// th06_s3_mb2 —— 东方红魔乡 Stage 3 中 boss 符卡 華符「芳華絢爛」
// 原文：ecldata3 Sub13 → Sub14（宣言 + 移到中央）+ Sub10（120 帧前奏）+ Sub15（攻击循环），时限 1200。
// 逐段对照 / 近似见 report.md。
const TIME_LIMIT: int = 1200;
const SPELL_ID: int = 20;    // 原文 E 的 spellcard_start id（N 为 21）；纯脚本词汇，引擎不登记
const SHARD: int = 96;       // TH06 弹型 5 SHARD（16px），色号原样照抄

// Sub15 的双层旋转弹 + 定期自机狙环。
// bullet_rank_influence(-0.5f, 0.0f, 0, 2, 0, 0) 在 rank 16 下（mapping §4.6）：
//   c1 += 16·(2−0)/32 + 0 = 1；速度 rs = 16·(0−(−0.5))/32 + (−0.5) = −0.25
//   → 环 E 3+1=4 / N 4+1=5；自机狙 E 32+1=33 / N 42+1=43；速度 2.0−0.25=1.75、1.2−0.25=0.95，
//     二层速 0.6−0.125=0.475（c2=1，实际只用 speed1）。
async sub pattern() {
    move_to(120, 0.0fx, 144.0fx, 2);   // move_position_time_decelerate(120, 192.0f, 144.0f, 0.0f)
    wait(120);                         // Sub10 的 120 帧前奏
    var rank: int = global(GVAR_RANK);
    var nring: int = 5;                // !N bullet_circle(5, 13, 4, 1, 2.0f, 0.6f, …)
    var naimed: int = 43;              // !N bullet_circle_aimed(5, 2, 42, 1, 1.2f, 0.6f, …)
    var period: int = 80;              // !N math_int_mod($I0, $SELF_TIME, 80)
    var rmod: int = 1;                 // !N math_int_mod($I0, $SELF_TIME, 1)
    if rank == RANK_EASY { nring = 4; naimed = 33; period = 160; rmod = 2; }
    // set_float_rand_bound_min($F0/$F1, 2π, −π)：整周随机相位
    var f0: angle = rand(65536) as angle;
    var f1: angle = rand(65536) as angle;
    var t: int = 120;                  // %SELF_TIME：boss_timer 从宣言起算，Sub15 在 120 帧后开始

    // 槽 0 / 1：两条反向旋转的 SHARD 环；槽 2：定期自机狙环
    sh_reset(0);
    sh_sprite(0, SHARD, 13);
    sh_offset(0, 0.0fx, 0.0fx);        // Sub14 shoot_offset(0.0f, 0.0f, 0.0f)
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, nring, 1);
    sh_speed(0, 1.75fx, 0fx);
    sh_reset(1);
    sh_sprite(1, SHARD, 13);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, nring, 1);
    sh_speed(1, 1.75fx, 0fx);
    sh_reset(2);
    sh_sprite(2, SHARD, 2);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_aim(2, 1);
    sh_ring(2, 1);
    sh_count(2, naimed, 1);
    sh_speed(2, 0.95fx, 0fx);

    loop {
        if t % rmod == 0 {             // Sub15_84：E %2 / N %1
            sh_angle(0, f0, 0deg);
            sh_fire(0);
            sh_angle(1, f1, 0deg);
            sh_fire(1);
        }
        f0 = f0 + 1183bam;             // math_float_add($F0, %F0, 0.1134464f) = 6.5°
        f1 = f1 - 1365bam;             // math_float_sub($F1, %F1, 0.1308997f) = 7.5°
        for k in 0..6 {                // set_int($I6, 6)；Sub15_640 +1 循环
            if t % period == 0 {       // Sub15_464：E %160 / N %80
                sh_angle(2, 0deg, 0deg);
                sh_fire(2);
            }
            wait(1);
            t = t + 1;
        }
        // Sub15_640 jump(0, Sub15_84)：时间回到 0，下一轮
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);               // Sub9 enemy_set_hitbox(56, 56, 32) → 56/3（mapping §8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 登场位置未知，取 (0,96) 再移向 (0,144)
    loop { wait(600); }
}
