// th06_s4_b15 —— 东方红魔乡 Stage 4 boss（帕秋莉·诺蕾姬）符卡 木符「グリーンストーム」
// 原文：ecldata4.ecl.txt Sub63 → Sub64（宣言 / timer 2100 / 移到中央）→ Sub65（每 5 帧一轮随机鳞弹 + 侧边鳞弹），时限 2100。

const TIME_LIMIT: int = 2100;
const SPELL_ID_H: int = 53;    // 原文 spellcard_start(1, 53/54)：H=53、L=54
const SPELL_ID_L: int = 54;
const SHARD: int = 96;         // TH06 弹型 5 SHARD 鳞弹（16px，色号原样）

// bullet_effects(-1,-1,-1,-1, 0.008f, f1, -1, -1) + flags 19(0x10|0x2|0x1)：
//   0x1  出生冲刺 5.0，16 帧内线性衰减回原速；
//   0x10 i0=-1 → 此后沿固定角 f1 永久加速 0.008；
//   0x2  出生特效（10 帧半速）有意不模拟（§4.2 / §5）。
// 固定角换算成重力分量：f1=90°→(0, 0.008)；f1=135°→(−0.005657, 0.005657)；f1=45°→(0.005657, 0.005657)。
xformdef BURST_XF {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0.0fx, 0.008fx);
}
xformdef EVEN_XF {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(-0.005657fx, 0.005657fx);
}
xformdef ODD_XF {
    add_speed(5.0fx);
    @16 set_accel(-0.3125fx);
    set_gravity(0.005657fx, 0.005657fx);
}

// 原文 Sub64 move_position_time_decelerate(120, 192.0f, 80.0f, 0.0f) → 我方 (0,80)，QuadOut。
// +120 ret 之后才 call("Sub65")，所以攻击循环从卡开始后第 120 帧起。
async sub pattern() {
    kill_all_enemies(KILL_SILENT);          // 原文 Sub64 `enemy_kill_all()`
    move_to(120, 0.0fx, 80.0fx, 2);         // 移到中央
    wait(120);                              // Sub64 +120 ret
    var rank: int = global(GVAR_RANK);
    var period: int = 8;                    // !H math_int_mod($I1, $I0, 8)
    if rank >= RANK_LUNATIC { period = 5; } // !L math_int_mod($I1, $I0, 5)
    // 侧弹速度上界：!H 1.4f、!L 2.0f（source.txt:58-59/68-69）→ speed = 0.3 + (hi−0.3)/256·rand(256)
    var side_hi: fx = 1.4fx;
    if rank >= RANK_LUNATIC { side_hi = 2.0fx; }
    var i0: int = 0;                        // 原文 Sub65 set_int($I0, 0)
    loop {
        if i0 % period == 0 {
            // !H/!L bullet_random(5, 11, 30, 1, 2.0, 0.3, π, −π, 19)：30 颗整周、速度 [0.3,2.0)
            for b in 0..30 {
                var sp_b: fx = 0.3fx + 1.7fx / 256 * rand(256);
                var an_b: angle = rand(65536) as angle;
                _ = fire(SHARD, 11, $self_x, $self_y, sp_b, an_b, BURST_XF, none);
            }
        }
        // Sub65_236 顺序落穿：爆发轮（i0%period==0）也照样发这一颗侧弹，
        // 只有 !burst 时才由 Sub65_20 的 jump_neq 直接跳到 Sub65_236。
        if i0 % 2 == 0 {
            // 偶数：shoot_offset(396−self_x, rand−self_y)，出弹点 x=396 → 我方 204（场右外）
            // bullet_random(5, 10, 1, 1, 1.4/2.0, 0.3, 151°, 119°, 19)
            var y_e: fx = 384.0fx / 256 * rand(256);
            var sp_e: fx = 0.3fx + (side_hi - 0.3fx) / 256 * rand(256);
            var an_e: angle = 21663bam + rand(5826) as angle;
            _ = fire(SHARD, 10, 204.0fx, y_e, sp_e, an_e, EVEN_XF, none);
        } else {
            // 奇数：shoot_offset(−12−self_x, rand−self_y)，出弹点 x=−12 → 我方 −204（场左外）
            // bullet_random(5, 10, 1, 1, 1.4/2.0, 0.3, 61°, 29°, 19)
            var y_o: fx = 384.0fx / 256 * rand(256);
            var sp_o: fx = 0.3fx + (side_hi - 0.3fx) / 256 * rand(256);
            var an_o: angle = 5279bam + rand(5826) as angle;
            _ = fire(SHARD, 10, -204.0fx, y_o, sp_o, an_o, ODD_XF, none);
        }
        i0 = i0 + 1;                        // Sub65_788 math_inc($I0)
        wait(5);                            // Sub65 `+5: jump(0, Sub65_20)`
    }
}

async sub boss_main() {
    set_invuln(65535);
    var sid: int = SPELL_ID_H;              // H→53、L→54（source.txt:19-20）
    if global(GVAR_RANK) >= RANK_LUNATIC { sid = SPELL_ID_L; }
    spell_begin(0, sid, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
