// th06_s4_w11 —— 东方红魔乡 Stage 4 道中 第 11 波
// 原文：ecldata4.ecl.txt timeline 帧 3378–3618（Sub14），E–L 四档。
const TIME_LIMIT: int = 560;
const BULLET: int = 128;   // TH06 弹型 0 PELLET
const BALL: int = 48;      // TH06 弹型 3 BALL

// flags 5 = 0x1|0x4：出生冲刺（mapping §5）；0x4 出生特效有意不模拟（§4.2）
xformdef BURST { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// TH06 敌进过场地再出界即删（mapping §6.2）
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

// Sub14：原地不动，每 50 帧两圈随机相位自机狙环（小玉环 + 中玉环，第二圈角偏 4681bam / 2979bam）。
// 原文 $I4 = 60 次 jump_dec 循环（每轮 50 帧）；此处照翻。
async sub sub14() {
    set_invuln(65535);
    set_hitbox(9.33fx);                        // enemy_set_hitbox(28, 28, 32) → 28/3
    spawn oob_guard();
    set_enemy_flag(ENEMY_NO_BODY, 1);          // enemy_flag_interactable(0)
    wait(30);
    set_enemy_flag(ENEMY_NO_BODY, 0);          // +30 enemy_flag_interactable(1)
    var rank: int = global(GVAR_RANK);
    for k in 0..60 {
        var a0: angle = rand(65536) as angle;  // set_float_rand_bound_min($F0, 2π, −π)
        var a1: angle = a0;
        var n: int = 7;                        // !E bullet_circle_aimed(0, 10, 7, 1, 1.2, 1.0, %F0, 0.0, 5)
        var layersB: int = 1;
        var layersY: int = 1;
        var s1: fx = 1.2fx;
        if rank == RANK_NORMAL { n = 11; }
        else if rank == RANK_HARD { n = 12; layersB = 2; s1 = 1.6fx; }
        else if rank >= RANK_LUNATIC { n = 15; layersB = 2; layersY = 2; s1 = 2.5fx; }
        if rank == RANK_EASY { a1 = a0 + 4681bam; }   // 0.44879895f
        else { a1 = a0 + 2979bam; }                    // 0.28559932f
        // 小玉环
        sh_reset(0);
        sh_sprite(0, BULLET, 10);
        sh_aim(0, 1);
        sh_ring(0, 1);
        sh_count(0, n, layersB);
        sh_speed(0, s1, (1.0fx - s1) / layersB);
        sh_angle(0, a0, 0deg);
        sh_xform(0, BURST);
        sh_fire(0);
        // 中玉环
        sh_reset(1);
        sh_sprite(1, BALL, 10);
        sh_aim(1, 1);
        sh_ring(1, 1);
        sh_count(1, n, layersY);
        sh_speed(1, s1, (1.0fx - s1) / layersY);
        sh_angle(1, a1, 0deg);
        sh_xform(1, BURST);
        sh_fire(1);
        wait(50);
    }
    set_enemy_flag(ENEMY_NO_BODY, 1);          // 循环结束 +80 enemy_flag_interactable(0)
    wait(30);                                  // +110
    die();                                     // enemy_delete(0)
}

// 导演：卡帧 = 120（开场缓冲）+ (原文帧 − 3378)
async sub wave() {
    wait(120);
    _ = spawn_enemy((rand(384) - 192) as fx, 32.0fx, 1, 0, 0, 0, sub14);   // 3378
    wait(40);
    _ = spawn_enemy((rand(384) - 192) as fx, 128.0fx, 1, 0, 0, 0, sub14);  // 3418
    wait(40);
    _ = spawn_enemy((rand(384) - 192) as fx, 144.0fx, 1, 0, 0, 0, sub14);  // 3458
    wait(50);
    _ = spawn_enemy((rand(384) - 192) as fx, 64.0fx, 1, 0, 0, 0, sub14);   // 3508
    wait(50);
    _ = spawn_enemy((rand(384) - 192) as fx, 80.0fx, 1, 0, 0, 0, sub14);   // 3558
    wait(60);
    _ = spawn_enemy((rand(384) - 192) as fx, 96.0fx, 1, 0, 0, 0, sub14);   // 3618
    loop { wait(1); }
}

async sub director() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, wave, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 0.0fx, 1000, 0, 0, 0, director);
    loop { wait(600); }
}
