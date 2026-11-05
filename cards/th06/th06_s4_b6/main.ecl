// th06_s4_b6 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）符卡 土符「トリリトンシェイク」
// 原文：ecldata4.ecl.txt Sub72（:2315–2321）→ Sub73（:2323–2342，宣言 + 移到中央 + timer 2100）
//       → Sub74（:2344–2366，每 15 帧一波：随机角度/速度的环玉，90 帧减速到 0 后随机转向并恢复 1.8 速）。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 60;   // 原文 spellcard_start(1, H=60 / L=61, "ST_ECLDATA4_SUB52_0")：本卡取 H 的 60（仅 UI/计分）
const OUTLINE: int = 32;    // TH06 弹型 1 RING_BALL（16px，色号原样）
const BALL: int = 48;       // TH06 弹型 3 BALL（16px，色号原样）
const LASERHEAD: int = 176; // TH06 弹型 9 BUBBLE（mapping §3「0–5、9 色号原样」；判定严重偏小，已知限制）

// 全局槽（>= GLOBALS_SYS_SEGMENT=16）：把每波随机转向角传给弹上任务。
const G_TURN: int = 16;

// Sub74 bullet_effects(90, 1, -1, -1, %F0, 1.8f, -1.0f, -1.0f) + flags 67(0x40|0x2|0x1)。
// 0x40 = 每 90 帧一周期：速度从当前值线性减到 0，周期末转向 f0、速度设为 1.8，共 i1=1 次。
// 0x1（出生冲刺）在 TH06 里每帧都被 0x40 分支的 sincosmul 覆盖，对速度无净影响，故不模拟。
// f0 是本波的随机值（运行时），xformdef 参数必须编译期常量，所以减速交给固定 xformdef（2 物理槽），
// 最终「转向 + 定速」交给弹上任务，任务在创建后第 1 帧从全局槽取参数再等 90 帧执行（同 th06_s4_b18）。
xformdef SHAKE_DECEL { @90 step_speed(0fx, 90); }

async sub shake_turn() {
    var a: int = global(G_TURN);   // 先捕获，避免被后续波次覆盖
    wait(90);                      // xform 的 90 帧减速走完（末帧速度精确为 0）
    turn(0, a as angle);           // TH06 curBullet->angle += dirChangeRotation = $F0（相对转向）
    set_speed(0, 1.8fx);           // TH06 curBullet->speed  = dirChangeSpeed      = 1.8
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    var n: int = 12;                        // !H count1=12
    if rank >= RANK_LUNATIC { n = 18; }     // !L count1=18

    kill_all_enemies(KILL_SILENT);          // Sub73 enemy_kill_all()（boss 卡里无其它敌，无实际作用）
    move_to(120, 0.0fx, 80.0fx, 2);         // Sub73 move_position_time_decelerate(120, 192.0f, 80.0f)
    wait(120);                              // Sub73 +120 ret → Sub74

    // 发射器 0：Sub74 bullet_random(1, 12, 12/18, 1, 2.4f, 1.0f, 3.1415927f, 0.0f, 67)，逐颗随机角度/速度
    sh_reset(0);
    sh_offset(0, 0.0fx, 0.0fx);             // Sub73 shoot_offset(0.0f, 0.0f, 0.0f)
    sh_sprite(0, OUTLINE, 12);
    sh_aim(0, 0);
    sh_ring(0, 0);
    sh_count(0, 1, 1);
    sh_xform(0, SHAKE_DECEL);
    sh_task(0, shake_turn);

    // 发射器 1：Sub74 bullet_fan_aimed(3, 6, 7, 2, 2.8f, 1.2f, 0.0f, 0.34906584f, 4)，自机在自身下方时
    sh_reset(1);
    sh_offset(1, 0.0fx, 0.0fx);
    sh_sprite(1, BALL, 6);
    sh_aim(1, 1);
    sh_ring(1, 0);
    sh_count(1, 7, 2);
    sh_speed(1, 2.8fx, (1.2fx - 2.8fx) / 2);
    sh_angle(1, 0deg, 3641bam);             // 20°

    // 发射器 2：Sub74 bullet_circle_aimed(9, 3, 7, 1, s1, 1.2f, 0.0f, a2, 4)，每 3 波一次
    var cs: fx = 2.4fx;                     // !H speed1
    var ca: angle = 4681bam;                // !H 25.71°
    if rank >= RANK_LUNATIC { cs = 3.4fx; ca = 4096bam; }   // !L speed1 / 22.5°
    sh_reset(2);
    sh_offset(2, 0.0fx, 0.0fx);
    sh_sprite(2, LASERHEAD, 3);
    sh_aim(2, 1);
    sh_ring(2, 1);
    sh_count(2, 7, 1);
    sh_speed(2, cs, 0fx);
    sh_angle(2, 0deg, ca);

    var i0: int = 0;                        // Sub74 set_int($I0, 0)
    var i1: int = 0;
    var ta: angle = 0deg;
    loop {                                  // Sub74_20
        ta = -16384bam + rand(32768) as angle;   // set_float_rand_bound_min($F0, π, -π/2) → [-90°, 90°)
        set_global(G_TURN, ta as int);
        for k in 0..n {
            sh_speed(0, 1.0fx + 1.4fx / 256 * rand(256), 0fx);   // 速度 [1.0, 2.4)
            sh_angle(0, rand(32768) as angle, 0deg);             // 角度 [0°, 180°)
            sh_fire(0);
        }
        if $player_y <= $self_y {           // cmp_float(%PLAYER_Y, %SELF_Y) / jump_gre → 自机不在上方才打
            sh_fire(1);
        }
        i1 = i0 % 3;                        // math_int_mod($I1, $I0, 3)
        if i1 == 0 {                        // cmp_int($I1, 0) / jump_neq → 每 3 波一次
            sh_fire(2);
        }
        i0 = i0 + 1;                        // math_inc($I0)
        wait(15);                           // +15: jump(0, Sub74_20)
    }
}

async sub boss_main() {
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
