// th06_s4_b18 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）符卡 金符「シルバードラゴン」
// 原文：ecldata4.ecl.txt Sub78（:2414–2420）→ Sub79（:2422–2441，宣言 + 移到中央 + timer 2100）
//       → Sub80（:2443–2457，每 50 帧一环：3 层中玉整周环，60 帧减速到 0 后集体转向自机方向并恢复随机速）。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 63;   // 原文 spellcard_start(1, H=63 / L=64, "ST_ECLDATA4_SUB54_0")：本卡取 H 的 63（仅 UI/计分）
const BALL: int = 48;       // TH06 弹型 3 BALL（中玉）

// 全局槽（>= GLOBALS_SYS_SEGMENT=16）：把每波的最终朝向与随机数传给弹上任务。
const G_ANGLE: int = 16;    // 本波最终朝向（BAM，位穿透）
const G_SPEED_R: int = 17;  // 本波速度随机数 r（0..255）→ 任务算 f1 = 1.0 + 2.5/256·r

// Sub80 bullet_effects(60, 1, -1, -1, %F1, %F0, -1, -1) + flags 257(0x100|0x1)。
// 0x100 = 每 60 帧一周期：速度从当前值线性减到 0，周期末朝向设为 f0、速度设为 f1（i1=1 次）。
// 0x1（出生冲刺）在 TH06 里每帧都被 0x100 的 else-if 分支覆盖，对速度无净影响，故不模拟。
// f0/f1 是本波的自机角与随机速度（运行时值），xformdef 参数必须编译期常量，所以减速交给固定
// xformdef（2 物理槽），最终「定向 + 定速」交给弹上任务，任务从全局槽取参数。
xformdef SILVER_DECEL { @60 step_speed(0fx, 60); }

async sub silver_turn() {
    var r: int = global(G_SPEED_R);
    var a: int = global(G_ANGLE);
    var f1: fx = 1.0fx + 2.5fx / 256 * r;
    wait(60);                       // xform 的 60 帧减速走完（末帧速度精确为 0）
    set_angle(0, a as angle);       // TH06 curBullet->angle = dirChangeRotation = $F1
    set_speed(0, f1);               // TH06 curBullet->speed  = dirChangeSpeed   = $F0
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var nw: int = 8;                        // !H count1=8
    if rank >= RANK_LUNATIC { nw = 10; }    // !L count1=10
    move_to(120, 0.0fx, 80.0fx, 2);         // Sub79 move_position_time_decelerate(120, 192.0f, 80.0f)
    wait(120);                              // Sub79 +120 ret → Sub80
    kill_all_enemies(KILL_SILENT);          // Sub79 enemy_kill_all()（boss 卡里无其它敌，无实际作用）
    loop {                                  // Sub80_20
        var r: int = rand(256);             // $F0 = [1.0, 3.5) → 本波转向后的速度
        set_global(G_SPEED_R, r);
        set_global(G_ANGLE, aim_player() as int);   // $F1 = $PLAYER_ANGLE（本波转向角）
        var f0: angle = rand(65536) as angle;       // $F0 重写为 [-π, π) 环基准角
        sh_reset(0);
        sh_sprite(0, BALL, 15);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, nw, 3);
        sh_speed(0, 6.0fx, (0.5fx - 6.0fx) / 3);
        sh_angle(0, f0, 0deg);
        sh_xform(0, SILVER_DECEL);
        sh_task(0, silver_turn);
        sh_fire(0);
        wait(50);                           // +50: jump(0, Sub80_20)
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
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
