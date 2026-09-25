// th06_s7_b4 —— 东方红魔乡 Extra（Stage 7）boss 芙兰朵露 符卡 2 禁忌「レーヴァテイン」
// 原文：ecldata7.ecl.txt Sub44 → Sub45（宣言 + 移到中央）+ Sub46（攻击循环）+ Sub47（激光扫 + 沿激光铺弹）
// 仅 Extra（rank 4）执行；原文全 [ENHL]，本例无难度分叉。

const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 122;
const RICE: int = 64;                 // TH06 弹型 2 RICE

// bullet_effects(96, -1, -1, -1, 0.02f, -999.0f, …) + flags 0x10（f1 ≤ −999 ⇒ 沿弹自身方向）：
// 出生后 96 帧沿自身方向加速度 0.02。（@N 是后置延迟：先 set_accel，再等 96 帧，再停。）
xformdef ACCEL02 { @96 set_accel(0.02fx); stop_fx(); }

// Sub47：每帧新建一条短激光（T0=1/T1=6/T2=1）；把主激光转过 f1、重锚到 boss；
// 每 5 帧沿两条活激光各从 start 起每 48px 铺一颗米弹（ex_ins_call(14,0)），并在敌位置补发一颗。
sub sub47(lz0: int, i4: int, f1: angle, f2: angle, f3: angle) {
    var lz1: int = -1;
    var a0: angle = 0deg;
    var a1: angle = 0deg;
    var d0: fx = 0fx;
    var d1: fx = 0fx;
    var e0: fx = 0fx;
    var e1: fx = 0fx;
    var k: int = 0;
    while k < i4 {
        // laser_index(1); laser_create(1, 2, %F3, 0, 32, 420, 388, 12, 1, 6, 1, 1, 8, 0)
        // sprite=1 ⇒ 色号原样；宽 12 → 6；start = max(32, 420−388) = 32
        lz1 = laser(2, $self_x, $self_y, f3, 420.0fx, 6.0fx, 1, 6, 1);
        lz_start(lz1, 32.0fx);
        // laser_rotate(0, %F1); laser_offset(0, 0, 0, 0)
        lz_rotate(lz0, f1);
        lz_origin(lz0, $self_x, $self_y);
        // math_float_add($F2, %F2, %F1); math_float_add($F3, %F3, %F1); norm 对 BAM 是 no-op
        f2 = f2 + f1;
        f3 = f3 + f1;
        // math_int_mod($I0, $I1, 5); cmp_int($I0, 0); jump_neq → 每 5 帧一次
        if k % 5 == 0 {
            // bullet_effects(96, -1, -1, -1, 0.02, -999, …) 粘滞；bullet_fan(2, 2, 1, 1, 0.01, 1.0, %F2, 0, 532)
            // 1 层 ⇒ 初速 s1=0.01 被钳到 0.3；flags 532 = 0x200|0x10|0x4（0x4 出生特效不模拟）
            sh_reset(0);
            sh_sprite(0, RICE, 2);
            sh_aim(0, 0);
            sh_ring(0, 0);
            sh_count(0, 1, 1);
            sh_angle(0, f2, 0deg);
            sh_speed(0, 0.3fx, 0fx);
            sh_xform(0, ACCEL02);
            sh_offset(0, 0.0fx, 0.0fx);
            sh_fire(0);
            // ex_ins_call(14,0)：遍历该敌还活着的激光，从 start 起每 48px 开一火直到 < end
            if lz_alive(lz0) == 1 {
                a0 = lz_angle(lz0);
                d0 = lz_near(lz0);
                e0 = lz_far(lz0);
                while d0 < e0 {
                    sh_offset_abs(0, lz_x(lz0) + d0 * cos(a0), lz_y(lz0) + d0 * sin(a0));
                    sh_fire(0);
                    d0 = d0 + 48.0fx;
                }
            }
            if lz_alive(lz1) == 1 {
                a1 = lz_angle(lz1);
                d1 = lz_near(lz1);
                e1 = lz_far(lz1);
                while d1 < e1 {
                    sh_offset_abs(0, lz_x(lz1) + d1 * cos(a1), lz_y(lz1) + d1 * sin(a1));
                    sh_fire(0);
                    d1 = d1 + 48.0fx;
                }
            }
        }
        // Sub47_480: math_inc($I1); +1; jump_dec(0, Sub47_20, $I4)
        k = k + 1;
        wait(1);
    }
    // Sub47_520: laser_cancel(0); ret()
    lz_cancel(lz0);
}

async sub pattern() {
    // ── Sub45：spellcard_start 之后移到中央 (192,80) → 我方 (0,80)；+120 ret ──
    // enemy_kill_all()（跳过 boss 自己）；enemy_flag_collision(1)；x1=0
    kill_all_enemies(KILL_SILENT);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    move_to(88, 0.0fx, 80.0fx, 2);
    wait(120);

    // ── Sub46：攻击循环（Sub46_16 跳回）──
    var lz0: int = -1;
    loop {
        // t=0 主激光 1：-171°；len 420 宽 12 warn 60 active 800 fade 20；start 32
        lz0 = laser(2, $self_x, $self_y, -31130bam, 420.0fx, 12.0fx, 60, 800, 20);
        lz_start(lz0, 32.0fx);
        // call Sub47：f1=+2.25°、f2=-81°、f3=-171°、重复 120 帧
        sub47(lz0, 120, 410bam, -14746bam, -31130bam);
        // move_position_time_decelerate(120, 0, 40, 0)  → (-192,40)
        move_to(120, -192.0fx, 40.0fx, 2);
        wait(120);

        // t=120 主激光 2：90°；len 400；start 32
        lz0 = laser(2, $self_x, $self_y, 16384bam, 400.0fx, 12.0fx, 60, 800, 20);
        lz_start(lz0, 32.0fx);
        // Sub46_432：laser_offset ×60
        for k1 in 0..60 {
            if lz_alive(lz0) == 1 { lz_origin(lz0, $self_x, $self_y); }
            wait(1);
        }
        // move_position_time_decelerate(90, 352, 96, 0) → (160,96)
        move_to(90, 160.0fx, 96.0fx, 2);
        // call Sub47：f1=0、f2=0°、f3=90°、重复 64 帧
        sub47(lz0, 64, 0deg, 0deg, 16384bam);
        // move_position_time_decelerate(30, 384, 40, 0) → (192,40)
        move_to(30, 192.0fx, 40.0fx, 2);
        // Sub46_688：laser_offset ×30（主激光已在 Sub47 末尾 lz_cancel，活时才重锚）
        for k2 in 0..30 {
            if lz_alive(lz0) == 1 { lz_origin(lz0, $self_x, $self_y); }
            wait(1);
        }

        // t=122 主激光 3：90°；len 400；start 32
        lz0 = laser(2, $self_x, $self_y, 16384bam, 400.0fx, 12.0fx, 60, 800, 20);
        lz_start(lz0, 32.0fx);
        wait(60);

        // t=182
        // move_position_time_decelerate(90, 32, 50, 0) → (-160,50)
        move_to(90, -160.0fx, 50.0fx, 2);
        // call Sub47：f1=0、f2=180°、f3=90°、重复 64 帧
        sub47(lz0, 64, 0deg, 32768bam, 16384bam);
        // move_position_time_decelerate(120, 192, 80, 0) → (0,80)
        move_to(120, 0.0fx, 80.0fx, 2);
        // 主激光 4：-9°；len 400；start 32
        lz0 = laser(2, $self_x, $self_y, -1638bam, 400.0fx, 12.0fx, 60, 800, 20);
        lz_start(lz0, 32.0fx);
        // call Sub47：f1=-2.25°、f2=-99°、f3=-9°、重复 120 帧
        sub47(lz0, 120, -410bam, -18022bam, -1638bam);
        // math_inc($I7)（I7 在本单元无读者，丢弃）
        wait(60);
        // +242 jump(0, Sub46_16) → loop
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
