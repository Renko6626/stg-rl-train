// th06_s6_mb2 —— 东方红魔乡 Stage 6 中 boss 符卡 奇術「エターナルミーク」
// 原文：ecldata6.ecl.txt Sub14 → Sub15（宣言 + 移到中央）+ Sub16（每 4 帧一轮随机双层弹），时限 900。
const TIME_LIMIT: int = 900;
const SPELL_ID: int = 100;     // 原文 spellcard_start id：E=-1 / N=100 / H=101 / L=102；本卡取 N 的 100（纯 UI/计分）
const BALL: int = 48;          // TH06 弹型 3 BALL 中玉（16px），色号原样照抄

// Sub14: call Sub15（120 帧前奏后 ret）→ call Sub16（攻击循环，无 ret）。
async sub pattern() {
    move_to(120, 0.0fx, 144.0fx, 2);   // Sub15 move_position_time_decelerate(120, 192.0f, 144.0f, 0.0f)
    wait(120);                         // Sub15 +120 ret；之后 Sub16 从 t=0 起循环
    var rank: int = global(GVAR_RANK);
    // Sub16 每轮：先按难度一组半球随机弹，再跟一组全难度 12 颗
    var n: int = 2;                    // !E bullet_random(3, 6, 2, 1, 6.0f, 3.0f, π, 0.0f, 4)
    if rank == RANK_NORMAL { n = 4; }        // !N
    else if rank == RANK_HARD { n = 6; }     // !H
    else if rank >= RANK_LUNATIC { n = 9; }  // !L

    loop {
        // bullet_random 角度 [0, π)（下半屏）、速度 [3, 6)
        for i1 in 0..n {
            var sp1: fx = 3.0fx + 3.0fx / 256 * rand(256);
            var an1: angle = rand(32768) as angle;
            _ = fire(BALL, 6, $self_x, $self_y, sp1, an1, none, none);
        }
        // !* bullet_random(3, 6, 12, 1, 5.0f, 3.0f, 0.0f, -π, 4)：角度 [-π, 0)（上半屏）、速度 [3, 5)
        for i2 in 0..12 {
            var sp2: fx = 3.0fx + 2.0fx / 256 * rand(256);
            var an2: angle = -32768bam + (rand(32768) as angle);
            _ = fire(BALL, 6, $self_x, $self_y, sp2, an2, none, none);
        }
        wait(4);                       // Sub16 +4: jump(0, Sub16_0)
    }
}

async sub boss_main() {
    set_hitbox(13.33fx);   // 段外继承：boss 初始化 Sub9 (40,56,32) → §6.1b
    set_invuln(65535);
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);   // 无 spellcard_flag_timeout → flags 0
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 96.0fx, 1000, 0, 0, 1, boss_main);   // 登场位置未知，取 (0,96) 再移向 (0,144)
    loop { wait(600); }
}
