// th06_s3_b8 —— 东方红魔乡 Stage 3 boss（红美铃）符卡 彩符「極彩颱風」
// 原文：ecldata3.ecl.txt Sub45（入口 +60）→ Sub46（宣言 / 移到中央 / Sub10 延时 120）→ Sub47（6 帧一循环的多向随机曲射流），时限 2160。

const TIME_LIMIT: int = 2160;
const SPELL_ID: int = 34;      // 原文 !N 的符卡 id（H=35 / L=36 / E 无此段）；本引擎里只进 boss UI 公告板

// TH06 弹型 5 = SHARD（16px 弹，色号原样，mapping §3）
const SHARD: int = 96;

// Sub47 的 8 个出弹位各占一只自由 global 槽，把"这一发的固定加速度方向"（BAM）传给弹任务。
// 弹任务出生次帧就读走它（同位的下一次写要 6 帧后，无竞态），等 16 帧让 flags 0x1 的冲刺跑完，
// 再 set_gravity 复现 flags 0x10 的固定角加速度——xformdef 参数是编译期常量，装不下 $F0/$F2。
const G_P0: int = 16;
const G_P1: int = 17;
const G_P2: int = 18;
const G_P3: int = 19;
const G_P4: int = 20;
const G_P5: int = 21;
const G_P6: int = 22;
const G_P7: int = 23;

// flags 19 = 0x1|0x2|0x10（mapping §5）：出生冲刺 5→0 走 16 帧
xformdef DASH { add_speed(5.0fx); @16 set_accel(-0.3125fx); stop_fx(); }

// 每个出弹位一只零参弹任务：读本位方向 → 等冲刺结束 → 写固定角加速度
async sub grav0() {
    var a: angle = global(G_P0) as angle;
    wait(16);
    set_gravity(0, 0.016fx * cos(a), 0.016fx * sin(a));
}
async sub grav1() {
    var a: angle = global(G_P1) as angle;
    wait(16);
    set_gravity(0, 0.018fx * cos(a), 0.018fx * sin(a));
}
async sub grav2() {
    var a: angle = global(G_P2) as angle;
    wait(16);
    set_gravity(0, 0.016fx * cos(a), 0.016fx * sin(a));
}
async sub grav3() {
    var a: angle = global(G_P3) as angle;
    wait(16);
    set_gravity(0, 0.018fx * cos(a), 0.018fx * sin(a));
}
async sub grav4() {
    var a: angle = global(G_P4) as angle;
    wait(16);
    set_gravity(0, 0.016fx * cos(a), 0.016fx * sin(a));
}
async sub grav5() {
    var a: angle = global(G_P5) as angle;
    wait(16);
    set_gravity(0, 0.018fx * cos(a), 0.018fx * sin(a));
}
async sub grav6() {
    var a: angle = global(G_P6) as angle;
    wait(16);
    set_gravity(0, 0.018fx * cos(a), 0.018fx * sin(a));
}
async sub grav7() {
    var a: angle = global(G_P7) as angle;
    wait(16);
    set_gravity(0, 0.016fx * cos(a), 0.016fx * sin(a));
}

async sub pattern() {
    kill_all_enemies(KILL_SILENT);    // Sub45 enemy_kill_all（跳过调用者自己；本卡无杂兵，等价 no-op）
    wait(60);                         // Sub45 +60
    move_to(120, 0.0fx, 128.0fx, 2);  // Sub46 move_position_time_decelerate(120, 192.0f, 128.0f)
    wait(120);                        // Sub46 call Sub10(120)：缓动 120 帧 + 再停 120 帧
    // Sub47：$F0 = π/2，$F2 = 随机整周，$I0 = 2
    var rank: int = global(GVAR_RANK);
    var f0: angle = 16384bam;
    var f2: angle = rand(65536) as angle;
    var f1: angle = 0deg;
    var i0: int = 2;
    var n7: int = 1;
    var sp: fx = 0fx;
    var an: angle = 0deg;
    loop {
        // +0 //0：$F1 = $F0，count = $I0，色 6，加速度 0.016
        f1 = f0;
        set_global(G_P0, f1 as int);
        for k0 in 0..i0 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 6, $self_x, $self_y, sp, an, DASH, grav0);
        }
        wait(1);
        // +1 //1：$F1 = $F0 + π/2（全难度 1 发，色 10，0.018）
        f1 = f0 + 16384bam;
        set_global(G_P1, f1 as int);
        for k1 in 0..1 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 10, $self_x, $self_y, sp, an, DASH, grav1);
        }
        if rank >= RANK_HARD {            // !HL：$F1 = $F0 + π（1 发，色 11，0.016）
            f1 = f0 + 32768bam;
            set_global(G_P2, f1 as int);
            for k2 in 0..1 {
                sp = 0.3fx + 0.7fx / 256 * rand(256);
                an = rand(65536) as angle;
                _ = fire(SHARD, 11, $self_x, $self_y, sp, an, DASH, grav2);
            }
        }
        wait(1);
        // +2 //2：$F1 = $F0 − π/2（1 发，色 8，0.018）
        f1 = f0 - 16384bam;
        set_global(G_P3, f1 as int);
        for k3 in 0..1 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 8, $self_x, $self_y, sp, an, DASH, grav3);
        }
        wait(1);
        // +3 //3：$F1 = $F2，count = $I0，色 2，0.016
        f1 = f2;
        set_global(G_P4, f1 as int);
        for k4 in 0..i0 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 2, $self_x, $self_y, sp, an, DASH, grav4);
        }
        if rank >= RANK_HARD {            // !H：$F1 = $F2 + π/2；!L：$F1 = $F2（各 1 发，0.018）
            if rank >= RANK_LUNATIC { f1 = f2; } else { f1 = f2 + 16384bam; }
            set_global(G_P5, f1 as int);
            for k5 in 0..1 {
                sp = 0.3fx + 0.7fx / 256 * rand(256);
                an = rand(65536) as angle;
                _ = fire(SHARD, 2, $self_x, $self_y, sp, an, DASH, grav5);
            }
        }
        wait(1);
        // +4 //4：$F1 = $F2 + π（1 发，色 2，0.018）
        f1 = f2 + 32768bam;
        set_global(G_P6, f1 as int);
        for k6 in 0..1 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 2, $self_x, $self_y, sp, an, DASH, grav6);
        }
        wait(1);
        // +5 //5：!NH $F1 = $F2 − π/2（1 发）；!L $F1 = $F2（3 发），0.016
        if rank >= RANK_LUNATIC { f1 = f2; n7 = 3; } else { f1 = f2 - 16384bam; n7 = 1; }
        set_global(G_P7, f1 as int);
        for k7 in 0..n7 {
            sp = 0.3fx + 0.7fx / 256 * rand(256);
            an = rand(65536) as angle;
            _ = fire(SHARD, 2, $self_x, $self_y, sp, an, DASH, grav7);
        }
        // +5 同帧：$F0 += 6°、$F2 −= 6°；$SELF_TIME 过 600 保持 2 路、过 1200 升 3 路
        f0 = f0 + 1092bam;
        f2 = f2 - 1092bam;
        if $self_age > 1200 { i0 = 3; } else if $self_age > 600 { i0 = 2; }
        wait(1);                          // +6 //6 → jump(0, Sub47_84)
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
