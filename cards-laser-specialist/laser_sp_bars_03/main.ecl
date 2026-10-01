const BAR_COLOR: int = 2;

async sub bar_pattern() {
    wait(90);
    for cycle in 0..4 {
        var lane: fx = 32.0fx;
        if cycle == 1 { lane = 128.0fx; }
        if cycle == 2 { lane = 256.0fx; }
        if cycle == 3 { lane = 384.0fx; }

        var normal: fx = (rand(49) - 24) as fx;
        var offset: fx = normal * 0.7071fx;
        spawn moving_bar(-192.0fx - offset, lane + offset, 45deg);
        wait(42);
        spawn moving_bar(-192.0fx - offset, lane + 64.0fx + offset, 45deg);
        wait(42);

        normal = (rand(49) - 24) as fx;
        offset = normal * 0.7071fx;
        spawn moving_bar(192.0fx - offset, 448.0fx - lane + offset, 225deg);
        wait(42);
        spawn moving_bar(192.0fx - offset, 384.0fx - lane + offset, 225deg);
        wait(42);

        normal = (rand(49) - 24) as fx;
        offset = normal * 0.7071fx;
        spawn moving_bar(-192.0fx + offset, 448.0fx - lane + offset, 315deg);
        wait(42);
        spawn moving_bar(-192.0fx + offset, 384.0fx - lane + offset, 315deg);
        wait(42);

        normal = (rand(49) - 24) as fx;
        offset = normal * 0.7071fx;
        spawn moving_bar(192.0fx + offset, lane + offset, 135deg);
        wait(42);
        spawn moving_bar(192.0fx + offset, lane + 64.0fx + offset, 135deg);
        wait(42);
    }
    loop { wait(1); }
}

async sub moving_bar(x: fx, y: fx, direction: angle) {
    var rank: int = global(0);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 210;
    var speed: fx = 0.8fx;
    var bar_len: fx = 104.0fx;

    if rank == 0 {
        bar_len = 104.0fx + (rand(17) as fx);
    }
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        active = 195;
        speed = 1.2fx;
        bar_len = 88.0fx + (rand(25) as fx);
    }
    if rank == 2 {
        width = 10.0fx;
        warn = 60;
        active = 180;
        speed = 1.6fx;
        bar_len = 72.0fx + (rand(33) as fx);
    }
    if rank == 3 {
        width = 12.0fx;
        warn = 45;
        active = 165;
        speed = 2.0fx;
        bar_len = 56.0fx + (rand(41) as fx);
    }

    var lz: int = laser(BAR_COLOR, x, y, direction, bar_len, width, warn, active, 12);
    wait(warn);
    var dx: fx = speed * cos(direction);
    var dy: fx = speed * sin(direction);
    for step in 1..active + 1 {
        if lz_alive(lz) == 1 {
            lz_origin(lz, x + dx * step, y + dy * step);
        }
        wait(1);
    }
    wait(12);
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, bar_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000000, 0, 0, 1, boss_main);
    loop { wait(1); }
}
