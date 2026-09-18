// th06_s5_b6 —— 东方红魔乡 Stage 5 boss 十六夜咲夜 符卡 幻世「ザ・ワールド」
// 原文：ecldata5.ecl.txt Sub55 → Sub56（宣言 + 移到中央）+ Sub57（时停 + 刀弧 + 大弹随机改向），时限 1800。
//
// 【时停窗口压平】原作 t=198..318 这 120 帧里 `isTimeStopped=1`：`Player::OnUpdate`（Player.cpp:158）
// 与 `BulletManager::OnUpdate`（BulletManager.cpp:668）整帧早退 —— 自机不能动/不能开火/不会被撞，
// 全场弹静止；唯一还在变的是 boss 自己（滑行 60 帧）、窗口内摆下的刀、以及 6 次随机改向。
// 也就是说这 120 帧对玩家是纯空转，等价于「瞬间把弹摆好」。故按 mapping §10.1 把整窗压成 1 帧：
//   · boss 按原滑行曲线的 7 个采样点瞬移摆刀（`move_to(0,…)` 当帧生效，摆完停在终点）
//   · 刀直接以 2.0 真速生成 —— 不需要停驻变换/任务
//   · 6 次 `ex_ins_call(4,2)` 压成一次抽签 p = 1−(3/4)^6 = 3367/4096（每次抽中都是均匀角，分布等价）
//   · `bossTimer` 在原作时停期间不 tick（EnemyManager.cpp:735），压平后我方符卡时限同样不烧这 120 帧
//     ⇒ 1800 帧内约 6 轮，与原作一致（旧的「停车」写法只有 4.3 轮）
const TIME_LIMIT: int = 1800;
const AMULET: int = 112;      // TH06 弹型 7 FIREBALL（32px 弹，色 1→2）
const ARROWHEAD: int = 16;    // TH06 弹型 8 DAGGER（32px 弹，色 3→6）
const EPOCH: int = 20;        // 脚本可写全局槽：随机改向的纪元计数（每轮 +1）

// ---------------------------------------------------------------------------
// ex_ins_call(4,2)：扫全场 32px 弹（heightPx>=30 且未改过向），每颗 1/4 概率重设角度，
// 每次调用上限 14（E/N）/ 52（H/L）颗。原作一轮调 6 次 ⇒ 每颗弹累计 1−(3/4)^6 的概率被改一次。
// 我方无「遍历全场弹」的内建，给每颗大弹挂一个**一次性**任务：等到纪元跳变，抽一次就退。
// 角度分支照 decomp EnemyEclInstr.cpp:585-600（E/N）/ 623-638（H/L）：
//   H/L 远距均匀整周、近距「离自机方向 +π/2 + 整周随机」也是均匀 ⇒ 一律 rand(65536)
//   E/N 远距 [π/4, π]（朝下的扇区）、近距同上均匀 ⇒ 取远距分支（近距占比小，见 report）
// ---------------------------------------------------------------------------
async sub reaim() {
    var seen: int = global(EPOCH);
    var rank: int = global(GVAR_RANK);
    while global(EPOCH) == seen { wait(1); }
    // 抽中即改向。注：环弹里已飞出场的那些（原作里早没了）这一句会计 contract_viol —— 悬垂句柄
    // 被 P4-b 吞成 no-op，读 $self_* 做在场判断同样计数，故不绕（mapping §10.1② 注 ②）。
    if rand(4096) < 3367 {
        if rank >= RANK_HARD {
            set_angle(0, rand(65536) as angle);
        } else {
            set_angle(0, (8192 + rand(24576)) as angle);   // [π/4, π]
        }
    }
}

// Sub57 +20：bullet_circle(7, 1, n, 4, 2.2f, 1.2f, 0, 0, 512)。四层速度 2.2/1.95/1.7/1.45
// （speed1 − (speed1−speed2)·j/count2）。四个发射器槽各一层，每颗挂一次性改向任务。
sub fire_ring(n: int) {
    sh_reset(0);
    sh_sprite(0, AMULET, 2);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, n, 1);
    sh_speed(0, 2.2fx, 0fx);
    sh_angle(0, 0deg, 0deg);
    sh_task(0, reaim);
    sh_fire(0);

    sh_reset(1);
    sh_sprite(1, AMULET, 2);
    sh_aim(1, 0);
    sh_ring(1, 1);
    sh_count(1, n, 1);
    sh_speed(1, 1.95fx, 0fx);
    sh_angle(1, 0deg, 0deg);
    sh_task(1, reaim);
    sh_fire(1);

    sh_reset(2);
    sh_sprite(2, AMULET, 2);
    sh_aim(2, 0);
    sh_ring(2, 1);
    sh_count(2, n, 1);
    sh_speed(2, 1.7fx, 0fx);
    sh_angle(2, 0deg, 0deg);
    sh_task(2, reaim);
    sh_fire(2);

    sh_reset(3);
    sh_sprite(3, AMULET, 2);
    sh_aim(3, 0);
    sh_ring(3, 1);
    sh_count(3, n, 1);
    sh_speed(3, 1.45fx, 0fx);
    sh_angle(3, 0deg, 0deg);
    sh_task(3, reaim);
    sh_fire(3);
}

// ---------------------------------------------------------------------------
// ex_ins_repeat(5) = Stage5Func5（EnemyEclInstr.cpp:655-733）：时停期间每 9 帧一批，
// 沿一段 90° 弧摆 9 个出弹点，每点 FAN_AIMED 发 count1 颗 DAGGER（E/N 1 颗、H/L 3 颗，间隔 π/6，速 2.0）。
// 几何（p = 批号 0..6，u = 出弹敌位→自机单位向量）：
//   scale = 0.5 − p·0.5/9；seed = ±256（p 偶 +，奇 −）
//   bp = (自机−敌位)·scale + seed·u；base = atan2(自机−敌位) + (p 偶 ? π : 0)
//   pos_i = 敌位 + bp + 256·unit(base − π/4 + (i+1)·π/18)，i = 0..8
// 压平后「敌位」取滑行曲线上的采样点 sample_p，而 boss 实体已瞬移到终点，
// 故出弹口偏移要补上 (sample − self)。一批一个任务：单任务每帧 1024 op 的预算装不下 189 颗（发射器槽是**每任务私有四个**，子任务各用自己的 0 号）。
// ---------------------------------------------------------------------------
async sub knives(sx: fx, sy: fx, p: int, cnt: int, rank: int) {
    var dx: fx = $player_x - sx;
    var dy: fx = $player_y - sy;
    var th: angle = atan2(dy, dx);
    var dst: fx = dist(dx, dy);
    var sc: fx = 0.5fx - p * 0.5fx / 9;
    var sgn: fx = 1.0fx;
    var base: angle = th;
    if p % 2 == 1 { sgn = -1.0fx; } else { base = th + 180deg; }
    var rad: fx = dst * sc + sgn * 256.0fx;
    var bx: fx = sx - $self_x + rad * cos(th);
    var by: fx = sy - $self_y + rad * sin(th);

    sh_reset(4);
    sh_sprite(0, ARROWHEAD, 6);
    sh_ring(0, 0);
    sh_count(0, cnt, 1);
    sh_speed(0, 2.0fx, 0fx);

    var ang: angle = base - 45deg;
    for i in 0..9 {
        ang = ang + 10deg;                         // base − π/4 + (i+1)·π/18
        sh_offset(0, bx + 256.0fx * cos(ang), by + 256.0fx * sin(ang));
        // 这一批弹的随机改向（与大弹同一次抽签）：抽中就把扇心换成随机角
        if rand(4096) < 3367 {
            sh_aim(0, 0);
            if rank >= RANK_HARD {
                sh_angle(0, rand(65536) as angle, 5461bam);
            } else {
                sh_angle(0, (8192 + rand(24576)) as angle, 5461bam);
            }
        } else {
            sh_aim(0, 1);
            sh_angle(0, 0deg, 5461bam);            // FAN_AIMED，间隔 π/6
        }
        sh_fire(0);
    }
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var cnt: int = 1;                              // Stage5Func5 的 count1：E/N 1、H/L 3
    if rank >= RANK_HARD { cnt = 3; }
    set_global(EPOCH, 0);
    kill_all_enemies(KILL_SILENT);                 // Sub56 enemy_kill_all()
    move_to(120, 0.0fx, 112.0fx, 2);               // Sub56 move_position_time_decelerate(120, 192, 112)
    wait(120);                                     // ret → Sub57 起算

    var v: int = 0;
    var d: fx = 0fx;
    var tx: fx = 0fx;
    var ty: fx = 0fx;
    var ex: fx = 0fx;
    var ey: fx = 0fx;
    var t: fx = 0fx;
    var u: fx = 0fx;
    loop {
        // Sub57_0：set_int($I4,32) + 32×4 帧的 effect_particle 循环（丢表现、留时序）→ t=128
        for k in 0..32 { wait(4); }
        wait(20);                                  // +20 //24 → t=148
        fire_ring(12);                             // bullet_circle 12 颗 × 4 层（E/N/H）
        if rank >= RANK_LUNATIC { fire_ring(14); } // !L 再补一环 14 颗 × 4 层
        wait(50);                                  // +50 //74 → t=198

        // ══ ex_ins_call(4,1) 开时停 …… ex_ins_call(4,0) 关时停：整窗压成这 1 帧 ══
        set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
        // §7.3：move_rand_in_bounds(-π,π) + move_speed(2.5) + move_time_decelerate(60)
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
        d = 2.5fx * 60 / 2;                        // 线性减速 60 帧的位移 = v0·t/2
        ex = $self_x;
        ey = $self_y;
        tx = ex + cos(v as angle) * d;
        ty = ey + sin(v as angle) * d;
        if tx < -160.0fx { tx = -160.0fx; } else if tx > 160.0fx { tx = 160.0fx; }
        if ty < 48.0fx { ty = 48.0fx; } else if ty > 132.0fx { ty = 132.0fx; }
        // 采样滑行曲线：move_to(…, easing 2 = QuadOut) ⇒ e(t) = 1 − (1−t)²，第 p 批在 t = 9p/60
        for p in 0..7 {
            t = p * 9.0fx / 60;
            u = 1.0fx - t;
            spawn knives(ex + (tx - ex) * (1.0fx - u * u), ey + (ty - ey) * (1.0fx - u * u), p, cnt, rank);
        }
        move_to(0, tx, ty, 0);                     // boss 瞬移到滑行终点
        set_global(EPOCH, global(EPOCH) + 1);      // ex_ins_call(4,2) ×6 → 一次抽签
        wait(1);                                   // 让 7 个批次任务当帧落弹
        set_enemy_flag(ENEMY_NO_BODY, 0);          // enemy_flag_interactable(1)
        // ══ 窗口结束 ══

        wait(99);                                  // 原作 t=318→418 的 +60/+40 收尾，减掉上面那 1 帧
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);
    var rank: int = global(GVAR_RANK);
    var sid: int = 94;                             // H
    if rank >= RANK_LUNATIC { sid = 95; }          // L
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 112.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
