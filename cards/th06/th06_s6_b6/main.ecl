// th06_s6_b6 —— 东方红魔乡 Stage 6 boss 十六夜咲夜 符卡 獄符「千本の針の山」（H/L 版）
// 原文：ecldata6.ecl.txt Sub41 → Sub42（宣言 + 移中央 120 帧）→ Sub43（攻击循环），时限 2400。
const TIME_LIMIT: int = 2400;
const SPELL_ID: int = 107;   // 原文 spellcard_start(2, H=107 / L=108, "ST_ECLDATA6_SUB33_0")；取 H 的 107（仅 UI/计分）
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（32px）；色号 1 经 §3 色表 → 2
const SHARD: int = 96;       // TH06 弹型 5 SHARD（16px，色号原样）

// Sub43 波 1/2：bullet_effects(100, -1, -1, -1, 0.0f, ±0.03141593f, …) + flags 544(0x20|0x200)。
// 0x20 = 前 100 帧每帧 speed += f0(=0)、angle += f1(±1.8°=±328bam)。@N 是后置延迟，故 stop_fx 挂在该槽之后。
xformdef CURVE_R { set_accel(0.0fx); @100 set_ang_vel(328bam);  stop_fx(); }
xformdef CURVE_L { set_accel(0.0fx); @100 set_ang_vel(-328bam); stop_fx(); }
// Sub43 波 3/4：bullet_effects(1, -1, -1, -1, -1.0f, …) + flags 2560(0x800|0x200)。
// 0x800 = 碰左右上三面场界反弹、速度保持（f0 < 0）；撞界次数 i0 = 1。
xformdef BOUNCE1 { bounce_arm(7, 1); }

// Sub43 +17：move_rand_in_bounds(-π, π) + move_speed(1.5f) + move_time_decelerate(90)。
// 边界沿用 Sub21 的 move_bounds_set(32,48,352,120) → 我方 (-160,48)-(160,120)；位移 = 1.5×90/2 = 67.5。
sub wander_move() {
    var v: int = rand(65536);
    if v >= 32768 { v = v - 65536; }                       // (-π, π)
    if $self_x < -64.0fx {                                 // lower.x + 96
        if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
    }
    if $self_x > 64.0fx {                                  // upper.x - 96
        if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
    }
    if $self_y < 96.0fx && v < 0 { v = 0 - v; }            // lower.y + 48
    if $self_y > 72.0fx && v > 0 { v = 0 - v; }            // upper.y - 48
    var d: fx = 67.5fx;
    var tx: fx = $self_x + cos(v as angle) * d;
    var ty: fx = $self_y + sin(v as angle) * d;
    if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
    if ty < 48.0fx { ty = 48.0fx; } else if ty > 120.0fx { ty = 120.0fx; }
    move_to(90, tx, ty, 2);
}

// Sub42（宣言 + 移中央）→ Sub43（攻击循环）。move_position_time_decelerate 的目标被 move_bounds 夹到 y=120。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);        // Sub42 enemy_kill_all()（跳过调用者 boss）
    move_to(120, 0.0fx, 120.0fx, 2);      // move_position_time_decelerate(120, 192.0f, 144.0f)，y 夹到 120
    wait(120);                            // Sub42 +120 ret → Sub43

    var rank: int = global(GVAR_RANK);
    // Sub43 波 3/4 颗数：原作 !H 12 / !L 32。L 的 32 颗照抄会把弹峰推到 1394（> 观测上限 1024）：
    // TH06 弹池只有 640（BulletManager.hpp:125，池满时整批放弃），原作画面被池压住；我方池 8192，
    // 只能按静止截止近似，L 折到 18 颗（实测弹峰 926）。详见 report.md「近似」。
    var n34: int = 12;
    if rank >= RANK_LUNATIC { n34 = 18; }

    // 槽 0/1/2 固定配置，循环里只改基准角 f0 与开火。
    sh_reset(0);
    sh_sprite(0, ARROWHEAD, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 16, 1);
    sh_speed(0, 2.0fx, 0fx);
    sh_xform(0, CURVE_R);
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 2);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 16, 1);
    sh_speed(1, 2.0fx, 0fx);
    sh_xform(1, CURVE_L);
    sh_reset(2);
    sh_sprite(2, SHARD, 2);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, n34, 1);
    sh_speed(2, 1.3fx, 0fx);
    sh_xform(2, BOUNCE1);

    var f0: angle = 0deg;
    loop {
        f0 = rand(65536) as angle;        // Sub43_0 set_float_rand_bound_min($F0, 2π, −π)
        for k in 0..5 {                   // set_int($I4, 5) + jump_dec(0, Sub43_44, $I4)：循环体共 5 次
            // bullet_circle 的 angle2 = -164bam 是逐层偏移，本卡 count2=1 用不到，故 sh_angle 步长写 0。
            sh_angle(0, f0, 0deg); sh_fire(0); f0 = f0 + 1024bam;   // +0  波 1：ARROWHEAD 16 颗（右转）
            wait(3);
            sh_angle(1, f0, 0deg); sh_fire(1); f0 = f0 + 1024bam;   // +3  波 2：ARROWHEAD 16 颗（左转）
            wait(3);
            sh_angle(2, f0, 0deg); sh_fire(2); f0 = f0 + 1024bam;   // +6  波 3：SHARD n34 颗（反弹）
            wait(3);
            sh_angle(2, f0, 0deg); sh_fire(2); f0 = f0 + 1024bam;   // +9  波 4：SHARD n34 颗（反弹）
            wait(8);                                                // +17 jump_dec 回 Sub43_44
        }
        wander_move();                    // +17 move_rand_in_bounds / move_speed / move_time_decelerate
        wait(50);                         // +67 jump(0, Sub43_0)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                  // 该 boss 的 enemy_set_hitbox(56,56,32) → 56/3（mapping §8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
