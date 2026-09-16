// th06_s2_mb1 —— 东方红魔乡 Stage 2 中 boss（琪露诺）非符
// 原文：ecldata2.ecl.txt Sub20（攻击从 +130 起）+ Sub14 + Sub15 + Sub16 + Sub17，timer_callback_threshold(1920)
const TIME_LIMIT: int = 1920;
const KUNAI: int = 80;   // TH06 弹型 4 KUNAI
const SHARD: int = 96;   // TH06 弹型 5 SHARD

// flags 5（0x1|0x4）的 0x1：出生后 16 帧冲刺速度 5→0；0x4 出生特效不模拟
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }
// flags 132（0x80|0x4）+ bullet_effects(40, 1, -1, -1, 0.0f, 4.0f, …)：
// 40 帧内速度线性减到 0，周期末朝向自机 +0°、速度设为 4.0（0x4 不模拟）
xformdef DECEL_AIM { @40 step_speed(0fx, 40); aim_player(0deg); set_speed(4.0fx); }

// Sub14：苦无（色 10）单点环、每帧 +7.5°、速度 +0.05；E1/N1×2/H2×2/L4×2 颗，48 发
sub sub14() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;
    var c2: int = 1;
    if rank == RANK_NORMAL { c2 = 2; }
    else if rank == RANK_HARD { c1 = 2; c2 = 2; }
    else if rank >= RANK_LUNATIC { c1 = 4; c2 = 2; }
    var f0: fx = 1.5fx;          // speed1，每发 +0.05
    var f1: fx = 1.4fx;          // speed2，每发 -0.02
    var a2: angle = 16384bam;    // 90°，每发 +7.5°
    wait(40);
    for k1 in 0..48 {
        sh_reset(0);
        sh_sprite(0, KUNAI, 10);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, c1, c2);
        sh_speed(0, f0, (f1 - f0) / c2);
        sh_angle(0, a2, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        f0 = f0 + 0.05fx;
        f1 = f1 - 0.02fx;
        a2 = a2 + 1365bam;
        wait(1);
    }
}

// Sub15：同 Sub14 但色 2、每帧 -7.5°（反向螺旋）
sub sub15() {
    var rank: int = global(GVAR_RANK);
    var c1: int = 1;
    var c2: int = 1;
    if rank == RANK_NORMAL { c2 = 2; }
    else if rank == RANK_HARD { c1 = 2; c2 = 2; }
    else if rank >= RANK_LUNATIC { c1 = 4; c2 = 2; }
    var f0: fx = 1.5fx;
    var f1: fx = 1.4fx;
    var a2: angle = 16384bam;
    wait(40);
    for k2 in 0..48 {
        sh_reset(0);
        sh_sprite(0, KUNAI, 2);
        sh_aim(0, 0);
        sh_ring(0, 1);
        sh_count(0, c1, c2);
        sh_speed(0, f0, (f1 - f0) / c2);
        sh_angle(0, a2, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        f0 = f0 + 0.05fx;
        f1 = f1 - 0.02fx;
        a2 = a2 - 1365bam;
        wait(1);
    }
}

// Sub16：两发自机狙扇 ×16 轮（每 10 帧一轮）
//   第一扇：SHARD 色 15，E1/N3/H5/L9 颗 ×2 层，速度 s1→2.0，flags 132（减速后转向自机、速度 4）
//   第二扇：SHARD 色 6，同颗数 ×1 层，速度 2.5（L 3.5），flags 4（无变换）
sub sub16() {
    var rank: int = global(GVAR_RANK);
    var n1: int = 1;
    var sp1: angle = 5461bam;    // 30°
    var s1: fx = 4.0fx;
    var n2: int = 1;
    var sp2: angle = 5461bam;
    var s2: fx = 2.5fx;
    if rank == RANK_NORMAL { n1 = 3; n2 = 3; }
    else if rank == RANK_HARD { n1 = 5; n2 = 5; sp1 = 3277bam; sp2 = 3277bam; }
    else if rank >= RANK_LUNATIC { n1 = 9; n2 = 9; s1 = 5.5fx; s2 = 3.5fx; sp1 = 2048bam; sp2 = 2048bam; }
    wait(40);
    for k3 in 0..16 {
        sh_reset(0);
        sh_sprite(0, SHARD, 15);
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, n1, 2);
        sh_speed(0, s1, (2.0fx - s1) / 2);
        sh_angle(0, 0deg, sp1);
        sh_xform(0, DECEL_AIM);
        sh_fire(0);
        sh_reset(0);
        sh_sprite(0, SHARD, 6);
        sh_aim(0, 1);
        sh_ring(0, 0);
        sh_count(0, n2, 1);
        sh_speed(0, s2, 0fx);
        sh_angle(0, 0deg, sp2);
        sh_fire(0);
        wait(10);
    }
}

// Sub17：暂停体碰 → 随机横移到 x∈[32,352)（TH06 坐标）、y=96 → 恢复体碰；共 80 帧
sub sub17() {
    set_enemy_flag(ENEMY_NO_BODY, 1);
    var rx: fx = 320.0fx / 256 * rand(256) + 32.0fx;
    wait(40);
    move_to(0, rx - 192.0fx, 96.0fx, 0);
    set_enemy_flag(ENEMY_NO_BODY, 0);
    wait(40);
}

async sub pattern() {
    // Sub20 登场：move_position(192, -32) → move_position_time_decelerate(60, 192, 96)
    // move_to 不阻塞；再 wait(130) 到 +130 开始攻击
    move_to(60, 0.0fx, 96.0fx, 2);
    wait(130);
    var i3: int = 0;
    for it in 0..8 {
        if i3 == 0 { sub14(); }
        else if i3 == 1 { sub15(); }
        else { sub16(); }
        i3 = i3 + 1;
        if i3 >= 3 { i3 = 0; }             // 原文 cmp_int/jump_lss(130,…) 后 set_int($I3, 0)
        sub17();
        wait(80);                          // +80: //210
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(15.0fx);                    // enemy_set_hitbox(45, 56, 32) → min(45,56)/3
    phase_begin(0, pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, -32.0fx, 1000, 0, 0, 1, boss_main);   // move_position(192.0f, -32.0f)
    loop { wait(600); }
}
