// th06_s5_mb2 —— 东方红魔乡 Stage 5 中 boss 符卡 奇術「ミスディレクション」
// 原文：ecldata5 Sub18 → Sub19（宣言 + 移到中央）+ Sub20（左右交替调度）+ Sub21/Sub22（镜像攻击），时限 1800。
// 逐段对照 / 近似见 report.md。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 84;      // 原文 E 的 spellcard_start id（N 为 85）；纯脚本词汇，引擎不登记
const KUNAI: int = 80;         // TH06 弹型 4 KUNAI（16px），色号原样照抄
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER（32px），色号查表：3 → 6

// 原文 Sub21/Sub22：镜像的一次攻击（Sub21 先左后右，Sub22 先右后左）。
// 原地环（bullet_circle_aimed，shoot_interval(6) 自动连发到 +60）+ 11 路自机狙扇（+80 起 3 轮）。
sub attack(mirror: int) {
    var rank: int = global(GVAR_RANK);
    var n_ang: int = 16;       // !E bullet_circle_aimed c1
    var n_lay: int = 1;        // !E c2
    var fs1: fx = 3.5fx;       // !E bullet_fan_aimed s1
    if rank == RANK_NORMAL { n_ang = 24; n_lay = 3; fs1 = 4.5fx; }   // !N
    var xa: fx = -96.0fx;      // Sub21 先到左；Sub22 镜像
    var xb: fx = 96.0fx;
    if mirror != 0 { xa = 96.0fx; xb = -96.0fx; }

    // Sub21/22 开头 move_position_time_decelerate(40, …, 144.0f)：40 帧减速平移
    move_to(40, xa, 144.0fx, 2);

    // bullet_circle_aimed(4, 2, c1, c2, 3.0f, 1.2f, 0.0f, 0.0f, 4) + shoot_interval(6)
    // → 配置发射器，之后每 6 帧自动开火一次；+60 处 shoot_interval(0) 停（原作 10 发，晚 1 帧）
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_offset(0, 0.0fx, 0.0fx);       // Sub19 shoot_offset(0.0f, 0.0f, 0.0f)
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n_ang, n_lay);
    sh_speed(0, 3.0fx, (1.2fx - 3.0fx) / n_lay);
    sh_angle(0, 0deg, 0deg);          // a1 = a2 = 0
    for kc in 0..10 {
        wait(6);
        sh_fire(0);
    }

    // +60: move_position(288.0f/96.0f, 96.0f)：瞬移到另一侧
    move_to(0, xb, 96.0fx, 0);

    // +80: bullet_fan_aimed(8, 3, 11, 4, fs1, 1.2f, 0.0f, 12°, 516) ×3，间隔 18 帧
    wait(20);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 6);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 11, 4);
    sh_speed(1, fs1, (1.2fx - fs1) / 4);
    sh_angle(1, 0deg, 2185bam);       // 0.20943952f = 12°
    for kf in 0..3 {
        sh_fire(1);
        wait(18);
    }

    // +158/+218 只有 anm，+218 move_position(192.0f, 144.0f) 回中央，+248 ret
    wait(24);                          // 134 → 158
    wait(60);                          // 158 → 218
    move_to(0, 0.0fx, 144.0fx, 0);
    wait(30);                          // 218 → 248
}

// Sub20：i0 = rand(2) 决定先左还是先右，之后 math_int_sub($I0, 1, $I0) 即 i0 = 1 − i0 永远交替
async sub pattern() {
    // Sub19 move_position_time_decelerate(120, 192.0f, 144.0f, 0.0f) + +120 ret
    move_to(120, 0.0fx, 144.0fx, 2);
    wait(120);
    var i0: int = rand(2);
    loop {
        if i0 == 0 { attack(0); } else { attack(1); }
        i0 = 1 - i0;
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    // 原文段起始位置未知（Sub19 直接移向中央），取 (0,96) 再移向 (0,144)
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
