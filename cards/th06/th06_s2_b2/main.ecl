// th06_s2_b2 —— 东方红魔乡 Stage 2 boss（琪露诺）符卡 氷符「アイシクルフォール」
// 原文：ecldata2.ecl.txt Sub30 → Sub31（宣言 + move_position_time_decelerate(120, 192, 96)）+ Sub32（冰柱循环），时限 1800。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 9;      // 原文 spellcard_start(0, 9/10, …)：E=9、N=10，本卡取 E 的值
const SHARD: int = 96;        // TH06 弹型 5 SHARD（16px，色号原样）
const BALL: int = 48;         // TH06 弹型 3 BALL（16px，色号原样）

// flags 68 = 0x40|0x4 + bullet_effects(60, 1, -1, -1, +1.5707964f, 1.6f, -1, -1)：
// 出生起 60 帧速度线性减到 0 → 转 +90° → 速度设为 1.6（mapping §5 的 0x40 周期）
xformdef ICICLE_R { @60 step_speed(0fx, 60); turn(90deg); set_speed(1.6fx); }
// bullet_effects(60, 1, -1, -1, -1.5707964f, 1.4f, -1, -1)：转 −90° → 速度 1.4
xformdef ICICLE_L { @60 step_speed(0fx, 60); turn(-90deg); set_speed(1.4fx); }

async sub pattern() {
    // Sub31：move_position_time_decelerate(120, 192.0f, 96.0f, 0.0f)，+120 ret（boss 起点取 (192,96)）
    move_to(120, 0.0fx, 96.0fx, 2);
    wait(120);

    // ── Sub32 状态初始化（set_int($I7,0) 之前的一次性设置）────────────────────
    var i0: int = 0;                       // $I0：是否发自机狙（0 = 发）
    var i3: int = 0;                       // $I3：冰柱每条的层数 3/4/5
    var i4: int = 0;                       // $I4：内层 jump_dec 计数 11→1
    var i7: int = 0;                       // $I7：外层轮次
    var a0: angle = 0deg;                  // %F0：第一条冰柱基准角
    var a1: angle = 0deg;                  // %F1：第二条冰柱基准角
    var a2: angle = 0deg;                  // %F2：随机偏角 [0,512bam)
    var a3: angle = 0deg;                  // %F3：本发实际角度
    var rank: int = global(GVAR_RANK);

    // 冰柱两条线，sprite/色/出弹口一次配好；xform 不同（右转 / 左转）
    sh_reset(0);
    sh_sprite(0, SHARD, 6);
    sh_offset(0, 0.0fx, -12.0fx);          // Sub21 shoot_offset(0.0f, -12.0f, 0.0f)
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_xform(0, ICICLE_R);
    sh_reset(1);
    sh_sprite(1, SHARD, 6);
    sh_offset(1, 0.0fx, -12.0fx);
    sh_aim(1, 0);
    sh_ring(1, 0);
    sh_xform(1, ICICLE_L);
    // !NHL bullet_fan_aimed(3, 13, 5, 1, 2.0f, 0.5f, 0.0f, 0.2617994f, 4)：N 档 5 向自机狙中玉
    sh_reset(2);
    sh_sprite(2, BALL, 13);
    sh_offset(2, 0.0fx, -12.0fx);
    sh_aim(2, 1);
    sh_ring(2, 0);
    sh_count(2, 5, 1);
    sh_speed(2, 2.0fx, (0.5fx - 2.0fx) / 1);
    sh_angle(2, 0deg, 2731bam);            // a2 = 0.2617994f = 15°

    i7 = 0;
    loop {                                 // Sub32_20
        i4 = 11;
        a0 = -2048bam;                     // set_float($F0, -0.19634955f) = -11.25°
        a1 = -30720bam;                    // set_float($F1, -2.9452431f) = -168.75°
        for k4 in 0..11 {                  // Sub32_80 … jump_dec(0, Sub32_80, $I4)：循环体跑 11 次
            i4 = 11 - k4;                  // TH06 循环体里 $I4 = 11,10,…,1（math_int_mod 用它）
            a2 = rand(512) as angle;       // set_float_rand_bound($F2, 0.049087387f) = [0, 2.813°)
            a3 = a0 + a2;                  // math_float_add($F3, %F0, %F2)
            // cmp_int($I7,3) / jump_geq / cmp_int($I7,6) / jump_geq → $I3 = 3/4/5
            if i7 >= 3 {
                if i7 >= 6 { i3 = 5; } else { i3 = 4; }
            } else { i3 = 3; }
            // bullet_fan(5, 6, 1, $I3, 6.5f, 0.5f, %F3, 0.0f, 68)：1 颗 × $I3 层，层间速度 6.5→0.5
            sh_count(0, 1, i3);
            sh_speed(0, 6.5fx, (0.5fx - 6.5fx) / i3);
            sh_angle(0, a3, 0deg);
            sh_fire(0);
            // math_float_sub($F3, %F1, %F2)；第二条线（−90°，末速 1.4）
            a3 = a1 - a2;
            sh_count(1, 1, i3);
            sh_speed(1, 6.5fx, (0.5fx - 6.5fx) / i3);
            sh_angle(1, a3, 0deg);
            sh_fire(1);
            // math_float_add($F0, %F0, 0.09817477f) / math_float_add($F1, %F1, -0.09817477f)
            a0 = a0 + 1024bam;             // +5.625°
            a1 = a1 - 1024bam;             // −5.625°
            // 自机高度分档：i0 == 0 才发自机狙（y<128 恒发；128–192 恒发；192–256 隔发；≥256 每 3 发）
            i0 = 1;
            if $player_y < 128.0fx { i0 = 0; }
            else if $player_y < 192.0fx { i0 = i4 % 1; }
            else if $player_y < 256.0fx { i0 = i4 % 2; }
            else { i0 = i4 % 3; }
            if i0 == 0 && rank != RANK_EASY {
                sh_fire(2);                // bullet_fan_aimed（!NHL）
            }
            // effect_sound(9) 丢弃
            wait(27);                      // +27
        }
        i7 = i7 + 1;                       // math_int_add($I7, $I7, 1); jump(0, Sub32_20)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                    // Sub21 enemy_set_hitbox(48, 56, 32) → min/3 = 16
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
