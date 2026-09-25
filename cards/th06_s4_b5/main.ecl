// th06_s4_b5 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）符卡 土符「レイジィトリリトン上級」
// 原文：ecldata4.ecl.txt Sub69（:2268）→ Sub70（:2276，宣言 + 移到中央 + timer 2100）→ Sub71（:2297，攻击循环）；
//       ranks = N/L 两档（spellcard_start id 57/58/59）。逐段对照见 report.md。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 57;     // 原文 !N 的 spellcard_start id（H=58 / L=59）；仅 UI/计分
const OUTLINE: int = 32;      // TH06 弹型 1 RING_BALL
const BALL: int = 48;         // TH06 弹型 3 BALL
const G_ZIG: int = 16;        // 全局自由段槽：本发的 0x40 转向角（BAM），供弹上任务取

// Sub71：bullet_effects(50, 2, -1, -1, %F0, 2.2f, -1, -1) + flags 67(0x40|0x2|0x1)。
//   0x2 出生特效按 §4.2 不模拟。
//   0x40 = 每 50 帧一周期：速度自当前值线性减到 0，周期末「转 f0、速度设为 f1」，i1=2 次。
//   0x1 出生冲刺在这里被 0x40 覆盖、无效果：decomp 先算 0x1 分支的 velocity（BulletManager.cpp:712-717），
//   紧接着 0x40 分支用 speed/angle 重算 velocity（:751-776），后者赢。
// f0 每发随机（set_float_rand_bound_min($F0, π, -π/2) → [-π/2, π/2)），xformdef 参数必须是编译期常量：
// 所以减速 + 周期末定速（2.2 是常量）交给 xform，转向（运行期随机角）交给弹上任务，参数走全局槽（同 s2_b3 做法）。
// @N 是后置延迟：step_speed 先发射再等 50 帧。
xformdef ZIG_DECEL {
    @50 step_speed(0fx, 50);
    set_speed(2.2fx);          // 周期 1 末：turn 由任务做，速度置 f1=2.2
    @50 step_speed(0fx, 50);
    set_speed(2.2fx);          // 周期 2 末
}

// 弹上任务：出生下一帧跑（sh_task/fire task 位比 xform 晚 1 帧），在第 50/100 帧各转 f0。
// wait(49) 后正好是出生后第 50 帧，与 xform 的 set_speed 同帧对齐。
async sub zigzag() {
    var a: int = global(G_ZIG);            // 本发共享的转向角；下一发 9 帧后才覆写，读得到
    wait(49);
    turn(0, a as angle);
    wait(50);
    turn(0, a as angle);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var n: int = 0;                        // !E 原文没有 bullet_random（只有 !N/!H/!L 三条）
    if rank == RANK_NORMAL { n = 10; }     // !N bullet_random(1, 12, 10, 1, …)
    else if rank == RANK_HARD { n = 12; }  // !H 12
    else if rank >= RANK_LUNATIC { n = 15; }  // !L 15

    move_to(120, 0.0fx, 80.0fx, 2);        // Sub70 move_position_time_decelerate(120, 192, 80)
    wait(120);                             // Sub70 +120 ret → Sub71

    // Sub71 瞄准扇发射器槽：bullet_fan_aimed(3, 6, 7, 2, 2.8f, 1.2f, 0.0f, 0.34906584f, 4)
    sh_reset(1);
    sh_sprite(1, BALL, 6);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 7, 2);                     // 7 颗 × 2 层
    sh_speed(1, 2.8fx, (1.2fx - 2.8fx) / 2);  // 逐层 -0.8
    sh_angle(1, 0deg, 3641bam);            // a1=0、a2=0.34906584f=20°=3641bam

    loop {                                 // Sub71_20 … +9: jump(0, Sub71_20)
        var a: int = rand(32768) - 16384;  // 每发 f0 = [-π/2, π/2)
        set_global(G_ZIG, a);
        // bullet_random(1, 12, n, 1, 3.3f, 2.3f, 3.1415927f, 0.0f, 67)：角度 [0, π)、速度 [2.3, 3.3)
        for j in 0..n {
            var sp: fx = 2.3fx + 1.0fx / 256 * rand(256);
            var an: angle = rand(32768) as angle;
            _ = fire(OUTLINE, 12, $self_x, $self_y, sp, an, ZIG_DECEL, zigzag);
        }
        // cmp_float(%PLAYER_Y, %SELF_Y); jump_geq(0, Sub71_320)：玩家在下方时跳过瞄准扇
        if $player_y < $self_y {
            sh_fire(1);
        }
        wait(9);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    kill_all_enemies(KILL_SILENT);         // Sub70 enemy_kill_all()（跳过调用者自己）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);  // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);  // 段起点未知，按 §13.2 默认 (0,96)
    loop { wait(600); }
}
