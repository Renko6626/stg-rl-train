// th06_s3_b2 —— 东方红魔乡 Stage 3 boss（红美铃）符卡 虹符「彩虹の風鈴」
// 原文：ecldata3.ecl.txt Sub33 → Sub34（宣言 + 移到中央 + Sub10 的 120 帧前奏）→ Sub35
//       （每 7 帧一整组 SHARD 彩色环：环基准角每环 +6.5°，相位每轮 ±7.5° 三角摆动），时限 1800。
const TIME_LIMIT: int = 1800;
const SPELL_ID: int = 24;   // 原文 spellcard_start(0, 24/25/26/27, …) = E/N/H/L；本卡取 Easy 的 24
const SHARD: int = 96;      // TH06 弹型 5 SHARD（16px，色号原样）

// 一次 bullet_circle：sprite 5(SHARD)、s1=2.6、s2=0.6、angle2=0，count1/count2 随环与难度。
// bullet_circle：angle = i·2π/c1 + j·a2 + a1 → sh_ring(1) + sh_angle(a1, a2)；
// speed(j) = s1 − (s1−s2)·j/c2 → sh_speed(s1, (s2−s1)/c2)。
sub fire_ring(color: int, c1: int, c2: int, a0: angle) {
    sh_sprite(0, SHARD, color);
    sh_count(0, c1, c2);
    sh_speed(0, 2.6fx, (0.6fx - 2.6fx) / c2);
    sh_angle(0, a0, 0deg);
    sh_fire(0);
}

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    // ── Sub34：宣言段 ──
    kill_all_enemies(KILL_SILENT);          // enemy_kill_all()（跳过调用者 boss）
    move_to(120, 0.0fx, 64.0fx, 2);         // move_position_time_decelerate(120, 192.0f, 64.0f, 0.0f)
    wait(120);                              // call Sub10：12 × 10 帧的宣言前奏
    // ── Sub35：攻击循环 ──
    var i7: int = 0;                        // $I7
    var f1: angle = 9102bam;                // $F1 = 0.87266463f = 50°
    move_to(2000, 0.0fx, 160.0fx, 2);       // move_position_time_decelerate(2000, 192.0f, 160.0f, 0.0f)
    sh_reset(0);
    sh_offset(0, 0.0fx, 0.0fx);             // Sub34 shoot_offset(0.0f, 0.0f, 0.0f)
    sh_aim(0, 0);                           // bullet_circle：不瞄自机
    sh_ring(0, 1);                          // bullet_circle：整周均分
    loop {                                  // Sub35_68
        var f0: angle = f1;                 // set_int($F0, $F1)
        fire_ring(2, 2, 1, f0);             // bullet_circle(5, 2, 2, 1, …)
        f0 = f0 + 1183bam;                  // +6.5°
        if rank == RANK_EASY { fire_ring(14, 1, 1, f0); } else { fire_ring(14, 3, 1, f0); }
        f0 = f0 + 1183bam;                  // +6.5°
        if rank == RANK_EASY { fire_ring(13, 1, 1, f0); } else { fire_ring(13, 4, 1, f0); }
        f0 = f0 + 1183bam;                  // +6.5°
        fire_ring(11, 2, 1, f0);            // bullet_circle(5, 11, 2, 1, …)
        f0 = f0 + 1183bam;                  // +6.5°
        if rank == RANK_EASY { fire_ring(8, 1, 1, f0); }
        else if rank == RANK_NORMAL { fire_ring(8, 4, 1, f0); }
        else if rank == RANK_HARD { fire_ring(8, 6, 2, f0); }
        else { fire_ring(8, 8, 2, f0); }
        f0 = f0 + 1183bam;                  // +6.5°
        fire_ring(6, 3, 1, f0);             // bullet_circle(5, 6, 3, 1, …)
        f0 = f0 + 1183bam;                  // +6.5°
        fire_ring(4, 2, 1, f0);             // bullet_circle(5, 4, 2, 1, …)
        if rank >= RANK_HARD {
            // !HL：$F2 = π；$F0 = π − $F0；两环镜像
            f0 = 32768bam - f0;
            fire_ring(8, 4, 1, f0);         // bullet_circle(5, 8, 4, 1, …)
            f0 = f0 - 1183bam;              // −6.5°
            fire_ring(10, 4, 1, f0);        // bullet_circle(5, 10, 4, 1, …)
        }
        // math_int_mod($I0, $I7, 96); cmp_int($I0, 48); jump_geq：
        // $I7%96 < 48 → $F1 += 7.5°，否则 −7.5°。原式的 $F1 < −π 回卷在本表示下恒不触发。
        if i7 % 96 < 48 { f1 = f1 + 1365bam; } else { f1 = f1 - 1365bam; }
        i7 = i7 + 1;                        // math_int_add($I7, $I7, 1)
        wait(7);                            // +7: jump(0, Sub35_68)，块时间重设为 0
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
