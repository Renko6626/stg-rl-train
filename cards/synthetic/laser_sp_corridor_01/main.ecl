async sub fixed_boss() {
    set_invuln(65535);
    set_enemy_flag(ENEMY_NO_BODY, 1);
    set_hitbox(0.0fx);
    set_hurtbox(0.0fx);
    phase_begin(0, none, 1800, 0);
    wait_spell();
    loop { wait(1); }
}

async sub vertical_corridor(center: fx, halfsep: fx, beam_width: fx, speed: fx, direction: int, warn: int, active: int) {
    var left_x: fx = center - halfsep;
    var right_x: fx = center + halfsep;
    var left: int = laser(0, left_x, 0.0fx, 90deg, 448.0fx, beam_width, warn, active, 12);
    var right: int = laser(0, right_x, 0.0fx, 90deg, 448.0fx, beam_width, warn, active, 12);
    var sign: fx = 1.0fx;
    if direction < 0 { sign = -1.0fx; }
    // Hold the edge position for the full warning. Start smooth translation
    // only after activation so the dangerous line, not its warning, sweeps the edge.
    wait(warn);
    var ticks: int = 0;
    var life: int = active + 12;
    while ticks < life {
        if lz_alive(left) == 1 && lz_alive(right) == 1 {
            center = center + speed * sign;
            if center > 164.0fx {
                center = 164.0fx - (center - 164.0fx);
                sign = -1.0fx;
            }
            if center < -164.0fx {
                center = -164.0fx + (-164.0fx - center);
                sign = 1.0fx;
            }
            lz_origin(left, center - halfsep, 0.0fx);
            lz_origin(right, center + halfsep, 0.0fx);
        }
        wait(1);
        ticks = ticks + 1;
    }
}

sub main() {
    _ = spawn_enemy(0.0fx, 64.0fx, 1000000, 0, 0, 1, fixed_boss);
    wait(90);

    var rank: int = global(GVAR_RANK);
    var beam_width: fx = 6.0fx;
    var clear_gap: fx = 60.0fx;
    var speed_min: fx = 1.10fx;
    var warn: int = 90;
    var active: int = 160;
    if rank == 1 {
        beam_width = 8.0fx;
        clear_gap = 52.0fx;
        speed_min = 1.12fx;
        warn = 75;
        active = 162;
    }
    if rank == 2 {
        beam_width = 10.0fx;
        clear_gap = 44.0fx;
        speed_min = 1.14fx;
        warn = 60;
        active = 180;
    }
    if rank == 3 {
        beam_width = 12.0fx;
        clear_gap = 40.0fx;
        speed_min = 1.16fx;
        warn = 45;
        active = 208;
    }

    var wave: int = 0;
    var side: int = 1;
    while wave < 17 {
        var q: int = rand(9);
        var jitter: fx = rand(25) as fx;
        var center: fx = 140.0fx + jitter;
        var direction: int = 1;
        if side < 0 {
            center = -140.0fx - jitter;
            direction = -1;
        }
        var halfsep: fx = (clear_gap + (q as fx)) / 2.0fx + beam_width / 2.0fx;
        var speed: fx = speed_min + (q as fx) * 0.005fx;
        spawn vertical_corridor(center, halfsep, beam_width, speed, direction, warn, active);
        wave = wave + 1;
        side = -side;
        if wave < 16 { wait(90); } else { if wave == 16 { wait(42); } }
    }
    loop { wait(1); }
}
