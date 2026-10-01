async sub moving_bar(x: fx, y: fx, a: angle, len: fx, w: fx, dx: fx, dy: fx, warn: int, active: int) {
    var lz: int = laser(3, x, y, a, len, w, warn, active, 12);
    wait(warn);
    for step in 0..active {
        var distance: fx = (step + 1) as fx;
        lz_origin(lz, x + dx * distance, y + dy * distance);
        wait(1);
    }
    wait(12);
}

async sub bars_pattern() {
    var rank: int = global(0);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 210;
    var speed: fx = 0.8fx;
    var min_len: int = 80;
    var len_span: int = 41;
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        active = 210;
        speed = 1.1fx;
        min_len = 80;
        len_span = 41;
    } else if rank == 2 {
        width = 10.0fx;
        warn = 60;
        active = 210;
        speed = 1.5fx;
        min_len = 80;
        len_span = 41;
    } else if rank == 3 {
        width = 12.0fx;
        warn = 45;
        active = 210;
        speed = 2.0fx;
        min_len = 80;
        len_span = 41;
    }

    wait(90);
    for wave in 0..17 {
        var drift_x: fx = speed * 0.8fx;
        var drift_y: fx = speed * 0.6fx;
        for lane in 0..4 {
            var x: int = -192 + lane * 128;
            var dx: fx = drift_x;
            if lane == 1 {
                x = x + rand(49) - 24;
            } else if lane == 2 {
                x = x + rand(49) - 24;
                dx = -drift_x;
            } else if lane == 3 {
                dx = -drift_x;
            }

            var layer: int = (lane + wave) % 4;
            var y: int = -24 + rand(25);
            if layer == 1 {
                y = 140 + rand(25) - 12;
            } else if layer == 2 {
                y = 280 + rand(25) - 12;
            } else if layer == 3 {
                y = 384 + rand(25) - 12;
            }

            var len: fx = (min_len + rand(len_span)) as fx;
            spawn moving_bar(x as fx, y as fx, 90deg, len, width, dx, drift_y, warn, active);
        }
        wait(83);
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(1800);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, bars_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000000, 0, 0, 0, boss_main);
    loop { wait(1); }
}
