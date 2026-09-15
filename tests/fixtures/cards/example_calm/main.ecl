// 测试卡：无敌 boss、不发弹，300 帧时限到 = done 2。
const TIME_LIMIT: int = 300;

async sub calm_pattern() {
    loop { wait(600); }
}

async sub boss_main() {
    set_invuln(65535);
    phase_begin(0, calm_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 100.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
