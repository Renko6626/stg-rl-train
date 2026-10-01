// Original specialist layout: alternating left/right, birth-frozen aimed fans.
// Every lz_aim is issued in the same frame as its laser() call; one center ray
// is directly aimed, flanked by frozen -22/+14 degree variants.
const LASER_COLOR: int = 6;

sub emit_aimed_group(side: int, warn: int, active: int, width: fx) {
    var ox: fx = -176.0fx;
    if side != 0 { ox = 176.0fx; }

    var lz: int = laser(LASER_COLOR, ox, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
    lz_aim(lz, 0deg);
    lz = laser(LASER_COLOR, ox, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
    lz_aim(lz, -22deg);
    lz = laser(LASER_COLOR, ox, 64.0fx, 0deg, 560.0fx, width, warn, active, 12);
    lz_aim(lz, 14deg);
}

async sub aimed_pattern() {
    var rank: int = global(GVAR_RANK);
    var warn: int = 90;
    var active: int = 162;
    var width: fx = 6.0fx;
    var interval: int = 99;
    var interval_jitter: int = 6;
    var groups: int = 14;

    if rank == RANK_NORMAL {
        warn = 75;
        active = 174;
        width = 8.0fx;
        interval = 90;
        interval_jitter = 8;
        groups = 15;
    }
    if rank == RANK_HARD {
        warn = 60;
        active = 186;
        width = 10.0fx;
        interval = 82;
        interval_jitter = 6;
        groups = 16;
    }
    if rank == RANK_LUNATIC {
        warn = 45;
        active = 198;
        width = 12.0fx;
        interval = 72;
        interval_jitter = 4;
        groups = 19;
    }

    // Randomized opening phase [90,91] and inter-group spacing; these are the
    // only random variables, and each interval remains within the declared band.
    wait(90 + rand(2));
    var side: int = 0;
    for g in 0..groups {
        emit_aimed_group(side, warn, active, width);
        side = 1 - side;
        if g + 1 < groups {
            wait(interval + rand(interval_jitter + 1));
        }
    }
    loop { wait(1); }
}

async sub boss_main() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    phase_begin(0, aimed_pattern, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 30000, 1, 0, 0, boss_main);
    loop { wait(1); }
}
