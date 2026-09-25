// th06_s7_b17 —— 东方红魔乡 Stage 7(Extra) boss 芙兰朵露 符卡
// 秘弾「そして誰もいなくなるか？」（ST_ECLDATA7_SUB60_0）
// 原文：ecldata7.ecl.txt Sub81→Sub82→Sub83(宣言/移中央)+Sub84(波次调度)，Sub90(小怪)，Sub85–Sub89(四角/边缘弹幕)。时限 5160→3000。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 129;      // 原文 spellcard_start(3, 129, "ST_ECLDATA7_SUB60_0")
const RICE: int = 64;           // TH06 弹型 2
const BALL: int = 48;           // TH06 弹型 3

// Sub88/Sub89 的 bullet_effects(220, …, 0.0f, ∓0.0074799825f, …) + flags 40 = 0x20|0x8：
// 出生后 220 帧每帧 angle += ∓78bam（0x8 出生特效按 §4/§5 有意不模拟）。
xformdef SWEEP_N { set_accel(0fx); @220 set_ang_vel(-78bam); stop_fx(); }
xformdef SWEEP_P { set_accel(0fx); @220 set_ang_vel(78bam); stop_fx(); }

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

// Sub90 的自动射击：bullet_fan_aimed(3, 6, 3, 1, 0.5f, 0.0f, 0.0f, 1.0471976f, 514) + shoot_interval(6)。
// 640 池等效截止：修正 Sub87 颗数、小怪血量后，无截止（间隔 6，首发 k=5）峰值 1282 > 1024，
// 故间隔 6→12（burst 形状不变，首发 k=11，wait(k−1)=10），实测峰值 641。
async sub minion_gun() {
    sh_reset(0);
    sh_sprite(0, BALL, 6);
    sh_aim(0, 1);
    sh_ring(0, 0);
    sh_count(0, 3, 1);
    sh_speed(0, 0.5fx, 0fx);
    sh_angle(0, 0deg, 10923bam);   // a2 = 60°
    wait(10);
    loop {
        sh_fire(0);
        wait(12);
    }
}

// Sub90：小怪。enemy_create("Sub90", …, life, …)，life 决定追击段数（math_int_mod($I4,$SELF_LIFE,10)）。
async sub minion(life: int) {
    set_invuln(65535);
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_hitbox(18.67fx);           // enemy_set_hitbox(56,56,32) → min(56,56)/3
    spawn minion_gun();
    var i4: int = life;
    var k: int = 0;
    wait(60);                      // Sub90 +60
    while k < i4 {
        move_to(192, $player_x, $player_y, 2);   // move_position_time_decelerate(192, %PLAYER_X, %PLAYER_Y, 0)
        wait(192);
        k = k + 1;
    }
    die();                         // enemy_delete(0)
}

// ── Sub85–Sub89：原文每个 sub 一帧内发完所有弹。单任务指令预算 1024，故每个波次按弹段拆成 4 个
//    spawn 子任务（part0 = 四角扇 + 第 1 段，part1..3 = 第 2..4 段），同帧落弹、各用自己的预算。

// Sub85：1×5 层定点扇 + 四段瞄准 (192,224)→我方 (0,224) 的慢弹。
async sub wave85(part: int) {
    var a0: angle = 0deg;
    var f2: fx = 0fx;
    var f3: fx = 0fx;
    var i4: int = 0;
    var k: int = 0;

    if part == 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 5);
        sh_speed(0, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(0, 90deg, 0deg);  sh_offset(0, -192.0fx - $self_x, -12.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 180deg, 0deg); sh_offset(0, 204.0fx - $self_x, -$self_y);            sh_fire(0);
        sh_angle(0, -90deg, 0deg); sh_offset(0, 192.0fx - $self_x, 460.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 0deg, 0deg);   sh_offset(0, -204.0fx - $self_x, 448.0fx - $self_y); sh_fire(0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.2fx, 0fx);
        f2 = -12.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 14; k = 0;
        while k < i4 {
            a0 = atan2(224.0fx - f3, 192.0fx - f2);
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 32.0fx;
            k = k + 1;
        }
    } else if part == 1 {
        sh_reset(0);
        sh_sprite(0, BALL, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.2fx, 0fx);
        f2 = 396.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 14; k = 0;
        while k < i4 {
            a0 = atan2(224.0fx - f3, 192.0fx - f2);
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 32.0fx;
            k = k + 1;
        }
    } else if part == 2 {
        sh_reset(0);
        sh_sprite(0, BALL, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.2fx, 0fx);
        f2 = 32.0fx / 256 * rand(256); f3 = -12.0fx; i4 = 12; k = 0;
        while k < i4 {
            a0 = atan2(224.0fx - f3, 192.0fx - f2);
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 32.0fx;
            k = k + 1;
        }
    } else {
        sh_reset(0);
        sh_sprite(0, BALL, 2);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.2fx, 0fx);
        f2 = 32.0fx / 256 * rand(256); f3 = 460.0fx; i4 = 12; k = 0;
        while k < i4 {
            a0 = atan2(224.0fx - f3, 192.0fx - f2);
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 32.0fx;
            k = k + 1;
        }
    }
}

// Sub86：1×5 层定点扇 + 四段 1×2 层直射。
async sub wave86(part: int) {
    var f2: fx = 0fx;
    var f3: fx = 0fx;
    var i4: int = 0;
    var k: int = 0;

    if part == 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 5);
        sh_speed(0, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(0, 0deg, 0deg);   sh_offset(0, -204.0fx - $self_x, -$self_y);            sh_fire(0);
        sh_angle(0, 90deg, 0deg);  sh_offset(0, 192.0fx - $self_x, -12.0fx - $self_y);   sh_fire(0);
        sh_angle(0, 180deg, 0deg); sh_offset(0, 204.0fx - $self_x, 448.0fx - $self_y);   sh_fire(0);
        sh_angle(0, -90deg, 0deg); sh_offset(0, -192.0fx - $self_x, 460.0fx - $self_y);  sh_fire(0);
        sh_count(0, 1, 2);
        sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / 2);
        f2 = -12.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 10; k = 0;
        while k < i4 {
            sh_angle(0, 0deg, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 44.8fx;
            k = k + 1;
        }
    } else if part == 1 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 2);
        sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / 2);
        f2 = 396.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 10; k = 0;
        while k < i4 {
            sh_angle(0, 180deg, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 44.8fx;
            k = k + 1;
        }
    } else if part == 2 {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 2);
        sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / 2);
        f2 = 32.0fx / 256 * rand(256); f3 = -12.0fx; i4 = 9; k = 0;
        while k < i4 {
            sh_angle(0, 90deg, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 44.8fx;
            k = k + 1;
        }
    } else {
        sh_reset(0);
        sh_sprite(0, BALL, 6);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 2);
        sh_speed(0, 1.5fx, (0.7fx - 1.5fx) / 2);
        f2 = 32.0fx / 256 * rand(256); f3 = 460.0fx; i4 = 9; k = 0;
        while k < i4 {
            sh_angle(0, -90deg, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 44.8fx;
            k = k + 1;
        }
    }
}

// Sub87：bullet_fan(3,10,1,5,…) 四角 1 颗×5 层（色 10）+ 四段 bullet_fan(3,10,2,1,0.8,…,a,60°) 每点 2 颗（中轴 ±30°）。
async sub wave87(part: int) {
    var f2: fx = 0fx;
    var f3: fx = 0fx;
    var i4: int = 0;
    var k: int = 0;

    if part == 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 10);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 5);
        sh_speed(0, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(0, 90deg, 0deg);  sh_offset(0, -192.0fx - $self_x, -12.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 180deg, 0deg); sh_offset(0, 204.0fx - $self_x, -$self_y);            sh_fire(0);
        sh_angle(0, -90deg, 0deg); sh_offset(0, 192.0fx - $self_x, 460.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 0deg, 0deg);   sh_offset(0, -204.0fx - $self_x, 448.0fx - $self_y); sh_fire(0);
        sh_count(0, 2, 1);
        sh_speed(0, 0.8fx, 0fx);
        f2 = -12.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 10; k = 0;
        while k < i4 {
            sh_angle(0, 0deg, 10923bam);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 44.8fx;
            k = k + 1;
        }
    } else if part == 1 {
        sh_reset(0);
        sh_sprite(0, BALL, 10);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 2, 1);
        sh_speed(0, 0.8fx, 0fx);
        f2 = 396.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 10; k = 0;
        while k < i4 {
            sh_angle(0, 180deg, 10923bam);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 44.8fx;
            k = k + 1;
        }
    } else if part == 2 {
        sh_reset(0);
        sh_sprite(0, BALL, 10);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 2, 1);
        sh_speed(0, 0.8fx, 0fx);
        f2 = 32.0fx / 256 * rand(256); f3 = -12.0fx; i4 = 9; k = 0;
        while k < i4 {
            sh_angle(0, 90deg, 10923bam);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 44.8fx;
            k = k + 1;
        }
    } else {
        sh_reset(0);
        sh_sprite(0, BALL, 10);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 2, 1);
        sh_speed(0, 0.8fx, 0fx);
        f2 = 32.0fx / 256 * rand(256); f3 = 460.0fx; i4 = 9; k = 0;
        while k < i4 {
            sh_angle(0, -90deg, 10923bam);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 44.8fx;
            k = k + 1;
        }
    }
}

// Sub88：1×5 层扇（色 14）+ 0x20 变换（每帧 −78bam，220 帧）的起步扫射。
async sub wave88(part: int) {
    var f2: fx = 0fx;
    var f3: fx = 0fx;
    var a0: angle = 0deg;
    var i4: int = 0;
    var k: int = 0;

    if part == 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 14);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 5);
        sh_speed(0, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(0, 0deg, 0deg);   sh_offset(0, -204.0fx - $self_x, -$self_y);            sh_fire(0);
        sh_angle(0, 90deg, 0deg);  sh_offset(0, 192.0fx - $self_x, -12.0fx - $self_y);   sh_fire(0);
        sh_angle(0, 180deg, 0deg); sh_offset(0, 204.0fx - $self_x, 448.0fx - $self_y);   sh_fire(0);
        sh_angle(0, -90deg, 0deg); sh_offset(0, -192.0fx - $self_x, 460.0fx - $self_y);  sh_fire(0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_N);
        f2 = 0.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 11; a0 = 90deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 40.0fx;
            a0 = a0 - 1489bam;
            k = k + 1;
        }
    } else if part == 1 {
        sh_reset(0);
        sh_sprite(0, BALL, 14);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_N);
        f2 = 384.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 11; a0 = 180deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 40.0fx;
            a0 = a0 + 1489bam;
            k = k + 1;
        }
    } else if part == 2 {
        sh_reset(0);
        sh_sprite(0, BALL, 14);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_N);
        f2 = 32.0fx / 256 * rand(256); f3 = 0.0fx; i4 = 9; a0 = 90deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 40.0fx;
            a0 = a0 + 1820bam;
            k = k + 1;
        }
    } else {
        sh_reset(0);
        sh_sprite(0, BALL, 14);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_N);
        f2 = 32.0fx / 256 * rand(256); f3 = 448.0fx; i4 = 9; a0 = 0deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 40.0fx;
            a0 = a0 - 1820bam;
            k = k + 1;
        }
    }
}

// Sub89：1×5 层扇（色 13）+ 0x20 变换（每帧 +78bam，220 帧）的起步扫射。
async sub wave89(part: int) {
    var f2: fx = 0fx;
    var f3: fx = 0fx;
    var a0: angle = 0deg;
    var i4: int = 0;
    var k: int = 0;

    if part == 0 {
        sh_reset(0);
        sh_sprite(0, BALL, 13);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 5);
        sh_speed(0, 3.2fx, (1.0fx - 3.2fx) / 5);
        sh_angle(0, 90deg, 0deg);  sh_offset(0, -192.0fx - $self_x, -12.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 180deg, 0deg); sh_offset(0, 204.0fx - $self_x, -$self_y);            sh_fire(0);
        sh_angle(0, -90deg, 0deg); sh_offset(0, 192.0fx - $self_x, 460.0fx - $self_y);  sh_fire(0);
        sh_angle(0, 0deg, 0deg);   sh_offset(0, -204.0fx - $self_x, 448.0fx - $self_y); sh_fire(0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_P);
        f2 = 0.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 11; a0 = 0deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 40.0fx;
            a0 = a0 - 1489bam;
            k = k + 1;
        }
    } else if part == 1 {
        sh_reset(0);
        sh_sprite(0, BALL, 13);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_P);
        f2 = 384.0fx; f3 = 32.0fx / 256 * rand(256); i4 = 11; a0 = 90deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f3 = f3 + 40.0fx;
            a0 = a0 + 1489bam;
            k = k + 1;
        }
    } else if part == 2 {
        sh_reset(0);
        sh_sprite(0, BALL, 13);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_P);
        f2 = 32.0fx / 256 * rand(256); f3 = 0.0fx; i4 = 9; a0 = 0deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 40.0fx;
            a0 = a0 + 1820bam;
            k = k + 1;
        }
    } else {
        sh_reset(0);
        sh_sprite(0, BALL, 13);
        sh_aim(0, 0);
        sh_ring(0, 0);
        sh_count(0, 1, 1);
        sh_speed(0, 1.0fx, 0fx);
        sh_xform(0, SWEEP_P);
        f2 = 32.0fx / 256 * rand(256); f3 = 448.0fx; i4 = 9; a0 = -90deg; k = 0;
        while k < i4 {
            sh_angle(0, a0, 0deg);
            sh_offset(0, (f2 - 192.0fx) - $self_x, f3 - $self_y);
            sh_fire(0);
            f2 = f2 + 40.0fx;
            a0 = a0 - 1820bam;
            k = k + 1;
        }
    }
}

// Sub81 setup + Sub83 移中央前奏 + Sub84 波次调度循环（一轮 5123 帧）。
async sub pattern() {
    set_enemy_flag(ENEMY_NO_BODY, 0);          // Sub81 enemy_flag_collision/invisible/interactable
    kill_all_enemies(KILL_SILENT);             // Sub81 enemy_kill_all
    wait(90);
    kill_all_enemies(KILL_SILENT);             // Sub83 enemy_kill_all
    move_to(120, 0.0fx, 80.0fx, 2);            // Sub83 move_position_time_decelerate(120, 192, 80, 0)
    wait(120);
    set_enemy_flag(ENEMY_NO_BODY, 1);          // Sub83 +120 invisible/interactable/collision = 0

    loop {
        _ = spawn_enemy(0.0fx, 96.0fx, 1, 0, 0, 0, minion(4));      // Sub84 t=0
        wait(800);
        _ = spawn_enemy(0.0fx, 96.0fx, 1, 0, 0, 0, minion(4));      // t=800
        wait(64);
        _ = spawn_enemy(-192.0fx, 0.0fx, 1, 0, 0, 0, minion(4));    // t=864
        wait(64);
        _ = spawn_enemy(192.0fx, 0.0fx, 1, 0, 0, 0, minion(3));     // t=928
        wait(64);
        _ = spawn_enemy(-192.0fx, 448.0fx, 1, 0, 0, 0, minion(3));  // t=992
        wait(64);
        _ = spawn_enemy(192.0fx, 448.0fx, 1, 0, 0, 0, minion(2));   // t=1056
        wait(800);
        spawn wave85(0); spawn wave85(1); spawn wave85(2); spawn wave85(3); wait(320);   // t=1856
        spawn wave86(0); spawn wave86(1); spawn wave86(2); spawn wave86(3); wait(320);   // t=2176
        spawn wave87(0); spawn wave87(1); spawn wave87(2); spawn wave87(3); wait(320);   // t=2496
        spawn wave88(0); spawn wave88(1); spawn wave88(2); spawn wave88(3); wait(320);   // t=2816
        spawn wave89(0); spawn wave89(1); spawn wave89(2); spawn wave89(3); wait(320);   // t=3136
        spawn wave85(0); spawn wave85(1); spawn wave85(2); spawn wave85(3); wait(240);   // t=3456
        spawn wave86(0); spawn wave86(1); spawn wave86(2); spawn wave86(3); wait(240);   // t=3696
        spawn wave87(0); spawn wave87(1); spawn wave87(2); spawn wave87(3); wait(240);   // t=3936
        spawn wave88(0); spawn wave88(1); spawn wave88(2); spawn wave88(3); wait(240);   // t=4176
        spawn wave89(0); spawn wave89(1); spawn wave89(2); spawn wave89(3); wait(240);   // t=4416
        spawn wave85(0); spawn wave85(1); spawn wave85(2); spawn wave85(3); wait(140);   // t=4556
        spawn wave86(0); spawn wave86(1); spawn wave86(2); spawn wave86(3); wait(140);   // t=4696
        spawn wave87(0); spawn wave87(1); spawn wave87(2); spawn wave87(3); wait(140);   // t=4836
        spawn wave88(0); spawn wave88(1); spawn wave88(2); spawn wave88(3); wait(140);   // t=4976
        spawn wave89(0); spawn wave89(1); spawn wave89(2); spawn wave89(3); wait(140);   // t=5116
        wait(7);                                                                          // t=5123
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);           // 沿回调链的 boss 值 (56,56,32) → 56/3
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, SPELL_SURVIVAL, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
