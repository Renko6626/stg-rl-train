const TIME_LIMIT: int = 1800;

async sub sweep_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 159;
    var omega: angle = 28bam;
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        active = 174;
        omega = 32bam;
    } else if rank == 2 {
        width = 10.0fx;
        warn = 60;
        active = 190;
        omega = 40bam;
    } else if rank >= 3 {
        width = 12.0fx;
        warn = 45;
        active = 210;
        omega = 48bam;
    }

    // Twenty warned fans advance by 18° around one complete circle.
    var center: angle = rand(65536) as angle;
    wait(90);
    for wave in 0..20 {
        var x: fx = (-40 + rand(81)) as fx;
        var signed_omega: angle = omega;
        if rand(2) == 1 {
            signed_omega = -omega;
        }

        var lz0: int = laser(5, x, 32.0fx, center - 12deg, 640.0fx, width, warn, active, 12);
        lz_omega(lz0, signed_omega);
        var lz1: int = laser(5, x, 32.0fx, center, 640.0fx, width, warn, active, 12);
        lz_omega(lz1, signed_omega);
        var lz2: int = laser(5, x, 32.0fx, center + 12deg, 640.0fx, width, warn, active, 12);
        lz_omega(lz2, signed_omega);
        center = center + 18deg;
        wait(72);
    }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, sweep_pattern, TIME_LIMIT, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000, 0, 0, 1, boss_main);
    loop { wait(600); }
}
