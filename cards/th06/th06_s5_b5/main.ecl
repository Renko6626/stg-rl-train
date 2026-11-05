// th06_s5_b5 —— 东方红魔乡 Stage 5 boss 符卡 幻象「ルナクロック」（原文 ecldata5 Sub52/53/54，E/N）
// 原文：Sub53 宣言 + 移到中央，Sub54 循环：bullet_circle(2,6,32,4,3.0,1.2) → ex_ins_call(4,1) 时停
//       + ex_ins_repeat(5)（Stage5Func5 每 9 帧沿自机方向铺 9 颗弧形弹）→ ex_ins_call(4,2) → 时停解除。
//
// 【时停窗口压平】原作 T=198..318 这 120 帧 `isTimeStopped=1`：自机与全场弹整帧早退
// （Player.cpp:158 / BulletManager.cpp:668），对玩家是纯空转 ⇒ 等价于瞬间摆弹。按 mapping §10.1
// 压成 1 帧：boss 按滑行曲线的 7 个采样点定位摆弹、弹直接以 2.0 真速出生、6 次随机改向压成
// 一次 p = 1−(3/4)^6 = 3367/4096 的抽签。符卡时限不烧这 120 帧，与原作 bossTimer 不 tick 一致。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 92;      // 原作 !E 的 id（N 为 93；单 id 常量取 E）
const RICE: int = 64;          // TH06 弹型 2 RICE
const ARROWHEAD: int = 16;     // TH06 弹型 8 DAGGER

// 旋转常量：cos/sin(π/18)、cos/sin(π/4)
const C18: fx = 0.98480775fx;
const S18: fx = 0.17364818fx;
const C45: fx = 0.70710678fx;
const S45: fx = 0.70710678fx;

// bullet_circle(2, 6, 32, 4, 3.0f, 1.2f, 0, 0, 512) → 32 向 × 4 层（3.0/2.55/2.1/1.65）。
// 压平后窗口不占时间，环弹一路直飞，不需要任何停驻变换。
sub ring_fire_a() {
    sh_reset(0);
    sh_sprite(0, RICE, 6);
    sh_offset(0, 0.0fx, 0.0fx);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 32, 1);
    sh_speed(0, 3.0fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_fire(0);
    sh_reset(1);
    sh_sprite(1, RICE, 6);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, 32, 1);
    sh_speed(1, 2.55fx, 0fx);
    sh_angle(1, 0deg, 0deg);
    sh_fire(1);
}

sub ring_fire_b() {
    sh_reset(2);
    sh_sprite(2, RICE, 6);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, 32, 1);
    sh_speed(2, 2.1fx, 0fx);
    sh_angle(2, 0deg, 0deg);
    sh_fire(2);
    sh_reset(3);
    sh_sprite(3, RICE, 6);
    sh_offset(3, 0.0fx, 0.0fx);
    sh_aim(3, 0);
    sh_ring(3, 1);
    sh_count(3, 32, 1);
    sh_speed(3, 1.65fx, 0fx);
    sh_angle(3, 0deg, 0deg);
    sh_fire(3);
}

// ex_ins_repeat(5) = Stage5Func5（EnemyEclInstr.cpp:655）：pp = 第几批（var2/9），批间隔 9 帧。
// 沿「敌→自机」方向取单位向量 u，弧心 C = E + (P−E)·(9−pp)/18 ± u·256，
// 9 颗弹沿半径 256 的弧均分（每次转 −π/18）；`aimMode = FAN_AIMED` ⇒ 弹角 = 出弹点自机狙 + angle1，
// angle1 在 pp 为奇数时（E/N）沿 −π/4 每颗 +π/18 递增，偶数时恒 0。
// 压平后「敌位置 E」取滑行曲线上的采样点 (sx,sy)，boss 实体已瞬移到终点。
// ex_ins_call(4,2) 的随机改向就地抽签（EnemyEclInstr.cpp:585-600，E/N 分支）：
//   >128px → [π/4, π) 随机；≤128px →「弹→自机方向 + π/2 + 整周随机」（等价均匀）。
//   原作每次调用上限 14 颗、命中者改色不再重复；压平版不建模（见 report 近似）。
async sub knives5(sx: fx, sy: fx, pp: int, odd: int) {
    var dx: fx = $player_x - sx;
    var dy: fx = $player_y - sy;
    var dir: angle = atan2(dy, dx);
    var ux: fx = cos(dir);
    var uy: fx = sin(dir);
    var seed: fx = 256.0fx;
    if odd != 0 { seed = -256.0fx; }
    var ms: fx = ((9 - pp) as fx) / 18.0fx;
    var offx: fx = dx * ms + ux * seed;
    var offy: fx = dy * ms + uy * seed;
    var mix: fx = 0fx - ux * seed;
    var miy: fx = 0fx - uy * seed;
    var tx: fx = mix * C45 + miy * S45;
    var ty: fx = 0fx - mix * S45 + miy * C45;
    mix = tx;
    miy = ty;
    var ba: angle = -8192bam;                         // −π/4
    var bx: fx = 0fx;
    var by: fx = 0fx;
    var bl: angle = 0deg;
    for i9 in 0..9 {
        tx = mix * C18 - miy * S18;                   // 转 −π/18
        ty = mix * S18 + miy * C18;
        mix = tx;
        miy = ty;
        bx = sx + offx + mix;
        by = sy + offy + miy;
        bl = atan2($player_y - by, $player_x - bx);    // FAN_AIMED 的自机狙（从出弹点算）
        if odd != 0 { bl = bl + ba; }                  // + angle1
        if rand(4096) < 3367 {                         // ex_ins_call(4,2) ×6 的合并抽签
            if dist(bx - $player_x, by - $player_y) > 128.0fx {
                bl = 8192bam + (rand(24576) as angle);           // [π/4, π)
            } else {
                bl = atan2(by - $player_y, bx - $player_x) + 16384bam + (rand(65536) as angle);
            }
        }
        _ = fire(ARROWHEAD, 6, bx, by, 2.0fx, bl, none, none);
        ba = ba + 1820bam;                            // π/18 ≈ 1820 bam
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var v: int = 0;
    var d: fx = 0fx;
    var ex: fx = 0fx;
    var ey: fx = 0fx;
    var tx: fx = 0fx;
    var ty: fx = 0fx;
    var t: fx = 0fx;
    var u: fx = 0fx;
    move_to(120, 0.0fx, 112.0fx, 2);                  // Sub53 move_position_time_decelerate(120,192,112)
    wait(120);                                        //          +120 ret
    loop {
        // Sub54: effect 循环 32×4=128 帧，再 +20 到 T=148（bullet_circle）
        wait(148);
        if rank == RANK_NORMAL { ring_fire_a(); ring_fire_b(); }   // !N bullet_circle
        wait(50);                                     // T=198：ex_ins_call(4,1) 时停开始

        // ══ 时停窗口（原作 T=198..318 共 120 帧）压平成这 1 帧 ══
        set_enemy_flag(ENEMY_NO_BODY, 1);             // enemy_flag_interactable(0)
        // §7.3：move_rand_in_bounds(-π,π) + move_speed(2.5) + move_time_decelerate(60)
        // 边界 move_bounds_set(32,48,352,132) → 我方 (-160,48)-(160,132)
        v = rand(65536);
        if v >= 32768 { v = v - 65536; }
        if $self_x < -64.0fx {
            if v > 16384 { v = 32768 - v; } else if v < -16384 { v = -32768 - v; }
        }
        if $self_x > 64.0fx {
            if v < 16384 && v >= 0 { v = 32768 - v; } else if v > -16384 && v <= 0 { v = -32768 - v; }
        }
        if $self_y < 96.0fx && v < 0 { v = 0 - v; }
        if $self_y > 84.0fx && v > 0 { v = 0 - v; }
        d = 2.5fx * 60 / 2;                           // 线性减速 60 帧的位移 = v0·t/2
        ex = $self_x;
        ey = $self_y;
        tx = ex + cos(v as angle) * d;
        ty = ey + sin(v as angle) * d;
        if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
        if ty < 48.0fx { ty = 48.0fx; } else if ty > 132.0fx { ty = 132.0fx; }
        // 滑行曲线 move_to(…, easing 2 = QuadOut) ⇒ e(t) = 1 − (1−t)²，第 pp 批落在 t = 9pp/60
        for pp in 0..7 {
            t = pp * 9.0fx / 60;
            u = 1.0fx - t;
            spawn knives5(ex + (tx - ex) * (1.0fx - u * u), ey + (ty - ey) * (1.0fx - u * u), pp, pp % 2);
        }
        move_to(0, tx, ty, 0);                        // boss 瞬移到滑行终点
        wait(1);                                      // 让 7 个批次任务当帧落弹
        set_enemy_flag(ENEMY_NO_BODY, 0);             // enemy_flag_interactable(1)
        // ══ 窗口结束 ══

        wait(99);                                     // 原作 T=318→418 的 +60/+40 收尾，减掉上面那 1 帧
    }
}

async sub boss_main() {
    set_hitbox(18.67fx);   // 段外继承：boss 初始化 Sub23 (56,56,32) → §6.1b
    set_invuln(65535);
    kill_all_enemies(KILL_SILENT);                    // Sub53 enemy_kill_all()
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
