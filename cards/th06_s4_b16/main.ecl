// th06_s4_b16 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）符卡 土符「レイジィトリリトン」（E/N 版）
// 原文：ecldata4.ecl.txt Sub66(:2222-2228) → Sub67(:2230-2249) → Sub68(:2251-2266)，时限 2100。
// 逐段对照见 report.md。
const TIME_LIMIT: int = 2100;
const SPELL_ID: int = 55;   // 原文 spellcard_start(1, 55/56, …)：E=55、N=56；rank 下界为 E，取 55（仅 UI/计分）
const OUTLINE: int = 32;    // TH06 弹型 1 RING_BALL → OUTLINE
const BALL: int = 48;       // TH06 弹型 3 BALL

// flags 67 = 0x40 | 0x2 | 0x1（mapping §5）：0x40 减速转向；0x2 出生特效按 §4.2 不模拟；
//   0x1 出生冲刺在 TH06 里与 0x40 同帧执行，0x40 分支在同一帧重写 velocity（decomp
//   BulletManager.cpp:712-762 两个独立 if，后者胜），故 0x1 实际不生效，不写。
// 0x40：i0=180 帧内线性减速到 0 → 末了转 f0（$F0，[-90°,90°) 随机）→ 速度设为 f1=1.4。
//   随机转角进不了 xformdef（参数必须编译期常量），按 4 等分量化（±22.5°/±67.5°），每轮随机选一档。
xformdef ST_TURN_A { @180 step_speed(0fx, 180); turn(-12288bam); set_speed(1.4fx); }  // 中心 -67.5°
xformdef ST_TURN_B { @180 step_speed(0fx, 180); turn(-4096bam);  set_speed(1.4fx); }  // 中心 -22.5°
xformdef ST_TURN_C { @180 step_speed(0fx, 180); turn(4096bam);   set_speed(1.4fx); }  // 中心 +22.5°
xformdef ST_TURN_D { @180 step_speed(0fx, 180); turn(12288bam);  set_speed(1.4fx); }  // 中心 +67.5°

async sub pattern() {
    var rank: int = global(GVAR_RANK);
    kill_all_enemies(KILL_SILENT);           // Sub67 enemy_kill_all()（跳过调用者 boss）
    move_to(120, 0.0fx, 80.0fx, 2);          // Sub67 move_position_time_decelerate(120, 192.0, 80.0)，x1=0
    wait(120);                               // Sub67 +120 ret → Sub68 开始
    var n: int = 7;                          // !E bullet_random count1 = 7
    if rank >= RANK_NORMAL { n = 10; }       // !N count1 = 10
    loop {                                   // Sub68_20
        // set_float_rand_bound_min($F0, π, -π/2)：每轮重摇 [-90°,90°) 转角，量化 4 档
        var choice: int = rand(4);
        // bullet_random(1, 13, n, 1, 2.4f, 1.0f, π, 0.0f, 67)：
        //   n 颗，角度 [0°,180°) 随机、速度 [1.0,2.4) 随机（§4.2 逐颗 fire）
        for i in 0..n {
            var sp: fx = 1.0fx + 1.4fx / 256 * rand(256);
            var an: angle = rand(32768) as angle;
            if choice == 0 { _ = fire(OUTLINE, 13, $self_x, $self_y, sp, an, ST_TURN_A, none); }
            else if choice == 1 { _ = fire(OUTLINE, 13, $self_x, $self_y, sp, an, ST_TURN_B, none); }
            else if choice == 2 { _ = fire(OUTLINE, 13, $self_x, $self_y, sp, an, ST_TURN_C, none); }
            else { _ = fire(OUTLINE, 13, $self_x, $self_y, sp, an, ST_TURN_D, none); }
        }
        // cmp_float(%PLAYER_Y, %SELF_Y); jump_geq(0, Sub68_276)：自机不在 boss 上方时跳过该发
        if $player_y < $self_y {
            // bullet_fan_aimed(3, 6, 7, 2, 2.8f, 1.2f, 0.0f, 0.34906584f, 4)：
            //   中玉 7 颗 × 2 层，自机狙 + 0° 中轴、间隔 20°（§4.2）
            sh_reset(0);
            sh_sprite(0, BALL, 6);
            sh_aim(0, 1);
            sh_ring(0, 0);
            sh_count(0, 7, 2);
            sh_speed(0, 2.8fx, (1.2fx - 2.8fx) / 2);
            sh_angle(0, 0deg, 3641bam);
            sh_fire(0);
        }
        wait(12);                            // Sub68 +12 jump(0, Sub68_20)
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(16.0fx);                      // Sub1 enemy_set_hitbox(48,56,32) → min/3 = 16（§8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 段起点未知，按 §13.2 取 (0,96)
    loop { wait(600); }
}
