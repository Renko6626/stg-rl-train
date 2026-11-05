// th06_s7_b2 —— 东方红魔乡 Stage 7(Extra) boss 芙兰朵露 符卡 禁忌「クランベリートラップ」
// 原文：ecldata7 Sub39（入口）→ Sub40（宣言 + 移中央）+ Sub41（使魔生成 + boss 游走）→ Sub42（使魔行为），
//       时限 3300（钳到 3000）。子使魔的 $SELF_LIFE（创建时的 life）按十进制各位数字决定落点 / 移动 / 弹种 / 轮数，
//       故把 life 当参数传进 familiar()。逐段对照见 report.md。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 121;
const OUTLINE: int = 32;   // TH06 弹型 1 RING_BALL
const BALL: int = 48;      // TH06 弹型 3 BALL

// 与 TH06 一致：先进过场地，再离开（留 16px 贴图余量）就退场（§6.2）
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

// Sub42：使魔。life 的各位数字：
//   个位 i0 = 初始角（0..3 → 四角 (-192,0)/(192,0)/(192,448)/(-192,448)）
//   十位 i5 = 外层次数（移动+扫射轮数）
//   百位 i3 ≠ 0 → 每轮 I1 反向
//   千位 i2 = 0 → 单颗 RING_BALL 朝场心 (0,224)；= 1 → 单颗 BALL 自机狙
async sub familiar(life: int) {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_collision(0)
    set_hitbox(9.333fx);                        // enemy_set_hitbox(28,28,32) → min(w,h)/3
    spawn oob_guard();
    wait(60);
    var i0: int = life % 10;
    var i1: int = 0;
    if i0 == 0 { move_to(0, -192.0fx, 0.0fx, 0); i1 = 0; }
    else if i0 == 1 { move_to(0, 192.0fx, 0.0fx, 0); i1 = 1; }
    else if i0 == 2 { move_to(0, 192.0fx, 448.0fx, 0); i1 = 2; }
    else { move_to(0, -192.0fx, 448.0fx, 0); i1 = 3; }
    var i5: int = (life / 10) % 10;
    var i3: int = (life / 100) % 10;
    if i3 != 0 { i1 = i1 - 1; }
    if i1 < 0 { i1 = 3; }
    var i2: int = (life / 1000) % 10;
    var f1: fx = 0fx;
    var f3: fx = 0fx;
    var f0: angle = 0deg;
    var outer: int = 0;
    while outer < i5 {
        // Sub42_796：以当前位置（先前落点）为基准，按 I1 取对角镜像点
        f1 = $self_x;
        f3 = $self_y;
        if i1 == 0 { f3 = f3 + 448.0fx; }
        else if i1 == 1 { f1 = f1 - 384.0fx; }
        else if i1 == 2 { f3 = f3 - 448.0fx; }
        else { f1 = f1 + 384.0fx; }
        // Sub42_1152：为下一轮更新 I1
        if i3 == 0 { i1 = i1 - 1; } else { i1 = i1 + 1; }
        if i1 < 0 { i1 = 3; }
        else if i1 > 3 { i1 = 0; }
        move_to(120, f1, f3, 2);                // move_position_time_decelerate(120, %F1, %F3)
        // Sub42_1448 内层：set_int($I4,10) 的 jump_dec 循环，每 12 帧一发，共 10 发
        for k in 0..10 {
            if i2 == 0 {
                f0 = atan2(224.0fx - $self_y, 0.0fx - $self_x);
                _ = fire(OUTLINE, 4, $self_x, $self_y, 1.3fx, f0, none, none);
            } else {
                _ = fire(BALL, 6, $self_x, $self_y, 1.3fx, aim_player(), none, none);
            }
            wait(12);
        }
        wait(1);                                 // +1: //73
        outer = outer + 1;
    }
    wait(30);                                    // +30: //103
    die();                                       // enemy_delete(0)
}

// Sub41 的 boss 随机游走（move_rand_in_bounds + move_speed(2.5) + move_time_decelerate(90)）。
// 边界来自 Sub37/Sub38 的 move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)。
sub wander(spd: fx, t: int, bx0: fx, by0: fx, bx1: fx, by1: fx) {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }
    if $self_x < bx0 + 96.0fx {
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > bx1 - 96.0fx {
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < by0 + 48.0fx && v < 0 { v = 0 - v; }
    if $self_y > by1 - 48.0fx && v > 0 { v = 0 - v; }
    var d: fx = spd * t / 2;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < bx0 { tx = bx0; } else if tx > bx1 { tx = bx1; }
    if ty < by0 { ty = by0; } else if ty > by1 { ty = by1; }
    move_to(t, tx, ty, 2);
}

// Sub39+Sub40+Sub41：宣言前奏（移中央 120 帧）→ 使魔生成循环
async sub pattern() {
    move_to(120, 0.0fx, 80.0fx, 2);             // Sub40 move_position_time_decelerate(120, 192, 80)
    wait(120);                                   // Sub40 +120 ret
    var i7: int = 0;                             // Sub39 set_int($I7,0)（原文仅 math_inc）
    loop {
        // Sub41 s=0（P=120）
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(20));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(22));
        wander(2.5fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(160);
        // s=160
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1121));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1123));
        wander(2.5fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(160);
        // s=320
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(20));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(22));
        wait(80);
        // s=400
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(111));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(113));
        wander(2.5fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(200);
        // s=600
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1111));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1113));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1010));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(1012));
        wander(2.5fx, 90, -160.0fx, 48.0fx, 160.0fx, 120.0fx);
        wait(200);
        // s=800
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(111));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(123));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(10));
        _ = spawn_enemy(-190.7fx, 0.0fx, 1, 0, 0, 0, familiar(22));
        i7 = i7 + 1;
        wait(7);                                 // +7: //807 jump(0, Sub41_36)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                         // Sub37 enemy_set_hitbox(56,56,32) → 56/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
