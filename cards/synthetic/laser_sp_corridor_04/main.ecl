async sub corridor_wave(index: int) {
    var rank: int = global(0);
    var width: fx = 6.0fx;
    var clearance: fx = 64.0fx;
    var speed: fx = 0.40fx;
    var warn: int = 90;
    if rank == 1 {
        width = 8.0fx;
        clearance = 56.0fx;
        speed = 0.60fx;
        warn = 75;
    }
    if rank == 2 {
        width = 10.0fx;
        clearance = 40.0fx;
        speed = 0.85fx;
        warn = 60;
    }
    if rank == 3 {
        width = 12.0fx;
        clearance = 32.0fx;
        speed = 1.00fx;
        warn = 45;
    }
    var spacing: fx = width + clearance;
    var inward: fx = rand(25) as fx;
    var edge: int = index % 4;
    var x1: fx = 0.0fx;
    var y1: fx = 0.0fx;
    var x2: fx = 0.0fx;
    var y2: fx = 0.0fx;
    var dir_angle: angle = 0deg;
    var length: fx = 384.0fx;
    var dx: fx = 0.0fx;
    var dy: fx = 0.0fx;

    if edge == 0 {
        // Top: two horizontal lines; the first can touch y=0.
        y1 = inward;
        x1 = -192.0fx;
        x2 = x1;
        y2 = y1 + spacing;
        dir_angle = 0deg;
        dy = speed;
    }
    if edge == 1 {
        // Left: two vertical lines; the first can touch x=-192.
        x1 = -192.0fx + inward;
        x2 = x1 + spacing;
        y1 = 0.0fx;
        y2 = y1;
        dir_angle = 90deg;
        length = 448.0fx;
        dx = speed;
    }
    if edge == 2 {
        // Bottom: the second line can touch y=448.
        y1 = 448.0fx - spacing - inward;
        y2 = y1 + spacing;
        x1 = -192.0fx;
        x2 = x1;
        dir_angle = 0deg;
        dy = 0.0fx - speed;
    }
    if edge == 3 {
        // Right: the second line can touch x=192.
        x1 = 192.0fx - spacing - inward;
        x2 = x1 + spacing;
        y1 = 0.0fx;
        y2 = y1;
        dir_angle = 90deg;
        length = 448.0fx;
        dx = 0.0fx - speed;
    }

    var first: int = laser(2, x1, y1, dir_angle, length, width, warn, 180, 12);
    var second: int = laser(2, x2, y2, dir_angle, length, width, warn, 180, 12);
    wait(warn);
    for frame in 0..180 {
        wait(1);
        x1 = x1 + dx;
        y1 = y1 + dy;
        x2 = x2 + dx;
        y2 = y2 + dy;
        lz_origin(first, x1, y1);
        lz_origin(second, x2, y2);
    }
    wait(12);
}

async sub practice_pattern() {
    wait(90);
    for wave in 0..10 {
        spawn corridor_wave(wave);
        wait(150);
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, practice_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000000, 0, 0, 1, boss_main);
    loop { wait(1); }
}
