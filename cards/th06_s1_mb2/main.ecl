// th06_s1_mb2 —— 东方红魔乡 Stage 1 中 boss（露米娅）符卡 月符「ムーンライトレイ」
// 原文：ecldata1.ecl.txt Sub10 → Sub11（spellcard_start + 移到中央 + 环自机狙自动射击）+ Sub12（两条交叉扫射激光），
//       仅 H/L 两档，timer_callback_threshold(1320)。逐段对照见 report.md。
// Sub9 遗留 shoot_offset(0, -12, 0)：环与激光原点都在 boss 位置下移 12（mapping §4.1 / §14.1）。
const TIME_LIMIT: int = 1320;
const SPELL_ID: int = 0;
const BULLET: int = 128;   // TH06 弹型 0 PELLET 小玉

// Sub12 +60：move_rand_in_bounds(-π, π); move_speed(2.0); move_time_decelerate(120)
// bounds = move_bounds_set(32, 48, 352, 144) → 我方 (-160, 48)-(160, 144)（mapping §7.3）
sub wander(spd: fx, t: int) {
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
    move_to(t, tx, ty, 2);
}

// Sub11 +120：shoot_disable 下 bullet_circle_aimed 只配置参数，随后 shoot_interval_delayed 自动射击（mapping §4.3 写法 A）
// H: 42 颗 × 2.5 速度 / 40 帧；L: 48 颗 × 2.8 速度 / 25 帧（均自机狙整周环）
async sub ring_shooter() {
    var rank: int = global(GVAR_RANK);
    var interval: int = 40;
    var cnt: int = 42;
    var spd: fx = 2.5fx;
    if rank >= RANK_LUNATIC { interval = 25; cnt = 48; spd = 2.8fx; }
    sh_reset(0);
    sh_sprite(0, BULLET, 6);          // sprite 0 = PELLET，16px 弹色号原样（mapping §3）
    sh_offset(0, 0.0fx, -12.0fx);     // Sub9 遗留 shoot_offset(0, -12, 0)
    sh_aim(0, 1);                     // bullet_circle_aimed
    sh_ring(0, 1);
    sh_count(0, cnt, 1);
    sh_speed(0, spd, 0fx);
    sh_angle(0, 0deg, 0deg);
    // shoot_interval_delayed(n)：原作首发 = S + (n − 1 − rand(n))（§4.3 帧对齐）。
    // 伴生任务出生当帧不跑（首跑 S+1），故 wait(k − 1) 落在 S + k；k == 0 只能 S+1 发（晚 1 帧，概率 1/n）。
    var k: int = interval - 1 - rand(interval);
    if k > 0 { wait(k - 1); }
    loop {
        sh_fire(0);
        wait(interval);
    }
}

// Sub12：两条 π/8、7π/8 的激光，宽 32→16，预警 30 / 生效 120 / 收缩 16；
// +30 起 120 帧每帧各转 ±86bam（0.008267349 rad = 86.23 bam 取整，mapping §14.2），
// 之后随机游走 120 帧再 jump(0, Sub12_0) 回到开头。
// 激光色：sprite 0、color 6 → 8 色表 [0,2,4,6,8,10,13,15][6] = 13（mapping §14.2）
// Sub12 与 Sub11 的 ret 同帧（同帧 call），所以激光循环直接写在 pattern 里：
// 建激光的帧 = spawn ring_shooter 的帧 S（环任务首跑 S+1），二者相对相位与原作一致。
async sub pattern() {
    move_to(120, 0.0fx, 96.0fx, 2);   // Sub11 move_position_time_decelerate(120, 192.0f, 96.0f)
    wait(120);
    spawn ring_shooter();             // Sub11 +120 起自动射击
    loop {
        var lz_0: int = laser(13, $self_x, $self_y - 12.0fx, 4096bam, 500.0fx, 16.0fx, 30, 120, 16);
        var lz_1: int = laser(13, $self_x, $self_y - 12.0fx, 28672bam, 500.0fx, 16.0fx, 30, 120, 16);
        wait(30);
        for k in 0..120 {
            wait(1);
            lz_rotate(lz_0, 86bam);
            lz_rotate(lz_1, -86bam);
        }
        wait(60);
        wander(2.0fx, 120);
        wait(120);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);               // enemy_set_hitbox(48, 56, 32) → min(48,56)/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
