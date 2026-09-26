// th06_s5_mb3 —— 东方红魔乡 Stage 5 中 boss 符卡 奇術「幻惑ミスディレクション」（Hard/Lunatic 版）
// 原文：ecldata5.ecl.txt Sub18 → Sub19（宣言 + 120 帧移中央）→ Sub20（左右交替调度）→ Sub21/Sub22（攻击），时限 1800。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 86;   // 原文 spellcard_start(2, H=86 / L=87, "ST_ECLDATA5_SUB18_1")：本卡取 H 的 86（仅 UI/计分）
const KUNAI: int = 80;      // TH06 弹型 4 KUNAI（半边长 2.5）
const ARROWHEAD: int = 16;  // TH06 弹型 8 DAGGER（半边长 4.5）

// Sub21/22 的 bullet_effects(1, -1, -1, -1, -1, -1, -1, -1) + flags 2052(0x800|0x4)：
// 0x800 = 碰左右上三面场界反弹、速度保持（f0 < 0）；撞界次数 i0 = 1。0x4 出生特效不模拟（mapping §5）。
xformdef BOUNCE1 { bounce_arm(7, 1); }

// Sub21/22 的 +80 起：bullet_fan_aimed(8, 3, 11, 4, s1, 1.2, 0, a7, 516)，共 3 发（jump_dec $I4=3）。
sub fan3(s1: fx, a7: angle) {
    for k in 0..3 {
        sh_reset(1);
        sh_sprite(1, ARROWHEAD, 6);          // 32px 弹色号 3 → 6（mapping §3）
        sh_offset(1, 0.0fx, 0.0fx);          // Sub19 shoot_offset(0, 0, 0)
        sh_aim(1, 1);
        sh_ring(1, 0);
        sh_count(1, 11, 4);
        sh_speed(1, s1, (1.2fx - s1) / 4);
        sh_angle(1, 0deg, a7);               // a1 = 0°、a2 = 18°
        sh_fire(1);
        wait(18);
    }
}

// Sub21：移左 (-96,144) → 自机狙环自动射击（shoot_interval(6)，+60 处 shoot_interval(0)）
// → 瞬移到 (96,96) → 三连扇形 → 移回 (0,144)。
// shoot_disable 期间 bullet_circle_aimed 只配置不发；shoot_interval(6) 首发 S+5（mapping §4.3 写法 B，在本任务里数帧）。
sub attack_left() {
    var rank: int = global(GVAR_RANK);
    var s1: fx = 5.5fx;
    var a7: angle = 3277bam;                 // 18°（H/L 相同）
    var n: int = 15;                         // !H 15 颗 × 2 层，!L 19 颗
    if rank >= RANK_LUNATIC { s1 = 6.5fx; n = 19; }

    move_to(40, -96.0fx, 144.0fx, 2);
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 2);
    sh_speed(0, 1.5fx, (0.8fx - 1.5fx) / 2);
    sh_angle(0, 0deg, 0deg);                 // bullet_circle_aimed a1 = 0°、a2 = 0°
    sh_xform(0, BOUNCE1);
    wait(5); sh_fire(0);                     // shoot_interval(6) 首发 S+5，之后每 6 帧：S+11,…,S+59 共 10 发
    for k1 in 0..9 { wait(6); sh_fire(0); }
    wait(1);                                 // 补到 S+60（shoot_interval(0) 处） // 第 6,12,…,60 帧各一发（原来 shoot_interval(6)）

    move_to(0, 96.0fx, 96.0fx, 0);           // move_position(288.0f, 96.0f) → x=96
    wait(20);
    fan3(s1, a7);
    wait(60);
    wait(60);
    move_to(0, 0.0fx, 144.0fx, 0);           // move_position(192.0f, 144.0f)
    wait(30);
}

// Sub22：Sub21 的镜像（移右 (96,144) → 瞬移到 (-96,96)）；环颗数 !H 12 / !L 16，其余同。
sub attack_right() {
    var rank: int = global(GVAR_RANK);
    var s1: fx = 5.5fx;
    var a7: angle = 3277bam;
    var n: int = 12;
    if rank >= RANK_LUNATIC { s1 = 6.5fx; n = 16; }

    move_to(40, 96.0fx, 144.0fx, 2);
    sh_reset(0);
    sh_sprite(0, KUNAI, 2);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 1);
    sh_ring(0, 1);
    sh_count(0, n, 2);
    sh_speed(0, 1.5fx, (0.8fx - 1.5fx) / 2);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, BOUNCE1);
    wait(5); sh_fire(0);                     // shoot_interval(6) 首发 S+5，之后每 6 帧：S+11,…,S+59 共 10 发
    for k2 in 0..9 { wait(6); sh_fire(0); }
    wait(1);                                 // 补到 S+60（shoot_interval(0) 处）

    move_to(0, -96.0fx, 96.0fx, 0);          // move_position(96.0f, 96.0f) → x=-96
    wait(20);
    fan3(s1, a7);
    wait(60);
    wait(60);
    move_to(0, 0.0fx, 144.0fx, 0);
    wait(30);
}

async sub pattern() {
    var i0: int = 0;
    // Sub19：move_position_time_decelerate(120, 192.0f, 144.0f) + +120 ret
    move_to(120, 0.0fx, 144.0fx, 2);
    wait(120);
    // Sub20：i0 = rand(2)；0 → Sub21、否则 Sub22；math_int_sub($I0, 1, $I0) 即 i0 = 1 − i0 → 左右交替
    i0 = rand(2);
    loop {
        if i0 == 0 { attack_left(); } else { attack_right(); }
        i0 = 1 - i0;
    }
}

async sub boss_main() {
    set_hitbox(13.33fx);   // 段外继承：boss 初始化 Sub13 (40,56,32) → §6.1b
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
