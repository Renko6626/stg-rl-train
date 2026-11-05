const TIME_LIMIT: int = 1800;
const LASER_COLOR: int = 15;

async sub relay_laser(x: fx, y: fx, initial: angle, omega: angle, width: fx, warn: int) {
    var lz: int = laser(LASER_COLOR, x, y, initial, 450.0fx, width, warn, 210, 12);
    wait(warn);
    lz_omega(lz, omega);
    wait(222);
}

async sub sweep_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var omega_abs: int = 20;
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        omega_abs = 40;
    }
    if rank == 2 {
        width = 10.0fx;
        warn = 60;
        omega_abs = 60;
    }
    if rank == 3 {
        width = 12.0fx;
        warn = 45;
        omega_abs = 80;
    }

    wait(90);
    for wave in 0..16 {
        var sector: int = wave / 2;
        var center: angle = (sector * 8192 + 5461) as angle;
        var jitter: angle = (rand(5461) - 2731) as angle;
        var x: fx = 0.0fx;
        var y: fx = (192 + rand(65)) as fx;
        var initial: angle = center;
        var omega: angle = omega_abs as angle;
        if wave % 2 == 0 {
            x = (-168 + rand(9)) as fx;
            initial = center - 10deg + jitter;
        } else {
            x = (160 + rand(9)) as fx;
            initial = center + 10deg + jitter;
            omega = (0 - omega_abs) as angle;
        }
        spawn relay_laser(x, y, initial, omega, width, warn);
        if wave < 15 {
            wait(88);
        }
    }
    loop { wait(1); }
}

async sub boss_pattern() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, sweep_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 0, 0, 1, boss_pattern);
    loop { wait(1); }
}
