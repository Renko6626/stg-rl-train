// th06_s7_b15 —— 东方红魔乡 Stage 7(Extra) 芙兰朵露 boss 非符 8
// 原文：ecldata7.ecl.txt Sub76（:2216-2260），timer/life 阈值 1800 收段。逐段对照见 report.md。
const TIME_LIMIT: int = 1800;
const RICE: int = 64;       // TH06 弹型 2 RICE
const LAYERS: int = 6;      // count2

// flags 513 = 0x200|0x1：低位 1 = 出生冲刺（0x200 音效丢弃）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// move_bounds_set(32.0f, 48.0f, 352.0f, 120.0f) → 我方 (-160, 48)-(160, 120)
sub wander(spd: fx, t: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 120.0fx;
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

async sub pattern() {
    // Sub76 序（时间 0）：boss_set_life_count / spellcard_end / enemy_life_set / 回调链由外壳接管。
    set_enemy_flag(ENEMY_NO_BODY, 0);   // invisible(0)+collision(1)+interactable(1) → 体碰开
    kill_all_enemies(KILL_SILENT);      // enemy_kill_all()

    wait(90);                           // +60: //90
    // shoot_disable(); bullet_circle_aimed(2, 6, 5, 6, 5.5f, 1.0f, 0.0f, 0.0f, 513);
    // shoot_enable(); shoot_interval(20);  ← disable 期间只写参数不开火，首发由自动射击在 +109 打出
    sh_reset(0);
    sh_offset(0, 0.0fx, -12.0fx);       // Sub76:27 shoot_offset(0,-12,0)，粘滞；须在 sh_reset 之后，否则被清零
    sh_sprite(0, RICE, 6);
    sh_aim(0, 1);                       // bullet_circle_aimed：自机狙
    sh_ring(0, 1);                      // 整周环
    sh_count(0, 5, LAYERS);             // count1 = 5 颗 × 6 层
    sh_speed(0, 5.5fx, (1.0fx - 5.5fx) / LAYERS);
    sh_angle(0, 0deg, 0deg);
    sh_xform(0, BURST);

    wander(2.5fx, 90);                  // Sub76_532：首次随机游走

    var t: int = 0;
    loop {
        wait(1);
        t = t + 1;
        if t % 20 == 19 { sh_fire(0); }         // shoot_interval(20)，写法 B：首发 S+19（§4.3）
        if t % 110 == 0 { wander(2.5fx, 90); }  // +100 math_inc → +10 jump(90, Sub76_532)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                // 沿回调链上游 Sub37 enemy_set_hitbox(56,56,32) → 56/3（mapping §6.1b/§8）
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
