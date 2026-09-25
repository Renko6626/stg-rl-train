// th06_s7_b18 —— 东方红魔乡 Extra boss 芙兰朵露 符卡 ＱＥＤ「４９５年の波紋」
// 原文：ecldata7.ecl.txt Sub91 → Sub92 → Sub93（spellcard_start id 130 + 移中央 120 帧）→ Sub94（攻击循环）。
// 时限 9000（unit.json 已钳到 3000）。按 Extra（rank 4）执行；原文全为 !*。
const TIME_LIMIT: int = 3000;
const SPELL_ID: int = 130;   // 原文 spellcard_start(3, 130, "ST_ECLDATA7_SUB68_0")；仅 UI/计分
const RICE: int = 64;        // TH06 弹型 2 RICE（16px，色号 6 原样）

// Sub94 bullet_effects(1, -1, -1, -1, -1.0f, -1.0f, …) + flags 2560(0x800|0x200)：
// 0x800 = 碰左右上三面场界反弹、速度保持（f0 < 0）；反弹次数 i0 = 1。0x200 音效丢弃。
xformdef BOUNCE1 { bounce_arm(7, 1); }

async sub pattern() {
    kill_all_enemies(KILL_SILENT);                 // Sub93 enemy_kill_all()（跳过调用者 boss）
    sh_reset(0);
    sh_offset(0, 0.0fx, 0.0fx);                    // Sub93 shoot_offset(0, 0, 0)
    // Sub93：move_position_time_decelerate(120, 192.0f, 80.0f, 0.0f)，boss 上一段已在 (0,80)
    move_to(120, 0.0fx, 80.0fx, 2);
    wait(120);
    // Sub94 前奏：set_int($I4,30) + 每 2 帧 effect_particle（drop）→ 共 60 帧，保留时序
    wait(60);

    // Sub94 bullet_effects + bullet_circle(2, 6, 88, 1, %F3, 1.0, %F0, 0, 2560)
    sh_sprite(0, RICE, 6);
    sh_aim(0, 0);
    sh_ring(0, 1);
    sh_count(0, 88, 1);
    sh_speed(0, 1.0fx, 0fx);
    sh_xform(0, BOUNCE1);

    var a: angle = 0deg;
    var rx: fx = 0fx;
    var ry: fx = 0fx;
    loop {
        // ex_ins_call(16,0) 每轮重设 float3 = 速度 = 1.0、var5 = 内层帧数 = 280（满血 6000 常量）
        a = rand(65536) as angle;                  // set_float_rand_bound_min($F0, 2π, −π)
        sh_angle(0, a, 0deg);
        sh_fire(0);                                // 本轮用「上一轮」算出的 shoot_offset（原作 fire 在前）
        // ex_ins_call(16,1)：float2 = rand(160)+112（TH06 x）、float3 = rand(64)+64（TH06 y）
        // 原作用 set_int($F0,$F2) 后 math_float_sub(…, %SELF_X/%SELF_Y) 写成 shoot_offset
        rx = 160.0fx / 256 * rand(256) + 112.0fx;
        ry = 64.0fx / 256 * rand(256) + 64.0fx;
        sh_offset(0, rx - 192.0fx - $self_x, ry - $self_y);
        // jump_dec(2, Sub94_380, $I5=280) 内层空转 280 帧 + jump(2, Sub94_160) 的 1 帧 = 281
        wait(281);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_hitbox(18.67fx);                           // 链上最近 enemy_set_hitbox(56,56,32) → 56/3（mapping §8）
    spell_begin(0, SPELL_ID, pattern, TIME_LIMIT, 0, 0, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 80.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
