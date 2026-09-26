// 激光夹具：无敌 boss，每 60 帧放一组三种形态的激光（预警扫射 · 自机狙 · 飞出去的短棒），原点左右不对称。
const TIME_LIMIT: int = 1800;

async sub laser_pattern() {
    wait(20);
    loop {
        var sweep: int = laser(4, -40.0fx, 120.0fx, 60deg, 500.0fx, 24.0fx, 20, 60, 10);
        _ = laser(6, $self_x, $self_y, aim_player() + 5deg, 400.0fx, 12.0fx, 30, 40, 8);
        var bar: int = laser(2, 50.0fx, 100.0fx, 100deg, 96.0fx, 8.0fx, 0, 90, 0);
        lz_speed(bar, 3.0fx, 96.0fx);
        wait(20);
        lz_omega(sweep, 120bam);
        wait(40);
    }
}

async sub boss_main() {
    set_invuln(65535);
    phase_begin(0, laser_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 100.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
