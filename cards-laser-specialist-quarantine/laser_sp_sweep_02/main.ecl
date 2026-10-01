const TIME_LIMIT: int = 1800;

async sub sweep_pattern() {
    var rank: int = global(GVAR_RANK);
    var width: fx = 6.0fx;
    var warn: int = 90;
    var active: int = 159;
    var omega: angle = 34bam;
    if rank == 1 {
        width = 8.0fx;
        warn = 75;
        active = 174;
        omega = 40bam;
    } else if rank == 2 {
        width = 10.0fx;
        warn = 60;
        active = 190;
        omega = 48bam;
    } else if rank >= 3 {
        width = 12.0fx;
        warn = 45;
        active = 210;
        omega = 56bam;
    }

    // One shared angular phase; alternating origins each advance the same 18° clock.
    var phase: angle = rand(65536) as angle;
    wait(90);
    for wave in 0..20 {
        var y: fx = (96 + rand(257)) as fx;
        var jitter: angle = (rand(1093) as angle) - (546 as angle);
        var left: int = wave % 2 == 0;
        var center: angle = phase + jitter;
        var x: fx = 184.0fx;
        var signed_omega: angle = omega;
        if left {
            x = -184.0fx;
        } else {
            center = center + 180deg;
            signed_omega = -omega;
        }

        var length: fx = 640.0fx;
        if rank == 0 {
            length = 520.0fx;
        }
        var lz0: int = laser(6, x, y, center - 8deg, length, width, warn, active, 12);
        var lz1: int = laser(6, x, y, center + 8deg, length, width, warn, active, 12);
        lz_omega(lz0, signed_omega);
        lz_omega(lz1, signed_omega);
        phase = phase + 18deg;
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
