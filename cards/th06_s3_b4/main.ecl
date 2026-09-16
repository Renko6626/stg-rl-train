// th06_s3_b4 —— 东方红魔乡 Stage 3 boss 符卡「幻符「華想夢葛」」（H/L）
// 原文：ecldata3.ecl.txt Sub36 → Sub37（宣言 + 移到中央 + call Sub10 120 帧）→ Sub38
//       （ex_ins_repeat(2) = ShootStarPattern：每 6 帧沿五角星边发 5 组自机狙扇形），时限 2400。
const TIME_LIMIT: int = 2400;
const SPELL_ID: int = 28;      // Sub37 的 H 档 id（ranks 下界 = Hard）
const BALL: int = 48;          // TH06 弹型 3 BALL（半边长 3）
const STAR_STEP: int = 26214;  // 4π/5 ≈ 26214.4bam：五角星相邻顶点（144°）
const FAN_A2: int = 23406;     // bullet_fan_aimed 的 angle2 = 128.6°

// Sub24 的 move_bounds_set(32,48,352,144) → (-160,48)-(160,144)；反射逻辑照 mapping §7.3。
sub wander(spd: fx, t: int, ease: int) {
    var bx0: fx = -160.0fx;
    var by0: fx = 48.0fx;
    var bx1: fx = 160.0fx;
    var by1: fx = 144.0fx;
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
    move_to(t, tx, ty, ease);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var n1: int = 2;             // !H bullet_fan_aimed count1
    var s1: fx = 1.15fx;         // !H speed1 = 1.0 + bullet_rank_influence +0.15
    if rank >= RANK_LUNATIC { n1 = 4; s1 = 1.35fx; }   // !L: count1=4, speed1=1.2+0.15
    kill_all_enemies(KILL_SILENT);   // Sub37 enemy_kill_all()（跳过调用者，单 boss 卡里 no-op）
    wait(1);                         // Sub37 +1
    move_to(120, 0.0fx, 64.0fx, 2);  // Sub37 move_position_time_decelerate(120, 192, 64)
    wait(120);                       // Sub37 call Sub10(120)：120 帧停顿
    move_to(2000, 0.0fx, 160.0fx, 2); // Sub38 move_position_time_decelerate(2000, 192, 160)
    // Sub38 的子弹属性在 shoot_disable 下配好一次（发射器槽 0）：
    // bullet_fan_aimed(3, 6, n1, 1, s1, 1.0, 0, 23406, 4) → 自机狙扇形（sh_ring 关 = fan）。
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, n1, 1);
    loop {                           // Sub38_292，周期 180 帧
        var ex: fx = $self_x;        // g_EnemyPosVector（var2==0 抓取）
        var ey: fx = $self_y;
        var ppx: fx = $player_x;     // g_PlayerPosVector
        var ppy: fx = $player_y;
        var r: int = rand(65536) - 32768;   // g_StarAngleTable 基准 [-π, π)
        for var2 in 0..160 {         // ex_ins_repeat(2)：每帧 ShootStarPattern
            if var2 % 6 == 0 {       // var2 % 6 == 0 发射一轮
                var frac: fx = (var2 as fx) / 160 * 0.1fx;  // 基准点向自机推进 10%·var2/160
                var bx: fx = ex + (ppx - ex) * frac;
                var by: fx = ey + (ppy - ey) * frac;
                var q: fx = ((var2 % 30) as fx) / 30;       // 星边插值系数 (var2%30)/30
                var b: int = var2 / 30;
                for i in 0..5 {
                    // angle1 = (π/3)·pp − i·(π/6)·pp, pp = var2/160 + 0.5
                    var a1i: int = (2 - i) * 65536 * (2 * var2 + 160) / 3840;
                    var ti: angle = (r as angle) + (((b + 1 + i) * STAR_STEP) as angle);
                    var tj: angle = ti + (STAR_STEP as angle);
                    var p0x: fx = cos(ti) * 112.0fx;   // $F3 星半径
                    var p0y: fx = sin(ti) * 112.0fx;
                    var p1x: fx = cos(tj) * 112.0fx;
                    var p1y: fx = sin(tj) * 112.0fx;
                    var sx: fx = p0x + (p1x - p0x) * q;
                    var sy: fx = p0y + (p1y - p0y) * q;
                    var px: fx = bx + sx;
                    var py: fx = by + sy;
                    var sp: fx = s1 + 1.075fx / 256 * rand(256);  // s1 + rand[0, speed2)
                    sh_offset_abs(0, px, py);
                    sh_angle(0, (a1i) as angle, (FAN_A2) as angle);
                    sh_speed(0, sp, 0fx);
                    sh_fire(0);
                }
            }
            if var2 == 80 {              // Sub38 +80
                wander(3.0fx, 80, 1);    // move_rand_in_bounds + move_speed(3.0) + move_time_accelerate(80)
            }
            wait(1);
        }
        wait(20);                        // 到 Sub38 +100（180 帧）前的 20 帧空档
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                 // Sub21 enemy_set_hitbox(56,56,32) → min(56,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
