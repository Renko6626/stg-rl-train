const TIME_LIMIT: int = 1800;
const GROUP_GAP: int = 98;
const LASER_LEN: fx = 640.0fx;

sub emit_horizontal(base_y: int, width: fx, warn: int, active: int) {
    _ = laser(15, -320.0fx, (base_y - 160) as fx, 0deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, -320.0fx, (base_y - 48) as fx, 0deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, -320.0fx, (base_y + 48) as fx, 0deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, -320.0fx, (base_y + 160) as fx, 0deg, LASER_LEN, width, warn, active, 12);
}

sub emit_vertical(base_x: int, width: fx, warn: int, active: int) {
    _ = laser(15, (base_x - 144) as fx, -96.0fx, 90deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, (base_x - 48) as fx, -96.0fx, 90deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, (base_x + 48) as fx, -96.0fx, 90deg, LASER_LEN, width, warn, active, 12);
    _ = laser(15, (base_x + 144) as fx, -96.0fx, 90deg, LASER_LEN, width, warn, active, 12);
}

async sub relay_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 150;
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        active = 170;
    } else if rank == 2 {
        width = 10.0fx;
        warn = 60;
        active = 190;
    } else if rank == 3 {
        width = 12.0fx;
        warn = 45;
        active = 210;
    }

    wait(90);
    var axis_phase: int = rand(2);
    var horizontal_phase: int = rand(7);
    var vertical_phase: int = rand(7);
    var horizontal_index: int = 0;
    var vertical_index: int = 0;

    for group in 0..15 {
        if (group + axis_phase) % 2 == 0 {
            var horizontal_level: int = (horizontal_index + horizontal_phase) % 7;
            var jitter_y: int = 0;
            if horizontal_level > 0 && horizontal_level < 6 {
                jitter_y = rand(17) - 8;
            }
            var base_y: int = 48 + horizontal_level * 40 + jitter_y;
            emit_horizontal(base_y, width, warn, active);
            horizontal_index = horizontal_index + 1;
        } else {
            var vertical_level: int = (vertical_index + vertical_phase) % 7;
            var jitter_x: int = 0;
            if vertical_level > 0 && vertical_level < 6 {
                jitter_x = rand(17) - 8;
            }
            var base_x: int = -48 + vertical_level * 16 + jitter_x;
            emit_vertical(base_x, width, warn, active);
            vertical_index = vertical_index + 1;
        }
        wait(GROUP_GAP);
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_invuln(65535);
    phase_begin(0, relay_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop {
        set_invuln(65535);
        wait(600);
    }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(1); }
}
