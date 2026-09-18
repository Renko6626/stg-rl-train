// th06_s5_b3 —— 东方红魔乡 Stage 5 boss 符卡 幻幽「ジャック・ザ・ルドビレ」（Hard/Lunatic 版）
// 原文：ecldata5.ecl.txt Sub49（入口/超时回调）→ Sub50（宣言 + 120 帧移中央）→ Sub51（时停摆弹循环），时限 1800。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 90;    // 原文 spellcard_start(2, H=90 / L=91, "ST_ECLDATA5_SUB45_0")：本卡取 H 的 90（仅 UI/计分）
const ARROWHEAD: int = 16;   // TH06 弹型 8 DAGGER（半边长 4.5）→ mapping §3
const LASERHEAD: int = 176;  // TH06 弹型 9 BUBBLE（半边长 16）→ mapping §3（判定严重偏小，已知限制）

// 【时停窗口压平】原作 //74→//198 那 152 帧 `isTimeStopped=1`：自机与全场弹整帧早退
// （Player.cpp:158 / BulletManager.cpp:668），对玩家是纯空转 ⇒ 等价于瞬间摆弹。按 mapping §10.1
// 压成 1 帧：boss 按滑行曲线的 10 个采样点定位摆刀、刀以 2.0 真速直接出生。
// 随之省掉的：停驻变换、以及 §10.1①b 那套「随机速度弹靠常驻任务冻结」——窗口不占时间，
// 随机大玉抽完速度/角度就退，不再占任务槽。符卡时限也不烧这 152 帧（与原作 bossTimer 一致）。

// Sub51 t=74：move_rand_in_bounds(-π, π) + move_speed(2.5f) + move_time_decelerate(90)（mapping §7.3）
// 边界取 §7.3 的 boss 标准界 TH06 (32,48)-(352,144) → (-160,48)-(160,144)。
// 压平后 boss 不真的滑，本 sub 只用来**算终点**（滑行曲线用于给 10 波定位），最后一步瞬移过去。
sub wander_to(spd: fx, t: int) {
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
    move_to(0, tx, ty, 0);   // 瞬移到滑行终点（窗口压平）
}

// Sub51 的 ex_ins_repeat(5)（ExInsStage5Func5，EnemyEclInstr.cpp:655）：var2 每帧 +1，var2%9==0 时
// 在 9 个弧形点上各开一个「以自机方向为中轴、±π/6、3 颗、速度 2.0」的扇形（H/L：count1=3，中轴=自机方向）。
// pp = var2 / 9（0..9）。位置公式逐行照抄源码，推导见 report.md。
// 压平后「敌位置」取滑行曲线上的采样点 (px0, py0)，boss 实体已瞬移到终点；一波一个任务
// （单任务每帧 1024 op 的预算装不下 270 颗；发射器槽是每任务私有的四个）。
async sub volley(px0: fx, py0: fx, pp: int) {
    var dx: fx = $player_x - px0;
    var dy: fx = $player_y - py0;
    var dist0: fx = dist(dx, dy);
    var nx: fx = dx / dist0;
    var ny: fx = dy / dist0;
    var s: fx = 256.0fx;
    if pp % 2 == 1 { s = -256.0fx; }
    var sx: fx = nx * s;
    var sy: fx = ny * s;
    var ix: fx = 0.0fx - sx;
    var iy: fx = 0.0fx - sy;
    // matrixIn 先转 -π/4
    var rx: fx = ix * cos(-8192bam) - iy * sin(-8192bam);
    var ry: fx = ix * sin(-8192bam) + iy * cos(-8192bam);
    // bpPositionOffset = d·m + n·s，m = 0.5 − pp·0.5/9
    var m: fx = 0.5fx - (0.5fx / 9) * pp;
    var bx: fx = dx * m + sx;
    var by: fx = dy * m + sy;
    var tx: fx = 0.0fx;
    var ty: fx = 0.0fx;
    // 每点 3 颗 DAGGER 扇形（FAN_AIMED：中轴=自机方向、±π/6、速度 2.0、停到 pulse）用一次
    // sh_fire 发出；逐颗 fire×3 会烧穿单帧 1024 条指令预算（同 th06_s5_b6 的处理）。
    sh_reset(1);
    sh_sprite(1, ARROWHEAD, 6);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 3, 1);
    sh_speed(1, 2.0fx, 0fx);
    sh_angle(1, 0deg, 5461bam);
    for i in 0..9 {
        tx = rx * cos(1820bam) - ry * sin(1820bam);
        ty = rx * sin(1820bam) + ry * cos(1820bam);
        rx = tx;
        ry = ty;
        sh_offset(1, px0 - $self_x + bx + rx, py0 - $self_y + by + ry);
        sh_fire(1);
    }
}

// bullet_random 的逐颗随机改由弹任务在出生后取（主任务逐颗 fire 35 颗会烧穿单帧
// 1024 条指令预算，同 th06_s5_b2 的处理）：弹出生当帧速度 0，下一帧才赋随机角/速（差 1 帧）。
// 窗口压平后不需要冻结，任务抽完就退（不占任务槽）。
async sub rand_bullet() {
    var rank: int = global(GVAR_RANK);
    var lo: fx = 2.2fx;                 // !H 速度下界
    var hi: fx = 4.4fx;                 // !H 速度上界
    if rank >= RANK_LUNATIC { lo = 1.2fx; hi = 5.0fx; }   // !L
    var sp: fx = lo + (hi - lo) / 256 * rand(256);        // [lo, hi)
    set_speed(0, sp);
    set_angle(0, rand(32768) as angle);                   // [0, π)：下半周
}

async sub pattern() {
    // Sub50：spellcard_start / boss_timer_set / timer_callback_threshold 由卡外壳接管；
    // enemy_flag_can_take_damage / anm_set_poses / effect_* 丢弃。保留移中央 + 120 帧前奏。
    move_to(120, 0.0fx, 112.0fx, 2);   // move_position_time_decelerate(120, 192.0f, 112.0f)
    wait(120);                          // Sub50 +120 ret

    // Sub51：
    var rank: int = global(GVAR_RANK);
    var n: int = 20;                    // !H count1=20
    if rank >= RANK_LUNATIC { n = 35; }   // !L count1=35
    var ex: fx = 0fx;
    var ey: fx = 0fx;
    var tq: fx = 0fx;
    var uq: fx = 0fx;
    loop {
        // Sub51_0 / Sub51_36：32 次 effect_particle，每 4 帧一次 = 128 帧充能（纯表现，全丢）
        wait(128);
        // +20 //24：bullet_random(9, 0, 20/35, 1, s1, s2, π, 0, 512)
        // 随机角/速交给弹任务 rand_bullet，一次 sh_fire 出全部 n 颗（mapping §4.2 random 族）
        wait(20);
        sh_reset(0);
        sh_sprite(0, LASERHEAD, 0);
        sh_aim(0, 0);
        sh_count(0, n, 1);
        sh_speed(0, 0fx, 0fx);
        sh_angle(0, 0deg, 0deg);
        sh_task(0, rand_bullet);
        sh_fire(0);
        // +50 //74：ex_ins_call(4, 1) 时停开始 + enemy_flag_interactable(0) + 随机游走
        wait(50);

        // ══ 时停窗口（原作 //74→//198 共 152 帧）压平成这 1 帧 ══
        set_enemy_flag(ENEMY_NO_BODY, 1);
        ex = $self_x;
        ey = $self_y;
        wander_to(2.5fx, 90);                // 算终点并瞬移过去（原作是 90 帧滑行）
        // ex_ins_repeat(5)：原作窗口前 90 帧每 9 帧一轮 = 10 轮（pp=0..9），
        // 出弹原点取滑行曲线 move_to(…, easing 2 = QuadOut) 的采样：e = 1 − (1−t)²，t = 9pp/90
        for v in 0..10 {
            tq = v * 9.0fx / 90;
            uq = 1.0fx - tq;
            spawn volley(ex + ($self_x - ex) * (1.0fx - uq * uq),
                         ey + ($self_y - ey) * (1.0fx - uq * uq), v);
        }
        wait(1);                             // 让 10 个波次任务当帧落弹
        set_enemy_flag(ENEMY_NO_BODY, 0);    // enemy_flag_interactable(1)
        // ══ 窗口结束 ══
        // +60 //258、+40 //298：jump(0, Sub51_0) 回到循环头
        wait(60);
        wait(40);
    }
}

async sub boss_main() {
    set_hitbox(18.67fx);   // 段外继承：boss 初始化 Sub23 (56,56,32) → §6.1b
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
