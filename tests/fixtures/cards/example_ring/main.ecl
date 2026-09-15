// RL 卡池骨架：无敌 boss + 一个非符段，时限到 = EVT_PHASE_ENDED = done 2。
const TIME_LIMIT: int = 1800; // 30 s
const RICE: int = 64; // 弹型号 = 图集行 × BULLET_COLOR_STRIDE（抄自 godot/ecl/game/bullets.ecl）

async sub ring_pattern() {
    sh_reset(0);
    sh_ring(0, 1);
    sh_sprite(0, RICE, 0);
    var base: angle = 0deg;
    wait(90); // 开场缓冲：预热随机游走期间别打死人
    loop {
        sh_count(0, 16 + global(GVAR_RANK) * 4, 1);
        sh_speed(0, 2.0fx, 0fx);
        sh_angle(0, base, 0deg);
        sh_fire(0);
        base = base + 7deg;
        wait(40);
    }
}

async sub boss_main() {
    set_invuln(65535); // 常按 SHOT 打不掉血：段长只由时限决定
    phase_begin(0, ring_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 100.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
