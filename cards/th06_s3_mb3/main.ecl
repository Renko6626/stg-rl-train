// th06_s3_mb3 —— 东方红魔乡 Stage 3 中 boss 符卡 華符「セラギネラ９」（Hard/Lunatic 版）
// 原文：ecldata3.ecl.txt Sub16 → Sub17（宣言 + boss_timer 1200 + 120 帧移中央）→ Sub18（双列反向旋转鳞弹 + 每 120 帧一发自机狙环），时限 1200。
const TIME_LIMIT: int = 1200;
const SPELL_ID: int = 22;   // 原文 spellcard_start(0, H=22 / L=23, "ST_ECLDATA3_SUB14_0")：本卡取 H 的 22
const SHARD: int = 96;      // TH06 弹型 5 SHARD（半边长 2）

// Sub18 bullet_effects(60, 2, -1, -1, -150°, 1.6, -1, -1) + flags 68(0x40|0x4)：
// 0x40 = 每 60 帧一周期，速度从当前值线性减到 0、周期末转 f0、速度设为 f1（i1=2 个周期）。
// 0x4 出生特效不模拟（mapping §4.2/§5）。@N 是后置延迟：step_speed 先发射再等 60 帧。
xformdef RING_A {
    @60 step_speed(0fx, 60); turn(-27307bam); set_speed(1.6fx);
    @60 step_speed(0fx, 60); turn(-27307bam); set_speed(1.6fx);
}
// Sub18 bullet_effects(60, 2, -1, -1, -210°, 1.6, -1, -1) + flags 68：同上，周期末转 -210°
xformdef RING_B {
    @60 step_speed(0fx, 60); turn(-38229bam); set_speed(1.6fx);
    @60 step_speed(0fx, 60); turn(-38229bam); set_speed(1.6fx);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    // Sub18：!H count1=5 / !L count1=6；自机狙环 !H 48 颗、速 1.3 / !L 52 颗、速 1.6
    var n: int = 5;
    var n_aim: int = 48;
    var s_aim: fx = 1.3fx;
    if rank >= RANK_LUNATIC { n = 6; n_aim = 52; s_aim = 1.6fx; }

    // Sub17：move_position_time_decelerate(120, 192, 144) + call Sub10(120)（纯 120 帧前奏）
    move_to(120, 0.0fx, 144.0fx, 2);
    wait(120);                             // 攻击从 pattern 第 120 帧起（全局帧 ≈ 123）

    // Sub18 主循环：外层每 6 帧一对反向旋转鳞弹环；每 20 轮（120 帧）补一发自机狙环。
    // 原作攻击自 $SELF_TIME=120 起、到 1200 收段，共 1080 帧 = 180 轮 = 9 个 120 帧块。
    var f0: angle = 0deg;                  // %F0：每轮 +0.14835298f = +8.5° = 1547bam
    var f1: angle = 0deg;                  // %F1：每轮 -0.16580628f = -9.5° = 1729bam
    for m in 0..9 {
        for k in 0..20 {
            // 第一列：SHARD 色 13、角度 f0、初速 4.0（单层）、flags 68 → RING_A
            sh_reset(0);
            sh_sprite(0, SHARD, 13);
            sh_offset(0, 0.0fx, 0.0fx);    // Sub17 shoot_offset(0, 0, 0)
            sh_aim(0, 0);
            sh_ring(0, 1);
            sh_count(0, n, 1);
            sh_speed(0, 4.0fx, (0.6fx - 4.0fx) / 1);
            sh_angle(0, f0, 0deg);
            sh_xform(0, RING_A);
            sh_fire(0);
            // 第二列：同型、角度 f1、flags 68 → RING_B
            sh_reset(1);
            sh_sprite(1, SHARD, 13);
            sh_offset(1, 0.0fx, 0.0fx);
            sh_aim(1, 0);
            sh_ring(1, 1);
            sh_count(1, n, 1);
            sh_speed(1, 4.0fx, (0.6fx - 4.0fx) / 1);
            sh_angle(1, f1, 0deg);
            sh_xform(1, RING_B);
            sh_fire(1);
            f0 = f0 + 1547bam;
            f1 = f1 - 1729bam;
            // 自机狙环：原作 $SELF_TIME % 120 == 0（本循环里即每块首轮 k == 0）
            if k == 0 {
                sh_reset(2);
                sh_sprite(2, SHARD, 2);
                sh_offset(2, 0.0fx, 0.0fx);
                sh_aim(2, 1);
                sh_ring(2, 1);
                sh_count(2, n_aim, 1);
                sh_speed(2, s_aim, (0.6fx - s_aim) / 1);
                sh_angle(2, 0deg, 0deg);   // bullet_circle_aimed：a1=0、a2=0
                sh_fire(2);
            }
            wait(6);
        }
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                   // Sub9 enemy_set_hitbox(56, 56, 32) → min(56,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 原文段起始位置未知，取 §13.2 默认 (0,96)
    loop { wait(600); }
}
