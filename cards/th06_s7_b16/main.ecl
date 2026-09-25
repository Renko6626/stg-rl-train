// th06_s7_b16 —— 东方红魔乡 Extra（Stage 7）boss 符卡「禁弾「過去を刻む時計」」
// 原文：ecldata7.ecl.txt Sub77/78/79/80（行 2262–2444）；Sub76 的 timer/life 回调进入 Sub77。
// Extra 档（unit ranks [4,4]），原文全档同形无难度分叉；原文 timer 4200 → unit.json 钳 3000。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 128;      // 原文 spellcard_start(3, 128, "ST_ECLDATA7_SUB57_0")
const BALL: int = 48;           // TH06 弹型 3 BALL（16px 弹，色号原样）

// 出界即删守卫（mapping §6.2）
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

// 原文 Sub80：六只「钟面」小怪，各挂四条十字旋转激光。
// 原文 set_int($F2, $SELF_Z) 把生成时的 z 当移动目标 y 用（第三对生成 y=128 但 z=288），
// 故 ty 由生成处当参数传入；目标 x = 384 − 自身 x → 我方 −$self_x（镜像）。
async sub hand(ty: fx) {
    set_invuln(65535);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);       // enemy_flag_collision(0) + interactable(0)
    set_hitbox(18.67fx);                    // enemy_set_hitbox(56,56,32) → min/3（mapping §8）
    wait(30);                               // +30：建激光
    // laser_create(1, 6, a, 0, 0, 216, 216, 24, 60, 800, 20, 60, 18, 0)
    // sprite=1 色号原样 6；宽 24 → 12；len=216；sp=0 且 st=0/en-sl=0 → 无需 lz_start
    var lz_0: int = laser(6, $self_x, $self_y, -16384bam, 216.0fx, 12.0fx, 60, 800, 20);
    var lz_1: int = laser(6, $self_x, $self_y, 0bam, 216.0fx, 12.0fx, 60, 800, 20);
    var lz_2: int = laser(6, $self_x, $self_y, 16384bam, 216.0fx, 12.0fx, 60, 800, 20);
    var lz_3: int = laser(6, $self_x, $self_y, 32768bam, 216.0fx, 12.0fx, 60, 800, 20);
    var rot: angle = 205bam;                // 0.019634955 rad = +1.125°
    if $self_x >= 0.0fx { rot = -205bam; }  // 原文 self_x ≥ 192 → 负向（镜像）
    var tx: fx = 0.0fx - $self_x;           // 384 − self_x（TH06）→ −self_x（我方）
    for k1 in 0..50 {                       // 原文 Sub80_756：原地转 50 帧
        lz_origin(lz_0, $self_x, $self_y); lz_origin(lz_1, $self_x, $self_y);
        lz_origin(lz_2, $self_x, $self_y); lz_origin(lz_3, $self_x, $self_y);
        lz_rotate(lz_0, rot); lz_rotate(lz_1, rot); lz_rotate(lz_2, rot); lz_rotate(lz_3, rot);
        wait(1);
    }
    move_to(220, tx, ty, 0);                // move_position_time_linear(220, %F1, %F2)
    for k2 in 0..220 {                      // 原文 Sub80_1044：边平移边转
        lz_origin(lz_0, $self_x, $self_y); lz_origin(lz_1, $self_x, $self_y);
        lz_origin(lz_2, $self_x, $self_y); lz_origin(lz_3, $self_x, $self_y);
        lz_rotate(lz_0, rot); lz_rotate(lz_1, rot); lz_rotate(lz_2, rot); lz_rotate(lz_3, rot);
        wait(1);
    }
    lz_cancel(lz_0); lz_cancel(lz_1); lz_cancel(lz_2); lz_cancel(lz_3);
    for k3 in 0..60 {                       // 原文 Sub80_1384：收缩后仍转 60 帧（回收后 no-op）
        if lz_alive(lz_0) == 1 {
            lz_origin(lz_0, $self_x, $self_y); lz_origin(lz_1, $self_x, $self_y);
            lz_origin(lz_2, $self_x, $self_y); lz_origin(lz_3, $self_x, $self_y);
            lz_rotate(lz_0, rot); lz_rotate(lz_1, rot); lz_rotate(lz_2, rot); lz_rotate(lz_3, rot);
        }
        wait(1);
    }
    wait(30);                               // +30 //63
    die();                                  // enemy_delete(0)
}

// 原文 Sub77 → Sub78（宣言/移中）→ Sub79（360 帧一轮的弹幕循环）
async sub pattern() {
    // ---- Sub78：保留有行为的指令 ----
    set_enemy_flag(ENEMY_NO_BODY, 0);       // enemy_flag_collision(1)
    kill_all_enemies(KILL_SILENT);          // enemy_kill_all()（跳过 boss）
    move_to(120, 0.0fx, 80.0fx, 2);         // move_position_time_decelerate(120, 192, 80)
    wait(120);                              // +120 ret → Sub79

    var i0: int = 0;                        // $I0
    var f1: fx = 0fx;                       // $F1
    var f2: fx = 1.8fx;                     // $F2
    loop {                                  // Sub79_16 … jump(0, Sub79_16)
        // ---- t=0：第一对小怪 ----
        _ = spawn_enemy(-128.0fx, 288.0fx, 1, 0, 0, 0, hand(288.0fx));
        _ = spawn_enemy(128.0fx, 160.0fx, 1, 0, 0, 0, hand(160.0fx));
        wait(90);                           // +90 //90
        // ---- 第一循环：I4=240、I0=0、F2=1.8；I0%16 fan / I0%24 aimed ----
        i0 = 0;
        f2 = 1.8fx;
        for k1 in 0..240 {
            if i0 % 16 == 0 {               // bullet_fan(3, 2, 32, 1, 5.2, 1.2, -π/2, 7.5°, 0)
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 0);
                sh_ring(0, 0);
                sh_count(0, 32, 1);
                sh_speed(0, 5.2fx, 0fx);
                sh_angle(0, -16384bam, 1365bam);
                sh_fire(0);
            }
            if i0 % 24 == 0 {               // bullet_fan_aimed(3, 2, 17, 1, %F2, 1.2, 0, 9°, 0)
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 1);
                sh_ring(0, 0);
                sh_count(0, 17, 1);
                sh_speed(0, f2, 0fx);
                sh_angle(0, 0bam, 1638bam);
                sh_fire(0);
            }
            i0 = i0 + 1;
            wait(1);
        }
        wait(20);                           // +20 //111
        // ---- t=111：第二对小怪 ----
        _ = spawn_enemy(-128.0fx, 160.0fx, 1, 0, 0, 0, hand(160.0fx));
        _ = spawn_enemy(128.0fx, 288.0fx, 1, 0, 0, 0, hand(288.0fx));
        wait(90);                           // +90 //201
        // ---- 第二循环：I4=250、I0=0；I0%16 fan + aimed7（速度 %F2+2.1）----
        i0 = 0;
        for k2 in 0..250 {
            if i0 % 16 == 0 {
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 0);
                sh_ring(0, 0);
                sh_count(0, 32, 1);
                sh_speed(0, 5.2fx, 0fx);
                sh_angle(0, -16384bam, 1365bam);
                sh_fire(0);
                f1 = f2 + 2.1fx;            // math_float_add($F1, %F2, 2.1f)
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 1);
                sh_ring(0, 0);
                sh_count(0, 7, 1);
                sh_speed(0, f1, 0fx);
                sh_angle(0, 0bam, 1638bam);
                sh_fire(0);
            }
            i0 = i0 + 1;
            wait(1);
        }
        wait(10);                           // +10 //212
        // ---- t=212：第三对小怪 ----
        _ = spawn_enemy(-128.0fx, 128.0fx, 1, 0, 0, 0, hand(288.0fx));
        _ = spawn_enemy(128.0fx, 128.0fx, 1, 0, 0, 0, hand(288.0fx));
        wait(90);                           // +90 //302
        // ---- 第三循环：I4=250、I0=0；I0%16 fan + aimed17（速度 %F2）----
        i0 = 0;
        for k3 in 0..250 {
            if i0 % 16 == 0 {
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 0);
                sh_ring(0, 0);
                sh_count(0, 32, 1);
                sh_speed(0, 5.2fx, 0fx);
                sh_angle(0, -16384bam, 1365bam);
                sh_fire(0);
                sh_reset(0);
                sh_sprite(0, BALL, 2);
                sh_aim(0, 1);
                sh_ring(0, 0);
                sh_count(0, 17, 1);
                sh_speed(0, f2, 0fx);
                sh_angle(0, 0bam, 1638bam);
                sh_fire(0);
            }
            i0 = i0 + 1;
            wait(1);
        }
        f2 = f2 + 0.2fx;                    // math_float_add($F2, %F2, 0.2f)（下一轮 t=90 重置，实际无效）
        wait(50);                           // +50 //353
        wait(7);                            // +7 //360 → jump(0, Sub79_16)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                    // boss 回调链最近一次 enemy_set_hitbox(56,56,32)，mapping §6.1b
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 80.0fx, 1000, 0, 0, 1, boss_main);   // Sub78 目标 (192,80) → 我方 (0,80)
    loop { wait(600); }
}
